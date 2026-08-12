import 'package:flutter/material.dart';

import '../services/error_log_service.dart';

/// 日志中心：查看错误日志 / 导出 / 清空
class LogCenterPage extends StatefulWidget {
  const LogCenterPage({super.key});

  @override
  State<LogCenterPage> createState() => _LogCenterPageState();
}

class _LogCenterPageState extends State<LogCenterPage> {
  late Future<List<LogEntry>> _future;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<LogEntry>> _load() => errorLog.readRecent(limit: 500);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    try {
      final path = await errorLog.export();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('日志已导出到：\n$path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空日志？'),
        content: const Text('所有已保存的错误日志都会被删除，用于排查问题的记录会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await errorLog.clear();
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日志已清空')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志中心'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '导出',
            onPressed: _export,
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<LogEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <LogEntry>[];
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('暂无日志', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('运行正常，没有记录到错误',
                      style: TextStyle(color: theme.colorScheme.outline)),
                ],
              ),
            );
          }
          final errors = entries
              .where((e) => e.level == LogLevel.error)
              .length;
          return Column(
            children: [
              // 顶部摘要条
              FutureBuilder<String>(
                future: errorLog.logDir().then((d) => d.path),
                builder: (context, snap) {
                  final dir = snap.data ?? '…';
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '共 ${entries.length} 条日志，其中 error $errors 条',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '日志目录：$dir',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    return _LogTile(entry: e);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;

  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (entry.level) {
      LogLevel.error => Colors.red,
      LogLevel.warning => Colors.orange,
      LogLevel.info => Colors.blueGrey,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // 有堆栈时点开完整查看
          if (entry.stackTrace == null || entry.stackTrace!.isEmpty) return;
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(entry.message,
                  maxLines: 3, overflow: TextOverflow.ellipsis),
              content: SingleChildScrollView(
                child: SelectableText(entry.stackTrace!),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('关闭'),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_sourceIcon(entry.source),
                      size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(entry.source.name,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: color)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.level.name,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                entry.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _fmt(entry.time),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  IconData _sourceIcon(LogSource s) => switch (s) {
        LogSource.ui => Icons.widgets_outlined,
        LogSource.judge => Icons.rule_outlined,
        LogSource.io => Icons.folder_open_outlined,
        LogSource.storage => Icons.save_outlined,
        LogSource.python => Icons.terminal,
        LogSource.uncaught => Icons.report_problem_outlined,
        LogSource.system => Icons.info_outline,
      };
}
