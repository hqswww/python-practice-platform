import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/models/judge_result.dart';
import 'package:python_practice/models/problem.dart';
import 'package:python_practice/models/problem_category.dart';
import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/data/problem_repository.dart';
import 'package:python_practice/services/c_runtime.dart';
import 'package:python_practice/pages/widgets/judge_result_panel.dart';
import 'package:python_practice/services/judge_engine.dart';

/// C 的编译型判题链路。
///
/// 与 Python 最大的差别：多一个**编译阶段**，且编译一次、所有用例复用产物。
void main() {
  final compilerReady = CRuntime.isCompilerAvailable(ProgrammingLanguage.c);

  Problem cProblem({
    required List<TestCase> cases,
    int id = 1,
    String title = 'C 题',
  }) =>
      Problem(
        id: id,
        title: title,
        difficulty: Difficulty.easy,
        description: '',
        inputFormat: '',
        outputFormat: '',
        sampleInput: '',
        sampleOutput: '',
        testCases: cases,
        hints: const [],
        language: ProgrammingLanguage.c,
      );

  group('C 编译器解析', () {
    test('源码扩展名是 .c', () {
      expect(CRuntime.extensionFor(ProgrammingLanguage.c), 'c');
      expect(CRuntime.extensionFor(ProgrammingLanguage.cpp), 'cpp');
    });

    test('找不到编译器时给出可操作的安装指引，而不是空话', () {
      final hint = CRuntime.installHint(ProgrammingLanguage.c);
      expect(hint, isNotEmpty);
      // 至少要说清楚「装什么」
      expect(hint.contains('MinGW') ||
          hint.contains('Command Line Tools') ||
          hint.contains('gcc'), isTrue);
    });

    test('本机应能解析到一个存在的编译器', () {
      if (!compilerReady) return; // 无编译器的机器上跳过
      final cmd = CRuntime.resolveCompiler(ProgrammingLanguage.c);
      expect(cmd, isNotEmpty);
      expect(File(cmd).existsSync() || cmd == 'clang' || cmd == 'gcc', isTrue,
          reason: '实际解析到的是 $cmd');
    });
  });

  group('C 判题链路', () {
    final engine = JudgeEngine(timeoutMs: 5000);

    test('能编译并跑通：输出正确 → passed', () async {
      if (!compilerReady) return;
      const code = r'''
#include <stdio.h>
int main() {
    int a, b;
    scanf("%d %d", &a, &b);
    printf("%d\n", a + b);
    return 0;
}
''';
      final result = await engine.judge(
        cProblem(cases: [
          TestCase(input: '1 2\n', output: '3'),
          TestCase(input: '10 20\n', output: '30'),
        ]),
        code,
      );

      expect(result.allPassed, isTrue,
          reason: '用例结果：${result.caseResults.map((r) => r.status.label).toList()}');
      expect(result.caseResults.length, 2);
    });

    test('答案算错 → wrongAnswer（不是编译错误）', () async {
      if (!compilerReady) return;
      const code = r'''
#include <stdio.h>
int main() {
    int a, b;
    scanf("%d %d", &a, &b);
    printf("%d\n", a - b);
    return 0;
}
''';
      final result = await engine.judge(
        cProblem(cases: [TestCase(input: '5 3\n', output: '8')]),
        code,
      );
      expect(result.caseResults.first.status, JudgeStatus.wrongAnswer);
    });

    test('编译失败 → 全部用例都是 compileError，且只报一次错', () async {
      if (!compilerReady) return;
      // 少了分号
      const code = r'''
#include <stdio.h>
int main() {
    printf("hi")
    return 0;
}
''';
      final result = await engine.judge(
        cProblem(cases: [
          TestCase(input: '', output: 'hi'),
          TestCase(input: '', output: 'hi'),
        ]),
        code,
      );

      expect(result.caseResults.every((r) => r.status == JudgeStatus.compileError),
          isTrue);
      expect(result.hasError, isTrue);
      // 编译不过就不该再去跑，耗时应是 0
      expect(result.caseResults.every((r) => r.timeMs == 0), isTrue);
    });

    test('编译错误信息清洗过：不含临时目录绝对路径，行号翻成中文', () async {
      if (!compilerReady) return;
      const code = 'int main() { return 0 }'; // 少分号
      final result = await engine.judge(
        cProblem(cases: [TestCase(input: '', output: '')]),
        code,
      );

      final msg = result.caseResults.first.message;
      expect(msg, contains('没通过编译'), reason: '实际信息：$msg');
      expect(msg, contains('error:'), reason: '应保留编译器原文：$msg');
      // 关键：不能把 /var/folders/... 这种噪音甩给学生
      expect(msg.contains('/var/folders'), isFalse,
          reason: '不该出现临时目录路径：$msg');
      expect(msg.contains('judge_'), isFalse,
          reason: '不该出现临时目录名：$msg');
      // 行号应被翻译
      expect(msg.contains('第 1 行'), isTrue, reason: '应标出行号：$msg');
    });

    test('程序崩溃（段错误）→ 给出 C 特有的排查方向', () async {
      if (!compilerReady) return;
      // 故意的空指针解引用
      const code = r'''
#include <stdio.h>
int main() {
    int *p = NULL;
    *p = 1;
    printf("done\n");
    return 0;
}
''';
      final result = await engine.judge(
        cProblem(cases: [TestCase(input: '', output: 'done')]),
        code,
      );

      final r = result.caseResults.first;
      expect(r.status, JudgeStatus.runtimeError,
          reason: '段错误应判运行错误而不是答案错误');
      expect(r.message, contains('崩溃'), reason: '实际信息：${r.message}');
      expect(r.message, contains('数组下标越界'),
          reason: '应给出 C 特有的排查方向：${r.message}');
    });

    test('用了 math.h 也能链接（-lm 生效）', () async {
      if (!compilerReady) return;
      const code = r'''
#include <stdio.h>
#include <math.h>
int main() {
    printf("%.0f\n", sqrt(16.0));
    return 0;
}
''';
      final result = await engine.judge(
        cProblem(cases: [TestCase(input: '', output: '4')]),
        code,
      );
      expect(result.allPassed, isTrue,
          reason: '少了 -lm 会链接失败：${result.caseResults.first.message}');
    });

    test('死循环 → 超时（不是卡死）', () async {
      if (!compilerReady) return;
      const code = r'''
int main() {
    while (1) { }
    return 0;
}
''';
      final result = await engine.judge(
        cProblem(cases: [TestCase(input: '', output: 'x')]),
        code,
      );
      expect(result.caseResults.first.status, JudgeStatus.timeout);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Python 不受影响（回归）', () {
    test('Python 判题仍走解释执行，没有编译阶段', () async {
      final engine = JudgeEngine(timeoutMs: 5000);
      final py = Problem(
        id: 1,
        title: 'py',
        difficulty: Difficulty.easy,
        description: '',
        inputFormat: '',
        outputFormat: '',
        sampleInput: '',
        sampleOutput: '',
        testCases: [TestCase(input: '2 3\n', output: '5')],
        hints: const [],
        language: ProgrammingLanguage.python,
      );
      final r = await engine.judge(py, 'a, b = map(int, input().split())\nprint(a + b)');
      expect(r.allPassed, isTrue);
    });
  });

  group('结果面板：编译错误', () {
    Future<void> pumpPanel(WidgetTester tester, JudgeResult result) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JudgeResultPanel(
              result: result,
              isJudging: false,
              showDetailed: true,
            ),
          ),
        ),
      ));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    JudgeResult compileFailed({required int cases}) => JudgeResult(
          problem: cProblem(cases: const []),
          hasError: true,
          caseResults: [
            for (var i = 0; i < cases; i++)
              TestCaseResult(
                testCase: TestCase(input: 'in$i', output: 'out$i'),
                status: JudgeStatus.compileError,
                actualOutput: '',
                stderr: '第 3 行: error: expected \';\'',
                timeMs: 0,
                message: '❌ 代码没通过编译。下面是编译器给出的报错：\n\n第 3 行: error: expected \';\'',
              ),
          ],
        );

    testWidgets('3 个用例只显示一块报错（不逐用例重复）', (tester) async {
      await pumpPanel(tester, compileFailed(cases: 3));

      expect(find.text('代码没通过编译'), findsOneWidget,
          reason: '编译错误不该每个用例重复一遍');
      // 逐用例的输入行不该出现
      expect(find.textContaining('输入: in0'), findsNothing);
      expect(find.textContaining('输入: in2'), findsNothing);
    });

    testWidgets('头部不显示「0/3 通过」这种误导性文案', (tester) async {
      await pumpPanel(tester, compileFailed(cases: 3));
      // 编译错误时要说「编译没通过」+「一个用例都没跑」，
      // 而不是「0/3 通过」（听起来像跑了但没过）
      expect(find.textContaining('0/3 通过'), findsNothing);
      expect(find.text('编译没通过'), findsOneWidget);
      expect(find.textContaining('一个用例都没跑'), findsOneWidget);
    });

    testWidgets('编译失败不会显示「实际输出/期望输出」对比', (tester) async {
      await pumpPanel(tester, compileFailed(cases: 2));
      expect(find.text('实际输出'), findsNothing,
          reason: '编译都没过，没有输出可比');
      expect(find.text('期望输出'), findsNothing);
    });
  });


  group('C 题库内容自检', () {
    // ⚠️ 两条踩过的坑：
    //
    // 1. rootBundle 在同一个测试文件里**只能成功加载一次**，
    //    所以这里用 _cats 缓存，无论多少条测试都只真加载一次。
    // 2. **一条测试里别判完整个题库**。曾经把 72 题放在一条测试里跑，
    //    耗时 33 秒，直接把 flutter_tools 的测试通道搞崩：
    //    `Bad state: Cannot close sink while adding stream`
    //    （flutter_platform.dart），suite 报「did not complete」。
    //    拆成每个分类一条（各约 3 秒）后稳定，失败也能直接定位到分类。
    List<ProblemCategory>? cache;
    Future<List<ProblemCategory>> allCats() async => cache ??=
        await ProblemRepository()
            .loadCategories(language: ProgrammingLanguage.c);

    const keys = [
      '01_basics', '02_datatype', '03_operators', '04_conditionals',
      '05_loops', '06_functions', '07_arrays', '08_strings',
      '09_pointers', '10_structs', '11_advanced', '12_challenges',
    ];

    for (final key in keys) {
      test('$key 的参考答案全部判过', () async {
        if (!compilerReady) return;

        final cats = await allCats();
        final cat = cats.where((c) => c.key == key).toList();
        if (cat.isEmpty) return; // 分类还没写，跳过
        final problems = cat.first.problems;
        expect(problems.length, 6, reason: '$key 应有 6 道题');

        final engine = JudgeEngine(timeoutMs: 5000);
        for (final p in problems) {
          expect(p.solution, isNotEmpty, reason: '题 ${p.id} 缺参考答案');
          expect(p.testCases, isNotEmpty, reason: '题 ${p.id} 没有测试用例');
          final r = await engine.judge(p, p.solution);
          expect(
            r.allPassed,
            isTrue,
            reason: '题 ${p.id}「${p.title}」参考答案没通过：'
                '${r.caseResults.first.message}',
          );
        }
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });

}
