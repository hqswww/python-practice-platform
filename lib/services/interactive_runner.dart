/// 交互式 Python 运行器 —— 模拟真实终端 REPL 体验。
///
/// 与前一个"方案C形态1"（已回滚的一次性多行输入手动测试）不同：
/// 这里是**常驻进程 + 流式 I/O**：
/// - 程序输出 → 实时推到 UI（stream）
/// - 程序跑到 `input()` 停下来 → UI 进入可输入态，用户敲一行回车 → 写 stdin
/// - 用户能亲眼看到每个 input() 各读到什么，彻底搞懂多 input 的喂数方式
///
/// 零第三方依赖，只用 dart:io 的 Process；离线打包无 pub 风险。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 一次交互运行的生命周期事件
enum RunnerEventKind {
  /// 程序输出到 stdout
  output,

  /// 程序输出到 stderr（含 traceback）
  error,

  /// 进程已退出（code 可能为 null，表示被外界终止）
  exit,
}

class RunnerEvent {
  final RunnerEventKind kind;
  final String text;
  final int? exitCode;
  const RunnerEvent(this.kind, [this.text = '', this.exitCode]);
}

class InteractiveRunner {
  /// 可选注入的 Python 命令（测试用 / Windows 捆绑路径）
  final String pythonCommand;

  Process? _process;
  Directory? _tempDir;
  StreamController<RunnerEvent>? _events;
  bool _isRunning = false;
  bool _ioClosed = false;

  InteractiveRunner({String? pythonCommand})
      : pythonCommand = pythonCommand ?? _defaultPython();

  static String _defaultPython() {
    if (Platform.isWindows) return 'python.exe';
    return 'python3';
  }

  bool get isRunning => _isRunning;

  /// 事件流：output / error / exit
  ///
  /// 懒初始化：首次访问时自动创建 controller，保证不再有 `_events!` 空崩溃
  /// （终端面板收起→销毁→再展开重建 State 时会新建 runner，这里必须能从头拿到流）。
  Stream<RunnerEvent> get events {
    _events ??= StreamController<RunnerEvent>.broadcast();
    return _events!.stream;
  }

  /// 启动一次交互运行，执行 [code]；之后的 input 由 [sendLine] 逐行喂入
  Future<Process> start(String code) async {
    // 复用已存在的 events controller：
    // 调用方在 start 前就已订阅 events，重建会丢事件 → 必须复用一个实例。
    if (_events == null || _events!.isClosed) {
      _events = StreamController<RunnerEvent>.broadcast();
    }
    final ev = _events!;
    _ioClosed = false;

    final tempDir = await Directory.systemTemp.createTemp('py_interactive_');
    _tempDir = tempDir;
    final file = File('${tempDir.path}/runner.py');
    await file.writeAsString(code);

    final process = await Process.start(
      pythonCommand,
      [file.absolute.path],
      workingDirectory: file.parent.path,
    );
    _process = process;
    _isRunning = true;

    void emit(RunnerEvent e) {
      if (_ioClosed) return;
      ev.add(e);
    }

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
      _ioClosed = true;
      ev.close();
      try {
        tempDir.delete(recursive: true);
      } catch (_) {}
      _tempDir = null;
    });

    return process;
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
