import 'package:flutter/material.dart';

import '../models/test_record.dart';
import '../services/progress_service.dart';
import 'widgets/responsive.dart';

/// 回顾测试：查看历史测试记录，点开逐题回看“我的代码 + 参考代码”
class TestHistoryPage extends StatefulWidget {
  const TestHistoryPage({super.key});

  @override
  State<TestHistoryPage> createState() => _TestHistoryPageState();
}

class _TestHistoryPageState extends State<TestHistoryPage> {
  final ProgressService _progress = ProgressService();
  late Future<List<TestRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _progress.testRecords();
  }

  void _reload() {
    setState(() => _future = _progress.testRecords());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('回顾测试')),
      body: FutureBuilder<List<TestRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('还没有测试记录', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('去测试板块做一次测验，交卷后就会留在这里～',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }
          return MaxWidthBody(
            maxWidth: ContentWidth.list,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: records.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _StatsCard(records: records);
                }
                final idx = i - 1;
                return _RecordCard(
                  record: records[idx],
                  rank: idx + 1,
                  onOpen: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TestRecordDetailPage(record: records[idx]),
                      ),
                    );
                    _reload();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// 历史统计概览卡（测试次数、平均分、最好成绩、通过率）
class _StatsCard extends StatelessWidget {
  final List<TestRecord> records;

  const _StatsCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = records.length;
    final passed = records.where((r) => r.passed).length;
    final passedRate = total == 0 ? 0 : (passed / total * 100).round();
    final avg =
        total == 0 ? 0 : (records.map((r) => r.score).reduce(
                (a, b) => a + b) /
            total *
            100)
            .round();
    final best = total == 0
        ? 0
        : (records.map((r) => r.score).reduce((a, b) => a > b ? a : b) * 100)
            .round();
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text('测验统计',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _stat(theme, '$total', '总次数', Icons.fact_check_outlined),
                _stat(theme, '$avg%', '平均分', Icons.timeline),
                _stat(theme, '$best%', '最好成绩', Icons.emoji_events),
                _stat(theme, '$passedRate%', '通过率', Icons.flag_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// 单条测试记录卡片（时间 + 得分 + 对错概览）
class _RecordCard extends StatelessWidget {
  final TestRecord record;
  final int rank;
  final VoidCallback onOpen;

  const _RecordCard({
    required this.record,
    required this.rank,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (record.score * 100).round();
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: record.passed
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 排名/序号
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (record.passed
                          ? theme.colorScheme.primary
                          : theme.colorScheme.tertiary)
                      .withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: record.passed
                        ? theme.colorScheme.primary
                        : theme.colorScheme.tertiary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtTime(record.timestamp),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.correctCount} / ${record.totalCount} 题 · '
                      '${record.items.length} 题作答记录',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // 得分百分比
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: record.passed
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        record.passed ? Icons.emoji_events : Icons.track_changes,
                        size: 14,
                        color: record.passed
                            ? Colors.amber
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        record.passed ? '通过' : '待提升',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// 单次测试的逐题回看详情页
class TestRecordDetailPage extends StatelessWidget {
  final TestRecord record;

  const TestRecordDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (record.score * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('测试回看')),
      body: MaxWidthBody(
        maxWidth: ContentWidth.list,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 顶部概要
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      record.passed ? Icons.emoji_events : Icons.track_changes,
                      size: 40,
                      color: record.passed ? Colors.amber : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '得分 ${record.correctCount} / ${record.totalCount}  ($pct%)',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            record.passed ? '表现很棒，继续冲刺！🎉' : '再接再厉，去练习板块多练练～',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('逐题回看',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // 每题一张可展开卡片
            ...record.items.asMap().entries.map((e) => _ReviewItemCard(
                  number: e.key + 1,
                  item: e.value,
                )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// 单题回看卡片（我的代码 + 参考代码），点击展开/收起
class _ReviewItemCard extends StatefulWidget {
  final int number;
  final TestRecordItem item;

  const _ReviewItemCard({required this.number, required this.item});

  @override
  State<_ReviewItemCard> createState() => _ReviewItemCardState();
}

class _ReviewItemCardState extends State<_ReviewItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final it = widget.item;
    final isCorrect = it.wasCorrect;
    final statusText = isCorrect ? '做对' : '做错';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCorrect
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (isCorrect
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.number}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCorrect
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      it.title.isEmpty ? '题 ${it.problemId}' : it.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    size: 18,
                    color: isCorrect
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isCorrect
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      )),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _codeBlock(context, label: '我的代码',
                        code: it.myCode.isEmpty ? '（本题未作答）' : it.myCode),
                    const SizedBox(height: 10),
                    _codeBlock(context, label: '参考代码',
                        code: it.solution.trim().isEmpty
                            ? '（暂未提供）'
                            : it.solution.trim(),
                        highlight: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _codeBlock(BuildContext context,
      {required String label, required String code, bool highlight = false}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              highlight ? Icons.emoji_objects_outlined : Icons.code,
              size: 13,
              color: highlight
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: highlight
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
