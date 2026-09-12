/// 交互式运行器 —— 模拟真实终端体验。
///
/// 设计要点：
/// - **常驻进程 + 流式 I/O**：程序输出实时推到 UI；程序读到输入停下来时，
///   用户在面板里敲一行回车写进 stdin，相当于在真终端里逐行喂数。
///   这对「一道题有多个 input / scanf」的学习场景价值最大 ——
///   学生能亲眼看到每一行被哪一次读取吃掉了。
/// - **与语言无关**：按 [language] 取对应的 [LanguageRuntime]。
///   解释型直接跑源码；编译型先编译、再跑产物。
///
/// ⚠️ 这个类曾经**写死 Python**：无论什么语言都写 `runner.py` 并执行
/// `pythonCommand`。于是 C / C++ 题目上点「编译运行」，实际起的是 Python
/// 解释器去解释 C 代码。语言维度必须一路贯到最底层，这里是最容易漏的一层。
///
/// 零第三方依赖，只用 dart:io 的 Process；离线打包无 pub 风险。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/programming_language.dart';
import 'language_runtime.dart';
import 'temp_workspace.dart';

/// 一次交互运行的生命周期事件
enum RunnerEventKind {
  /// 程序输出到 stdout
  output,

  /// 程序输出到 stderr（含 traceback / 编译器报错）
  error,

  /// 进程已退出（code 可能为 null，表示被外界终止）
  exit,

  /// 面板自己产生的提示（命令行回显、编译中、失败原因等）
  hint,
}

class RunnerEvent {
  final RunnerEventKind kind;
  final String text;
  final int? exitCode;
  const RunnerEvent(this.kind, [this.text = '', this.exitCode]);
}

class InteractiveRunner {
  /// 本次要跑哪门语言 —— 决定源码文件名、要不要先编译、以及怎么解释报错
  final ProgrammingLanguage language;

  /// 覆盖解释器 / 编译器路径（测试注入或设置页自定义）
  final String? commandOverride;

  /// 编译超时。编译比运行慢得多（C++ 尤其），给得宽松些
  static const Duration compileTimeout = Duration(seconds: 20);

  Process? _process;
  Directory? _tempDir;
  StreamController<RunnerEvent>? _events;
  bool _isRunning = false;
  bool _ioClosed = false;

  InteractiveRunner({
    this.language = ProgrammingLanguage.python,
    this.commandOverride,
  });

  bool get isRunning => _isRunning;

  /// 事件流：output / error / hint / exit
  ///
  /// 懒初始化：首次访问时自动创建 controller，保证不再有 `_events!` 空崩溃
  /// （终端面板收起→销毁→再展开重建 State 时会新建 runner，这里必须能从头拿到流）。
  Stream<RunnerEvent> get events {
    _events ??= StreamController<RunnerEvent>.broadcast();
    return _events!.stream;
  }

  LanguageRuntime get _runtime =>
      runtimeFor(language, commandOverride: commandOverride);

  /// 把命令行渲染成学生看得懂的样子（临时目录那串路径换成 `.`）
  String _prettyCommand(String command, List<String> args, Directory dir) {
    String trim(String s) => s.replaceFirst(dir.path, '.');
    return [trim(command), ...args.map(trim)].join(' ');
  }

  void _finish(Directory tempDir) {
    _ioClosed = true;
    _events?.close();
    try {
      tempDir.delete(recursive: true);
    } catch (_) {}
    _tempDir = null;
  }

