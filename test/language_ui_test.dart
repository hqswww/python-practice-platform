import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/pages/widgets/language_switcher.dart';
import 'package:python_practice/pages/widgets/language_syntax.dart';
import 'package:python_practice/services/language_runtime.dart';
import 'package:python_practice/services/language_service.dart';
import 'package:python_practice/services/settings_service.dart';

/// 多语言改造的表现层：运行时策略、语法高亮、语言切换器、按语言的运行时路径。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LanguageRuntime 策略', () {
    test('Python 是解释型：不需要编译步骤', () {
      final rt = runtimeFor(ProgrammingLanguage.python);
      expect(rt.language, ProgrammingLanguage.python);
      expect(rt.compileSpec(Directory.systemTemp, File('x')), isNull,
          reason: '解释型语言不该有编译步骤');
    });

    test('Python 源码文件名带 .py；参数含 UTF-8 加固', () {
      final rt = runtimeFor(ProgrammingLanguage.python);
      expect(rt.sourceFileName, 'solution.py');
      final spec = rt.runSpec(Directory.systemTemp, File('/tmp/solution.py'));
      expect(spec.args, contains('-X'));
      expect(spec.args, contains('utf8'));
      expect(spec.environment['PYTHONIOENCODING'], 'utf-8');
    });

    test('commandOverride 能覆盖解释器路径（测试注入 / 设置页自定义）', () {
      final rt = runtimeFor(
        ProgrammingLanguage.python,
        commandOverride: '/custom/python3',
      );
      expect(rt.runSpec(Directory.systemTemp, File('x')).command,
          '/custom/python3');
    });

    test('尚未接入的语言抛出可读错误，而不是静默跑错', () {
      // C 已接入；C++ 还没有（复用同一套编译流程，等 C 验收后接）
      expect(runtimeFor(ProgrammingLanguage.c).language,
          ProgrammingLanguage.c);
      expect(() => runtimeFor(ProgrammingLanguage.cpp),
          throwsA(isA<UnsupportedError>()));
    });

    test('Python 能识别自己的运行时错误特征', () {
      final rt = runtimeFor(ProgrammingLanguage.python);
      expect(rt.looksLikeRuntimeError('Traceback (most recent call last):', ''), isTrue);
      expect(rt.looksLikeRuntimeError('', 'NameError: x'), isTrue);
      expect(rt.looksLikeRuntimeError('', '3'), isFalse);
    });

    test('Python 的错误提示覆盖常见异常，未知的交给通用兜底', () {
      final rt = runtimeFor(ProgrammingLanguage.python);
      expect(rt.explainRuntimeError('NameError: name x', ''), contains('名称错误'));
      expect(rt.explainRuntimeError('IndentationError: x', ''), contains('缩进错误'));
      expect(rt.explainRuntimeError('SomethingWeird', ''), isNull,
          reason: '没见过的错误应返回 null，让引擎用通用文案');
    });
  });

  group('语法高亮描述', () {
    test('正则从词表组装，关键字与内置都在里面（不会两处漂移）', () {
      final pattern = LanguageSyntax.python.pattern;
      for (final kw in ['def', 'return', 'while', 'lambda']) {
        expect(pattern, contains(kw), reason: '关键字 $kw 应在正则里');
      }
      for (final bi in ['print', 'len', 'range']) {
        expect(pattern, contains(bi), reason: '内置 $bi 应在正则里');
      }
    });

    test('正则能编译，且捕获组顺序为 注释/字符串/扩展/数字/关键字/内置', () {
      final re = RegExp(LanguageSyntax.python.pattern, multiLine: true);
      final m = re.firstMatch('def f():\n  # 注释\n  return "abc" 42 print');
      expect(m, isNotNull);

      // 逐个验证各组的识别结果
      void kindOf(String code, String expectedKind) {
        final match = re.firstMatch(code);
        expect(match, isNotNull, reason: '$code 应能匹配');
        final idx = [1, 2, 3, 4, 5, 6]
            .firstWhere((i) => match!.group(i) != null);
        const names = {1: 'comment', 2: 'string', 3: 'extra', 4: 'number',
                       5: 'keyword', 6: 'builtin'};
        expect(names[idx], expectedKind, reason: '$code 应识别为 $expectedKind');
      }

      kindOf('# 注释', 'comment');
      kindOf('"abc"', 'string');
      kindOf('@decorator', 'extra');
      kindOf('42', 'number');
      kindOf('return', 'keyword');
      kindOf('print', 'builtin');
    });

    test('C 的描述也已备好（虽然还没接上）', () {
      final pattern = LanguageSyntax.c.pattern;
      expect(pattern, contains('int'));
      expect(pattern, contains('printf'));
      // C 用 // 注释，且支持 /* */
      expect(pattern, contains('//'));
      expect(pattern, contains(r'/\*'));
    });

    test('of() 目前对 C/C++ 回退到 Python 描述（题库还没做）', () {
      expect(LanguageSyntax.of(ProgrammingLanguage.c), LanguageSyntax.python);
      expect(LanguageSyntax.of(ProgrammingLanguage.cpp), LanguageSyntax.python);
      expect(LanguageSyntax.of(ProgrammingLanguage.python), LanguageSyntax.python);
    });

    test('没有「扩展」语法的语言用永不匹配的片段占位，组号不会错位', () {
      // 组号错位会导致关键字被涂成字符串颜色之类的诡异 bug
      final re = RegExp(LanguageSyntax.c.pattern, multiLine: true);
      final m = re.firstMatch('int');
      expect(m!.group(5), 'int', reason: 'int 必须落在「关键字」那一组');
    });
  });

  group('语言切换器', () {
    /// 注入一个「允许 Python 和 C」的服务，模拟 C 题库接入后的状态。
    /// 直接改全局单例会让用例之间互相污染，所以走注入。
    LanguageService twoLangService() => LanguageService(
          available: () =>
              const [ProgrammingLanguage.python, ProgrammingLanguage.c],
        );

    Future<LanguageService> pump(
      WidgetTester tester,
      List<ProgrammingLanguage> langs, {
      LanguageService? service,
    }) async {
      final svc = service ?? twoLangService();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('测试'),
            actions: [LanguageSwitcher(available: langs, service: svc)],
          ),
        ),
      ));
      await tester.pump();
      return svc;
    }

    testWidgets('只有一个语言：显示当前语言，但不可点击、无下拉箭头', (tester) async {
      await pump(
        tester,
        const [ProgrammingLanguage.python],
        service: LanguageService(available: () => const [ProgrammingLanguage.python]),
      );

      expect(find.text('Python'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing,
          reason: '只有一个选项时不该诱导用户去点');

      // 点下去不应弹菜单
      await tester.tap(find.text('Python'));
      await tester.pumpAndSettle();
      expect(find.text('C'), findsNothing);
    });

    testWidgets('多个语言：可展开菜单并列出全部', (tester) async {
      await pump(tester, const [ProgrammingLanguage.python, ProgrammingLanguage.c]);

      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      await tester.tap(find.text('Python'));
      await tester.pumpAndSettle();

      // 菜单里两项都在（Python 此时出现两次：按钮 + 菜单项）
      expect(find.text('Python'), findsNWidgets(2));
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('选中另一门语言会切换状态并刷新按钮', (tester) async {
      final svc = await pump(
        tester,
        const [ProgrammingLanguage.python, ProgrammingLanguage.c],
      );
      expect(svc.value, ProgrammingLanguage.python);

      await tester.tap(find.text('Python'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C').last);
      await tester.pumpAndSettle();

      expect(svc.value, ProgrammingLanguage.c);
      expect(find.text('C'), findsOneWidget, reason: '按钮应显示新语言');
    });

    test('语言选择会被持久化，重启后恢复', () async {
      final a = LanguageService(
        available: () =>
            const [ProgrammingLanguage.python, ProgrammingLanguage.c],
      );
      await a.select(ProgrammingLanguage.c);

      final b = LanguageService(
        available: () =>
            const [ProgrammingLanguage.python, ProgrammingLanguage.c],
      );
      await b.load();
      expect(b.value, ProgrammingLanguage.c);
    });

    test('拒绝切到没有题库的语言（避免进到空科目）', () async {
      // Python 和 C 都已接入；C++ 还没有题库
      final svc = LanguageService();
      await svc.select(ProgrammingLanguage.cpp);
      expect(svc.value, ProgrammingLanguage.python,
          reason: 'C++ 还没题库，不该让人切过去看到空白');
    });

    test('有题库的语言可以正常切入（C 已接入）', () async {
      final svc = LanguageService();
      await svc.select(ProgrammingLanguage.c);
      expect(svc.value, ProgrammingLanguage.c);
    });

    test('存了一个已下线的语言会回退到可用语言', () async {
      SharedPreferences.setMockInitialValues({
        'settings_current_language': 'rust',
      });
      final s = LanguageService();
      await s.load();
      expect(s.value, ProgrammingLanguage.python);
    });
  });

  group('运行时路径按语言分开', () {
    test('默认都是空（自动解析）', () {
      final s = SettingsService();
      for (final lang in ProgrammingLanguage.values) {
        expect(s.runtimePath(lang), '');
      }
    });

    test('各语言互不影响', () async {
      final s = SettingsService();
      await s.setRuntimePath(ProgrammingLanguage.python, '/usr/bin/python3');
      await s.setRuntimePath(ProgrammingLanguage.c, '/usr/bin/clang');

      expect(s.runtimePath(ProgrammingLanguage.python), '/usr/bin/python3');
      expect(s.runtimePath(ProgrammingLanguage.c), '/usr/bin/clang');
      expect(s.runtimePath(ProgrammingLanguage.cpp), '');
    });

    test('持久化：新实例 load() 后仍在', () async {
      final a = SettingsService();
      await a.setRuntimePath(ProgrammingLanguage.c, '/opt/clang');

      final b = SettingsService();
      await b.load();
      expect(b.runtimePath(ProgrammingLanguage.c), '/opt/clang');
    });

    test('迁移：旧的单一「Python 解释器路径」会被搬进来', () async {
      SharedPreferences.setMockInitialValues({
        'settings_python_path': '/legacy/python3',
      });
      final s = SettingsService();
      await s.load();
      expect(s.runtimePath(ProgrammingLanguage.python), '/legacy/python3',
          reason: '老用户设过的解释器路径不能丢');
    });

    test('迁移不会覆盖已按语言存好的新值', () async {
      SharedPreferences.setMockInitialValues({
        'settings_python_path': '/legacy/python3',
        'settings_runtime_path_python': '/new/python3',
      });
      final s = SettingsService();
      await s.load();
      expect(s.runtimePath(ProgrammingLanguage.python), '/new/python3');
    });
  });
}
