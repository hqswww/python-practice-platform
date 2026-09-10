import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/pages/test_page.dart';
import 'package:python_practice/services/settings_service.dart';
import 'package:python_practice/models/programming_language.dart';

/// 测试板块「各模式各自的倒计时时长」。
///
/// 改造前是「一个全局开关 + 一个全局时长」，跟题量脱钩：5 题和 72 题用同一个值。
/// 现在每个模式独立配置，时长里直接含「不限时」。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('各模式倒计时配置', () {
    test('默认值：按题量递增，全题库不限时', () {
      final s = SettingsService();
      expect(s.testTimeLimit('quick'), 600, reason: '快速测验 5 题 → 10 分钟');
      expect(s.testTimeLimit('standard'), 900, reason: '标准测验 10 题 → 15 分钟');
      expect(s.testTimeLimit('intensive'), 1200, reason: '强化测验 15 题 → 20 分钟');
      expect(s.testTimeLimit('full'), 0, reason: '全题库默认不限时');
      expect(s.hasTestTimeLimit('full'), isFalse);
      expect(s.hasTestTimeLimit('quick'), isTrue);
    });

    test('改一个模式不影响其它模式（这就是「不再一刀切」）', () async {
      final s = SettingsService();
      await s.setTestTimeLimit('quick', 300);

      expect(s.testTimeLimit('quick'), 300);
      expect(s.testTimeLimit('standard'), 900, reason: '未改动的模式应保持原值');
      expect(s.testTimeLimit('intensive'), 1200);
      expect(s.testTimeLimit('full'), 0);
    });

    test('可以单独把某个模式设成不限时', () async {
      final s = SettingsService();
      await s.setTestTimeLimit('standard', 0);
      expect(s.testTimeLimit('standard'), 0);
      expect(s.hasTestTimeLimit('standard'), isFalse);
      expect(s.testTimeLimit('quick'), 600, reason: '其它模式不受影响');
    });

    test('负数归零，避免出现负时长', () async {
      final s = SettingsService();
      await s.setTestTimeLimit('quick', -100);
      expect(s.testTimeLimit('quick'), 0);
    });

    test('未知模式 id 返回 0（安全默认）', () {
      expect(SettingsService().testTimeLimit('no_such_mode'), 0);
    });

    test('持久化：新实例 load() 后各模式时长都还在', () async {
      final a = SettingsService();
      await a.setTestTimeLimit('quick', 1800);
      await a.setTestTimeLimit('full', 3600);

      final b = SettingsService();
      await b.load();

      expect(b.testTimeLimit('quick'), 1800, reason: '改过的值应持久化');
      expect(b.testTimeLimit('full'), 3600, reason: '全题库也能从不限时改成限时');
      expect(b.testTimeLimit('standard'), 900, reason: '没改过的应回到默认');
    });

    test('持久化是分模式独立存储的（换个模式不会串）', () async {
      final a = SettingsService();
      await a.setTestTimeLimit('standard', 240);

      final b = SettingsService();
      await b.load();

      expect(b.testTimeLimit('standard'), 240);
      expect(b.testTimeLimit('quick'), 600, reason: 'shared_preferences 的键必须按模式分开');
      expect(b.testTimeLimit('intensive'), 1200);
    });
  });

  group('回归：load() 必须读回所有已持久化的字段', () {
    // 改造前 load() 只读了 themeMode / timeoutMs / accentId，
    // 这三项的 setter 写了 prefs 却从不读回 —— 重启即静默回落默认值。
    test('字体大小 / 缩进宽度 / 解释器路径重启后不丢', () async {
      final a = SettingsService();
      await a.setEditorFontSize(18);
      await a.setEditorIndentWidth(2);
      await a.setRuntimePath(
          ProgrammingLanguage.python, '/opt/homebrew/bin/python3');

      final b = SettingsService();
      await b.load();

      expect(b.editorFontSize, 18, reason: '以前漏读，重启会回落成 14');
      expect(b.editorIndentWidth, 2, reason: '以前漏读，重启会回落成 4');
      expect(b.runtimePath(ProgrammingLanguage.python), '/opt/homebrew/bin/python3',
          reason: '以前漏读，重启会丢失');
    });

    test('原有三项照常读回（别改出回归）', () async {
      final a = SettingsService();
      await a.setTimeoutMs(3500);
      await a.setThemeMode(ThemeMode.dark);
      await a.setAccent('purple');

      final b = SettingsService();
      await b.load();

      expect(b.timeoutMs, 3500);
      expect(b.themeMode, ThemeMode.dark);
      expect(b.accentId, 'purple');
    });
  });

  group('测试页界面', () {
    // 注意：这个用例会读 assets 题库，而 rootBundle 在同一个测试文件里
    // 只能成功加载一次（详见 practice_grid_test.dart 的说明），
    // 所以整个文件里只有这一个用例碰题库。
    testWidgets('四个模式各自显示自己的倒计时，互不相同', (tester) async {
      // 刻意用较窄的窗口：新布局是「按钮 + 时长选择器」并排，
      // 窄窗口下最容易挤爆，任何 RenderFlex overflow 都会让这个用例失败。
      // 应用允许的最小宽度是 420，这里取 600 留点余量。
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: TestPage()));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // 四个模式都在
      expect(find.textContaining('快速测验'), findsOneWidget);
      expect(find.textContaining('标准测验'), findsOneWidget);
      expect(find.textContaining('强化测验'), findsOneWidget);
      expect(find.textContaining('全题库'), findsOneWidget);

      // 每个模式旁边显示的是「它自己」的时长 —— 不再是同一个值
      expect(find.text('10 分钟'), findsOneWidget, reason: '快速测验');
      expect(find.text('15 分钟'), findsOneWidget, reason: '标准测验');
      expect(find.text('20 分钟'), findsOneWidget, reason: '强化测验');
      expect(find.text('不限时'), findsOneWidget, reason: '全题库默认不限时');

      // 旧的全局开关应该已经没有了
      expect(find.byType(Switch), findsNothing,
          reason: '总开关已移除，时长里直接含「不限时」');

      expect(tester.takeException(), isNull, reason: '窄窗口下不应有溢出等异常');
    });
  });
}
