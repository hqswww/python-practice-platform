import 'package:flutter/material.dart';

import '../data/problem_repository.dart';
import '../models/problem.dart';
import '../services/export_service.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';

/// 设置板块
class SettingsPage extends StatefulWidget {
  /// 清空进度后回调（让练习页刷新）
  final Future<void> Function() onResetProgress;

  const SettingsPage({super.key, required this.onResetProgress});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ProgressService _progress = ProgressService();
  final ExportService _export = ExportService();

  // 动画控制
  int _hoveredCard = -1;
  bool _showDetails = false;

  Future<(int, int, Map<Difficulty, (int, int)>)>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _refreshSummary();
  }

  void _refreshSummary() {
    _statsFuture = _loadStats();
  }

  /// 加载进度统计：返回 (完成数, 总数, 各难度完成/总数)
  Future<(int, int, Map<Difficulty, (int, int)>)> _loadStats() async {
    final cats = await ProblemRepository().loadCategories();
    final all = <Problem>[];
    for (final c in cats) {
      all.addAll(c.problems);
    }
    final ids = all.map((p) => p.id).toList();
    final solvedMap = await _progress.solvedMap(ids);

    final diffStats = <Difficulty, int>{for (final d in Difficulty.values) d: 0};
    final diffTotal = <Difficulty, int>{for (final d in Difficulty.values) d: 0};
    var solved = 0;
    for (final p in all) {
      diffTotal[p.difficulty] = diffTotal[p.difficulty]! + 1;
      if (solvedMap[p.id] == true) {
        solved++;
        diffStats[p.difficulty] = diffStats[p.difficulty]! + 1;
      }
    }
    final stats = <Difficulty, (int, int)>{};
    for (final d in Difficulty.values) {
      stats[d] = (diffStats[d] ?? 0, diffTotal[d] ?? 0);
    }
    return (solved, all.length, stats);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 外观 ----
          _sectionTitle(context, '外观'),
          _settingsCard(
            index: 0,
            icon: Icons.palette_outlined,
            color: Colors.purple,
            title: '主题模式',
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('跟随系统'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('浅色'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('深色'),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          const SizedBox(height: 16),

          // ---- 判题 ----
          _sectionTitle(context, '判题'),
          _settingsCard(
            index: 1,
            icon: Icons.timer_outlined,
            color: Colors.teal,
            title: '判题超时',
            subtitle: '代码卡住或死循环时，等待多久后判为超时',
            child: ListenableBuilder(
              listenable: settings,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('更严格'),
                        Expanded(
                          child: Slider(
                            value: settings.timeoutMs.toDouble(),
                            min: 1000,
                            max: 5000,
                            divisions: 8,
                            label: '${settings.timeoutMs} ms',
                            onChanged: (v) =>
                                settings.setTimeoutMs(v.round()),
                          ),
                        ),
                        const Text('更宽松'),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '当前 ${settings.timeoutMs} ms',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ---- 数据 ----
          _sectionTitle(context, '数据'),
          _settingsCard(
            index: 2,
            icon: Icons.ios_share,
            color: Colors.indigo,
            title: '导出进度',
            subtitle: '把已解决/错题/收藏/测试历史导出成文件（JSON 或 CSV）',
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _exportJson,
                      icon: const Icon(Icons.data_object),
                      label: const Text('导出 JSON'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _exportCsv,
                      icon: const Icon(Icons.table_rows_outlined),
                      label: const Text('导出 CSV'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _settingsCard(
            index: 3,
            icon: Icons.delete_sweep_outlined,
            color: Colors.red,
            title: '清除进度',
            subtitle: '所有已做题目的完成标记将被移除',
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _confirmReset,
            ),
            onTap: _confirmReset,
          ),
          const SizedBox(height: 24),

          // ---- 进度统计 ----
          _sectionTitle(context, '我的进度'),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '完成情况',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _showDetails ? '收起' : '展开详情',
                        onPressed: () =>
                            setState(() => _showDetails = !_showDetails),
                        icon: AnimatedRotation(
                          turns: _showDetails ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: const Icon(Icons.expand_more),
                        ),
                      ),
                    ],
                  ),
                  FutureBuilder<(int, int, Map<Difficulty, (int, int)>)>(
                    future: _statsFuture,
                    builder: (context, snapshot) {
                      final data = snapshot.data;
                      final solved = data?.$1 ?? 0;
                      final total = data?.$2 ?? 0;
                      final diff = data?.$3 ?? {};
                      final ratio =
                          total == 0 ? 0.0 : (solved / total).clamp(0.0, 1.0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 10,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '已完成 $solved / $total 题 (${
                                (ratio * 100).toStringAsFixed(0)}%)',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _showDetails
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child:
                                        _buildDifficultyBreakdown(diff),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildAbout(context),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  /// 带悬浮/点击动画的设置卡片
  Widget _settingsCard({
    required int index,
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? child,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final hovered = _hoveredCard == index;
    return AnimatedScale(
      scale: hovered ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Card(
        elevation: hovered ? 4 : 1,
        margin: EdgeInsets.zero,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredCard = index),
          onExit: (_) => setState(() => _hoveredCard = -1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            if (subtitle != null)
                              Text(subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
                if (child != null) ...[
                  const SizedBox(height: 12),
                  child,
                  const Divider(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 难度分布详情（真实数据）
  Widget _buildDifficultyBreakdown(Map<Difficulty, (int, int)> diff) {
    return Row(
      children: [
        _difficultyBadge('简单', Colors.green, diff[Difficulty.easy]),
        const SizedBox(width: 12),
        _difficultyBadge('中等', Colors.orange, diff[Difficulty.medium]),
        const SizedBox(width: 12),
        _difficultyBadge('困难', Colors.red, diff[Difficulty.hard]),
      ],
    );
  }

  Widget _difficultyBadge(String label, Color color, (int, int)? stats) {
    final solved = stats?.$1 ?? 0;
    final total = stats?.$2 ?? 0;
    final frac = total == 0 ? 0.0 : (solved / total).clamp(0.0, 1.0);
    return Expanded(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 4),
          Text('$label $solved/$total', style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAbout(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      child: ListTile(
        leading: const Icon(Icons.info_outline, color: Colors.blue),
        title: const Text('关于'),
        subtitle: Text(
          'Python 练习平台 V1.1\nFlutter (Material 3) + 系统 Python 判题',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          showAboutDialog(
            context: context,
            applicationName: 'Python 练习平台',
            applicationVersion: 'V1.1',
            applicationLegalese: '为学弟学妹准备的 Python 练习与判题工具',
            children: const [
              Text('技术栈：Flutter (Material 3) + 系统 Python 判题\n题库：12 分类 72 道题'),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportJson() async {
    String path;
    try {
      path = await _export.exportJson();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
      return;
    }
    _showExportDialog('JSON', path);
  }

  Future<void> _exportCsv() async {
    String path;
    try {
      path = await _export.exportCsv();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
      return;
    }
    _showExportDialog('CSV', path);
  }

  void _showExportDialog(String label, String path) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('已导出 $label'),
        content: Text('文件已保存到：\n$path'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除进度？'),
        content: const Text('此操作不可撤销，所有题目的完成状态都会清空。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _progress.resetAll();
      await widget.onResetProgress();
      _refreshSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清除全部进度')),
      );
    }
  }
}