  /// 启动一次交互运行，执行 [code]；之后的输入由 [sendLine] 逐行喂入。
  ///
  /// 返回是否真的跑起来了。编译型语言编译失败时返回 false ——
  /// 这时已经通过 [events] 把编译器报错推给界面了。
  Future<bool> start(String code) async {
    // 复用已存在的 events controller：
    // 调用方在 start 前就已订阅 events，重建会丢事件 → 必须复用一个实例。
    if (_events == null || _events!.isClosed) {
      _events = StreamController<RunnerEvent>.broadcast();
    }
    final ev = _events!;
    _ioClosed = false;

    void emit(RunnerEvent e) {
      if (_ioClosed) return;
      ev.add(e);
    }

    final runtime = _runtime;
    // 同判题：Windows 上 %TEMP% 可能在中文用户名下，而 as/ld 不带 UTF-8 清单。
    // 交互运行也会编译（C/C++），所以这里同样要走 ASCII 安全的工作目录。
    final tempDir = await TempWorkspace.create('run_interactive_');
    _tempDir = tempDir;
    final file = File(
        '${tempDir.path}${Platform.pathSeparator}${runtime.sourceFileName}');
    await file.writeAsString(code);

    // ---------------------------------------------------------- 编译阶段
    final compile = runtime.compileSpec(tempDir, file);
    if (compile != null) {
      emit(RunnerEvent(
          RunnerEventKind.hint, '\$ ${_prettyCommand(compile.command, compile.args, tempDir)}\n'));

      final Process proc;
      try {
        proc = await Process.start(
          compile.command,
          compile.args,
          workingDirectory: tempDir.path,
          environment: compile.environment,
        );
      } catch (e) {
        emit(RunnerEvent(RunnerEventKind.error, '无法启动编译器：$e\n'));
        emit(RunnerEvent(RunnerEventKind.exit, '', 1));
        _isRunning = false;
        _finish(tempDir);
        return false;
      }

      final outFuture = proc.stdout.transform(utf8.decoder).join();
      final errFuture = proc.stderr.transform(utf8.decoder).join();

      int exitCode;
      try {
        exitCode = await proc.exitCode.timeout(compileTimeout);
      } on TimeoutException {
        // 和判题引擎同一个教训：超时必须真的把进程杀掉，
        // 否则编译进程会在后台一直跑（提示里写着"已终止"却没有）
        try {
          proc.kill(ProcessSignal.sigkill);
        } catch (_) {}
        emit(RunnerEvent(RunnerEventKind.error,
            '⏱ 编译超时（超过 ${compileTimeout.inSeconds} 秒），已强制终止。\n'));
        emit(RunnerEvent(RunnerEventKind.exit, '', 1));
        _isRunning = false;
        _finish(tempDir);
        return false;
      }

      final raw = '${await outFuture}\n${await errFuture}'.trim();
      // 临时目录的绝对路径对学生是纯噪音，清洗掉
      final cleaned = runtime.cleanDiagnostics(raw, tempDir);
      if (cleaned.isNotEmpty) {
        emit(RunnerEvent(
            exitCode == 0 ? RunnerEventKind.output : RunnerEventKind.error,
            '$cleaned\n'));
      }
      if (exitCode != 0) {
        emit(RunnerEvent(RunnerEventKind.hint,
            '\n❌ 没通过编译，没有生成可执行文件 —— 上面是编译器给出的报错。\n'));
        emit(RunnerEvent(RunnerEventKind.exit, '', exitCode));
        _isRunning = false;
        _finish(tempDir);
        return false;
      }
    }

    // ---------------------------------------------------------- 运行阶段
    final spec = runtime.runSpec(tempDir, file);
    emit(RunnerEvent(
        RunnerEventKind.hint, '\$ ${_prettyCommand(spec.command, spec.args, tempDir)}\n'));

    final process = await Process.start(
      spec.command,
      spec.args,
      workingDirectory: tempDir.path,
      environment: spec.environment,
    );
    _process = process;
    _isRunning = true;

    // stdout 实时推送
    process.stdout.transform(utf8.decoder).listen((chunk) {
      emit(RunnerEvent(RunnerEventKind.output, chunk));
    });

    // stderr 实时推送
    process.stderr.transform(utf8.decoder).listen((chunk) {
      emit(RunnerEvent(RunnerEventKind.error, chunk));
    });

    // 进程退出 → 广播 exit，随后关闭流并清理
    process.exitCode.then((code) {
      _isRunning = false;
      emit(RunnerEvent(RunnerEventKind.exit, '', code));
      _finish(tempDir);
    });

    return true;
  }

  /// 往运行中的 stdin 写一行（等价于用户在终端敲了一行回车）。
  /// 回调 [onEcho] 用于把这一行回显到终端 UI。
  void sendLine(String line, {void Function(String line)? onEcho}) {
    final p = _process;
    if (p == null || !_isRunning) return;
    p.stdin.writeln(line);
    onEcho?.call(line);
  }

  /// 主动终止当前交互进程
  Future<void> stop() async {
    final p = _process;
    if (p == null) return;
    _isRunning = false;
    try {
      p.stdin.close();
    } catch (_) {}
    try {
      p.kill();
    } catch (_) {}
    await p.exitCode.timeout(
      const Duration(seconds: 1),
      onTimeout: () => 1,
    );
  }

  void dispose() {
    stop();
    _events?.close();
    _ioClosed = true;
    try {
      _tempDir?.delete(recursive: true);
    } catch (_) {}
    _tempDir = null;
  }
}
