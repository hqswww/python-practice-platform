/// 判题引擎
///
/// 核心闭环：把学生代码写入临时文件 → 起进程运行
/// → 喂入每个测试用例的输入 → 捕获 stdout → 与期望输出比对
/// → 返回结果（含友好错误提示）。
///
/// **本引擎与语言无关**：源码文件名、要不要先编译、错误怎么翻译，
/// 全部由 [LanguageRuntime] 决定（见 language_runtime.dart）。
/// 接入 C/C++ 时只需新增一个 LanguageRuntime 实现，这里不用动。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/judge_result.dart';
import '../models/problem.dart';
import 'error_log_service.dart';
import 'c_runtime.dart';
import 'language_runtime.dart';
import 'temp_workspace.dart';

class JudgeEngine {
  /// 判题超时时间（毫秒）
  final int timeoutMs;

  /// 可选注入的运行命令（测试用 / 设置页自定义路径）
  final String? commandOverride;

  /// 编译超时（毫秒）。**与运行超时分开**：编译本身慢得多（C++ 尤其），
  /// 混在一起会把「首次编译慢」误判成超时。
  final int compileTimeoutMs;

  JudgeEngine({
    this.timeoutMs = 2000,
    this.compileTimeoutMs = 10000,
    this.commandOverride,
  });


