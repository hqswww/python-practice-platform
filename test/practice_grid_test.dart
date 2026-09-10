import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/models/problem.dart';
import 'package:python_practice/models/problem_category.dart';
import 'package:python_practice/pages/practice_page.dart';
import 'package:python_practice/models/programming_language.dart';

/// 练习页分类网格的自适应行为。
///
/// ⚠️ 两个踩过的坑，改这个文件前先看：
///
/// 1. **刻意不用 `ProblemRepository().loadCategories()`**。
///    它走 `rootBundle` 从 assets 读 JSON，而 `rootBundle` 缓存的 Future
///    跨 fake-async zone 会失效 → **同一个测试文件里第二次调用必卡死**
///    （实测第二个用例停在 loadCategories 第一行）。网格布局只关心
///    卡片尺寸，用合成数据即可，顺带让用例不再依赖 assets。
///
/// 2. **一个用例里只 pumpWidget 一次**，也不要中途改
///    `tester.view.physicalSize` 后再 pump —— 同样会卡住。
///    所以每个窗口尺寸单独一个用例。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// 12 个分类，名称/描述与真实题库一致，保证卡片文字长度贴近实际
  List<ProblemCategory> fakeCategories() {
    const names = [
      ('基础语法', '变量、输入输出、print、类型转换'),
      ('数据类型', '整数、浮点数、类型转换、运算'),
      ('运算符', '算术、比较、逻辑、幂运算'),
      ('条件判断', 'if / elif / else 分支逻辑'),
      ('循环', 'for / while / break / continue'),
      ('字符串', '切片、拼接、大小写、统计'),
      ('列表', '增删改查、切片、推导式'),
      ('元组与集合', 'tuple / set 的用法'),
      ('字典', '键值对存取、遍历'),
      ('函数', '定义、参数、返回值、作用域'),
      ('进阶', '迭代器、生成器、异常、文件'),
      ('综合挑战', '跨知识点应用题'),
    ];
    return [
      for (var i = 0; i < names.length; i++)
        ProblemCategory(
          language: ProgrammingLanguage.python,
          key: 'c${i + 1}',
          name: names[i].$1,
          description: names[i].$2,
          problems: [
            for (var j = 1; j <= 6; j++)
              Problem(
                language: ProgrammingLanguage.python,
                id: i * 100 + j,
                title: '题 $j',
                difficulty: Difficulty.easy,
                description: '占位',
                inputFormat: '',
                outputFormat: '',
                sampleInput: '',
                sampleOutput: '',
                testCases: const [],
                hints: const [],
              ),
          ],
        ),
    ];
  }

  Future<void> pumpPracticeAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: PracticePage(categories: fakeCategories())),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// 量第一张分类卡片的宽度
  double firstCardWidth(WidgetTester tester) {
    final cells = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Card),
    );
    return tester.getSize(cells.first).width;
  }

  // 卡片宽度的合理区间：低于下限说明被挤扁，高于上限说明被撑成巨型方块
  const minW = 120.0;
  const maxW = 280.5; // maxCrossAxisExtent = 280，留一点亚像素余量

  testWidgets('窄窗口（600）：卡片不被挤扁', (tester) async {
    await pumpPracticeAt(tester, 600);
    final w = firstCardWidth(tester);
    expect(w, greaterThan(minW), reason: '600 宽下卡片实际 $w');
    expect(w, lessThanOrEqualTo(maxW), reason: '600 宽下卡片实际 $w');
  });

  testWidgets('中等窗口（900）：卡片尺寸落在合理区间', (tester) async {
    await pumpPracticeAt(tester, 900);
    final w = firstCardWidth(tester);
    expect(w, greaterThan(minW), reason: '900 宽下卡片实际 $w');
    expect(w, lessThanOrEqualTo(maxW), reason: '900 宽下卡片实际 $w');
  });

  testWidgets('超宽窗口（1920）：卡片不被撑大（改造的核心目的）', (tester) async {
    await pumpPracticeAt(tester, 1920);
    final w = firstCardWidth(tester);
    expect(w, lessThanOrEqualTo(maxW),
        reason: '宽窗口下卡片不应跟着无限变大，实际 $w');
    expect(w, greaterThan(minW), reason: '也不该被压得过小，实际 $w');
  });
}
