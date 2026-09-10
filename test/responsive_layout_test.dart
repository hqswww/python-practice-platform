import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/pages/settings_page.dart';
import 'package:python_practice/pages/widgets/responsive.dart';

/// 按逻辑像素铺开一个测试窗口
Future<void> pumpAt(WidgetTester tester, Widget child, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: child));
  // 有限 pump 代替 pumpAndSettle：页面里有常驻动画，settle 会死等
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('断点判定', () {
    test('宽度达到 twoPane 才算宽屏', () {
      expect(isTwoPaneWidth(0), isFalse);
      expect(isTwoPaneWidth(Breakpoints.twoPane - 1), isFalse);
      expect(isTwoPaneWidth(Breakpoints.twoPane), isTrue);
      expect(isTwoPaneWidth(Breakpoints.twoPane + 1), isTrue);
      expect(isTwoPaneWidth(4000), isTrue);
    });

    test('侧栏宽度必须给详情留出足够空间', () {
      // 若侧栏超过断点一半，右侧详情会被挤到没法用
      expect(Breakpoints.masterWidth, lessThan(Breakpoints.twoPane / 2));
    });
  });

  group('AdaptiveMasterDetail', () {
    Widget build() => Scaffold(
          body: AdaptiveMasterDetail(
            masterBuilder: (_, isWide) => Text(isWide ? 'MASTER-WIDE' : 'MASTER-NARROW'),
            detailBuilder: (_, _) => const Text('DETAIL'),
          ),
        );

    testWidgets('宽屏：左右两栏都渲染，且有分隔线', (tester) async {
      await pumpAt(tester, build(), const Size(1200, 700));

      expect(find.text('MASTER-WIDE'), findsOneWidget);
      expect(find.text('DETAIL'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('窄屏：只渲染左栏，detailBuilder 不被调用', (tester) async {
      await pumpAt(tester, build(), const Size(600, 700));

      expect(find.text('MASTER-NARROW'), findsOneWidget);
      expect(find.text('DETAIL'), findsNothing);
      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('跨断点缩放时布局实时切换', (tester) async {
      await pumpAt(tester, build(), const Size(1200, 700));
      expect(find.text('DETAIL'), findsOneWidget);

      // 缩到断点以下
      tester.view.physicalSize = const Size(600, 700);
      await tester.pump();
      expect(find.text('DETAIL'), findsNothing, reason: '缩窄后应变成单列');

      // 再拉宽回去
      tester.view.physicalSize = const Size(1200, 700);
      await tester.pump();
      expect(find.text('DETAIL'), findsOneWidget, reason: '拉宽后应恢复两栏');
    });
  });

  group('设置页响应式', () {
    Widget settings() => SettingsPage(onResetProgress: () async {});

    testWidgets('宽屏：左栏分类列表 + 右栏详情同时可见', (tester) async {
      await pumpAt(tester, settings(), const Size(1200, 800));

      // 左栏：分类条目
      expect(find.text('判题'), findsOneWidget);
      expect(find.text('代码编辑'), findsOneWidget);
      expect(find.text('数据'), findsOneWidget);

      // 右栏：默认选中「外观」，其详情卡片应已铺开
      expect(find.text('主题模式'), findsOneWidget);
      expect(find.text('主题强调色'), findsOneWidget);

      // 两栏才有的分隔线
      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('窄屏：只有分类列表，详情不在同页', (tester) async {
      await pumpAt(tester, settings(), const Size(600, 800));

      expect(find.text('判题'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNothing);
      // 详情没被渲染 → 点进去之前看不到
      expect(find.text('主题模式'), findsNothing,
          reason: '窄屏不应把详情铺在同一页');
    });

    testWidgets('窄屏：点分类进入详情页，AppBar 是分类名', (tester) async {
      await pumpAt(tester, settings(), const Size(600, 800));

      await tester.tap(find.text('判题'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // 详情页内容出现
      expect(find.text('判题超时'), findsOneWidget);

      // 新页面的 AppBar 标题 = 分类名。
      // 注意：push 之后底层列表页仍留在 widget 树里，所以「判题」会匹配到 2 个
      // Text（AppBar 标题 + 底层列表项），这里精确校验 AppBar 而不数 Text。
      final bars = tester.widgetList<AppBar>(find.byType(AppBar)).toList();
      expect(bars.length, greaterThanOrEqualTo(2),
          reason: '应同时存在列表页与详情页两个 AppBar');
      expect((bars.last.title as Text?)?.data, '判题');
    });

    testWidgets('宽屏：点分类只换右栏，不进新页面', (tester) async {
      await pumpAt(tester, settings(), const Size(1200, 800));

      await tester.tap(find.text('代码编辑'));
      await tester.pump();

      // 右栏换成「代码编辑」的内容
      expect(find.text('编辑器字体大小'), findsOneWidget);
      // 左栏仍在（没有 push 新页面把它盖掉）
      expect(find.text('数据'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('常见窗口宽度下都不溢出', (tester) async {
      // 任何 RenderFlex overflow 都会被 flutter_test 当异常抛出 → 测试失败
      const widths = [420.0, 600.0, 780.0, 839.0, 840.0, 1000.0, 1440.0, 1920.0];
      for (final w in widths) {
        await pumpAt(tester, settings(), Size(w, 720));
        expect(find.byType(SettingsPage), findsOneWidget, reason: '宽度 $w 应正常渲染');
      }
    });

    testWidgets('窄屏下每个分类的详情页都能正常渲染', (tester) async {
      const titles = ['外观', '成长', '判题', '代码编辑', '诊断', '数据', '我的进度', '关于'];
      await pumpAt(tester, settings(), const Size(480, 760));

      for (final title in titles) {
        // pop 回来后列表应恢复唯一匹配，否则说明上一轮没退干净
        expect(find.text(title), findsOneWidget, reason: '$title 在列表里应唯一');
        await tester.tap(find.text(title));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byType(AppBar), findsWidgets, reason: '$title 详情页应打开');

        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }
    });
    testWidgets('宽屏两栏的几何关系正确', (tester) async {
      await pumpAt(tester, settings(), const Size(1200, 800));

      final divider = tester.getRect(find.byType(VerticalDivider));
      expect(divider.left, closeTo(Breakpoints.masterWidth, 1.0),
          reason: '分隔线应正好落在左栏右边界');
      expect(divider.height, greaterThan(600),
          reason: '分隔线应纵向铺满可用高度');

      // 详情内容必须整体落在分隔线右侧，不能压到左栏
      final detail = tester.getRect(find.text('主题模式'));
      expect(detail.left, greaterThan(divider.right),
          reason: '详情应位于右栏内');

      // 左栏的分类条目也必须在分隔线左边
      final listItem = tester.getRect(find.text('代码编辑'));
      expect(listItem.right, lessThan(divider.left),
          reason: '分类条目应位于左栏内');
    });
  });
}
