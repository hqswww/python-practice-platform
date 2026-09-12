import 'dart:io';

import '../models/programming_language.dart';
import 'settings_service.dart';

/// C / C++ 编译器解析
///
/// 与 [PythonRuntime] 的区别值得说明：Python 是**解释器**，我们是把它
/// 整个捆进 `.app` / 分发目录的（免装）；C/C++ 是**编译器**，捆绑不现实 ——
/// clang 二进制 98MB + macOS SDK 258MB，而且 Apple 的 SDK 不允许再分发。
///
/// 所以这里走「用系统编译器」的路线：
/// - **macOS**：`/usr/bin/clang`（Xcode Command Line Tools 提供。本机是开发机，没问题）
/// - **Linux**：`/usr/bin/gcc`（绝大多数发行版自带）
/// - **Windows**：MinGW-w64 的 `gcc.exe`（需要用户装，后续会提供一键安装脚本）
///
/// 找不到时要给出**可操作**的提示，而不是一句「运行环境有问题」。
class CRuntime {
  /// 该语言的源码扩展名（C 是 .c，C++ 是 .cpp）。
  /// 编译器在扩展名上会区分语言，所以这个必须对。
  static const Map<ProgrammingLanguage, String> _extensions = {
    ProgrammingLanguage.c: 'c',
    ProgrammingLanguage.cpp: 'cpp',
  };

  /// 按平台给的兜底候选路径（优先于 PATH 查找：这些是官方安装位置，更可信）。
  ///
  /// 和 Python 那边同一个理由：从 Finder 启动的 `.app` 只有极简 PATH，
  /// 光靠 `Process.start('gcc')` 在 macOS 上虽然能命中 /usr/bin，
  /// 但 MinGW / MacPorts 装在别处时就找不到了。
  static const Map<String, List<String>> _fallbackByPlatform = {
    'macos': [
      '/usr/bin/clang', // Xcode Command Line Tools
      '/opt/homebrew/bin/gcc-14', // Apple Silicon Homebrew
      '/usr/local/bin/gcc-14', // Intel Homebrew
      '/opt/local/bin/gcc', // MacPorts
    ],
    'linux': [
      '/usr/bin/gcc',
      '/usr/bin/cc',
      '/usr/local/bin/gcc',
    ],
    'windows': [
      r'C:\mingw64\bin\gcc.exe',
      r'C:\msys64\mingw64\bin\gcc.exe',
      r'C:\Program Files\mingw-w64\mingw64\bin\gcc.exe',
    ],
  };

  /// 解析当前平台该用的编译器命令。
  ///
  /// 优先级：设置页自定义 → 平台兜底路径 → PATH 里的编译器名。
  static String resolveCompiler(ProgrammingLanguage language) {
    final custom = settings.runtimePath(language).trim();
    if (custom.isNotEmpty) return custom;

    final names = _compilerNames(language);
    final fallbacks = <String>[
      if (Platform.isMacOS) ..._fallbackByPlatform['macos']!,
      if (Platform.isLinux) ..._fallbackByPlatform['linux']!,
      if (Platform.isWindows) ..._fallbackByPlatform['windows']!,
    ];
    for (final candidate in fallbacks) {
      if (_isExecutable(candidate)) return candidate;
    }
    for (final name in names) {
      final found = _which(name);
      if (found != null) return found;
    }
    // 没找到也返回名字：让 Process.start 抛 ProcessException，
    // 由判题引擎翻译成「请先安装编译器」的可操作提示。
    return names.first;
  }

  /// 编译器候选命令名（按优先级）
  static List<String> _compilerNames(ProgrammingLanguage language) {
    if (Platform.isWindows) {
      return language == ProgrammingLanguage.cpp
          ? ['g++.exe', 'gcc.exe']
          : ['gcc.exe'];
    }
    // clang 显式排在 gcc 之前：macOS 上 /usr/bin/gcc 其实就是 clang 的转发，
    // 报错格式按 clang 处理更一致
    return language == ProgrammingLanguage.cpp
        ? ['clang++', 'g++', 'c++']
        : ['clang', 'gcc', 'cc'];
  }

  /// 该语言源码的扩展名
  static String extensionFor(ProgrammingLanguage language) =>
      _extensions[language] ?? 'c';

  /// 该语言的编译器是否可用（用于 UI 提前提示，而不是等判题才报错）
  static bool isCompilerAvailable(ProgrammingLanguage language) {
    final cmd = resolveCompiler(language);
    if (cmd.contains('/') || cmd.contains(r'\')) return _isExecutable(cmd);
    return _which(cmd) != null;
  }

  /// 给用户的安装指引（各平台一句话）
  static String installHint(ProgrammingLanguage language) {
    if (Platform.isMacOS) {
      return '请先安装 Xcode Command Line Tools：在终端执行 `xcode-select --install`';
    }
    if (Platform.isWindows) {
      return '请先安装 MinGW-w64（提供 gcc），并把它加到 PATH；'
          '或在本应用设置页手动指定 gcc.exe 的路径';
    }
    return '请先安装 gcc：例如 `sudo apt install build-essential`（Debian/Ubuntu）'
        '或 `sudo dnf install gcc`（Fedora）';
  }

  static bool _isExecutable(String path) {
    try {
      final stat = FileStat.statSync(path);
      return stat.type == FileSystemEntityType.file && (stat.mode & 0x49) != 0;
    } catch (_) {
      return false;
    }
  }

  /// 简易 which（Dart 没有内置实现）
  static String? _which(String exe) {
    final rawPath = Platform.environment['PATH'];
    if (rawPath == null || rawPath.isEmpty) return null;
    final sep = Platform.isWindows ? ';' : ':';
    for (final dir in rawPath.split(sep)) {
      if (dir.isEmpty) continue;
      final candidate = '$dir${Platform.pathSeparator}$exe';
      if (_isExecutable(candidate)) return candidate;
    }
    return null;
  }
}
