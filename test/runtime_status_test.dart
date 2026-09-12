import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/pages/settings_page.dart';
import 'package:python_practice/services/c_runtime.dart';
import 'package:python_practice/services/language_runtime.dart';
import 'package:python_practice/services/python_runtime.dart';
import 'package:python_practice/services/settings_service.dart';

/// 运行时自检：设置页要能**提前**告诉用户环境缺什么。
///
/// 为什么值得这样做：环境缺件的失败发生在**判题时**，那时学生已经写完代码了
/// —— 明明代码是对的，却弹一句「程序运行环境有问题，请联系管理员」，
/// 最打击人，而且那句话什么都没说清。
///
/// 单独一个测试文件：设置页会读题库（走 rootBundle），而 rootBundle 在同一个
/// 测试文件里只能成功加载一次（详见 practice_grid_test.dart 的注释）。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // settings 是全局单例：每个用例先清掉自定义路径，避免用例之间互相污染
    for (final lang in ProgrammingLanguage.values) {
      await settings.setRuntimePath(lang, '');
    }
  });

  group('checkStatus：运行时自检', () {
    test('本机的 Python 解释器被判为可用，并给出实际路径', () {
      final st = runtimeFor(ProgrammingLanguage.python).checkStatus();
      expect(st.resolved, isNotEmpty);
      expect(st.available, isTrue, reason: '实际解析到：${st.resolved}');
      expect(st.hint, isNull, reason: '可用时不该给「怎么装」的指引');
    });

    test('本机的 C 编译器被判为可用（机器上没编译器则跳过）', () {
      if (!CRuntime.isCompilerAvailable(ProgrammingLanguage.c)) return;
      final st = runtimeFor(ProgrammingLanguage.c).checkStatus();
      expect(st.available, isTrue, reason: '实际解析到：${st.resolved}');
      expect(st.hint, isNull);
    });

    test('commandOverride 生效：注入不存在的编译器要判为不可用并给指引', () {
      // 回归：早先这里用的是 CRuntime.isCompilerAvailable(language)，
      // 它只看平台默认解析、**无视 commandOverride**，于是「用户在设置页
      // 指定了一个好用的编译器」会被误判成不可用，卡片上显示「未找到编译器」。
      const bogus = '/definitely/not/here/clang';
      final st = runtimeFor(ProgrammingLanguage.c, commandOverride: bogus)
          .checkStatus();

      expect(st.resolved, bogus, reason: '应尊重注入的命令，而不是平台默认值');
      expect(st.available, isFalse);
      expect(st.hint, isNotNull);
      expect(st.hint, isNotEmpty);
    });

    test('Python 注入不存在的解释器：指引要说清「装什么」', () {
      const bogus = '/definitely/not/here/python3';
      final st = runtimeFor(ProgrammingLanguage.python,
              commandOverride: bogus)
          .checkStatus();

      expect(st.available, isFalse);
      expect(st.hint, contains('Python 3'), reason: '实际：${st.hint}');
    });

    test('isCommandAvailable：路径形态与裸命令名都要能判', () {
      // 绝对路径走文件系统检查
      expect(CRuntime.isCommandAvailable('/definitely/not/here/gcc'), isFalse);
      expect(PythonRuntime.isCommandAvailable('/definitely/not/here/python3'),
          isFalse);
      // 空的要给 false，不能因为「没填 = 用默认」就当成可用
      expect(CRuntime.isCommandAvailable('   '), isFalse);
      expect(PythonRuntime.isCommandAvailable(''), isFalse);
      // 裸命令名走 PATH 查找；用一个必然不存在的名字
      expect(CRuntime.isCommandAvailable('definitely-not-a-real-compiler'),
          isFalse);
    });
  });

  group('设置页：代码编辑分类显示运行时状态', () {
    Future<void> openEditorCategory(WidgetTester tester) async {
      // 宽屏才有左右两栏，运行时卡片在「代码编辑」分类里
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: SettingsPage(onResetProgress: () async {}),
      ));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.text('代码编辑').first);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('找不到编译器时，卡片直接给出「装什么、怎么装」', (tester) async {
      await settings.setRuntimePath(
          ProgrammingLanguage.c, '/definitely/not/here/gcc');
      await openEditorCategory(tester);

      expect(find.text('未找到编译器'), findsWidgets);
      // 关键：必须是可操作的安装指引，不能是「请联系管理员」那种废话。
      // 三平台的文案都以「请先安装」开头
      // （macOS: Xcode CLT / Windows: MinGW-w64 / Linux: gcc）
      expect(find.textContaining('请先安装'), findsWidgets);
    });

    testWidgets('能找到时显示「已就绪」和实际使用的路径', (tester) async {
      await openEditorCategory(tester);

      // 本机三种语言都装齐了才会全绿；至少 Python 一定可用
      expect(find.text('已就绪'), findsWidgets);
      expect(find.textContaining('实际使用：'), findsWidgets);
    });
  });
}
