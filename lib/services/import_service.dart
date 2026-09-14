import 'dart:convert';
import 'dart:io';

import '../models/programming_language.dart';
import '../models/test_record.dart';
import 'progress_service.dart';

/// 导入结果统计（供 UI 展示）
class ProgressImportSummary {
  final int problemsTotal;
  final int solvedMarked;
  final int favoritesAdded;
  final int testRecordsAdded;
  final int testRecordsSkipped;
  final String message;

  const ProgressImportSummary({
    required this.problemsTotal,
    required this.solvedMarked,
    required this.favoritesAdded,
    required this.testRecordsAdded,
    required this.testRecordsSkipped,
    required this.message,
  });
}

/// 进度导入服务
///
/// 读取导出的 JSON 进度文件，**合并**进当前进度（取并集）：
/// - 已解决：导入里「已解决」的题 → 若当前未解决则标记为已解决（不会清掉当前已解决的）
/// - 错题：当前与导入各取**较大**的错误次数（不因导入而减少）
/// - 未作答 / 收藏：与当前取并集
/// - 测试历史：按时间戳去重后追加
class ImportService {
  final ProgressService _progress = ProgressService();

  /// 从 JSON 文件路径导入并合并进度。
  Future<ProgressImportSummary> importFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('导入文件不存在');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('不是有效的进度 JSON');
    }
    return _merge(decoded);
  }

  /// 合并一份解析后的进度数据到当前进度。
  ///
  /// 语言从数据里的 `language` 字段读；**老导出文件没有这个字段**，
  /// 那时平台上只有 Python，所以 [ProgrammingLanguage.fromId] 会回退到 Python，
  /// 老文件照样能正确导入。
  Future<ProgressImportSummary> _merge(Map<String, dynamic> data) async {
    final lang = ProgrammingLanguage.fromId(data['language'] as String?);
    final problems = data['problems'] as List? ?? [];
    var solvedMarked = 0;
    var favoritesAdded = 0;

    for (final raw in problems) {
      if (raw is! Map) continue;
      final id = int.tryParse(raw['id']?.toString() ?? '');
      if (id == null) continue;

      final importedSolved = raw['solved'] == true;
      final importedWrong = (raw['wrongTimes'] as num?)?.toInt() ?? 0;
      final importedUnanswered = raw['unanswered'] == true;
      final importedFavorite = raw['favorite'] == true;

      // 已解决：取并集（导入里有且当前未解决 → 标记；已解决则顺带清错题）
      final isSolvedNow = await _progress.isSolved(lang, id);
      if (importedSolved && !isSolvedNow) {
        await _progress.markSolved(lang, id);
        solvedMarked++;
      } else if (importedSolved && isSolvedNow) {
        // 已解决但可能残留错题记录 → 清掉
        await _progress.markSolved(lang, id);
      }

      // 错题次数：取较大值合并（未解决/导入有错题数时才写）
      final wrongNow = await _progress.wrongCountFor(lang, id);
      if (importedWrong > wrongNow) {
        await _progress.setWrongCount(lang, id, importedWrong);
      }

      // 未作答标志：取并集
      if (importedUnanswered) {
        await _progress.setUnanswered(lang, id, true);
      }

      // 收藏：取并集
      if (importedFavorite && !(await _progress.isFavorite(lang, id))) {
        await _progress.setFavorite(lang, id, true);
        favoritesAdded++;
      }
    }

    // 测试历史：按时间戳去重后追加
    var testAdded = 0;
    var testSkipped = 0;
    final history = data['testHistory'] as List? ?? [];
    final existing = await _progress.testRecords();
    final existingStamps = existing
        .map((r) => r.timestamp.millisecondsSinceEpoch)
        .toSet();
    for (final raw in history) {
      if (raw is! Map) {
        testSkipped++;
        continue;
      }
      try {
        final rec = TestRecord.fromJson(raw as Map<String, dynamic>);
        final stamp = rec.timestamp.millisecondsSinceEpoch;
        if (existingStamps.contains(stamp)) {
          testSkipped++;
          continue;
        }
        existingStamps.add(stamp);
        await _progress.addTestRecord(rec);
        testAdded++;
      } catch (_) {
        testSkipped++;
      }
    }

    // 练习活动：同日取较大值（见 ProgressService.mergeActivity）。
    // 老导出文件没有这个字段 → 当成空，不影响导入。
    var activityDays = 0;
    final rawActivity = data['activity'];
    if (rawActivity is Map) {
      final incoming = <DateTime, int>{};
      rawActivity.forEach((k, v) {
        final day = DateTime.tryParse(k.toString());
        final n = (v as num?)?.toInt() ?? 0;
        if (day != null && n > 0) {
          incoming[DateTime(day.year, day.month, day.day)] = n;
        }
      });
      if (incoming.isNotEmpty) {
        activityDays = await _progress.mergeActivity(lang, incoming);
      }
    }

    final message =
        '已导入：解决 $solvedMarked 题 · 收藏 +$favoritesAdded · '
        '测试历史 +$testAdded 条${testSkipped > 0 ? '（跳过重复 $testSkipped）' : ''}'
        '${activityDays > 0 ? ' · 练习记录 +$activityDays 天' : ''}';

    return ProgressImportSummary(
      problemsTotal: problems.length,
      solvedMarked: solvedMarked,
      favoritesAdded: favoritesAdded,
      testRecordsAdded: testAdded,
      testRecordsSkipped: testSkipped,
      message: message,
    );
  }
}
