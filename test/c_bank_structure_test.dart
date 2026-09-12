import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/data/problem_repository.dart';
import 'package:python_practice/models/programming_language.dart';

/// C 题库的结构守卫。
///
/// 内容对不对由「参考答案必须判过自己全部用例」那条测试保证（见 c_runtime_test.dart），
/// 这里守的是**结构不变量**——这类问题不会让程序报错，只会让学生的进度悄悄串掉。
///
/// 注意：用例会读 assets，而 rootBundle 在同一个测试文件里只能成功加载一次，
/// 所以整个文件只有这一个用例碰题库。
void main() {
  // 读 assets 需要初始化测试 binding（普通 test() 不会自动做，
  // 只有 testWidgets 才会）。漏了会报 "Binding has not yet been initialized"，
  // 而且题库会静默加载成空数组 —— 断言失败时看起来像「题库没有分类」，
  // 很容易被误判成内容问题。
  TestWidgetsFlutterBinding.ensureInitialized();

  test('C 题库结构符合规格', () async {
    final cats = await ProblemRepository()
        .loadCategories(language: ProgrammingLanguage.c);

    // 允许「还没写完」——写一个分类就自动纳入校验，不用改测试
    expect(cats, isNotEmpty, reason: 'C 至少应有一个分类');

    final seenIds = <int, String>{}; // id -> 出处，用来查跨分类撞号

    for (final cat in cats) {
      // 分类 key 形如 01_basics：前两位是分类序号
      final m = RegExp(r'^(\d{2})_').firstMatch(cat.key);
      expect(m, isNotNull,
          reason: '分类 key「${cat.key}」应为 NN_xxx 格式（序号决定 id 段）');
      final ordinal = int.parse(m!.group(1)!);

      expect(cat.language, ProgrammingLanguage.c,
          reason: '分类 ${cat.key} 的语言应为 C');
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

        expect(p.language, ProgrammingLanguage.c,
            reason: '题 ${p.id} 的语言与分类不一致');
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
      }
    }
  });
}
