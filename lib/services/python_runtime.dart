import 'dart:io';

import 'settings_service.dart';

/// Python 运行时解析与 UTF-8 加固（Windows 迁移关键）
///
/// Windows 迁移两大坑：
/// 1. **Python 位置**：打包时把「嵌入式 Python」放进应用目录，
///    运行时按「exe 所在目录」的相对路径找捆绑的 python.exe，
///    不能依赖系统 PATH（目标机器可能没装 Python）。
/// 2. **编码**：Windows 下 Python 的 stdin/stdout 默认可能走 GBK，
///    中文输出会跟 UTF-8 比对错。统一加 `-X utf8` + `PYTHONIOENCODING=utf-8`。
class PythonRuntime {
  /// 捆绑 Python 在应用目录下的相对子目录（打包脚本也按此放置）
  static const String bundledRelativeDir = 'python';

  /// Windows 下可执行文件名
  static const String bundledExeName = 'python.exe';

  /// 解析实际要用的 Python 命令：
  /// 1. 若用户在设置页填了自定义路径，优先用它（可指向任意 python/python.exe）
  /// 2. Windows：找捆绑的 python.exe（exe 同目录/python/python.exe），找不到回退 `python.exe`
  /// 3. 其他平台：`python3`
  static String resolvePythonCommand() {
    // 自定义路径优先（设置页可配，方便引导到指定解释器）
    final custom = settings.pythonPath.trim();
    if (custom.isNotEmpty) return custom;

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

  /// 传给 Python 的通用 UTF-8 启动参数
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
