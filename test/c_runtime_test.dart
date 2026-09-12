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
import 'package:python_practice/services/language_runtime.dart';

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

    test('编译产物名：Windows 必须带 .exe，其它平台不带', () {
      // 这条的两个分支都要覆盖 —— 本机（macOS）永远走不到 Windows 那条，
      // 而 Windows 上不带 .exe 就意味着**所有 C/C++ 题目都跑不起来**。
      expect(CRuntime.binaryName(onWindows: true), 'solution.exe');
      expect(CRuntime.binaryName(onWindows: false), 'solution');
    });

    test('实际平台上的产物名与判题用的是同一个', () {
      final rt = runtimeFor(ProgrammingLanguage.c);
      expect(rt.binaryName, CRuntime.binaryName());
      // 编译产物名和运行命令里用的名字必须是同一个，否则编完找不到
      final spec = rt.runSpec(Directory.systemTemp, File('solution.c'));
      expect(spec.command, endsWith(rt.binaryName));
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

    test('整数除以 0 → 提示「除以 0」，不能误报成崩溃/指针问题', () async {
      if (!compilerReady) return;
      // 回归：除零(-8) 和段错误(-11) 都会让 exitCode 变成负数。
      // 早先只判断 `exitCode < 0` 就一律报「崩溃：数组越界／指针」，
      // 把写 `a / b` 的学生指去查指针 —— 方向完全相反。
      const code = r'''
#include <stdio.h>
int main() {
    int a = 10;
    int b = 0;
    printf("%d\n", a / b);
    return 0;
}
''';
      final result = await engine.judge(
        cProblem(cases: [TestCase(input: '', output: '')]),
        code,
      );

      final r = result.caseResults.first;
      expect(r.status, JudgeStatus.runtimeError,
          reason: '除零应判运行错误而不是答案错误');
      expect(r.message, contains('除以 0'), reason: '实际信息：${r.message}');
      // 这两句是段错误专属的排查方向，出现在除零的题上就是把学生带偏
      expect(r.message.contains('数组下标越界'), isFalse,
          reason: '除零不该被指去查数组越界：${r.message}');
      expect(r.message.contains('指针指向了非法地址'), isFalse,
          reason: '除零不该被指去查指针：${r.message}');
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

  group('异常终止的退出码分类（跨平台）', () {
    // 退出码是**唯一**可靠的线索：判题用 Process.start 直接拉进程、不走 shell，
    // 而「Floating point exception」「Segmentation fault」这些字样是 shell 打印的，
    // 在 stderr 里根本不会出现（实测：除零的 C 程序经 Dart 启动后 stderr 为空）。
    //
    // Windows 分支在本机（macOS）跑不到，所以这里直接喂状态码，把那半边逻辑锁住。
    final rt = runtimeFor(ProgrammingLanguage.c);

    // stderr 默认给非空值：空 stderr 会命中「非正常退出但没输出」那条兜底，
    // 那是另一条分支，不该混进来干扰这里的判断。
    String? explain(int exitCode, {String stderr = 'boom'}) =>
        rt.explainRuntimeError(stderr, '', exitCode: exitCode);

    test('POSIX：除零是 SIGFPE(-8)，段错误是 SIGSEGV(-11)，两者必须分开', () {
      final dz = explain(-8)!;
      expect(dz, contains('除以 0'), reason: '实际：$dz');
      expect(dz.contains('数组下标越界'), isFalse,
          reason: '除零不该被指去查数组越界：$dz');

      final seg = explain(-11)!;
      expect(seg, contains('崩溃'));
      expect(seg, contains('数组下标越界'));
    });

    test('Windows：状态码被 Dart 转成负数后仍能分辨（0xC0000094 / 0xC0000005）', () {
      // 依据 dart:io 的 Process.exitCode 文档：32 位状态码按**有符号**返回，
      // 0xC0000094 → -1073741676，0xC0000005 → -1073741819。
      final dz = explain(-1073741676)!;
      expect(dz, contains('除以 0'), reason: 'Windows 除零应认出来：$dz');

      final av = explain(-1073741819)!;
      expect(av, contains('崩溃'));
      expect(av, contains('数组下标越界'),
          reason: '访问违规对标段错误，排查方向一致：$av');
    });

    test('abort / 未知信号不掉进「数组越界」的错误方向', () {
      expect(explain(-6), contains('被强行中止')); // SIGABRT
      final killed = explain(-9)!; // SIGKILL 等未列出的信号
      expect(killed, contains('被系统异常终止'), reason: '实际：$killed');
      expect(killed.contains('数组下标越界'), isFalse);
    });

    test('正常退出（exitCode >= 0）不触发任何崩溃文案', () {
      expect(explain(0), isNull);
      expect(explain(1), isNull);
    });
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