  /// 判一道题的全部测试用例
  ///
  /// 语言从 [Problem.language] 取，运行时策略由 [runtimeFor] 决定。
  Future<JudgeResult> judge(Problem problem, String code) async {
    final runtime = runtimeFor(
      problem.language,
      commandOverride: commandOverride,
    );
    // 用 TempWorkspace 而不是 Directory.systemTemp：Windows 上 %TEMP% 可能
    // 落在中文用户名下，而 as.exe / ld.exe 不带 UTF-8 清单，见 temp_workspace.dart
    final tempDir = await TempWorkspace.create('judge_');
    final solutionFile = File('${tempDir.path}/${runtime.sourceFileName}');
    await solutionFile.writeAsString(code);
    // 语言相关的前置准备（Python 要写 sitecustomize 把 input 提示挪到 stderr）
    await runtime.prepare(tempDir);

    try {
      // ── 编译阶段（仅编译型语言；解释型 compileSpec 返回 null，直接跳过）
      //
      // 编译一次、所有用例复用同一个产物 —— 比每个用例重编快得多，
      // 也比 Python 每个用例起一次解释器快。
      final compileSpec = runtime.compileSpec(tempDir, solutionFile);
      if (compileSpec != null) {
        final failure = await _compile(runtime, compileSpec, tempDir);
        if (failure != null) {
          // 编译失败：全部用例都判编译错误。
          // 不逐用例重复同一条报错 —— 展示层只用第一条。
          return JudgeResult(
            problem: problem,
            caseResults: [
              for (final tc in problem.testCases)
                TestCaseResult(
                  testCase: tc,
                  status: JudgeStatus.compileError,
                  actualOutput: '',
                  stderr: failure,
                  timeMs: 0,
                  message: failure,
                ),
            ],
            hasError: true,
          );
        }
      }

      final results = <TestCaseResult>[];
      var hasRuntimeError = false;

      for (final testCase in problem.testCases) {
        final result = await _runTestCase(runtime, solutionFile, testCase);
        // 记录非通过用例到错误日志，方便排查判题/环境问题
        if (result.status != JudgeStatus.passed) {
          _logNonPass(result);
        }
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

  /// 编译源码。成功返回 null；失败返回给学生看的错误信息。
  Future<String?> _compile(
    LanguageRuntime runtime,
    RunSpec spec,
    Directory workDir,
  ) async {
    try {
      final result = await Process.run(
        spec.command,
        spec.args,
        workingDirectory: workDir.path,
        environment: spec.environment,
      ).timeout(Duration(milliseconds: compileTimeoutMs));

      // 只看退出码：**警告不影响判题**（编译器输出警告时退出码仍是 0），
      // 而且警告对初学者是有价值的，不该被当成错误藏起来。
      if (result.exitCode == 0) return null;

      final raw = '${result.stdout}\n${result.stderr}'.trim();
      final cleaned = runtime.cleanDiagnostics(raw, workDir);
      errorLog.logError(
        '编译失败（${runtime.language.displayName}）:\n$cleaned',
        source: LogSource.judge,
      );
      if (cleaned.isEmpty) return '编译失败，但编译器没有给出任何信息。';
      // 加一句抬头：C 的编译报错和 Python 的 traceback 长得完全不一样，
      // 初学者需要被告知「这是编译器在说话，不是你的程序输出」。
      return '❌ 代码没通过编译。下面是编译器给出的报错：\n\n$cleaned';
    } on TimeoutException {
      errorLog.logError(
        '编译超时（${compileTimeoutMs}ms，${runtime.language.displayName}）',
        source: LogSource.judge,
      );
      return '⏱ 编译超时（超过 ${compileTimeoutMs ~/ 1000} 秒）。'
          '代码是不是过于复杂，或者模板展开太深了？';
    } on ProcessException catch (e) {
      // 找不到编译器是最常见的失败，要给可操作的指引而不是「环境有问题」
      final hint = runtime is CLanguageRuntime
          ? CRuntime.installHint(runtime.language)
          : '';
      errorLog.logError(
        '无法启动编译器（${spec.command}）: ${e.message}',
        source: LogSource.judge,
        error: e,
      );
      return '❌ 找不到 ${runtime.language.displayName} 编译器'
          '（尝试执行 `${spec.command}`）。\n$hint';
    }
  }

  /// 运行单个测试用例
  Future<TestCaseResult> _runTestCase(
    LanguageRuntime runtime,
    File solutionFile,
    TestCase testCase,
  ) async {
    final stopwatch = Stopwatch()..start();

    // 第一次：按题目原始输入喂
    var result = await _execute(runtime, solutionFile, testCase, stopwatch);

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
        final retryResult =
            await _execute(runtime, solutionFile, retryCase, stopwatch);
        // 重试通过则采用；否则保留第一次结果（错误信息对用户更有用）
        if (retryResult.status == JudgeStatus.passed ||
            retryResult.status == JudgeStatus.wrongAnswer) {
          result = retryResult;
        }
      }
    }

    return result;
  }

  /// 起一次进程并喂指定输入，返回评估结果。
  Future<TestCaseResult> _execute(
    LanguageRuntime runtime,
    File solutionFile,
    TestCase testCase,
    Stopwatch stopwatch,
  ) async {
    final spec = runtime.runSpec(solutionFile.parent, solutionFile);
    Process? process;
    Future<String>? stdoutFuture;
    Future<String>? stderrFuture;
    try {
      process = await Process.start(
        spec.command,
        spec.args,
        workingDirectory: solutionFile.parent.path,
        environment: spec.environment,
      );

      // 写入输入（判题用到的测试输入）
      process.stdin.write(testCase.input);
      await process.stdin.close();

      // 读取输出（分别捕获 stdout 和 stderr）
      //
      // ⚠️ 只给 exitCode 加超时，**不要**给这两个流也各加一个：
      // exitCode 先超时返回后，那两个带超时的 future 就没人 await 了，
      // 它们随后也会抛 TimeoutException，变成「未处理的异步异常」直接把测试/应用搞崩。
      // 超时的收尾交给下面统一杀进程 —— 进程一死流自然关闭。
      stdoutFuture = process.stdout.transform(utf8.decoder).join();
      stderrFuture = process.stderr.transform(utf8.decoder).join();

      final elapsedMs = stopwatch.elapsedMilliseconds;

      final exitCode =
          await process.exitCode.timeout(Duration(milliseconds: timeoutMs));
      final actualOutput = await stdoutFuture;
      final stderr = await stderrFuture;

      return _evaluate(runtime, testCase, exitCode, actualOutput, stderr,
          elapsedMs, solutionFile.parent);
    } on TimeoutException {
      // **必须真的杀掉进程**：只返回超时结果而不杀，学生的 while(1)
      // 会在后台一直跑下去吃满 CPU（提示里写着"已强制终止"，实际并没有）。
      _killQuietly(process);
      // 进程没了，两个流会关闭；给一点时间让它们收尾，失败也不管
      // （此时进程已终止，流的内容也没用了）。
      try {
        await Future.wait([stdoutFuture!, stderrFuture!])
            .timeout(const Duration(milliseconds: 500));
      } catch (_) {}
      return TestCaseResult(
        testCase: testCase,
        status: JudgeStatus.timeout,
        actualOutput: '(程序运行超时，已强制终止)',
        stderr: '',
        timeMs: stopwatch.elapsedMilliseconds,
        message: '程序运行超过限制时间，可能陷入了死循环。',
      );
    } on ProcessException catch (e) {
      // 运行时无法启动 → 记入错误日志供排查（如解释器/编译器路径配错、未安装）
      errorLog.logError(
        '无法运行 ${runtime.language.displayName}（${spec.command}）: ${e.message}',
        source: LogSource.python,
        error: e,
      );
      return TestCaseResult(
        testCase: testCase,
        status: JudgeStatus.runtimeError,
        actualOutput: '',
        stderr: '无法运行 ${runtime.language.displayName}: ${e.message}',
        timeMs: stopwatch.elapsedMilliseconds,
        message: '程序运行环境有问题，请联系管理员。',
      );
    }
  }

  /// 尽力杀掉进程；已经退出或权限不足都忽略
  void _killQuietly(Process? p) {
    if (p == null) return;
    try {
      p.kill(ProcessSignal.sigkill);
    } catch (_) {
      // 进程可能已自行退出
    }
  }

  /// 记录一次非通过用例到错误日志（超时 / 运行时错误 / 答案错误）。
  /// 便于在「日志中心」排查：解释器路径配错、权限不足、环境异常等。
  void _logNonPass(TestCaseResult result) {
    final t = result.testCase;
    final level = result.status == JudgeStatus.wrongAnswer
        ? LogLevel.warning
        : LogLevel.error;
    // 用例没有 id，用输入摘要做标识
    final inputHead = t.input.trim().replaceAll('\n', ' ');
    final brief = (result.message.isNotEmpty ? result.message : result.status.name)
        .trim();
    errorLog.log(
      '判题未通过 [${result.status.name}] 输入「$inputHead」：${brief.split('\n').first}',
      source: LogSource.judge,
      level: level,
    );
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
    LanguageRuntime runtime,
    TestCase testCase,
    int exitCode,
    String actualOutput,
    String stderr,
    int timeMs,
    Directory workDir,
  ) {
    final expected = testCase.output;
    final actual = actualOutput;

    // 1. 程序有运行错误（非零退出码 或 stderr 有 traceback）
    if (exitCode != 0 ||
        runtime.looksLikeRuntimeError(stderr, actualOutput)) {
      return TestCaseResult(
        testCase: testCase,
        status: JudgeStatus.runtimeError,
        actualOutput: actual.isEmpty ? '(无输出)' : actual,
        stderr: stderr.isEmpty ? actualOutput : stderr,
        timeMs: timeMs,
        message: _runtimeErrorMessage(
            runtime, stderr, actualOutput, exitCode, workDir),
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

  /// 运行时错误提示：优先用该语言自己的翻译，没有则用通用兜底。
  ///
  /// 语言相关的错误名（Python 的 NameError、clang 的 `error:` 等）
  /// 都住在各自的 [LanguageRuntime] 里，这里只负责兜底。
  String _runtimeErrorMessage(
    LanguageRuntime runtime,
    String stderr,
    String output,
    int exitCode,
    Directory workDir,
  ) {
    // ⚠️ 必须传**真实**的工作目录：cleanDiagnostics 靠它把报错里的绝对路径
    // 换成 `.`。工作目录挪到 ASCII 位置后，这里若还写 Directory.systemTemp，
    // 替换就匹配不上，学生的报错里会漏出一长串 `C:\ProgramData\...`。
    final cleaned = runtime.cleanDiagnostics(stderr, workDir);
    return runtime.explainRuntimeError(cleaned, output, exitCode: exitCode) ??
        '程序运行出错：\n\n$cleaned\n$output';
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

