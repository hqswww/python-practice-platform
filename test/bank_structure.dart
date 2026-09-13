import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/data/problem_repository.dart';
import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/services/language_runtime.dart';
import 'package:python_practice/services/source_check.dart';

/// 题库结构守卫的共用实现（C / C++ 各有一个薄薄的 `*_bank_structure_test.dart`）。
///
/// 内容对不对由「参考答案必须判过自己全部用例」那条测试保证
/// （见 c_runtime_test.dart / cpp_runtime_test.dart），
/// 这里守的是**结构不变量**——这类问题不会让程序报错，只会让学生的进度悄悄串掉。
///
/// 文件名故意不以 `_test.dart` 结尾，这样 `flutter test` 不会把它当成一个套件。
///
/// 为什么每个语言要单独一个测试文件而不是一个文件里调两次：
/// rootBundle 在同一个测试文件里只能成功加载一次，第二次调用会挂住。
/// 每个测试文件跑在独立 isolate 里，各自有一份干净的 bundle，所以
/// 「一个文件一种语言」是唯一稳妥的组织方式。
Future<void> verifyBankStructure(
  ProgrammingLanguage language, {
  int expectedCategories = 12,
}) async {
  // 读 assets 需要初始化测试 binding（普通 test() 不会自动做，
  // 只有 testWidgets 才会）。漏了会报 "Binding has not yet been initialized"，
  // 而且题库会静默加载成空数组 —— 断言失败时看起来像「题库没有分类」，
  // 很容易被误判成内容问题。
  TestWidgetsFlutterBinding.ensureInitialized();

  final cats = await ProblemRepository().loadCategories(language: language);

  // 允许「还没写完」——写一个分类就自动纳入校验，不用改测试
  expect(cats, isNotEmpty, reason: '${language.displayName} 至少应有一个分类');
  // 数量卡死而不是只卡上限：分类数变少的两种可能都是 bug ——
  // 题库文件被删了，或者文件在但 problem_repository 的分类表漏登记了
  // （后者不会让任何代码报错，只会让这门语言在语言切换器里少一块）。
  expect(cats.length, expectedCategories,
      reason: '${language.displayName} 应有 $expectedCategories 个分类，实际 ${cats.length} 个；'
          '少了多半是 problem_repository.dart 的 _categoryMeta 漏登记');

  final seenIds = <int, String>{}; // id -> 出处，用来查跨分类撞号

  for (final cat in cats) {
    // 分类 key 形如 01_basics：前两位是分类序号
    final m = RegExp(r'^(\d{2})_').firstMatch(cat.key);
    expect(m, isNotNull,
        reason: '分类 key「${cat.key}」应为 NN_xxx 格式（序号决定 id 段）');
    final ordinal = int.parse(m!.group(1)!);

    expect(cat.language, language,
        reason: '分类 ${cat.key} 的语言应为 ${language.displayName}');
    expect(cat.problems.length, 6,
        reason: '分类 ${cat.key}（${cat.name}）应有 6 道题，'
            '实际 ${cat.problems.length} 道');

    final expected = [for (var i = 1; i <= 6; i++) ordinal * 100 + i];
    final actual = cat.problems.map((p) => p.id).toList()..sort();
    expect(actual, expected,
        reason: '分类 ${cat.key} 的 id 必须是 ${expected.first}~${expected.last}；'
            '越界或乱序会导致进度与其它分类串号。实际：$actual');

    for (final p in cat.problems) {
      expect(seenIds.containsKey(p.id), isFalse,
          reason: 'id ${p.id} 在「${seenIds[p.id]}」和「${cat.key}」里重复了 —— '
              '进度键是「语言_题号」，撞号会让两道题共享进度');
      seenIds[p.id] = cat.key;

      expect(p.language, language, reason: '题 ${p.id} 的语言与分类不一致');
      expect(p.title.trim(), isNotEmpty, reason: '题 ${p.id} 缺标题');
      expect(p.description.trim(), isNotEmpty, reason: '题 ${p.id} 缺描述');
      expect(p.inputFormat.trim(), isNotEmpty, reason: '题 ${p.id} 缺输入格式');
      expect(p.outputFormat.trim(), isNotEmpty, reason: '题 ${p.id} 缺输出格式');
      expect(p.testCases, isNotEmpty, reason: '题 ${p.id} 没有测试用例');
      expect(p.hints, isNotEmpty, reason: '题 ${p.id} 没有提示');
      expect(p.solution.trim(), isNotEmpty, reason: '题 ${p.id} 没有参考答案');
      expect(p.tutorial, isNotEmpty,
          reason: '题 ${p.id}「${p.title}」没有教程 —— '
              '这个平台的定位是「边学边练」，教程不能缺');

      for (var i = 0; i < p.testCases.length; i++) {
        final tc = p.testCases[i];
        expect(tc.output.trim().isNotEmpty, isTrue,
            reason: '题 ${p.id} 用例 ${i + 1} 的期望输出是空的');
      }

      // ── 源码语法要求（见 source_check.dart）
      if (p.sourceRequirements.isNotEmpty) {
        // 检查名写错的话，运行时按「满足」处理（不冤判学生），
        // 于是错了也没人知道 —— 所以必须在这里拦住。
        expect(unknownSourceChecks(p.sourceRequirements), isEmpty,
            reason: '题 ${p.id}「${p.title}」用了不存在的检查名：'
                '${unknownSourceChecks(p.sourceRequirements)}；'
                '可用的是 ${kSourceChecks.keys.join('、')}');

        for (final req in p.sourceRequirements) {
          expect(req.label.trim(), isNotEmpty,
              reason: '题 ${p.id} 的要求 ${req.check} 缺 label（学生看不到要改什么）');
          expect(req.hint.trim(), isNotEmpty,
              reason: '题 ${p.id} 的要求 ${req.check} 缺 hint（学生不知道怎么改）');
        }

        // ⚠️ 这条是整个机制的**底线**：参考答案必须满足它自己声明的每一条要求。
        // 检查是启发式的文本匹配，写宽了挡不住作弊、写窄了连正确答案都判不过 ——
        // 后者是最坏的情况（照抄参考答案都过不了），所以用一个测试钉死。
        final solution = runtimeFor(language)
            .stripCommentsAndLiterals(p.solution);
        final unmet =
            unmetSourceRequirements(p.sourceRequirements, solution);
        expect(unmet, isEmpty,
            reason: '题 ${p.id}「${p.title}」的参考答案满足不了自己声明的源码要求：'
                '${unmet.map((r) => r.check).join('、')} —— '
                '这样学生照抄参考答案都会判不过');
      }
    }
  }
}
