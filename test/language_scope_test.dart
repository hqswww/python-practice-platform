import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/models/problem.dart';
import 'package:python_practice/models/problem_category.dart';
import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/models/test_record.dart';
import 'package:python_practice/services/progress_service.dart';

/// 多语言改造的数据层：进度主键带语言 + 旧数据迁移。
///
/// 这是「加 C/C++」的地基：题号只在同一语言内唯一，
/// 不带语言的键会让 C 的第 101 题和 Python 的第 101 题互相覆盖。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Problem makeProblem(int id, ProgrammingLanguage lang) => Problem(
        id: id,
        title: '题 $id',
        difficulty: Difficulty.easy,
        description: '',
        inputFormat: '',
        outputFormat: '',
        sampleInput: '',
        sampleOutput: '',
        testCases: const [],
        hints: const [],
        language: lang,
      );

  group('ProgrammingLanguage', () {
    test('fromId 对已知标识返回对应语言', () {
      expect(ProgrammingLanguage.fromId('python'), ProgrammingLanguage.python);
      expect(ProgrammingLanguage.fromId('c'), ProgrammingLanguage.c);
      expect(ProgrammingLanguage.fromId('cpp'), ProgrammingLanguage.cpp);
    });

    test('未知/空标识回退到 python（老数据没有语言字段）', () {
      expect(ProgrammingLanguage.fromId(null), ProgrammingLanguage.python);
      expect(ProgrammingLanguage.fromId(''), ProgrammingLanguage.python);
      expect(ProgrammingLanguage.fromId('rust'), ProgrammingLanguage.python);
    });

    test('只有编译型语言标记 compiled', () {
      expect(ProgrammingLanguage.python.compiled, isFalse);
      expect(ProgrammingLanguage.c.compiled, isTrue);
      expect(ProgrammingLanguage.cpp.compiled, isTrue);
    });

    test('id 是稳定标识，不随显示名变化', () {
      // 这些 id 已经写进用户的进度数据，改了等于让进度失联
      expect(ProgrammingLanguage.python.id, 'python');
      expect(ProgrammingLanguage.c.id, 'c');
      expect(ProgrammingLanguage.cpp.id, 'cpp');
      expect(ProgrammingLanguage.cpp.displayName, 'C++');
    });

    test('扩展名用于判题临时文件名', () {
      expect(ProgrammingLanguage.python.fileExtension, 'py');
      expect(ProgrammingLanguage.c.fileExtension, 'c');
      expect(ProgrammingLanguage.cpp.fileExtension, 'cpp');
    });
  });

  group('Problem.progressKey', () {
    test('格式是 语言_题号', () {
      expect(makeProblem(101, ProgrammingLanguage.python).progressKey,
          'python_101');
      expect(makeProblem(101, ProgrammingLanguage.c).progressKey, 'c_101');
    });

    test('同一题号在两门语言下不冲突（这正是改动的原因）', () {
      final py = makeProblem(101, ProgrammingLanguage.python);
      final c = makeProblem(101, ProgrammingLanguage.c);
      expect(py.progressKey, isNot(c.progressKey));
    });

    test('分类的语言与题目一致（仓库统一赋值）', () {
      final cat = ProblemCategory(
        key: 'k',
        name: 'n',
        description: 'd',
        language: ProgrammingLanguage.c,
        problems: [makeProblem(1, ProgrammingLanguage.c)],
      );
      expect(cat.language, cat.problems.first.language);
    });
  });

  group('进度按语言隔离', () {
    test('同一题号在两门语言下互不影响', () async {
      final p = ProgressService();
      await p.markSolved(ProgrammingLanguage.python, 101);
      await p.setWrongCount(ProgrammingLanguage.c, 101, 3);

      expect(await p.isSolved(ProgrammingLanguage.python, 101), isTrue);
      expect(await p.isSolved(ProgrammingLanguage.c, 101), isFalse,
          reason: 'C 的同一题号不该被 Python 的进度影响');

      expect(await p.wrongCountFor(ProgrammingLanguage.c, 101), 3);
      expect(await p.wrongCountFor(ProgrammingLanguage.python, 101), 0);
    });

    test('收藏与未作答同样按语言隔离', () async {
      final p = ProgressService();
      await p.setFavorite(ProgrammingLanguage.python, 5, true);
      expect(await p.isFavorite(ProgrammingLanguage.python, 5), isTrue);
      expect(await p.isFavorite(ProgrammingLanguage.c, 5), isFalse);

      await p.markUnanswered(ProgrammingLanguage.c, 5);
      expect(await p.isUnanswered(ProgrammingLanguage.c, 5), isTrue);
      expect(await p.isUnanswered(ProgrammingLanguage.python, 5), isFalse);
    });

    test('语言级统计只数自己那一门', () async {
      final p = ProgressService();
      await p.markSolved(ProgrammingLanguage.python, 1);
      await p.markSolved(ProgrammingLanguage.python, 2);
      await p.markSolved(ProgrammingLanguage.c, 1);
      await p.setWrongCount(ProgrammingLanguage.c, 9, 2);

      expect(await p.solvedCount(ProgrammingLanguage.python), 2);
      expect(await p.solvedCount(ProgrammingLanguage.c), 1);
      expect(await p.wrongCount(ProgrammingLanguage.python), 0);
      expect(await p.wrongCount(ProgrammingLanguage.c), 1);
    });
  });

  group('旧数据迁移（老用户进度不能丢）', () {
    test('旧格式键会改写成 python 的键，值原样保留', () async {
      SharedPreferences.setMockInitialValues({
        'problem_101': 'solved',
        'wrong_202': 4,
        'unans_303': true,
        'fav_404': true,
      });
      final p = ProgressService();

      // 触发一次读写 → 迁移
      expect(await p.isSolved(ProgrammingLanguage.python, 101), isTrue);
      expect(await p.wrongCountFor(ProgrammingLanguage.python, 202), 4);
      expect(await p.isUnanswered(ProgrammingLanguage.python, 303), isTrue);
      expect(await p.isFavorite(ProgrammingLanguage.python, 404), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('problem_python_101'), 'solved');
      expect(prefs.getInt('wrong_python_202'), 4);
      expect(prefs.getBool('unans_python_303'), isTrue);
      expect(prefs.getBool('fav_python_404'), isTrue);

      // 旧键应被清掉，否则统计会重复计数
      expect(prefs.containsKey('problem_101'), isFalse);
      expect(prefs.containsKey('wrong_202'), isFalse);
    });

    test('迁移后统计数字正确（不会把旧键新键都算上）', () async {
      SharedPreferences.setMockInitialValues({
        'problem_1': 'solved',
        'problem_2': 'solved',
      });
      final p = ProgressService();
      // 先触发迁移
      await p.isSolved(ProgrammingLanguage.python, 1);
      expect(await p.solvedCount(ProgrammingLanguage.python), 2,
          reason: '迁移后应恰好 2 题，重复计数说明旧键没清掉');
    });

    test('迁移是幂等的（重复调用不重复计数、不报错）', () async {
      SharedPreferences.setMockInitialValues({'problem_7': 'solved'});
      final p = ProgressService();
      await p.isSolved(ProgrammingLanguage.python, 7);
      await p.isSolved(ProgrammingLanguage.python, 7);
      expect(await p.solvedCount(ProgrammingLanguage.python), 1);
    });

    test('已经是新格式的键不会被二次迁移', () async {
      SharedPreferences.setMockInitialValues({
        'problem_c_88': 'solved',
      });
      final p = ProgressService();
      await p.isSolved(ProgrammingLanguage.python, 1); // 触发迁移

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('problem_c_88'), 'solved',
          reason: '新格式键必须原样保留');
      expect(prefs.containsKey('problem_python_c_88'), isFalse,
          reason: '不该被当成旧键再套一层语言');
    });

    test('标记了版本号，后续不再扫描', () async {
      SharedPreferences.setMockInitialValues({'problem_1': 'solved'});
      final p = ProgressService();
      await p.isSolved(ProgrammingLanguage.python, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('progress_schema_version'), 1);
    });
  });

  group('TestRecord 带语言', () {
    test('序列化往返保留语言', () {
      final rec = TestRecord(
        timestamp: DateTime(2026, 9, 10),
        correctCount: 3,
        totalCount: 5,
        language: ProgrammingLanguage.c,
        items: const [],
      );
      final back = TestRecord.fromJson(rec.toJson());
      expect(back.language, ProgrammingLanguage.c);
    });

    test('老记录（无 language 字段）回退为 python', () {
      final back = TestRecord.fromJson({
        'timestamp': '2026-09-10T00:00:00.000',
        'correctCount': 1,
        'totalCount': 2,
        'items': <dynamic>[],
      });
      expect(back.language, ProgrammingLanguage.python);
    });

    test('测试历史可按语言过滤', () async {
      final p = ProgressService();
      await p.addTestRecord(TestRecord(
        timestamp: DateTime(2026, 1, 1),
        correctCount: 1,
        totalCount: 1,
        language: ProgrammingLanguage.python,
        items: const [],
      ));
      await p.addTestRecord(TestRecord(
        timestamp: DateTime(2026, 1, 2),
        correctCount: 1,
        totalCount: 1,
        language: ProgrammingLanguage.c,
        items: const [],
      ));

      expect(await p.testCount(), 2, reason: '不传语言 = 全部');
      expect(await p.testCount(language: ProgrammingLanguage.python), 1);
      expect(await p.testCount(language: ProgrammingLanguage.c), 1);
    });
  });
}
