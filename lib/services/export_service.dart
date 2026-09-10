import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/problem_repository.dart';
import '../models/problem.dart';
import '../models/programming_language.dart';
import 'language_service.dart';
import 'progress_service.dart';

/// 进度导出服务
///
/// 把当前进度（已解决/错题/收藏/未作答/测试历史）与题库信息，
/// 导出成 JSON 或 CSV 文件，写入系统的文档目录。
class ExportService {
  final ProgressService _progress = ProgressService();
  final ProblemRepository _repo = ProblemRepository();

  /// 收集完整进度数据供导出使用。
  ///
  /// [language] 为空时导出**当前语言**。导出的 JSON 里带 `language` 字段，
  /// 导入时据此归位（老导出文件没有该字段，按 Python 处理）。
  Future<Map<String, dynamic>> collect({ProgrammingLanguage? language}) async {
    final lang = language ?? languageService.value;
    final cats = await _repo.loadCategories(language: lang);
    final all = <Problem>[];
    final catOf = <int, String>{};
    for (final c in cats) {
      for (final p in c.problems) {
        all.add(p);
        catOf[p.id] = c.name;
      }
    }
    final ids = all.map((p) => p.id).toList();
    final solved = await _progress.solvedMap(lang, ids);
    final wrong = await _progress.allWrong(lang);
    final unans = await _progress.unansweredSet(lang, ids);
    final favs = await _progress.favoriteIds(lang);
    final records = await _progress.testRecords(language: lang);

    final solvedNow = ids.where((id) => solved[id] == true).length;

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      // 语言标识：导入时据此把进度写回对应语言（老文件缺这个字段 → Python）
      'language': lang.id,
      'summary': {
        'totalProblems': all.length,
        'solved': solvedNow,
        'solvedPercent':
            all.isEmpty ? 0 : (solvedNow / all.length * 100).toStringAsFixed(1),
        'wrongProblems': wrong.length,
        'favorites': favs.length,
        'testCount': records.length,
      },
      'problems': all.map((p) {
        return {
          'id': p.id,
          'title': p.title,
          'difficulty': p.difficulty.value,
          'category': catOf[p.id] ?? '',
          'solved': solved[p.id] == true,
          'wrongTimes': wrong[p.id] ?? 0,
          'unanswered': unans.contains(p.id),
          'favorite': favs.contains(p.id),
        };
      }).toList(),
      'testHistory': records.map((r) {
        return {
          'timestamp': r.timestamp.toIso8601String(),
          'correctCount': r.correctCount,
          'totalCount': r.totalCount,
          'score': r.score,
          'passed': r.passed,
          'items': r.items.map((e) => e.toJson()).toList(),
        };
      }).toList(),
    };
  }

  /// 导出为 JSON 文件，返回写入路径。
  Future<String> exportJson() async {
    final data = await collect();
    final name = _fileName('progress', 'json');
    final dir = await _exportDir();
    final file = File('${dir.path}/$name');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  /// 导出为 CSV 文件（每题一行），返回写入路径。
  Future<String> exportCsv() async {
    final data = await collect();
    final name = _fileName('progress', 'csv');
    final dir = await _exportDir();
    final file = File('${dir.path}/$name');

    final buf = StringBuffer();
    buf.writeln('id,title,category,difficulty,solved,wrongTimes,unanswered,'
        'favorite,language');
    for (final p in data['problems'] as List) {
      final m = p as Map;
      buf.writeln([
        _csvCell(m['id'].toString()),
        _csvCell(m['title'].toString()),
        _csvCell(m['category'].toString()),
        _csvCell(m['difficulty'].toString()),
        _csvCell(m['solved'].toString()),
        _csvCell(m['wrongTimes'].toString()),
        _csvCell(m['unanswered'].toString()),
        _csvCell(m['favorite'].toString()),
        _csvCell((data['language'] ?? '').toString()),
      ].join(','));
    }
    await file.writeAsString(buf.toString());
    return file.path;
  }

  /// 取导出目录（文档目录；不可用时退回临时目录）。
  Future<Directory> _exportDir() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/PythonPractice导出');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  String _fileName(String stem, String ext) {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final ts =
        '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}'
        '${two(t.second)}';
    return '${stem}_$ts.$ext';
  }

  /// CSV 单元格包装（转义逗号/引号/换行）。
  static String _csvCell(String v) {
    return '"${v.replaceAll('"', '""').replaceAll('\n', ' ')}"';
  }
}
