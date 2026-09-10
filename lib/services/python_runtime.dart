import 'dart:ffi' show Abi;
import 'dart:io';

import 'settings_service.dart';

/// Python 运行时解析与 UTF-8 加固（Windows / macOS 迁移关键）
///
/// **Windows 迁移两大坑：**
/// 1. **Python 位置**：打包时把「嵌入式 Python」放进应用目录，
///    运行时按「exe 所在目录」的相对路径找捆绑的 python.exe，
///    不能依赖系统 PATH（目标机器可能没装 Python）。
/// 2. **编码**：Windows 下 Python 的 stdin/stdout 默认可能走 GBK，
///    中文输出会跟 UTF-8 比对错。统一加 `-X utf8` + `PYTHONIOENCODING=utf-8`。
///
/// **macOS 迁移三大坑（对应下面的 macOS 分支）：**
/// 1. **Finder 启动的 .app 只有极简 PATH**（`/usr/bin:/bin:/usr/sbin:/sbin`），
///    Homebrew（`/opt/homebrew`、`/usr/local`）和 MacPorts（`/opt/local`）
///    的 python3 **不在 PATH 里**，所以必须显式探测绝对路径。
/// 2. **`/usr/bin/python3` 是 Xcode 的 shim**：装了 Command Line Tools 才是真解释器，
///    没装时执行它会弹系统安装提示（GUI 环境下会卡住）→ 只能当最后兜底。
/// 3. **捆绑解释器要放进 .app 内，且必须放 `Contents/Resources/`**：
///    `Contents/Resources/python-<arch>/bin/python3`。
///    放 `Frameworks/` 会让 codesign 拒签（详见 [macBundledRelativePaths]）。
/// 4. **产物是 universal，Python 是单架构**：两种架构各带一份，按 `Abi.current()` 挑。
class PythonRuntime {
  // ---------------------------------------------------------------- Windows

  /// 捆绑 Python 在应用目录下的相对子目录（打包脚本也按此放置）
  static const String bundledRelativeDir = 'python';

  /// Windows 下可执行文件名
  static const String bundledExeName = 'python.exe';

  // ------------------------------------------------------------------ macOS

  /// macOS 捆绑 Python 在 `.app/Contents/` 下的相对路径（按优先级）。
  ///
  /// ⚠️ **Resources 必须排在 Frameworks 前面**（实测踩坑）：
  /// `codesign` 把 `Contents/Frameworks/` 下的**任何目录**都当作「嵌套代码」解析，
  /// 要求它是合法的 framework/bundle。Python 是几千个散文件的大目录树，
  /// 放进去会直接签名失败：
  /// ```
  /// code object is not signed at all
  ///   In subcomponent: .../Frameworks/python-arm64/lib/pkgconfig/python-3.12.pc
  /// bundle format unrecognized, invalid, or unsuitable
  ///   In subcomponent: .../Frameworks/python-arm64/lib/python3.12
  /// ```
  /// 放 `Contents/Resources/` 则被当作「资源」按哈希封存，
  /// 只需单独签里面的 Mach-O（.dylib / .so / bin/python3）即可 —— 实测签名校验通过。
  ///
  /// 仍然保留 Frameworks 候选，是为了兼容手工组装的其他布局。
  static const List<String> macBundledRelativePaths = [
    'Resources/python/bin/python3',
    'Frameworks/python/bin/python3',
  ];

  /// universal 包里按架构区分的捆绑目录名
  static const String macArchDirArm64 = 'python-arm64';
  static const String macArchDirX64 = 'python-x86_64';

  /// 当前进程运行架构对应的捆绑目录名；无法判定时返回 null
  ///
  /// 为什么需要这个：`flutter build macos --release` 的产物是 **universal
  /// 二进制**（x86_64 + arm64 都在同一份 App 里），而捆绑的 Python 是单架构的。
  /// 所以 universal 包必须同时带两份 Python，运行时按当前架构挑。
  /// 拿错架构的解释器会直接 `Bad CPU type in executable`。
  static String? currentMacArchDirName() {
    // 首选 dart:ffi —— AOT 下每一条 slice 各自编译，返回的就是正在跑的那个架构
    try {
      final abi = Abi.current();
      if (abi == Abi.macosArm64) return macArchDirArm64;
      if (abi == Abi.macosX64) return macArchDirX64;
    } catch (_) {}

    // 兜底：从 Platform.version 嗅探（形如 ... on "macos_arm64"）
    try {
      final v = Platform.version;
      if (v.contains('macos_arm64')) return macArchDirArm64;
      if (v.contains('macos_x64')) return macArchDirX64;
      if (v.contains('arm64')) return macArchDirArm64;
      if (v.contains('x64')) return macArchDirX64;
    } catch (_) {}

    return null;
  }

  /// macOS 没有捆绑解释器时的兜底候选（按优先级，均为绝对路径）。
  ///
  /// 之所以把这些写死：Finder 启动的 .app 拿不到用户 shell 里的 PATH，
  /// 光靠 `Process.start('python3')` 会直接 ProcessException。
  static const List<String> macFallbackPaths = [
    '/opt/homebrew/bin/python3', // Apple Silicon Homebrew
    '/usr/local/bin/python3', // Intel Homebrew
    '/opt/local/bin/python3', // MacPorts
    '/usr/bin/python3', // Xcode Command Line Tools（无 CLT 时是 shim）
  ];

