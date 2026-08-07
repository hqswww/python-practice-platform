import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/test_record.dart';

/// 进度存储服务
///
/// 用 shared_preferences 持久化记录：
/// - 每道题是否已解决（problem_{id} -> 'solved'）
/// - 错题本（wrong_{id} -> 错误次数，int）
/// - 测试历史（test_{timestamp} -> TestRecord 的 JSON 字符串）
class ProgressService {
  static const String _prefix = 'problem_';
  static const String _wrongPrefix = 'wrong_';
  static const String _unansPrefix = 'unans_';
  static const String _favPrefix = 'fav_';
  static const String _testPrefix = 'test_';
  static const String _solvedValue = 'solved';

  /// 记录/查询某道题是否已解决（缓存避免频繁读盘）
  final Map<int, bool> _cache = {};
  /// 错题次数缓存（题目 id -> 次数）
  final Map<int, int> _wrongCache = {};
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ---------------- 已解决 ----------------

  /// 标记一道题已解决（同时从错题本移除）
  Future<void> markSolved(int problemId) async {
    final prefs = await _ensure();
    await prefs.setString('$_prefix$problemId', _solvedValue);
    _cache[problemId] = true;
    await clearWrong(problemId);
  }

  /// 查询一道题是否已解决
  Future<bool> isSolved(int problemId) async {
    if (_cache.containsKey(problemId)) return _cache[problemId]!;
    final prefs = await _ensure();
    final solved = prefs.getString('$_prefix$problemId') == _solvedValue;
    _cache[problemId] = solved;
    return solved;
  }

  /// 批量查询一组题哪些已解决
  Future<Map<int, bool>> solvedMap(List<int> ids) async {
    final map = <int, bool>{};
    for (final id in ids) {
      map[id] = await isSolved(id);
    }
    return map;
  }

  /// 统计所有题目的完成情况：返回 (已解决数, 总数)
  Future<(int, int)> summary(int totalCount) async {
    final prefs = await _ensure();
    final keys = prefs.getKeys();
    var solved = 0;
    for (final key in keys) {
      if (key.startsWith(_prefix) &&
          prefs.getString(key) == _solvedValue) {
        solved++;
      }
    }
    for (final entry in _cache.entries) {
      if (entry.value) solved++;
    }
    if (solved > totalCount) solved = totalCount;
    return (solved, totalCount);
  }

  // ---------------- 错题本 ----------------

  /// 记录一次错误（次数 +1）
  Future<void> recordWrong(int problemId) async {
    final prefs = await _ensure();
    final current = _wrongCache[problemId] ??
        (prefs.getInt('$_wrongPrefix$problemId') ?? 0);
    final next = current + 1;
    await prefs.setInt('$_wrongPrefix$problemId', next);
    _wrongCache[problemId] = next;
  }

  /// 标记一道题为“未作答”并纳入错题本（交卷时对没做的题调用）
  Future<void> markUnanswered(int problemId) async {
    final prefs = await _ensure();
    await recordWrong(problemId); // 先计入错题本
    await prefs.setBool('$_unansPrefix$problemId', true);
  }

  /// 该错题是否来自“未作答”（而非做错）
  Future<bool> isUnanswered(int problemId) async {
    final prefs = await _ensure();
    return prefs.getBool('$_unansPrefix$problemId') ?? false;
  }

  /// 批量取一组题目中哪些被标记为“未作答”
  Future<Set<int>> unansweredSet(List<int> ids) async {
    final prefs = await _ensure();
    final result = <int>{};
    for (final id in ids) {
      if (prefs.getBool('$_unansPrefix$id') ?? false) {
        result.add(id);
      }
    }
    return result;
  }

  // ---------------- 收藏 ----------------

  /// 切换某题的收藏状态，返回切换后是否已收藏
  Future<bool> toggleFavorite(int problemId) async {
    final prefs = await _ensure();
    final key = '$_favPrefix$problemId';
    final now = !(prefs.getBool(key) ?? false);
    await prefs.setBool(key, now);
    return now;
  }

  /// 是否已收藏
  Future<bool> isFavorite(int problemId) async {
    final prefs = await _ensure();
    return prefs.getBool('$_favPrefix$problemId') ?? false;
  }

  /// 全部已收藏的题目 id（用于“从题库中取出收藏”排序）
  Future<Set<int>> favoriteIds() async {
    final prefs = await _ensure();
    return prefs.getKeys()
        .where((k) => k.startsWith(_favPrefix) && (prefs.getBool(k) ?? false))
        .map((k) => int.tryParse(k.substring(_favPrefix.length)))
        .whereType<int>()
        .toSet();
  }

  /// 已收藏数量
  Future<int> favoriteCount() async {
    return (await favoriteIds()).length;
  }

  /// 清除某题错题记录（做对/移除时调用）
  Future<void> clearWrong(int problemId) async {
    final prefs = await _ensure();
    if (prefs.containsKey('$_wrongPrefix$problemId')) {
      await prefs.remove('$_wrongPrefix$problemId');
    }
    if (prefs.containsKey('$_unansPrefix$problemId')) {
      await prefs.remove('$_unansPrefix$problemId');
    }
    _wrongCache.remove(problemId);
  }

  /// 某题错误次数（0 表示不在错题本）
  Future<int> wrongCountFor(int problemId) async {
    if (_wrongCache.containsKey(problemId)) return _wrongCache[problemId]!;
    final prefs = await _ensure();
    final count = prefs.getInt('$_wrongPrefix$problemId') ?? 0;
    _wrongCache[problemId] = count;
    return count;
  }

  /// 获取所有错题 (题目 id -> 错误次数)，按错误次数降序
  Future<Map<int, int>> allWrong() async {
    final prefs = await _ensure();
    final map = <int, int>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_wrongPrefix)) {
        final idStr = key.substring(_wrongPrefix.length);
        final id = int.tryParse(idStr);
        if (id != null) {
          map[id] = prefs.getInt(key) ?? 0;
        }
      }
    }
    final sorted = Map.fromEntries(
      map.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );
    return sorted;
  }

  /// 错题总数
  Future<int> wrongCount() async {
    return (await allWrong()).length;
  }

  /// 是否有错题
  Future<bool> hasWrong() async {
    return (await wrongCount()) > 0;
  }

  // ---------------- 测试历史 ----------------

  /// 记录一次测试（追加到历史，时间戳保证唯一性）
  Future<void> addTestRecord(TestRecord record) async {
    final prefs = await _ensure();
    final key = '$_testPrefix${record.timestamp.millisecondsSinceEpoch}_'
        '${record.correctCount}_${DateTime.now().microsecond}';
    await prefs.setString(key, jsonEncode(record.toJson()));
  }

  /// 取全部测试记录（按时间倒序，最新在前）
  Future<List<TestRecord>> testRecords() async {
    final prefs = await _ensure();
    final list = <TestRecord>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_testPrefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        list.add(
          TestRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        // 跳过损坏的记录
      }
    }
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// 测试总次数
  Future<int> testCount() async {
    return (await testRecords()).length;
  }

  // ---------------- 重置 ----------------

  /// 清除全部进度（含错题本、测试历史）
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
