import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/programming_language.dart';
import '../models/test_record.dart';

/// 进度存储服务
///
/// 用 shared_preferences 持久化记录（**键里都带语言**）：
/// - 每道题是否已解决（`problem_{语言}_{题号}` -> 'solved'）
/// - 错题本（`wrong_{语言}_{题号}` -> 错误次数，int）
/// - 未作答标记（`unans_{语言}_{题号}` -> bool）
/// - 收藏（`fav_{语言}_{题号}` -> bool）
/// - 测试历史（`test_{时间戳}_{得分}_{微秒}` -> TestRecord 的 JSON）
///
/// **为什么键里必须带语言**：题号只在同一语言内唯一，C 的第 101 题和
/// Python 的第 101 题是完全不同的两道题。不带语言会互相覆盖进度。
///
/// **旧数据迁移**：加语言之前键是 `problem_101` 这种裸题号格式。
/// 首次读写时 [_migrateIfNeeded] 会把它们整体改写成 Python 的键，
/// 老用户进度不会丢。
class ProgressService {
  static const String _prefix = 'problem_';
  static const String _wrongPrefix = 'wrong_';
  static const String _unansPrefix = 'unans_';
  static const String _favPrefix = 'fav_';
  static const String _testPrefix = 'test_';
  static const String _solvedValue = 'solved';

  /// 记录进度数据格式版本的键。
  /// 缺失或 0 = 旧格式（键里没有语言）；1 = 新格式。
  static const String _schemaKey = 'progress_schema_version';
  static const int _schemaVersion = 1;

  /// 需要迁移的几种键前缀（测试历史键不含题号，不用迁移）
  static const List<String> _migratedPrefixes = [
    _prefix,
    _wrongPrefix,
    _unansPrefix,
    _favPrefix,
  ];

  /// 已解决的缓存：键为 `{语言}_{题号}`
  final Map<String, bool> _cache = {};

  /// 错题次数缓存：键为 `{语言}_{题号}`
  final Map<String, int> _wrongCache = {};

  SharedPreferences? _prefs;
  bool _migrated = false;

  /// 存储键：`{前缀}{语言}_{题号}`
  static String _key(
    String prefix,
    ProgrammingLanguage language,
    int problemId,
  ) =>
      '$prefix${language.id}_$problemId';

  /// 不带前缀的题目标识：`{语言}_{题号}`（缓存用）
  static String _ref(ProgrammingLanguage language, int problemId) =>
      '${language.id}_$problemId';

  /// 从存储键里解出 (语言, 题号)；格式不符返回 null。
  ///
  /// 用 `lastIndexOf('_')` 而不是第一个：题号一定是纯数字、绝不含下划线，
  /// 所以从后往前找分隔符最稳（万一将来语言 id 里带下划线也不会错）。
  static (ProgrammingLanguage, int)? _parseKey(String prefix, String key) {
    if (!key.startsWith(prefix)) return null;
    final rest = key.substring(prefix.length);
    final sep = rest.lastIndexOf('_');
    if (sep <= 0 || sep == rest.length - 1) return null;
    final langId = rest.substring(0, sep);
    final id = int.tryParse(rest.substring(sep + 1));
    if (id == null || !ProgrammingLanguage.isKnownId(langId)) return null;
    return (ProgrammingLanguage.fromId(langId), id);
  }

