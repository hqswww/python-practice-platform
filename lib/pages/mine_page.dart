import 'package:flutter/material.dart';

import '../services/achievement_service.dart';
import '../services/language_service.dart';
import '../services/stats_service.dart';
import 'about_page.dart';
import 'settings_page.dart';
import 'widgets/language_switcher.dart';
import 'widgets/stat_charts.dart';
import 'widgets/responsive.dart';

/// 「我的」页：三门语言的练习/测试数据 + 基于数据的结论 + 设置/关于入口。
///
/// 它取代了原来底栏的「设置」板块：用户找自己数据的地方和找设置的地方
/// 本来就是同一处（「我的」），分成两个 tab 反而要来回切。
///
/// 图表在 C 段接 fl_chart；这里先用普通的进度条把数据结构和结论跑通 ——
/// 数与话对了再加图，避免出现「图好看但数不对」。
class MinePage extends StatefulWidget {
  const MinePage({
    super.key,
    required this.onResetProgress,
    this.isActive = true,
  });

  /// 重置进度后要刷新（沿用设置页那个回调）
  final Future<void> Function() onResetProgress;

  /// 本页当前是不是可见的那个 tab。
  ///
  /// 底栏是 IndexedStack，页面一直活着、不会重新 initState，
  /// 所以在别处做完题回来时数据是旧的。可见性一变就重算一次。
  final bool isActive;

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  final StatsService _service = StatsService();
  Future<OverallStats>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
    // 切语言要重算分类完成度（它按当前语言的分类名显示）
    languageService.addListener(_onLanguageChanged);
  }

  @override
  void didUpdateWidget(MinePage old) {
    super.didUpdateWidget(old);
    // 从别的 tab 切回来就重算：用户可能刚做完题
    if (widget.isActive && !old.isActive) _reload();
  }

  @override
  void dispose() {
    languageService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  void _reload() {
    // 必须是块体：`setState(() => x = future)` 的箭头函数会把 Future 当返回值，
    // Flutter 会直接报「setState() callback argument returned a Future」
    setState(() {
      _future = _service.collect();
    });
  }

  Future<void> _refresh() async {
    _reload();
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: const [LanguageSwitcher()],
      ),
      body: MaxWidthBody(
        maxWidth: ContentWidth.list,
        child: FutureBuilder<OverallStats>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final stats = snap.data;
            if (stats == null) {
              return Center(
                child: Text(
                  '读不到进度数据。',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _OverviewCard(stats: stats),
                  const SizedBox(height: 12),
                  // 设置与关于的入口放在**靠上**的位置：底栏「设置」没了之后，
                  // 找设置的人第一站就是这里，埋到页面底部会让人以为功能被删了
                  Row(
                    children: [
                      Expanded(
                        child: _EntryCard(
                          icon: Icons.settings_outlined,
                          label: '设置',
                          subtitle: '外观、判题、编辑器、数据',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SettingsPage(
                                  onResetProgress: widget.onResetProgress,
                                ),
                              ),
                            );
                            // 设置里可能清了进度、改了语言，回来重算一次
                            if (mounted) _reload();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _EntryCard(
                          icon: Icons.info_outline,
                          label: '关于',
                          subtitle: '版本、更新日志、许可证',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const AboutPage()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ConclusionCard(stats: stats),
                  const SizedBox(height: 12),
                  _LanguagesCard(stats: stats),
                  const SizedBox(height: 12),
                  // 宽屏把「难度分布」和「测试趋势」并排 —— 两张图都矮，
                  // 竖着堆会把页面拉得很长，横着看还能互相参照
                  LayoutBuilder(
                    builder: (context, c) {
                      const gap = 12.0;
                      final twoCol = c.maxWidth >= 720;
                      final w = twoCol ? (c.maxWidth - gap) / 2 : c.maxWidth;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          SizedBox(
                            width: w,
                            child: _ChartCard(
                              title: '难度分布',
                              subtitle: '做对的题里，各难度占多少',
                              child: DifficultyPieChart(stats: stats),
                            ),
                          ),
                          SizedBox(
                            width: w,
                            child: _ChartCard(
                              title: '测试正确率',
                              subtitle: '最近 ${stats.allTestAccuracies.length} 次',
                              child: TestTrendChart(stats: stats),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ChartCard(
                    title: '练习节奏',
                    subtitle: stats.streakTextOn(DateTime.now()),
                    child: DailyActivityChart(stats: stats),
                  ),
                  const SizedBox(height: 12),
                  _ChartCard(
                    title: '分类完成度',
                    subtitle: '当前语言（${languageService.value.displayName}）的 12 个大类',
                    child: CategoryBarChart(
                      languageStats: stats.forLanguage(languageService.value)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 总览：总进度 + 称号
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.stats});

  final OverallStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = AchievementService().getTitle(stats.solved);
    final percent = (stats.ratio * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('总进度',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                        '${stats.solved} / ${stats.total}',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                // 称号直接用成就系统那一份（图标/颜色都跟着走）
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('当前称号',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(title.icon, color: title.color, size: 18),
                        const SizedBox(width: 6),
                        Text(title.title,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: title.color)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: stats.ratio,
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '已完成 $percent%'
              '${stats.wrong > 0 ? ' · 错题 ${stats.wrong} 道' : ''}'
              '${stats.favorite > 0 ? ' · 收藏 ${stats.favorite} 道' : ''}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置 / 关于的入口卡
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// 结论卡：这是「我的」页的灵魂 —— 不只是列数字，还要说出数字意味着什么
class _ConclusionCard extends StatelessWidget {
  const _ConclusionCard({required this.stats});

  final OverallStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final conclusions = buildConclusions(stats);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('小结',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (final c in conclusions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_iconFor(c.tone),
                        size: 18, color: _colorFor(c.tone, scheme)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(c.text,
                          style: const TextStyle(fontSize: 13, height: 1.5)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(ConclusionTone tone) => switch (tone) {
        ConclusionTone.progress => Icons.trending_up,
        ConclusionTone.attention => Icons.error_outline,
        ConclusionTone.suggestion => Icons.lightbulb_outline,
      };

  static Color _colorFor(ConclusionTone tone, ColorScheme scheme) =>
      switch (tone) {
        ConclusionTone.progress => Colors.green,
        ConclusionTone.attention => Colors.orange,
        ConclusionTone.suggestion => scheme.primary,
      };
}

/// 三门语言各自的进度
class _LanguagesCard extends StatelessWidget {
  const _LanguagesCard({required this.stats});

  final OverallStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('三门语言',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '进度、错题、测试都是分开统计的',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            LanguageProgressChart(stats: stats),
            const SizedBox(height: 12),
            for (final l in stats.languages) _LanguageRow(stats: l),
          ],
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.stats});

  final LanguageStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = stats.language;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${stats.solved} / ${stats.total}',
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (stats.testPoints.isNotEmpty)
                '测试 ${stats.testPoints.length} 次'
              else
                '还没测过',
              if (stats.wrong > 0) '错题 ${stats.wrong} 道',
              if (stats.unanswered > 0) '未作答 ${stats.unanswered} 道',
              if (stats.favorite > 0) '收藏 ${stats.favorite} 道',
            ].join(' · '),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 图表卡片外壳：标题 + 副标题 + 图
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
