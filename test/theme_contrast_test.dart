import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/models/judge_result.dart';
import 'package:python_practice/models/problem.dart';
import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/pages/widgets/interactive_terminal.dart';
import 'package:python_practice/pages/widgets/judge_result_panel.dart';
import 'package:python_practice/theme.dart';

/// 深色 / 浅色两套主题下的可读性。
///
/// 学生报上来的两个问题属于**同一类**：颜色写死成只在一种主题下才看得见。
///
/// 1. 深色模式下判题结果的说明文字是黑的（`Colors.black54` 写死）
/// 2. 浅色模式下终端输入框的文字是白的
///    —— 根因不是「白字写错了」，而是全局 `InputDecorationTheme` 的
///    `filled: true` 给这个输入框刷了一层**浅灰底**（浅色模式），
///    于是写死的白字落在浅色底上。所以修的也是输入框本身（`filled: false`），
///    而不是把字改成黑的 —— 终端本来就该是深色底 + 浅色字。
///
/// 这里不逐条去测「某个颜色等于什么」（那种测试改一次颜色就要改一次，
/// 最后只会被人删掉），而是测**颜色跟主题的方向对不对**：
/// 深色主题下不许出现近黑的文字，浅色主题下不许出现近白的文字。
/// 顺带把终端输入框的「文字 vs 底色」按 WCAG 算一遍对比度。
void main() {
  /// 判断「近黑」/「近白」。用**声明**的颜色而不是合成后的 ——
  /// `Colors.black54` 是带 alpha 的黑，`computeLuminance()` 直接是 0，
  /// 正好能被抓出来（合成之后再算反而要看它压在什么底色上，更绕）。
  const nearBlack = 0.15;
  const nearWhite = 0.85;

  double lum(Color c) => c.computeLuminance();

  /// WCAG 对比度：(亮 + 0.05) / (暗 + 0.05)
  double contrast(Color a, Color b) {
    final la = lum(a);
    final lb = lum(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  Widget wrap(Widget child, Brightness brightness) => MaterialApp(
        theme: buildAppTheme(brightness: brightness, seedColor: Colors.green),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  /// 面板里所有**显式指定**了颜色的文字
  List<Color> declaredTextColors(WidgetTester tester) {
    final colors = <Color>[];
    for (final el in find.byType(Text).evaluate()) {
      final t = el.widget as Text;
      final c = t.style?.color;
      if (c != null) colors.add(c);
    }
    return colors;
  }

  Problem problem() => Problem(
        id: 901,
        title: '用指针读取变量的值',
        difficulty: Difficulty.easy,
        description: '',
        inputFormat: '',
        outputFormat: '',
        sampleInput: '',
        sampleOutput: '',
        testCases: [TestCase(input: '1\n', output: '1\n1')],
        hints: const [],
        language: ProgrammingLanguage.c,
      );

  TestCaseResult passedCase() => TestCaseResult(
        testCase: TestCase(input: '1\n', output: '1\n1'),
        status: JudgeStatus.passed,
        actualOutput: '1\n1',
        stderr: '',
        timeMs: 1,
      );

  /// 三种会走到不同文案分支的结果，尽量把面板的文字都渲染出来
  List<JudgeResult> allShapes() => [
        // 输出全对、但没按要求用上语法
        JudgeResult(
          problem: problem(),
          caseResults: [passedCase()],
          unmetRequirements: const [
            SourceRequirement(
              check: 'pointer.use',
              label: '用指针读取变量的值（*p 解引用）',
              hint: '先写 `int *p = &n;`，再用 `printf("%d", *p);`',
            ),
          ],
        ),
        // 答案错误 + 友好提示
        JudgeResult(
          problem: problem(),
          caseResults: [
            TestCaseResult(
              testCase: TestCase(input: '1\n', output: '1\n1'),
              status: JudgeStatus.wrongAnswer,
              actualOutput: '2\n2',
              stderr: '',
              timeMs: 1,
              message: '❌ 输出与期望在第 1 个字符处不同。\n请检查 `printf` 的格式串。',
            ),
          ],
        ),
        // 编译失败
        JudgeResult(
          problem: problem(),
          hasError: true,
          caseResults: [
            TestCaseResult(
              testCase: TestCase(input: '1\n', output: '1\n1'),
              status: JudgeStatus.compileError,
              actualOutput: '',
              stderr: '',
              timeMs: 0,
              message: '❌ 代码没通过编译。\n\n第 3 行: error: expected \';\'',
            ),
          ],
        ),
      ];

  group('判题结果面板', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final name = brightness == Brightness.light ? '浅色' : '深色';

      testWidgets('$name主题：文字颜色不能写反', (tester) async {
        final bad = <String>[];
        for (final result in allShapes()) {
          await tester.pumpWidget(wrap(
            JudgeResultPanel(
              result: result,
              isJudging: false,
              showDetailed: true,
            ),
            brightness,
          ));
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          for (final c in declaredTextColors(tester)) {
            final l = lum(c);
            if (brightness == Brightness.dark && l < nearBlack) {
              bad.add('$c（亮度 $l）在深色主题下是黑字');
            }
            if (brightness == Brightness.light && l > nearWhite) {
              bad.add('$c（亮度 $l）在浅色主题下是白字');
            }
          }
        }
        expect(bad, isEmpty,
            reason: '颜色写死成只在一套主题下可见：\n${bad.toSet().join('\n')}');
      });

      testWidgets('$name主题：代码块的衬底也要跟着主题走', (tester) async {
        // ⚠️ 必须用一个**没过**的用例：ExpansionTile 折叠时 children 根本不建，
        //    「实际输出 / 期望输出」那两块衬底就不会出现在树里，测了个寂寞。
        final result = allShapes()[1];
        await tester.pumpWidget(wrap(
          JudgeResultPanel(
            result: result,
            isJudging: false,
            showDetailed: true,
          ),
          brightness,
        ));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        // 确认真的是展开状态，否则下面那条断言等于没测
        expect(find.text('实际输出'), findsOneWidget,
            reason: '用例没展开，输出块压根没渲染 —— 这条断言会变成空转');

        final bad = <Color>[];
        for (final el in find.byType(Container).evaluate()) {
          final w = el.widget as Container;
          final d = w.decoration;
          if (d is BoxDecoration && d.color != null) {
            if (brightness == Brightness.dark && lum(d.color!) < nearBlack) {
              bad.add(d.color!);
            }
          }
        }
        expect(bad, isEmpty,
            reason: '深色主题下用了近黑的衬底，等于没画：${bad.toSet()}');
      });
    }
  });

  group('交互终端输入框', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final name = brightness == Brightness.light ? '浅色' : '深色';

      Future<void> pumpTerminal(WidgetTester tester) async {
        await tester.pumpWidget(wrap(
          InteractiveTerminal(
            language: ProgrammingLanguage.python,
            getCode: () => 'print(1)',
            sampleInput: '1',
            onJudge: () async {},
          ),
          brightness,
        ));
        await tester.pump();
      }

      testWidgets('$name主题：白字必须落在深色底上', (tester) async {
        await pumpTerminal(tester);

        final field = tester.widget<TextField>(find.byType(TextField));
        final textColor = field.style?.color;
        expect(textColor, isNotNull, reason: '终端输入框必须是浅色字，得显式给出来');

        // 输入框自己画了深色底（这个 BoxDecoration 就是终端的输入栏衬底）
        final boxFinder = find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first;
        final box = tester.widget<Container>(boxFinder);
        final bg = (box.decoration as BoxDecoration).color;
        expect(bg, isNotNull, reason: '输入栏应当自带深色衬底');

        expect(contrast(textColor!, bg!), greaterThanOrEqualTo(4.5),
            reason: '输入文字 $textColor 压在 $bg 上对比度太低，'
                '学生看不清自己敲了什么');
      });

      testWidgets('$name主题：不能被全局 InputDecorationTheme 刷上底色', (tester) async {
        await pumpTerminal(tester);

        final field = tester.widget<TextField>(find.byType(TextField));
        // 全局主题是 filled: true + 浅灰 fillColor（浅色模式）。
        // 输入框自己画了衬底，必须显式 filled: false 才能豁免 ——
        // 否则浅灰底会盖掉深色衬底，写死的白字就看不见了。
        expect(field.decoration?.filled, isFalse,
            reason: '全局主题的 filled: true 会盖掉终端的深色衬底'
                '（浅色模式下白字落在浅灰底上，正是学生报的那个问题）');
      });
    }
  });
}