  Future<SharedPreferences> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!_migrated) {
      await _migrateIfNeeded();
      _migrated = true;
    }
    return _prefs!;
  }

  /// 把旧格式（键里无语言）的进度一次性改写成 Python 的键。
  ///
  /// 判别方式：前缀之后若是**纯数字**，就是旧格式。
  /// 新格式前缀之后是 `python_101`，`int.tryParse` 必然失败。
  /// 迁移完写版本号，之后不再扫描。
  Future<void> _migrateIfNeeded() async {
    final prefs = _prefs!;
    if ((prefs.getInt(_schemaKey) ?? 0) >= _schemaVersion) return;

    var moved = 0;
    for (final key in prefs.getKeys().toList()) {
      for (final prefix in _migratedPrefixes) {
        if (!key.startsWith(prefix)) continue;
        final rest = key.substring(prefix.length);
        // 不是纯数字 → 已经是新格式（或别的数据），跳过
        if (rest.isEmpty || int.tryParse(rest) == null) break;

        final newKey = '$prefix${ProgrammingLanguage.python.id}_$rest';
        final value = prefs.get(key);
        if (value is bool) {
          await prefs.setBool(newKey, value);
        } else if (value is int) {
          await prefs.setInt(newKey, value);
        } else if (value is double) {
          await prefs.setDouble(newKey, value);
        } else if (value is String) {
          await prefs.setString(newKey, value);
        } else if (value is List<String>) {
          await prefs.setStringList(newKey, value);
        }
        await prefs.remove(key);
        moved++;
        break;
      }
    }

    await prefs.setInt(_schemaKey, _schemaVersion);
    if (moved > 0) {
      debugPrint('进度数据迁移：$moved 项旧格式键已归到 Python');
    }
  }

  // ---------------- 已解决 ----------------

  /// 标记一道题已解决（同时从错题本移除）
  Future<void> markSolved(ProgrammingLanguage language, int problemId) async {
    final prefs = await _ensure();
    await prefs.setString(_key(_prefix, language, problemId), _solvedValue);
    _cache[_ref(language, problemId)] = true;
    await clearWrong(language, problemId);
  }

  /// 查询一道题是否已解决
  Future<bool> isSolved(ProgrammingLanguage language, int problemId) async {
    final ref = _ref(language, problemId);
    if (_cache.containsKey(ref)) return _cache[ref]!;
    final prefs = await _ensure();
    final solved =
        prefs.getString(_key(_prefix, language, problemId)) == _solvedValue;
    _cache[ref] = solved;
    return solved;
  }

  /// 批量查询一组题哪些已解决（题号 -> 是否已解决）
  Future<Map<int, bool>> solvedMap(
    ProgrammingLanguage language,
    List<int> ids,
  ) async {
    final map = <int, bool>{};
    for (final id in ids) {
      map[id] = await isSolved(language, id);
    }
    return map;
  }

  /// 某语言已解决的题数（只统计该语言的键）
  Future<int> solvedCount(ProgrammingLanguage language) async {
    final prefs = await _ensure();
    final tag = '${language.id}_';
    var solved = 0;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      if (!key.substring(_prefix.length).startsWith(tag)) continue;
      if (prefs.getString(key) == _solvedValue) solved++;
    }
    return solved;
  }

  // ---------------- 错题本 ----------------

  /// 记录一次错误（次数 +1）
  Future<void> recordWrong(ProgrammingLanguage language, int problemId) async {
    final prefs = await _ensure();
    final ref = _ref(language, problemId);
    final current = _wrongCache[ref] ??
        (prefs.getInt(_key(_wrongPrefix, language, problemId)) ?? 0);
    final next = current + 1;
    await prefs.setInt(_key(_wrongPrefix, language, problemId), next);
    _wrongCache[ref] = next;
  }

  /// 标记一道题为「未作答」并纳入错题本（交卷时对没做的题调用）
  Future<void> markUnanswered(
    ProgrammingLanguage language,
    int problemId,
  ) async {
    final prefs = await _ensure();
    await recordWrong(language, problemId); // 先计入错题本
    await prefs.setBool(_key(_unansPrefix, language, problemId), true);
  }

  /// 直接设置某题的错题次数（导入进度用；0 清除错题记录）
  Future<void> setWrongCount(
    ProgrammingLanguage language,
    int problemId,
    int count,
  ) async {
    final prefs = await _ensure();
    if (count <= 0) {
      await clearWrong(language, problemId);
      return;
    }
    await prefs.setInt(_key(_wrongPrefix, language, problemId), count);
    final unansKey = _key(_unansPrefix, language, problemId);
    if (prefs.containsKey(unansKey)) {
      await prefs.remove(unansKey);
    }
    _wrongCache[_ref(language, problemId)] = count;
  }

  /// 直接设置某题的「未作答」标志（导入进度用）
  Future<void> setUnanswered(
    ProgrammingLanguage language,
    int problemId,
    bool value,
  ) async {
    final prefs = await _ensure();
    final key = _key(_unansPrefix, language, problemId);
    if (value) {
      await prefs.setBool(key, true);
    } else {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
  }

  /// 直接设置某题的收藏状态（导入进度用，非 toggle）
  Future<void> setFavorite(
    ProgrammingLanguage language,
    int problemId,
    bool value,
  ) async {
    final prefs = await _ensure();
    await prefs.setBool(_key(_favPrefix, language, problemId), value);
  }

  /// 该错题是否来自「未作答」（而非做错）
  Future<bool> isUnanswered(
    ProgrammingLanguage language,
    int problemId,
  ) async {
    final prefs = await _ensure();
    return prefs.getBool(_key(_unansPrefix, language, problemId)) ?? false;
  }

  /// 批量取一组题目中哪些被标记为「未作答」
  Future<Set<int>> unansweredSet(
    ProgrammingLanguage language,
    List<int> ids,
  ) async {
    final prefs = await _ensure();
    final result = <int>{};
    for (final id in ids) {
      if (prefs.getBool(_key(_unansPrefix, language, id)) ?? false) {
        result.add(id);
      }
    }
    return result;
  }

  /// 清除某题错题记录（做对/移除时调用）
  Future<void> clearWrong(ProgrammingLanguage language, int problemId) async {
    final prefs = await _ensure();
    for (final p in [_wrongPrefix, _unansPrefix]) {
      final key = _key(p, language, problemId);
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
    _wrongCache.remove(_ref(language, problemId));
  }

  /// 某题错误次数（0 表示不在错题本）
  Future<int> wrongCountFor(ProgrammingLanguage language, int problemId) async {
    final ref = _ref(language, problemId);
    if (_wrongCache.containsKey(ref)) return _wrongCache[ref]!;
    final prefs = await _ensure();
    final count = prefs.getInt(_key(_wrongPrefix, language, problemId)) ?? 0;
    _wrongCache[ref] = count;
    return count;
  }

  /// 某语言的全部错题（题号 -> 错误次数），按错误次数降序
  Future<Map<int, int>> allWrong(ProgrammingLanguage language) async {
    final prefs = await _ensure();
    final map = <int, int>{};
    for (final key in prefs.getKeys()) {
      final parsed = _parseKey(_wrongPrefix, key);
      if (parsed == null || parsed.$1 != language) continue;
      map[parsed.$2] = prefs.getInt(key) ?? 0;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// 某语言的错题总数
  Future<int> wrongCount(ProgrammingLanguage language) async =>
      (await allWrong(language)).length;

  /// 某语言是否有错题
  Future<bool> hasWrong(ProgrammingLanguage language) async =>
      (await wrongCount(language)) > 0;

  // ---------------- 收藏 ----------------

  /// 切换某题的收藏状态，返回切换后是否已收藏
  Future<bool> toggleFavorite(
    ProgrammingLanguage language,
    int problemId,
  ) async {
    final prefs = await _ensure();
    final key = _key(_favPrefix, language, problemId);
    final now = !(prefs.getBool(key) ?? false);
    await prefs.setBool(key, now);
    return now;
  }

  /// 是否已收藏
  Future<bool> isFavorite(ProgrammingLanguage language, int problemId) async {
    final prefs = await _ensure();
    return prefs.getBool(_key(_favPrefix, language, problemId)) ?? false;
  }

  /// 某语言全部已收藏的题号
  Future<Set<int>> favoriteIds(ProgrammingLanguage language) async {
    final prefs = await _ensure();
    final result = <int>{};
    for (final key in prefs.getKeys()) {
      final parsed = _parseKey(_favPrefix, key);
      if (parsed == null || parsed.$1 != language) continue;
      if (prefs.getBool(key) ?? false) result.add(parsed.$2);
    }
    return result;
  }

  /// 某语言已收藏数量
  Future<int> favoriteCount(ProgrammingLanguage language) async =>
      (await favoriteIds(language)).length;

  // ---------------- 测试历史 ----------------

  /// 记录一次测试（追加到历史，时间戳保证唯一性）
  Future<void> addTestRecord(TestRecord record) async {
    final prefs = await _ensure();
    final key = '$_testPrefix${record.timestamp.millisecondsSinceEpoch}_'
        '${record.correctCount}_${DateTime.now().microsecond}';
    await prefs.setString(key, jsonEncode(record.toJson()));
  }

  /// 取全部测试记录（按时间倒序，最新在前）。
  /// [language] 指定时只返回该语言的测试。
  Future<List<TestRecord>> testRecords({ProgrammingLanguage? language}) async {
    final prefs = await _ensure();
    final list = <TestRecord>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_testPrefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final rec = TestRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (language != null && rec.language != language) continue;
        list.add(rec);
      } catch (_) {
        // 跳过损坏的记录
      }
    }
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// 测试总次数（可按语言过滤）
  Future<int> testCount({ProgrammingLanguage? language}) async =>
      (await testRecords(language: language)).length;

  // ---------------- 重置 ----------------

  /// 清除全部进度（含错题本、测试历史）—— 所有语言一起清
  Future<void> resetAll() async {
    final prefs = await _ensure();
    final toRemove = prefs.getKeys()
        .where((k) =>
            k.startsWith(_prefix) ||
            k.startsWith(_wrongPrefix) ||
            k.startsWith(_unansPrefix) ||
            k.startsWith(_favPrefix) ||
            k.startsWith(_testPrefix))
        .toList();
    for (final key in toRemove) {
      await prefs.remove(key);
    }
    _cache.clear();
    _wrongCache.clear();
  }
}
