import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/main.dart';
import 'package:python_practice/services/settings_service.dart';

/// 应用启动路径。
///
/// 首次运行和之后是不一样的：第一次要先过设置向导（检查这台机器上有没有
/// 编译器/解释器），之后才直接进主界面。两条路都得测 ——
/// 只有一条的话，很容易在改动启动逻辑时把另一条弄坏而毫无察觉。
void main() {
  setUp(() async {
    // ⚠️ settings 是全局单例，它内部的 SharedPreferences 实例是**缓存**的。
    // setMockInitialValues 只是换掉底层 store，缓存住的那个实例还指着旧的，
    // 所以「先 setMockInitialValues 再 load()」读不到新值 —— 单独跑能过、
    // 一起跑就挂。稳妥的办法是每次都在同一个 store 上用 setter 把状态摆好。
    SharedPreferences.setMockInitialValues({});
    await settings.load();
    await settings.setSetupWizardDone(false); // 每个用例先回到「首次运行」
  });

  // 向导里有三门语言的检测卡片，默认 800x600 的测试窗口会溢出
  void useLargeWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('首次运行：先出设置向导，而不是直接进主界面', (tester) async {
    useLargeWindow(tester);
    await tester.pumpWidget(const PythonPracticeApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('欢迎使用'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget, reason: '必须给得出「不想管」的出路');
  });

  testWidgets('走过向导：启动直接进学习页', (tester) async {
    await settings.setSetupWizardDone(true);
    useLargeWindow(tester);

    await tester.pumpWidget(const PythonPracticeApp());
    await tester.pump();

    // 首页(index 0)是学习页
    expect(find.text('学习笔记'), findsWidgets);
    expect(find.textContaining('欢迎使用'), findsNothing,
        reason: '走过向导就不该再弹了');
  });
}
