import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 全局错误/日志收集服务单例
///
/// 把运行时的错误与重要事件写到本地日志文件（按天滚动），
/// 便于用户排查判题异常、IO 失败与未捕获的崩溃。
/// 在 main.dart 里通过 [installGlobalHandlers] 挂载 Flutter 全局错误钩子。
final errorLog = ErrorLogService();

/// 日志来源标记
enum LogSource { ui, judge, io, storage, python, uncaught, system }

/// 日志级别
enum LogLevel { info, warning, error }

/// 单条日志记录
class LogEntry {
  final DateTime time;
  final LogSource source;
  final LogLevel level;
  final String message;
  final String? stackTrace;

  const LogEntry({
    required this.time,
    required this.source,
    required this.level,
    required this.message,
    this.stackTrace,
  });

  /// 格式化为可读文本行
  String toLine() {
    final t = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final ts = '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
    final s = source.name.padRight(8);
    final lv = level.name.padRight(7);
    final sb = StringBuffer('[$ts] [$s] [$lv] $message');
    if (stackTrace != null && stackTrace!.isNotEmpty) {
      sb.write('\n$stackTrace');
    }
    return sb.toString();
  }
}

/// 错误日志服务
///
/// - [write] 追加写一条日志（内存缓冲 + 异步落盘，失败静默不打断主流程）
/// - [readRecent] 读取最近 N 条（按文件从新到旧）
/// - [clear] 清空全部日志
class ErrorLogService {
  /// 内存中的最近日志（供日志中心快速展示）
  final List<LogEntry> _buffer = [];

  /// 缓冲上限，避免内存无限增长
  static const int _maxBuffer = 500;

  bool _installed = false;

  List<LogEntry> get recent => List.unmodifiable(_buffer);

  /// 已挂载全局钩子标记（防重复 install）
  bool get installed => _installed;

  /// 记录一条日志（级别默认 info）
  void log(
    String message, {
    LogSource source = LogSource.system,
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      time: DateTime.now(),
      source: source,
      level: level,
      message: message,
      stackTrace: stackTrace?.toString() ??
          (error is Error ? error.stackTrace?.toString() : null),
    );

    _buffer.add(entry);
    if (_buffer.length > _maxBuffer) {
      _buffer.removeAt(0);
    }

    // 异步落盘，失败静默（日志本身不能再炸）
    unawaited(_appendToFile(entry));
  }

