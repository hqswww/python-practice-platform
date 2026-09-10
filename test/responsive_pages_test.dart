import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/models/problem.dart';
import 'package:python_practice/models/problem_category.dart';
import 'package:python_practice/pages/achievements_page.dart';
import 'package:python_practice/pages/learn_page.dart';
import 'package:python_practice/pages/problem_list_page.dart';
import 'package:python_practice/pages/widgets/responsive.dart';
import 'package:python_practice/models/programming_language.dart';

/// 各页面的响应式行为。
///
/// 刻意用合成数据、不碰 `ProblemRepository`：它走 rootBundle，
/// 同一测试文件里第二次调用会卡死（详见 practice_grid_test.dart 的注释）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAt(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: child));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  List<ProblemCategory> fakeCategories() => [
        ProblemCategory(
          language: ProgrammingLanguage.python,
          key: 'c1',
          name: '基础语法',
          description: '变量、输入输出',
          problems: [
            Problem(
              language: ProgrammingLanguage.python,
              id: 101,
              title: '认识 print()',
              difficulty: Difficulty.easy,
              description: '占位',
              inputFormat: '',
              outputFormat: '',
              sampleInput: '',
              sampleOutput: '',
              testCases: const [],
              hints: const [],
              tutorial: [
                TutorialSection(title: '教程小节标题', body: '正文占位'),
              ],
            ),
            Problem(
              language: ProgrammingLanguage.python,
              id: 102,
              title: '变量',
              difficulty: Difficulty.easy,
              description: '占位',
              inputFormat: '',
              outputFormat: '',
              sampleInput: '',
              sampleOutput: '',
              testCases: const [],
              hints: const [],
              tutorial: [
                TutorialSection(title: '小节二', body: '正文占位'),
              ],
            ),
          ],
        ),
      ];

  group('MaxWidthBody', () {
    testWidgets('宽窗口：内容被限宽并居中', (tester) async {
      await pumpAt(
        tester,
        Scaffold(
          body: MaxWidthBody(
            maxWidth: 600,
            child: Container(key: const ValueKey('inner'), color: Colors.red),
          ),
        ),
        const Size(1400, 700),
      );

      final rect = tester.getRect(find.byKey(const ValueKey('inner')));
      expect(rect.width, lessThanOrEqualTo(600.5), reason: '不该超过 maxWidth');
      expect(rect.width, closeTo(600, 1), reason: '应撑满 maxWidth');
      // 居中：左右留白应基本相等
      expect(rect.left, closeTo(1400 - rect.right, 1.5), reason: '应水平居中');
    });

    testWidgets('窄窗口：不额外加宽，也不缩水', (tester) async {
      await pumpAt(
        tester,
        Scaffold(
          body: MaxWidthBody(
            maxWidth: 600,
            child: Container(key: const ValueKey('inner'), color: Colors.red),
          ),
        ),
        const Size(420, 700),
      );

      final rect = tester.getRect(find.byKey(const ValueKey('inner')));
      expect(rect.width, closeTo(420, 1), reason: '窗口比 maxWidth 窄时应铺满');
    });

    testWidgets('限宽后滚动区仍拿得到有界高度（不会崩）', (tester) async {
      await pumpAt(
        tester,
        Scaffold(
          body: MaxWidthBody(
            maxWidth: 600,
            child: ListView(
              children: [for (var i = 0; i < 40; i++) Text('行 $i')],
            ),
          ),
        ),
        const Size(1400, 700),
      );

      expect(find.text('行 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('学习页响应式', () {
    testWidgets('宽屏：侧栏与正文并排，AppBar 无汉堡按钮', (tester) async {
      await pumpAt(
        tester,
        LearnPage(categories: fakeCategories()),
        const Size(1200, 800),
      );

      // 侧栏的分类名可见
      expect(find.text('基础语法'), findsWidgets);
      // 宽屏不该有抽屉入口
      expect(find.byIcon(Icons.menu), findsNothing, reason: '宽屏侧栏常驻，无需抽屉');

      // 正文起点应在侧栏（230 + 1px 分隔线）右侧
      final body = tester.getRect(find.byKey(const ValueKey('bodyRow')));
      expect(body.width, closeTo(1200, 1));
      final note = tester.getRect(find.text('教程小节标题'));
      expect(note.left, greaterThan(200),
          reason: '正文应排在侧栏右侧，实际 left=${note.left}');
    });

    testWidgets('窄屏：正文独占整屏，侧栏收进抽屉', (tester) async {
      await pumpAt(
        tester,
        LearnPage(categories: fakeCategories()),
        const Size(520, 800),
      );

      // 窄屏出现抽屉入口
      expect(find.byIcon(Icons.menu), findsOneWidget,
          reason: '窄屏应能通过抽屉选题目');

      // 正文不再被 230px 侧栏挤压：起点应接近左边缘
      final note = tester.getRect(find.text('教程小节标题'));
      expect(note.left, lessThan(120),
          reason: '窄屏正文应独占宽度，实际 left=${note.left}');

      final body = tester.getRect(find.byKey(const ValueKey('bodyRow')));
      expect(body.width, closeTo(520, 1));
    });

    testWidgets('窄屏：打开抽屉能选题目，且选完自动收起', (tester) async {
      await pumpAt(
        tester,
        LearnPage(categories: fakeCategories()),
        const Size(520, 800),
      );

      await tester.tap(find.byIcon(Icons.menu));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('变量'), findsWidgets, reason: '抽屉里应列出题目');

      await tester.tap(find.text('变量').last);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // 抽屉已收起 → 汉堡按钮回到 AppBar，且正文切到了第二题
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.text('小节二'), findsWidgets, reason: '应切换到第二题的教程');
    });
  });

  group('成就页网格', () {
    testWidgets('超宽窗口下成就卡片不被撑大', (tester) async {
      await pumpAt(tester, const AchievementsPage(), const Size(1920, 900));

      final cells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Card),
      );
      final w = tester.getSize(cells.first).width;
      expect(w, lessThanOrEqualTo(200.5),
          reason: '应受 maxCrossAxisExtent=200 约束，实际 $w');
      expect(w, greaterThan(80), reason: '也不该被压得过小，实际 $w');
    });
  });

  group('跨页面尺寸扫描', () {
    // 任何 RenderFlex overflow 都会被 flutter_test 当异常抛出 → 用例直接失败，
    // 所以这里只要「能渲染完不抛异常」就说明这个宽度没问题。
    const widths = [420.0, 560.0, 839.0, 840.0, 1200.0, 1920.0];

    testWidgets('学习页在各宽度下都不溢出', (tester) async {
      for (final w in widths) {
        await pumpAt(
          tester,
          LearnPage(categories: fakeCategories()),
          Size(w, 780),
        );
        expect(tester.takeException(), isNull, reason: '宽度 $w 出现异常');
        expect(find.text('教程小节标题'), findsWidgets, reason: '宽度 $w 正文应渲染');
      }
    });

    testWidgets('成就页在各宽度下都不溢出', (tester) async {
      for (final w in widths) {
        await pumpAt(tester, const AchievementsPage(), Size(w, 780));
        expect(tester.takeException(), isNull, reason: '宽度 $w 出现异常');
      }
    });

    testWidgets('题目列表页在各宽度下都不溢出', (tester) async {
      for (final w in widths) {
        await pumpAt(
          tester,
          ProblemListPage(category: fakeCategories().first),
          Size(w, 780),
        );
        expect(tester.takeException(), isNull, reason: '宽度 $w 出现异常');
      }
    });
  });
}
