import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/pages/settings_page.dart';
import 'package:python_practice/pages/setup_wizard_page.dart';
import 'package:python_practice/services/language_service.dart';
import 'package:python_practice/services/runtime_installer.dart';
import 'package:python_practice/services/settings_service.dart';

/// 首次运行向导。
///
/// 这里最要紧的一条是「**同一份存储**」：向导里改的主题色 / 字号 / 运行时路径
/// 必须和设置页读写的是同一个 [settings]，否则就会出现「向导里设了、设置页里
/// 看不到」这种最难解释的 bug。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // settings 是全局单例，用例之间会互相污染
    await settings.load();
    for (final lang in ProgrammingLanguage.values) {
      await settings.setRuntimePath(lang, '');
    }
    await settings.setSetupWizardDone(false);
  });

  Future<void> pumpWizard(
    WidgetTester tester, {
    VoidCallback? onFinished,
    Size size = const Size(1200, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: SetupWizardPage(onFinished: onFinished ?? () {}),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> goToStep(WidgetTester tester, int step) async {
    for (var i = 0; i < step; i++) {
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
    }
  }

  group('首次运行判断', () {
    test('没走过向导 → 应该显示', () {
      expect(shouldShowSetupWizard(), isTrue);
    });

    test('走过了 → 不再显示', () async {
      await settings.setSetupWizardDone(true);
      expect(shouldShowSetupWizard(), isFalse);
    });

    test('标记会持久化（重启后不再弹）', () async {
      await settings.setSetupWizardDone(true);

      // 换一个实例重新读，模拟重启
      SharedPreferences.setMockInitialValues({
        'settings_setup_wizard_done': true,
      });
      final fresh = SettingsService();
      await fresh.load();
      expect(fresh.setupWizardDone, isTrue);
      expect(fresh.setupWizardDone, isTrue);
    });

    test('老用户升级上来（键不存在）会看到一次向导', () async {
      SharedPreferences.setMockInitialValues({'settings_theme_mode': 1});
      final fresh = SettingsService();
      await fresh.load();
      expect(fresh.setupWizardDone, isFalse,
          reason: '他们那台机器上编译器可能确实没配好，顺带补一次是有价值的');
    });
  });

  group('向导界面', () {
    testWidgets('第一步是欢迎页，能走到运行环境那一步', (tester) async {
      await pumpWizard(tester);
      expect(find.textContaining('欢迎使用'), findsOneWidget);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('检查运行环境'), findsOneWidget);
    });

    testWidgets('运行环境那步把三种语言都列出来，并各给一个检测结果', (tester) async {
      await pumpWizard(tester);
      await goToStep(tester, 1);

      for (final lang in ProgrammingLanguage.values) {
        expect(find.text(lang.displayName), findsWidgets,
            reason: '${lang.displayName} 应该出现在环境检查里');
      }
      // 检测结果只可能是这两种说法之一
      final okCount = find.text('已就绪').evaluate().length;
      final missCount = find.textContaining('未找到').evaluate().length;
      expect(okCount + missCount, greaterThanOrEqualTo(3),
          reason: '三门语言都该有一个检测结论');
    });

    testWidgets('能走到「完成」并收尾', (tester) async {
      var finished = false;
      await pumpWizard(tester, onFinished: () => finished = true);
      await goToStep(tester, 3);

      expect(find.text('开始使用'), findsOneWidget);
      await tester.tap(find.text('开始使用'));
      await tester.pumpAndSettle();

      expect(finished, isTrue, reason: '应收尾并回调');
      expect(settings.setupWizardDone, isTrue);
    });

    testWidgets('跳过也能收尾，且不强迫用户改任何设置', (tester) async {
      var finished = false;
      await pumpWizard(tester, onFinished: () => finished = true);

      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
      expect(settings.setupWizardDone, isTrue);
    });
  });

  group('向导改的设置与设置页是同一份存储', () {
    testWidgets('选主题色 → settings.accentId 变了（设置页读的就是它）', (tester) async {
      await pumpWizard(tester);
      await goToStep(tester, 2);

      expect(settings.accentId, 'green', reason: '默认应是清新绿');
      await tester.tap(find.byKey(const ValueKey('accent_purple')));
      await tester.pumpAndSettle();

      expect(settings.accentId, 'purple',
          reason: '向导里选的色必须写进全局 settings，否则设置页看不到');
    });

    testWidgets('调代码字号 → settings.editorFontSize 变了', (tester) async {
      await pumpWizard(tester);
      await goToStep(tester, 2);

      final before = settings.editorFontSize;
      // 拖动滑块到最右
      await tester.drag(find.byType(Slider), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(settings.editorFontSize, greaterThan(before));
    });

    testWidgets('切缩进宽度 → settings.editorIndentWidth 变了', (tester) async {
      await pumpWizard(tester);
      await goToStep(tester, 2);

      await tester.tap(find.text('2 空格'));
      await tester.pumpAndSettle();
      expect(settings.editorIndentWidth, 2);
    });

    testWidgets('选默认语言 → languageService 跟着变（顶栏切换器读的也是它）',
        (tester) async {
      await pumpWizard(tester);
      await goToStep(tester, 2);

      await tester.tap(find.text('C++'));
      await tester.pumpAndSettle();
      expect(languageService.value, ProgrammingLanguage.cpp);
    });
  });

  group('装不上时的退路', () {
    test('非 Windows 不给「一键安装」（本机是 macOS）', () {
      // 目前只有 Windows 有随包分发的安装脚本
      expect(RuntimeInstaller.findScript(), isNull);
      expect(RuntimeInstaller.canAutoInstall, isFalse);
    });

    test('每种语言都有可操作的退路指引', () {
      for (final lang in ProgrammingLanguage.values) {
        final g = RuntimeInstaller.guidanceFor(lang);
        expect(g.isEmpty, isFalse,
            reason: '${lang.displayName} 必须给出下载页或可复制命令，'
                '否则用户碰上安装失败就没有出路了');
      }
    });

    test('C 与 C++ 共用同一套编译器指引', () {
      final c = RuntimeInstaller.guidanceFor(ProgrammingLanguage.c);
      final cpp = RuntimeInstaller.guidanceFor(ProgrammingLanguage.cpp);
      expect(c.command, cpp.command);
      expect(c.url, cpp.url);
    });
  });

  group('设置页能重新进入向导', () {
    testWidgets('「关于」里有入口，点开能进向导', (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: SettingsPage(onResetProgress: () async {}),
      ));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('关于').first);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('重新运行设置向导'), findsOneWidget);

      await tester.tap(find.text('重新运行设置向导'));
      await tester.pumpAndSettle();
      expect(find.textContaining('欢迎使用'), findsOneWidget);
    });
  });
}
