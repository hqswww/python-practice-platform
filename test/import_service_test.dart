import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/models/test_record.dart';
import 'package:python_practice/services/import_service.dart';
import 'package:python_practice/services/progress_service.dart';

/// 用假 path_provider，避免真实文件系统依赖。
class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;
  late ImportService import;
  late ProgressService progress;

  setUp(() async {
    PathProviderPlatform.instance = _FakePathProvider();
    tmpDir = await Directory.systemTemp.createTemp('import_test');
    SharedPreferences.setMockInitialValues({});
    import = ImportService();
    progress = ProgressService();
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  File writeJson(Map<String, dynamic> data) {
    final f = File('${tmpDir.path}/progress.json');
    f.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(data),
    );
    return f;
  }

  Map<String, dynamic> exportLike({
    List<Map<String, dynamic>>? problems,
    List<Map<String, dynamic>>? history,
  }) {
    return {
      'exportedAt': '2026-08-08T00:00:00.000',
      'summary': {'solved': 2},
      'problems': problems ?? [],
      'testHistory': history ?? [],
    };
  }

  test('导入标记未解决的题（已解决并集）', () async {
    // 当前：题1已解决，题2未解决
    await progress.markSolved(1);
    final f = writeJson(exportLike(problems: [
      {'id': 1, 'solved': true},
      {'id': 2, 'solved': true}, // 导入里题2解决了
    ]));

    final s = await import.importFromFile(f.path);

    expect(await progress.isSolved(1), isTrue);
    expect(await progress.isSolved(2), isTrue);
    expect(s.solvedMarked, 1); // 只新标记了题2
    expect(s.message, contains('解决 1 题'));
  });

  test('错题次数取较大值合并', () async {
    // 当前：题1错2次
    await progress.setWrongCount(1, 2);
    // 导入：题1错5次（更大）→ 应为5；题2错3次 → 应为3
    final f = writeJson(exportLike(problems: [
      {'id': 1, 'wrongTimes': 5},
      {'id': 2, 'wrongTimes': 3},
    ]));

    await import.importFromFile(f.path);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('wrong_1'), 5);
    expect(prefs.getInt('wrong_2'), 3);
  });

  test('错题次数不会被导入减小', () async {
    await progress.setWrongCount(1, 10);
    final f = writeJson(exportLike(problems: [
      {'id': 1, 'wrongTimes': 3}, // 比当前小，不应回退
    ]));

    await import.importFromFile(f.path);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('wrong_1'), 10);
  });

  test('收藏取并集', () async {
    await progress.setFavorite(1, true); // 当前已收藏1
    final f = writeJson(exportLike(problems: [
      {'id': 1, 'favorite': false}, // 导入里没收藏1 → 不应取消
      {'id': 9, 'favorite': true}, // 导入新增收藏9
    ]));

    final s = await import.importFromFile(f.path);

    expect(await progress.isFavorite(1), isTrue);
    expect(await progress.isFavorite(9), isTrue);
    expect(s.favoritesAdded, 1);
  });

  test('测试历史按时间戳去重追加', () async {
    // 当前已有一条 1000ms 的记录
    await progress.addTestRecord(
      TestRecord(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
        correctCount: 2,
        totalCount: 3,
        items: [],
      ),
    );
    final f = writeJson(exportLike(history: [
      {
        'timestamp': '1970-01-01T00:00:01.000Z', // 1000ms，重复
        'correctCount': 2,
        'totalCount': 3,
        'items': [],
      },
      {
        'timestamp': '1970-01-01T00:00:02.000Z', // 2000ms，新增
        'correctCount': 1,
        'totalCount': 2,
        'items': [
          {
            'problemId': 5,
            'title': '题5',
            'solution': 'x=1',
            'wasCorrect': true,
            'myCode': 'x=1',
          },
        ],
      },
    ]));

    final s = await import.importFromFile(f.path);

    final records = await progress.testRecords();
    expect(records.length, 2); // 原有 + 新增1个
    expect(s.testRecordsAdded, 1);
    expect(s.testRecordsSkipped, 1);
  });

  test('找不到文件报错', () async {
    expect(
      () => import.importFromFile('${tmpDir.path}/nonexist.json'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('非法 JSON 报错', () async {
    final f = File('${tmpDir.path}/bad.json')..writeAsStringSync('not json');
    expect(
      () => import.importFromFile(f.path),
      throwsA(isA<FormatException>()),
    );
  });
}
