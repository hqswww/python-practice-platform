import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/programming_language.dart';

/// 装不上时的退路：一个下载页，和/或一条可以复制的命令。
///
/// 为什么需要它：一键安装不可能覆盖所有情况（没网、非 Windows、企业策略拦了
/// 脚本执行）。这时候必须给用户一条**能自己走通**的路，而不是一句「安装失败」。
class InstallGuidance {
  const InstallGuidance({this.url, this.urlLabel, this.command});

  /// 官方下载页（用系统浏览器打开）
  final String? url;

  /// 按钮上显示的文字，比如「打开 Python 官网」
  final String? urlLabel;

  /// 可以直接粘到终端里跑的命令（Linux / macOS 用）
  final String? command;

  bool get isEmpty => url == null && command == null;
}

/// 「一键安装编译器 / 解释器」。
///
/// 目前只有 Windows 支持自动安装（`tools/install_mingw.ps1` 随应用一起分发）。
/// Linux / macOS 刻意不做自动安装：
/// - Linux 各发行版的包管理器不同，装系统级软件包本来就该由用户自己确认
/// - macOS 上 `xcode-select --install` 会弹系统自己的确认框，我们再套一层反而绕
///
/// 两边的共同点是**都不需要管理员权限去改系统的东西**，做不到时就退回
/// [guidanceFor] 给出的指引。
class RuntimeInstaller {
  /// 随应用分发的 Windows 安装脚本文件名
  static const String windowsScriptName = 'install_mingw.ps1';

  /// 找到可用于自动安装的脚本；找不到返回 null。
  ///
  /// 找两处：
  /// 1. 可执行文件旁边 —— 打包分发后的布局（build_windows.ps1 会把它拷进 dist）
  /// 2. `tools/` 下 —— 源码运行时（`flutter run`）的布局
  static File? findScript() {
    if (!Platform.isWindows) return null;
    final candidates = <String>[];

    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      candidates.add('$exeDir${Platform.pathSeparator}$windowsScriptName');
    } catch (_) {}

    candidates.add(
        'tools${Platform.pathSeparator}$windowsScriptName'); // 相对当前工作目录

    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync()) return f;
    }
    return null;
  }

  /// 这台机器上能不能「一键安装」
  static bool get canAutoInstall => findScript() != null;

  /// 跑安装脚本，输出按行回调（脚本会打印自己的进度）。
  ///
  /// 返回进程退出码：0 = 成功。
  ///
  /// 注意**不要**请求管理员权限：脚本刻意只装到用户目录、只改用户 PATH，
  /// 不需要 UAC。弹一个提权框只会吓退用户，而且提权进程的环境变量还更麻烦。
  static Future<int> runScript(
    File script, {
    void Function(String line)? onOutput,
  }) async {
    final process = await Process.start(
      'powershell.exe',
      [
        '-NoProfile', // 别加载用户 profile，避免被自定义函数干扰
        '-ExecutionPolicy', 'Bypass', // 组策略若禁止脚本，Bypass 能绕开
        '-File', script.path,
      ],
      runInShell: false,
    );

    // stdout / stderr 都要转发：脚本的进度在 stdout，PowerShell 的错误在 stderr。
    // 不读的话管道写满会导致子进程卡死（判题那边踩过同样的坑）。
    final done = Completer<void>();
    var pending = 2;
    void forward(Stream<List<int>> s) {
      s.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          if (line.trim().isNotEmpty) onOutput?.call(line);
        },
        onDone: () {
          if (--pending == 0) done.complete();
        },
        onError: (_) {
          if (--pending == 0) done.complete();
        },
      );
    }

    forward(process.stdout);
    forward(process.stderr);

    final code = await process.exitCode;
    // 进程退出后流可能还没读完，等一小会儿收尾（内容是给人看的，不必阻塞太久）
    await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    return code;
  }

  /// 这个平台的退路指引
  static InstallGuidance guidanceFor(ProgrammingLanguage language) {
    if (language == ProgrammingLanguage.python) {
      if (Platform.isWindows) {
        return const InstallGuidance(
          url: 'https://www.python.org/downloads/windows/',
          urlLabel: '打开 Python 官网',
          command: 'winget install Python.Python.3.12',
        );
      }
      if (Platform.isMacOS) {
        return const InstallGuidance(
          url: 'https://www.python.org/downloads/macos/',
          urlLabel: '打开 Python 官网',
          command: 'brew install python3',
        );
      }
      return const InstallGuidance(command: 'sudo apt install python3');
    }

    // C / C++ 是同一套编译器，指引共用
    if (Platform.isWindows) {
      return const InstallGuidance(
        url: 'https://github.com/skeeto/w64devkit/releases',
        urlLabel: '打开 w64devkit 下载页',
      );
    }
    if (Platform.isMacOS) {
      return const InstallGuidance(command: 'xcode-select --install');
    }
    return const InstallGuidance(command: 'sudo apt install build-essential');
  }

  /// 用系统默认浏览器打开一个网址。
  ///
  /// 刻意不引 url_launcher：那是个带三平台原生实现的插件，为了打开一个网址
  /// 增加三个平台的构建依赖不划算。这里调各平台自带的命令，够用且零依赖。
  static Future<bool> openExternal(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isWindows) {
        // cmd 的 start 会把第一个带引号的参数当成窗口标题，所以要先给个空标题
        await Process.run('cmd', ['/c', 'start', '', url], runInShell: false);
      } else {
        await Process.run('xdg-open', [url]);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
