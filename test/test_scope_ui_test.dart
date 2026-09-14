import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/models/test_scope.dart';
import 'package:python_practice/pages/test_page.dart';
import 'package:python_practice/services/language_service.dart';
import 'package:python_practice/services/settings_service.dart';

/// 测试页的「出题范围」界面。
///
/// ⚠️ 整个文件只放**一条** testWidgets：`rootBundle` 在同一个测试文件里
/// 只能成功加载一次，而每 pump 一次 TestPage 都会去加载题库 ——
/// 拆成多条会让第二条挂住（见 practice_grid_test.dart 的说明）。
/// 所以这里一条用例走完整条交互链路。
void main() {
  testWidgets('出题范围：从入口到保存的完整链路', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await languageService.load();
    await languageService.select(ProgrammingLanguage.python);

    // 窄窗口：新布局是「按钮 + 两个设置控件」，窄了最容易挤爆。
    // 应用允许的最小宽度是 420，这里取 480。
    tester.view.physicalSize = const Size(480, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TestPage())));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // ── 前提：题池只含当前语言（多语言重构时这一处漏过，池子里混了三门语言）
    expect(find.textContaining('全题库（72 题）'), findsOneWidget,
        reason: '「全题库」应当是当前语言的 72 题，不是三门语言混起来的 216 题');

    // ── 默认范围：全部大类
    expect(find.text('全部大类'), findsNWidgets(4), reason: '四个模式默认都是全部大类');

    expect(tester.takeException(), isNull, reason: '窄窗口下不应有溢出');

    // ── 打开「快速测验」的范围设置
    final quickScope = find.text('全部大类').first;
    await tester.tap(quickScope);
    await tester.pumpAndSettle();

    expect(find.text('快速测验 · 出题范围'), findsOneWidget);
    expect(find.text('从哪些大类出题'), findsOneWidget);
    expect(find.text('难度范围'), findsOneWidget);

    // 12 个大类的 chip 都在（用的是当前语言的分类名）
    expect(find.text('基础语法'), findsOneWidget);
    expect(find.text('数据类型'), findsOneWidget);
    expect(find.text('综合挑战'), findsOneWidget);

    // 默认：全部大类 + 难度三，范围就是 72 题
    expect(find.textContaining('一共 72 题'), findsOneWidget);
    expect(find.textContaining('简单 34'), findsOneWidget);
    expect(find.textContaining('困难 6'), findsOneWidget);

    // ── 只留「基础语法」这一大类
    await tester.tap(find.text('全不选'));
    await tester.pumpAndSettle();
    expect(find.text('至少要选一个大类'), findsOneWidget);
    // 保存按钮应当被禁用
    final saveBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '保存'));
    expect(saveBtn.onPressed, isNull, reason: '一个大类都没选时不该能保存');

    await tester.tap(find.text('基础语法'));
    await tester.pumpAndSettle();
    expect(find.text('至少要选一个大类'), findsNothing);

    // 基础语法里没有困难题 → 难度三必须变成不可选
    expect(find.text('范围内没有困难题'), findsOneWidget,
        reason: '用户明确要求：范围内没有红色题时难度三不可选');

    // 范围预览跟着变。基础语法（01_syntax）实际是 5 简单 + 1 中等 + 0 困难，
    // 此时档位被自动夹到「难度二」，所以是 6 题
    expect(find.textContaining('一共 6 题'), findsOneWidget);
    expect(find.textContaining('简单 5'), findsOneWidget);
    expect(find.textContaining('中等 1'), findsOneWidget);

    // ── 存成「难度一」
    await tester.tap(find.text('难度一'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 入口摘要要立刻反映出来（不是等重启）
    expect(find.text('1 个大类'), findsOneWidget);
    expect(find.text('全部大类'), findsNWidgets(3), reason: '只有快速测验被改了');
    expect(settings.testScope('quick').ordinals, {1});
    expect(settings.testScope('quick').tier, DifficultyTier.one);

    // 快速测验的题量随范围收窄（基础语法只有 6 题，5 题模式仍出 5 题）
    expect(find.textContaining('快速测验（5 题）'), findsOneWidget);

    // ── 全题库模式在窄范围下只能出 6 题
    final scopeButtons = find.text('全部大类');
    await tester.tap(scopeButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('全不选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('基础语法'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('难度一'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(settings.testScope('standard').ordinals, {1});
    // 只留简单题 → 池子 5 题，10 题的模式只能出 5 题（题量按题池夹紧）
    expect(find.textContaining('标准测验（5 题）'), findsOneWidget,
        reason: '题量要按范围里的题数夹紧，不能显示 10 题却出 5 题');

    // ── 真的开始一次测试，确认抽题用的是「范围里的池子」而不是整库
    await tester.tap(find.textContaining('快速测验（5 题）'));
    await tester.pumpAndSettle();

    // 测试流程里的进度条写的是 `当前 / 总数`
    expect(find.textContaining('1 / 5'), findsOneWidget,
        reason: '范围里只有 5 道简单题，卷子就该是 5 题'); 

    expect(tester.takeException(), isNull);
  });
}