  /// 便捷：记录 error 级别
  void logError(
    String message, {
    LogSource source = LogSource.system,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      message,
      source: source,
      level: LogLevel.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// 便捷：记录 warning 级别
  void logWarning(
    String message, {
    LogSource source = LogSource.system,
  }) {
    log(message, source: source, level: LogLevel.warning);
  }

  /// 追加一条日志到今天的日志文件
  Future<void> _appendToFile(LogEntry entry) async {
    try {
      final dir = await _logDir();
      final file = File('${dir.path}/app_${_dayTag(entry.time)}.log');
      await file.writeAsString('${entry.toLine()}\n',
          mode: FileMode.append, flush: true);
    } catch (_) {
      // 静默：日志写入失败不应影响主流程
    }
  }

  /// 目前日志文件所在目录
  Future<Directory> _logDir() async {
    final app = await getApplicationSupportDirectory();
    final dir = Directory('${app.path}/logs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 内部：log 目录（供日志中心浏览用）
  Future<Directory> logDir() => _logDir();

  /// 日期标签 `YYYY-MM-DD`
  static String _dayTag(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}';
  }

  /// 读取最近 [limit] 条日志（按时间倒序；跨文件从新到旧）
  Future<List<LogEntry>> readRecent({int limit = 200}) async {
    // 内存缓冲优先（最新），若足够多则直接返回
    final buffered = _buffer.reversed.take(limit).toList();
    if (buffered.length >= limit) return buffered;

    final result = <LogEntry>[...buffered];
    try {
      final dir = await _logDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList();
      // 按文件名（日期）倒序
      files.sort((a, b) => b.path.compareTo(a.path));

      // 从内存已覆盖的最新时间往前补，不重复
      final haveTimes = _buffer.map((e) => e.time).toSet();
      for (final f in files) {
        if (result.length >= limit) break;
        final lines = await f.readAsLines();
        for (final line in lines.reversed) {
          if (result.length >= limit) break;
          final entry = _parseLine(line);
          if (entry != null && !haveTimes.contains(entry.time)) {
            result.add(entry);
          }
        }
      }
    } catch (_) {
      // 读取失败回退到内存缓冲
    }
    return result;
  }

  /// 解析一行日志文本回 [LogEntry]（解析失败返回 null）
  LogEntry? _parseLine(String line) {
    if (line.isEmpty) return null;
    // 简单解析：前部 `[时间] [来源] [级别] 消息`
    final m = RegExp(
      r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] \[(\w+)\] \[(\w+)\] (.*)$',
    ).firstMatch(line);
    if (m == null) return null;
    return LogEntry(
      time: DateTime.tryParse(m.group(1)!.replaceFirst(' ', 'T')) ??
          DateTime.now(),
      source: LogSource.values.asNameMap()[m.group(2)] ?? LogSource.system,
      level: LogLevel.values.asNameMap()[m.group(3)] ?? LogLevel.info,
      message: m.group(4) ?? '',
    );
  }

  /// 清空全部日志（内存 + 磁盘文件）
  Future<void> clear() async {
    _buffer.clear();
    try {
      final dir = await _logDir();
      for (final f in dir.listSync().whereType<File>()) {
        await f.delete();
      }
    } catch (_) {}
  }

  /// 导出当前日志到用户可访问的位置（返回文件路径）
  Future<String> export({Directory? to}) async {
    final entries = await readRecent(limit: 10000);
    final buffer = StringBuffer('Python 练习平台日志导出\n'
        '时间：${DateTime.now().toLocal().toIso8601String()}\n'
        '共 ${entries.length} 条\n'
        '${'=' * 60}\n');
    for (final e in entries.reversed.toList()) {
      buffer.writeln(e.toLine());
      buffer.writeln();
    }

    final outDir = to ?? await getDownloadsDirectory();
    if (outDir == null) {
      // 无下载目录则退回应用支持目录
      final app = await getApplicationSupportDirectory();
      final d = await Directory('${app.path}/exports').create(recursive: true);
      final f = File('${d.path}/logs_${_dayTag(DateTime.now())}.txt');
      await f.writeAsString(buffer.toString());
      return f.path;
    }
    final f = File('${outDir.path}/python_practice_logs.txt');
    await f.writeAsString(buffer.toString());
    return f.path;
  }

  /// 挂载全局 Flutter 错误钩子（应用启动时调用一次）
  void installGlobalHandlers() {
    if (_installed) return;
    _installed = true;

    // Flutter 框架错误（widget build / layout 等）
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      logError(
        details.exceptionAsString(),
        source: LogSource.ui,
        error: details.exception,
        stackTrace: details.stack,
      );
      oldOnError?.call(details);
    };

    // 未捕获的异步/平台异常
    final oldPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      logError(
        error.toString(),
        source: LogSource.uncaught,
        error: error,
        stackTrace: stack,
      );
      return oldPlatformError?.call(error, stack) ?? true;
    };

    // 记录应用启动横幅（含平台信息，崩溃排查时很有用）
    log('应用启动 (V1.2)',
        source: LogSource.system, level: LogLevel.info);
    log('系统信息：${_platformInfo()}',
        source: LogSource.system, level: LogLevel.info);
    // 异步补记日志目录（路径获取较慢，不阻塞启动）
    unawaited(() async {
      final p = await _logDirPath();
      log('日志文件目录：$p',
          source: LogSource.system, level: LogLevel.info);
    }());
  }

  /// 生成平台/环境描述（Windows 版本、Dart 版本）
  String _platformInfo() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isWindows) {
        return 'Windows (${Platform.operatingSystemVersion}) / Dart ${Platform.version}';
      }
      return '${Platform.operatingSystem} / Dart ${Platform.version}';
    } catch (_) {
      return 'unknown';
    }
  }

  /// 日志目录绝对路径（崩溃排查用）
  Future<String> _logDirPath() async {
    try {
      return (await _logDir()).path;
    } catch (_) {
      return 'unavailable';
    }
  }
}
