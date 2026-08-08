/// 判题引擎
///
/// 核心闭环：把学生代码写入临时 solution.py → 调用 Python 运行
/// → 喂入每个测试用例的输入 → 捕获 stdout → 与期望输出比对
/// → 返回结果（含友好错误提示）。
///
/// 平台差异：开发期（Linux）用系统 python3；打包 Windows 时
/// 改用捆绑的 python.exe（见 DESIGN.md 第五节）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/judge_result.dart';
import '../models/problem.dart';
import 'python_runtime.dart';

class JudgeEngine {
  /// 判题超时时间（毫秒）
  final int timeoutMs;

  /// 可选注入的 Python 命令（测试用 / Windows 捆绑路径）
  final String pythonCommand;

  JudgeEngine({this.timeoutMs = 2000, String? pythonCommand})
      : pythonCommand = pythonCommand ?? PythonRuntime.resolvePythonCommand();

  /// 判题用包装：重写 input()，把提示(prompt)写到 stderr 而非 stdout。
  /// 这样 prompt 不会混入判题比对的标准输出，`a=input("a=")` 这类代码能正常判对。
  static const String _siteCustomize = r'''
import builtins, sys

# 记录原始 input，避免递归
_real_input = builtins.input

def _judge_input(prompt=""):
    # 提示语改写到 stderr（判题比对只看 stdout），真正的 input 读取不变
    if prompt:
        try:
            sys.stderr.write(prompt)
            sys.stderr.flush()
        except Exception:
            pass
    return _real_input("")

builtins.input = _judge_input
''';