  // ------------------------------------------------------------------- 解析

  /// 解析实际要用的 Python 命令：
  /// 1. 若用户在设置页填了自定义路径，优先用它（可指向任意 python/python.exe）
  /// 2. macOS：捆绑解释器 → Homebrew/MacPorts/Xcode 绝对路径 → PATH 里的 python3
  /// 3. Windows：找捆绑的 python.exe（exe 同目录/python/python.exe），找不到回退 `python.exe`
  /// 4. 其他平台（Linux）：`python3`
  static String resolvePythonCommand() {
    // 自定义路径优先（设置页可配，方便引导到指定解释器）
    final custom = settings.pythonPath.trim();
    if (custom.isNotEmpty) return custom;

    if (Platform.isMacOS) {
      final bundled = _bundledMacPythonPath();
      if (bundled != null) return bundled;

      for (final candidate in macFallbackPaths) {
        if (_isExecutableFile(candidate)) return candidate;
      }

      final onPath = _whichSync('python3');
      if (onPath != null) return onPath;

      // 最后兜底：交给判题引擎抛 ProcessException，
      // 由 errorLog + 友好提示引导用户去设置页手动指定解释器。
      return 'python3';
    }

    if (!Platform.isWindows) return 'python3';

    final bundled = _bundledPythonPath();
    if (bundled != null && File(bundled).existsSync()) {
      return bundled;
    }
    return 'python.exe'; // 开发期回退
  }

  /// 捆绑 python.exe 的绝对路径（基于当前 exe 所在目录）
  ///
  /// 兼容两种布局：
  /// - Windows 源码运行（dart run / flutter test）：exe 在 build 目录，找不到捆绑 → 返回 null
  /// - 打包后：exe 在 `bundle/`，python 在 `bundle/python/python.exe`
  static String? _bundledPythonPath() {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final candidate = '$exeDir${Platform.pathSeparator}'
          '$bundledRelativeDir${Platform.pathSeparator}$bundledExeName';
      if (File(candidate).existsSync()) return candidate;
    } catch (_) {}
    return null;
  }

  /// macOS 捆绑解释器的绝对路径；找不到返回 null。
  ///
  /// 布局（`resolvedExecutable` = `<App>.app/Contents/MacOS/<exe>`）：
  /// ```
  /// <App>.app/Contents/MacOS/<exe>                            ← resolvedExecutable
  /// <App>.app/Contents/Resources/python-<arch>/bin/python3    ← universal 包，优先
  /// <App>.app/Contents/Frameworks/python-<arch>/bin/python3
  /// <App>.app/Contents/Resources/python/bin/python3           ← 单架构包（回退）
  /// <App>.app/Contents/Frameworks/python/bin/python3
  /// ```
  /// `<arch>` 由 [currentMacArchDirName] 决定（Apple 芯片 = `arm64`，Intel = `x86_64`）。
  /// 为什么 Resources 优先于 Frameworks 见 [macBundledRelativePaths] 的说明。
  ///
  /// 源码运行（`flutter test` / `dart run`）时 exe 不在 .app 内，
  /// 这里算出的路径自然不存在 → 返回 null，安全回退到系统解释器。
  static String? _bundledMacPythonPath() {
    try {
      // .../Contents/MacOS/<exe> → .../Contents
      final contentsDir = File(Platform.resolvedExecutable).parent.parent;

      final archDir = currentMacArchDirName();
      final candidates = <String>[
        // 架构专属目录优先：universal 包里两份 Python 靠这个区分
        if (archDir != null)
          for (final rel in macBundledRelativePaths)
            rel.replaceFirst('/python/', '/$archDir/'),
        // 再退回通用目录：兼容只带一份 Python 的单架构包
        ...macBundledRelativePaths,
      ];

      for (final rel in candidates) {
        final candidate = '${contentsDir.path}/$rel';
        if (_isExecutableFile(candidate)) return candidate;
      }
    } catch (_) {}
    return null;
  }

  /// 判断路径是否为「存在的可执行文件」（0o111 任一位置位）
  static bool _isExecutableFile(String path) {
    try {
      final stat = FileStat.statSync(path);
      return stat.type == FileSystemEntityType.file && (stat.mode & 0x49) != 0;
    } catch (_) {
      return false;
    }
  }

  /// 简易 `which`：在 PATH 里找可执行文件（Dart 无内置实现）
  static String? _whichSync(String exe) {
    final rawPath = Platform.environment['PATH'];
    if (rawPath == null || rawPath.isEmpty) return null;
    for (final dir in rawPath.split(':')) {
      if (dir.isEmpty) continue;
      final candidate = '$dir/$exe';
      if (_isExecutableFile(candidate)) return candidate;
    }
    return null;
  }

  // -------------------------------------------------------------- UTF-8 加固

  /// 传给 Python 的通用 UTF-8 启动参数（Python 3.7+ 支持）
  static const List<String> utf8Args = ['-X', 'utf8'];

  /// 融合基础环境变量的 UTF-8 环境（合并用户的 PATH，避免破坏依赖查找）
  static Map<String, String> withUtf8Env([Map<String, String>? base]) {
    return {
      ...(base ?? {}),
      'PYTHONIOENCODING': 'utf-8',
      'PYTHONUTF8': '1',
    };
  }
}
