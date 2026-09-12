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

    group('编译参数带 -B（告诉 gcc 去哪找 as / ld / cc1）', () {
      // 回归：Windows 上实测到
      //   gcc.exe: fatal error: cannot execute 'as' CreateProcess: No such file or directory
      // 报的是**裸名** 'as'，说明 GCC 没在自己所在目录找到它 —— 而 cc1 是找到了的
      // （否则会先报 cc1）。gcc 找子程序最终要靠 PATH，但应用可能是在用户装编译器
      // **之前**启动的（比如在向导里点了「一键安装」），进程的 PATH 不会更新。
      // -B 就是干这个的：显式指定「编译器自己的可执行文件在哪」。
      List<String> argsFor(String compiler, {required bool onWindows}) =>
          (runtimeFor(ProgrammingLanguage.c)
                  as CompiledLanguageRuntime)
              .compileArgs(
        workDir: Directory.systemTemp,
        sourceFile: File('solution.c'),
        compiler: compiler,
        onWindows: onWindows,
      );

      test('Windows：加上 -B，且路径转成正斜杠并保留结尾斜杠', () {
        final args = argsFor(r'C:\mingw64\bin\gcc.exe', onWindows: true);
        expect(args, contains('-BC:/mingw64/bin/'),
            reason: '结尾的反斜杠会转义掉命令行里的引号（经典 Win32 坑），'
                '必须用正斜杠。实际：$args');
      });

      test('Windows：用户自定义的安装位置也一样', () {
        expect(
          argsFor(
            r'C:\Users\xiao\AppData\Local\code_workbook\w64devkit\bin\gcc.exe',
            onWindows: true,
          ),
          contains('-BC:/Users/xiao/AppData/Local/code_workbook/w64devkit/bin/'),
        );
      });

      test('Windows：裸命令名（交给 PATH 找）时不加 -B', () {
        // 没有目录信息，加了反而会指向错误的位置
        for (final bare in ['gcc', 'gcc.exe', 'clang++']) {
          final args = argsFor(bare, onWindows: true);
          expect(args.any((a) => a.startsWith('-B')), isFalse,
              reason: '「$bare」没有目录，不该加 -B。实际：$args');
        }
      });

      test('macOS / Linux：**完全不加** -B（这两个平台本来是好的，不该动）', () {
        // 保持原样还有个额外好处：题库自检（144 道真题真编译）验证的
        // 就是这两个平台用户实际拿到的行为。
        for (final compiler in ['/usr/bin/clang', '/opt/homebrew/bin/g++-14', 'gcc']) {
          final args = argsFor(compiler, onWindows: false);
          expect(args.any((a) => a.startsWith('-B')), isFalse,
              reason: '$compiler 在非 Windows 上不该加 -B。实际：$args');
        }
      });

      test('本机实际用的编译参数里没有 -B（确认没影响到 macOS）', () {
        if (Platform.isWindows) return;
        final rt = runtimeFor(ProgrammingLanguage.c) as CompiledLanguageRuntime;
        final args = rt.compileSpec(Directory.systemTemp, File('solution.c'))!.args;
        expect(args.any((a) => a.startsWith('-B')), isFalse, reason: '$args');
      });

      test('-B 排在源文件之前，且不影响其它参数', () {
        final args = argsFor(r'C:\mingw64\bin\gcc.exe', onWindows: true);
        // 源文件用的是 absolute.path，所以按结尾匹配
        final srcIndex = args.indexWhere((a) => a.endsWith('solution.c'));
        expect(srcIndex, greaterThan(0), reason: '实际：$args');
        expect(args.indexOf('-BC:/mingw64/bin/'), lessThan(srcIndex));
        expect(args, contains('-O0'));
        expect(args, contains('-lm'));
        expect(args, contains('-std=c11'));
      });
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

    test('编译器找不到 as：必须说清是环境问题，不是代码问题', () async {
      // 用假编译器复现 Windows 上实测到的报错，不需要真的 MinGW：
      //   gcc.exe: fatal error: cannot execute 'as' CreateProcess: No such file or directory
      //
      // 为什么要专门测：这种失败会被普通的「代码没通过编译」抬头带偏，
      // 学生于是去改本来没错的代码，而真正该做的事（补装工具链）永远想不到。
      final dir = await Directory.systemTemp.createTemp('fakecc_');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      });
      final fake = File('${dir.path}/fake-gcc.sh');
      await fake.writeAsString('#!/bin/sh\n'
          'echo "gcc.exe: fatal error: cannot execute \'as\' CreateProcess: No such file or directory" >&2\n'
          'echo "compilation terminated." >&2\n'
          'exit 1\n');
      await Process.run('chmod', ['+x', fake.path]);

      final result =
          await JudgeEngine(timeoutMs: 5000, commandOverride: fake.path).judge(
        cProblem(cases: [TestCase(input: '', output: '')]),
        'int main(void) { return 0; }',
      );

      final r = result.caseResults.first;
      expect(r.status, JudgeStatus.compileError);
      expect(r.message, contains('这不是你代码的问题'),
          reason: '环境故障不能被说成学生的代码问题：${r.message}');
      expect(r.message, contains('as.exe'),
          reason: '要具体说出缺的是什么：${r.message}');
      expect(r.message, contains('设置'),
          reason: '要给可操作的方向（去哪儿看实际路径）：${r.message}');
      expect(r.message, isNot(contains('代码没通过编译')),
          reason: '不该用「代码没通过编译」这个抬头：${r.message}');
      // 原始输出仍要保留，方便排查
      expect(r.message, contains('cannot execute'), reason: r.message);
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

    test('运行时报错里的临时目录路径要被清洗掉', () async {
      if (!compilerReady) return;
      // __FILE__ 就是编译器看到的源码路径 —— 用它能**真的**验出
      // 清洗函数拿到的是不是正确的工作目录。
      //
      // 为什么值得专门测：judge_engine 曾经把 Directory.systemTemp（工作目录的
      // 父目录）传给 cleanDiagnostics，只能剥掉长前缀、留下 judge_xxxx/ 那一段。
      // 在 macOS 上这两者长得很像，不这么构造就测不出来。
      const code = r'''
#include <stdio.h>
int main(void) {
    fprintf(stderr, "source: %s\n", __FILE__);
    return 1;
}
''';
      final result = await engine.judge(
        cProblem(cases: [TestCase(input: '', output: '')]),
        code,
      );

      final msg = result.caseResults.first.message;
      expect(msg, contains('source:'), reason: '实际：$msg');
      expect(msg, contains('solution.c'), reason: '文件名该留着：$msg');
      expect(msg, isNot(contains('judge_')),
          reason: '不该出现判题临时目录名：$msg');
      expect(msg.contains('/var/folders') || msg.contains('/tmp'), isFalse,
          reason: '不该出现临时目录绝对路径：$msg');
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

    testWidgets('提示里的 **加粗** 和 `代码` 会被渲染掉，不会原样显示标记', (tester) async {
      // 这些标记一直写在提示文案里，而面板原先用普通 Text，
      // 学生看到的是字面的星号和反引号 —— 既像 bug，也把重点冲淡了。
      final result = JudgeResult(
        problem: cProblem(cases: const []),
        hasError: false,
        caseResults: [
          TestCaseResult(
            testCase: TestCase(input: '', output: ''),
            status: JudgeStatus.wrongAnswer,
            actualOutput: 'x',
            stderr: '',
            timeMs: 1,
            message: '✅ 内容是对的！只是**格式不对**——看 `as.exe`',
          ),
        ],
      );
      await pumpPanel(tester, result);

      // Text.rich 的内容用 toPlainText() 取；Text.data 则直接取
      final all = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
          .join('\n');

      expect(all, contains('格式不对'), reason: '内容不该丢：$all');
      expect(all, contains('as.exe'), reason: '内容不该丢：$all');
      expect(all, isNot(contains('**')), reason: 'markdown 标记漏到界面上了：$all');
      expect(all, isNot(contains('`')), reason: '反引号漏到界面上了：$all');
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