  /// 判一道题的全部测试用例
  Future<JudgeResult> judge(Problem problem, String code) async {
    final tempDir = await Directory.systemTemp.createTemp('python_judge_');
    final solutionFile = File('${tempDir.path}/solution.py');
    await solutionFile.writeAsString(code);
    // 写一个 sitecustomize 包装：把 input() 的提示(prompt)从 stdout 挪到 stderr。
    // 这样 input("a=") 的提示文字不会混入最终输出比对，`a=input("a=")` 这类题能判对。
    await File('${tempDir.path}/sitecustomize.py').writeAsString(_siteCustomize);

    try {
      final results = <TestCaseResult>[];
      var hasRuntimeError = false;

      for (final testCase in problem.testCases) {
        final result = await _runTestCase(solutionFile, testCase);
        if (result.status == JudgeStatus.runtimeError) hasRuntimeError = true;
        results.add(result);
      }

      return JudgeResult(
        problem: problem,
        caseResults: results,
        hasError: hasRuntimeError,
      );
    } finally {
      // 清理临时目录
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// 运行单个测试用例
  Future<TestCaseResult> _runTestCase(
    File solutionFile,
    TestCase testCase,
  ) async {
    final stopwatch = Stopwatch()..start();

    // 第一次：按题目原始输入喂
    var result = await _execute(solutionFile, testCase, stopwatch);

    // 自适应兜底：如果因“读了比输入更多的内容”而 EOFError，
    // 很可能是代码用了多次 input()，但题目输入是单行空格分隔（如 `17 5`）。
    // 此时重试一次：把输入按所有空白拆成多行（17 5 → 17\n5\n）。
    // 这样单行 split 和分行多次 input 的写法都能判对，只要答案对上就算对。
    if (result.status == JudgeStatus.runtimeError &&
        (result.stderr + result.actualOutput).contains('EOFError')) {
      final splitInput = _splitInputIntoLines(testCase.input);
      if (splitInput != testCase.input) {
        final retryCase = TestCase(
          input: splitInput,
          output: testCase.output,
        );
        final retryResult = await _execute(solutionFile, retryCase, stopwatch);
        // 重试通过则采用；否则保留第一次结果（错误信息对用户更有用）
        if (retryResult.status == JudgeStatus.passed ||
            retryResult.status == JudgeStatus.wrongAnswer) {
          result = retryResult;
        }
      }
    }

    return result;
  }

  /// 起一次 Python 进程并喂指定输入，返回评估结果。
  Future<TestCaseResult> _execute(
    File solutionFile,
    TestCase testCase,
    Stopwatch stopwatch,
  ) async {
    try {
      final process = await Process.start(
        pythonCommand,
        [...PythonRuntime.utf8Args, solutionFile.absolute.path],
        workingDirectory: solutionFile.parent.path,
        // 保证 sitecustomize.py 被加载（input prompt 转 stderr）+ 强制 UTF-8
        environment: PythonRuntime.withUtf8Env({
          'PYTHONPATH': solutionFile.parent.path,
        }),
      );

      // 写入输入（判题用到的测试输入）
      process.stdin.write(testCase.input);
      await process.stdin.close();

      // 读取输出（分别捕获 stdout 和 stderr）
      final stdoutFuture = process.stdout
          .transform(utf8.decoder)
          .join()
          .timeout(Duration(milliseconds: timeoutMs));
      final stderrFuture = process.stderr
          .transform(utf8.decoder)
          .join()
          .timeout(Duration(milliseconds: timeoutMs));

      final exitCodeFuture = process.exitCode
          .timeout(Duration(milliseconds: timeoutMs));

      final elapsedMs = stopwatch.elapsedMilliseconds;

      // 等待全部完成（先等退出码，再取输出）
      final exitCode = await exitCodeFuture;
      final actualOutput = await stdoutFuture;
      final stderr = await stderrFuture;

      return _evaluate(testCase, exitCode, actualOutput, stderr, elapsedMs);
    } on TimeoutException {
      // 超时
      return TestCaseResult(
        testCase: testCase,
        status: JudgeStatus.timeout,
        actualOutput: '(程序运行超时，已强制终止)',
        stderr: '',
        timeMs: stopwatch.elapsedMilliseconds,
        message: '程序运行超过限制时间，可能陷入了死循环。',
      );
    } on ProcessException catch (e) {
      // Python 无法执行
      return TestCaseResult(
        testCase: testCase,
        status: JudgeStatus.runtimeError,
        actualOutput: '',
        stderr: '无法运行 Python: ${e.message}',
        timeMs: stopwatch.elapsedMilliseconds,
        message: '程序运行环境有问题，请联系管理员。',
      );
    }
  }

  /// 把输入按所有空白拆成多行：`17 5\n` → `17\n5\n`。
  /// 这样一次读取一行（多次 input()）也能拿到完整数据。
  String _splitInputIntoLines(String input) {
    final tokens = input.split(RegExp(r'[ \t\n]+')).where((t) => t.isNotEmpty);
    if (tokens.isEmpty) return input;
    return '${tokens.join('\n')}\n';
  }

  /// 评估一个用例：比对输出 + 生成友好错误提示
  TestCaseResult _evaluate(
    TestCase testCase,
    int exitCode,
    String actualOutput,
    String stderr,
    int timeMs,
  ) {
    final expected = testCase.output;
    final actual = actualOutput;

    // 1. 程序有运行错误（非零退出码 或 stderr 有 traceback）
    if (exitCode != 0 || _hasTraceback(stderr) || _hasTraceback(actualOutput)) {
      return TestCaseResult(
        testCase: testCase,
        status: JudgeStatus.runtimeError,
        actualOutput: actual.isEmpty ? '(无输出)' : actual,
        stderr: stderr.isEmpty ? actualOutput : stderr,
        timeMs: timeMs,
        message: _analyzeRuntimeError(stderr, actualOutput),
      );
    }

    // 2. 输出一致 → 通过（规范化行尾：去掉每行尾随空白 + 统一换行）
    if (_normalizeLines(actual) == _normalizeLines(expected)) {
      return TestCaseResult(
        testCase: testCase,
        status: JudgeStatus.passed,
        actualOutput: actual,
        stderr: stderr,
        timeMs: timeMs,
      );
    }

    // 3. 输出不一致 → 生成友好提示
    return TestCaseResult(
      testCase: testCase,
      status: JudgeStatus.wrongAnswer,
      actualOutput: actual,
      stderr: stderr,
      timeMs: timeMs,
      message: _analyzeWrongAnswer(expected, actual),
    );
  }

  /// 规范化输出以处理平台换行差异：
  /// - 统一换行符为 \n
  /// - 去掉所有行的尾随空白（print 会自动加换行，去掉尾部空行）
  /// - 把全角标点统一成半角（`，`→`,`、`！`→`!` 等），避免中文题被标点坑绊倒
  /// 注意：保留行内空格与前导空格，避免把"多打了空格"误判为通过；
  /// 不碰数字/字母（它们本就 ASCII），仅映射标点符号。
  String _normalizeLines(String s) {
    var text = _normalizePunctuation(s);
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    // 去掉每行尾随空白，去掉头部/尾部的空行
    final cleaned = lines.map((l) => l.replaceFirst(RegExp(r'\s+$'), '')).toList();
    while (cleaned.isNotEmpty && cleaned.first.isEmpty) {
      cleaned.removeAt(0);
    }
    while (cleaned.isNotEmpty && cleaned.last.isEmpty) {
      cleaned.removeLast();
    }
    return cleaned.join('\n');
  }

  /// 全角标点统一成半角，避免中英文标点的差异误判（不影响数字/字母/空格）。
  /// 逐一替换常见标点；其余字符原样保留。
  String _normalizePunctuation(String s) {
    // 全角 → 半角，一一对应（不影响数字/字母/空格）
    const full = ['，', '。', '！', '？', '：', '；', '“', '”', '‘', '’', '（', '）', '【', '】', '、'];
    const half = [',', '.', '!', '?', ':', ';', '"', '"', "'", "'", '(', ')', '[', ']', ','];
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      final idx = full.indexOf(ch);
      buffer.write(idx >= 0 ? half[idx] : ch);
    }
    return buffer.toString();
  }

  // ---------- 友好错误提示的分析逻辑 ----------

  bool _hasTraceback(String s) {
    return s.contains('Traceback') || s.contains('SyntaxError') ||
        s.contains('NameError') || s.contains('TypeError') ||
        s.contains('ValueError') || s.contains('IndexError') ||
        s.contains('KeyError') || s.contains('ZeroDivisionError') ||
        s.contains('EOFError') || s.contains('IndentationError');
  }

  /// 分析运行错误，给新手听得懂的提示
  String _analyzeRuntimeError(String stderr, String output) {
    final combined = '$stderr\n$output';
    if (combined.contains('SyntaxError')) {
      return '⚠️ 语法错误：代码有拼写或格式问题，通常是少了冒号、括号没闭合或缩进不对。\n\n$combined';
    }
    if (combined.contains('NameError')) {
      return '⚠️ 名称错误：用了一个未定义的变量或函数。可能是拼写错误（试试变量名是否一致）。\n\n$combined';
    }
    if (combined.contains('TypeError')) {
      return '⚠️ 类型错误：对类型不匹配的数据做了操作。比如字符串和数字相加。\n\n$combined';
    }
    if (combined.contains('ValueError')) {
      return '⚠️ 值错误：数值转换/输入格式有问题。比如 int() 空字符串时会报这个。\n\n$combined';
    }
    if (combined.contains('IndexError')) {
      return '⚠️ 索引越界：访问了列表/字符串不存在的下标。下标从 0 开始，最末一个是 len-1。\n\n$combined';
    }
    if (combined.contains('ZeroDivisionError')) {
      return '⚠️ 除零错误：不能除以 0。\n\n$combined';
    }
    if (combined.contains('EOFError')) {
      // 输入读取错误：程序想读更多，但测试用例输入已耗尽。
      // 常见根因：代码用了多个 input()，但题目输入是单行空格分隔（如 `17 5`）。
      return '⚠️ 输入读取错误：程序试图读取比输入更多的内容。\n'
          '这通常是**代码用了多个 input()，但题目的输入是单行、多个数用空格分隔**。\n'
          '\n'
          '✅ 如果是一行多个数，改成一次读取再拆分：\n'
          '> a, b = map(int, input().split())   # 一行读 17 5 两个数\n'
          '\n'
          '💡 也可以先看题目「输入格式」说明，确认是一行还是多行。\n'
          '\n$combined';
    }
    if (combined.contains('IndentationError')) {
      return '⚠️ 缩进错误：Python 用缩进表示代码块，记得统一用空格或制表符（最好统一用 4 个空格）。\n\n$combined';
    }
    // 兜底
    return '程序运行出错：\n\n$combined';
  }

  /// 分析输出错误原因，给出针对性提示
  String _analyzeWrongAnswer(String expected, String actual) {
    // 去掉所有空白后内容一致 → 大概率是空格/换行格式问题
    String stripWs(String s) => s.replaceAll(RegExp(r'\s'), '');

    if (stripWs(actual) == stripWs(expected)) {
      return '✅ 内容是对的！只是**格式不对**——检查一下空格和换行。\n'
          '你输出的是：\n> $actual\n期望输出是：\n> $expected';
    }

    // 实际输出包含期望输出 → 可能输出了多余内容
    if (stripWs(actual).contains(stripWs(expected))) {
      return '💡 答案包含在输出中，但**多了额外内容**。可能需要去掉多余的 print。\n'
          '你输出：$actual\n期望：$expected';
    }

    // 期望输出包含实际输出 → 可能漏了部分
    if (stripWs(expected).contains(stripWs(actual))) {
      return '💡 输出缺少了一部分。可能漏了某些 print 或换行。\n'
          '你输出：$actual\n期望：$expected';
    }

    // 计算首个不同位置，指出差异点
    final minLen = expected.length < actual.length ? expected.length : actual.length;
    for (int i = 0; i < minLen; i++) {
      if (expected[i] != actual[i]) {
        return '❌ 输出与期望在第 ${i + 1} 个字符处不同（从 1 开始数）。\n'
            '你输出了：[${actual[i] == '\n' ? '换行' : actual[i]}]，'
            '期望是：[${expected[i] == '\n' ? '换行' : expected[i]}]。\n'
            '请检查运算逻辑或输出格式。';
      }
    }
    // 长度不同但前缀相同
    if (actual.length < expected.length) {
      return '❌ 输出偏短，可能漏了内容（期望 ${expected.length} 个字符，实际 ${actual.length} 个）。';
    }
    return '❌ 输出偏长，可能有额外内容（期望 ${expected.length} 个字符，实际 ${actual.length} 个）。';
  }
}

