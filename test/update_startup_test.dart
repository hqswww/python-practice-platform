import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/main.dart';
import 'package:python_practice/services/settings_service.dart';
import 'package:python_practice/services/update_service.dart';

/// 启动时那条「有新版就弹窗」的链路。
///
/// 这是整个自动更新功能里**唯一没法用纯单元测试覆盖**的一环 ——
/// 它挂在首帧回调上，前面的 check()/parse/挑包都测过了，但「到底有没有被调用、
/// 有没有被设置项挡住、跳过过的版本会不会又弹」只能在这里验证。
///
/// 之所以值得专门测：这几种失效都是**静默**的 —— 发完 Release 打开应用，
/// 什么都不弹，你根本不知道是没网、还是 tag 写错了、还是回调压根没跑。
/// 没有这条测试就只能靠「发个真 Release 再手点一遍」来确认，那种验证没人会跑。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// 每条测试都显式把全局设置摆成自己要的样子。
  ///
  /// ⚠️ 不能指望 `setMockInitialValues({})` 帮你隔离：`settings` 是**全局单例**，
  /// 它的 SharedPreferences 实例是缓存的，setUp 换掉的是底层 mock store，
  /// 单例手里那份引用和缓存都不变 —— 于是「单跑过、整套跑挂」。
  /// 项目里别的测试文件也踩过同一个坑（见 PROJECT_BACKLOG「测试与工具」）。
  Future<void> resetSettings({bool auto = true, String skipped = ''}) async {
    await settings.load();
    await settings.setAutoCheckUpdate(auto);
    await settings.setSkippedUpdateVersion(skipped);
  }

  String releaseJson(String tag) => jsonEncode({
        'tag_name': tag,
        'body': '- 修了某某问题',
        'html_url':
            'https://github.com/hqswww/python-practice-platform/releases/tag/$tag',
        'assets': const [],
      });

  /// 一个总是报告「有新版本 [tag]」的服务
  UpdateService serviceReporting(String tag, {String current = '1.4.0'}) =>
      UpdateService(
        currentVersion: current,
        fetcher: (_) async => HttpTextResponse(200, releaseJson(tag)),
      );

  Future<void> pumpHome(WidgetTester tester, UpdateService svc) async {
    await tester.pumpWidget(MaterialApp(home: HomePage(updateServiceOverride: svc)));
    // 首帧回调 + 异步的 check() 都在这几步里跑完
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('启动时检查更新', () {
    testWidgets('有新版本 → 弹出提示', (tester) async {
      await resetSettings();
      await pumpHome(tester, serviceReporting('v1.5.0'));
      expect(find.text('发现新版本'), findsOneWidget,
          reason: '发了新 Release 但应用一声不吭 —— 启动回调没跑到');
      expect(find.textContaining('v1.5.0'), findsWidgets);
    });

    testWidgets('没有新版本 → 不打扰', (tester) async {
      await resetSettings();
      // 远端 tag 比本地低（开发机上跑未发布版本就是这种情况）
      await pumpHome(tester, serviceReporting('v1.4.0'));
      expect(find.text('发现新版本'), findsNothing);
    });

    testWidgets('设置里关掉之后，即使有新版本也不弹', (tester) async {
      await resetSettings(auto: false);
      await pumpHome(tester, serviceReporting('v1.5.0'));
      expect(find.text('发现新版本'), findsNothing,
          reason: '设置页那个开关必须真的能拦住启动检查');
    });

    testWidgets('检查失败（断网）→ 静默，不能弹错误框', (tester) async {
      await resetSettings();
      final broken = UpdateService(
        currentVersion: '1.4.0',
        fetcher: (_) async => const HttpTextResponse(500, 'boom'),
      );
      await pumpHome(tester, broken);
      expect(find.text('发现新版本'), findsNothing);
      // 也不能冒出别的对话框把用户拦住
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('跳过过的版本不再提示，换个版本照常提示', (tester) async {
      await resetSettings(skipped: '1.5.0');

      await pumpHome(tester, serviceReporting('v1.5.0'));
      expect(find.text('发现新版本'), findsNothing,
          reason: '用户说「跳过这个版本」了，不能每次启动都再问一遍');

      // 换个更新的版本 —— 只该跳过那一个版本，不是永久静音。
      // ⚠️ 必须先把它卸载掉：直接再 pump 一个 HomePage，Flutter 会复用同一个
      //    State（widget 类型没变），initState 不会再跑，第二次检查根本不会发生 ——
      //    那样这条断言会「因为没查」而通过，等于空转。
      await tester.pumpWidget(const SizedBox());
      await pumpHome(tester, serviceReporting('v1.6.0'));
      expect(find.text('发现新版本'), findsOneWidget,
          reason: '跳过 1.5.0 顺手把以后所有版本都静音了 —— 那就成了「再也不提示」');
    });
  });
}
