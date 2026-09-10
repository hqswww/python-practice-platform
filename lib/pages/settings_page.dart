import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/problem_repository.dart';
import '../models/problem.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../models/programming_language.dart';
import '../services/language_service.dart';
import 'achievements_page.dart';
import 'log_center_page.dart';
import 'widgets/language_switcher.dart';
import 'widgets/responsive.dart';

/// 设置分类：宽屏时作为左栏条目，窄屏时作为「点进去看详情」的入口
class _CategoryMeta {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _CategoryMeta({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

/// 分类清单（顺序即左栏显示顺序，与原扁平布局保持一致）
const List<_CategoryMeta> _kCategories = [
  _CategoryMeta(
    id: 'appearance',
    title: '外观',
    subtitle: '主题模式与强调色',
    icon: Icons.palette_outlined,
    color: Colors.purple,
  ),
  _CategoryMeta(
    id: 'growth',
    title: '成长',
    subtitle: '成就与称号',
    icon: Icons.emoji_events_outlined,
    color: Colors.amber,
  ),
  _CategoryMeta(
    id: 'judge',
    title: '判题',
    subtitle: '超时时间',
    icon: Icons.timer_outlined,
    color: Colors.teal,
  ),
  _CategoryMeta(
    id: 'editor',
    title: '代码编辑',
    subtitle: '字体、缩进、Python 解释器',
    icon: Icons.code_outlined,
    color: Colors.blueGrey,
  ),
  _CategoryMeta(
    id: 'diagnostics',
    title: '诊断',
    subtitle: '日志中心',
    icon: Icons.bug_report_outlined,
    color: Colors.purple,
  ),
  _CategoryMeta(
    id: 'data',
    title: '数据',
    subtitle: '导出 / 导入 / 清除进度',
    icon: Icons.storage_outlined,
    color: Colors.indigo,
  ),
  _CategoryMeta(
    id: 'progress',
    title: '我的进度',
    subtitle: '完成情况统计',
    icon: Icons.insights_outlined,
    color: Colors.green,
  ),
  _CategoryMeta(
    id: 'about',
    title: '关于',
    subtitle: '版本与项目信息',
    icon: Icons.info_outline,
    color: Colors.blueGrey,
  ),
];

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
  final ImportService _import = ImportService();

  // 动画控制
  int _hoveredCard = -1;
  bool _showDetails = false;
  // 宽屏左栏选中的分类（窄屏不用，走 push 进详情页）
  String _selectedCategoryId = _kCategories.first.id;
  // 各语言运行时路径输入框（保持引用避免 rebuild 重建）
  final Map<ProgrammingLanguage, TextEditingController> _runtimeControllers = {
    for (final lang in availableLanguages)
      lang: TextEditingController(text: settings.runtimePath(lang)),
  };

  Future<(int, int, Map<Difficulty, (int, int)>)>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _refreshSummary();
    // 路径可能提前被外部改过（预留），每次进设置同步一次初始值
    for (final entry in _runtimeControllers.entries) {
      entry.value.text = settings.runtimePath(entry.key);
    }
  }

  @override
  void dispose() {
    for (final c in _runtimeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _refreshSummary() {
    _statsFuture = _loadStats();
  }

  /// 加载进度统计：返回 (完成数, 总数, 各难度完成/总数)
  Future<(int, int, Map<Difficulty, (int, int)>)> _loadStats() async {
    final lang = languageService.value;
    final cats =
        await ProblemRepository().loadCategories(language: lang);
    final all = <Problem>[];
    for (final c in cats) {
      all.addAll(c.problems);
    }
    final ids = all.map((p) => p.id).toList();
    final solvedMap = await _progress.solvedMap(lang, ids);

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
      appBar: AppBar(
        title: const Text('设置'),
        actions: const [LanguageSwitcher()],
      ),
      // 宽屏：左栏分类 + 右栏详情并排；窄屏：整页分类列表，点进详情页
      body: AdaptiveMasterDetail(
        masterBuilder: (context, isWide) =>
            _buildCategoryList(context, showChevron: !isWide),
        detailBuilder: (context, _) =>
            _buildDetailPane(context, _selectedCategoryId),
      ),
    );
  }

  // ---------------------------------------------------------------- 分类列表

  Widget _buildCategoryList(BuildContext context, {required bool showChevron}) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _kCategories.length,
      itemBuilder: (context, i) {
        final meta = _kCategories[i];
        final selected = meta.id == _selectedCategoryId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openCategory(context, meta),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(meta.icon, size: 20, color: meta.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meta.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 12, color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                    // 只有窄屏才提示「点进去」，宽屏是直接换右栏
                    if (showChevron)
                      Icon(Icons.chevron_right,
                          size: 20, color: scheme.outline),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 宽屏 → 换右栏内容；窄屏 → push 一个详情页
  ///
  /// 用 `MediaQuery.sizeOf` 而不是再次 LayoutBuilder：设置页占满整个窗口，
  /// 两者宽度一致；且 LayoutBuilder 在 build 期间拿不到，点击回调里也得用这个。
  void _openCategory(BuildContext context, _CategoryMeta meta) {
    if (isTwoPaneWidth(MediaQuery.sizeOf(context).width)) {
      setState(() => _selectedCategoryId = meta.id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SettingsDetailPage(
          meta: meta,
          cards: _detailCards(context, meta.id),
        ),
      ),
    );
  }

  /// 宽屏右栏：分类标题 + 该分类的卡片
  Widget _buildDetailPane(BuildContext context, String id) {
    final meta = _kCategories.firstWhere(
      (m) => m.id == id,
      orElse: () => _kCategories.first,
    );
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(meta.icon, color: meta.color),
            const SizedBox(width: 8),
            Text(
              meta.title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(meta.subtitle, style: TextStyle(color: scheme.outline)),
        const SizedBox(height: 20),
        ..._detailCards(context, id),
      ],
    );
  }

  // ---------------------------------------------------------------- 详情内容

  /// 某个分类下的全部卡片。
  /// 宽屏直接铺进右栏，窄屏交给 [_SettingsDetailPage]。
  List<Widget> _detailCards(BuildContext context, String id) {
    switch (id) {
      // ---------------------------------------------------------- 外观
      case 'appearance':
        return [
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
          const SizedBox(height: 12),
          _settingsCard(
            index: 0,
            icon: Icons.color_lens_outlined,
            color: settings.accentColor,
            title: '主题强调色',
            child: _accentColorPicker(context),
          ),
        ];

      // ---------------------------------------------------------- 成长
      case 'growth':
        return [
          _settingsCard(
            index: 1,
            icon: Icons.emoji_events_outlined,
            color: Colors.amber,
            title: '成就与称号',
            subtitle: '查看解锁的成就与当前称号',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AchievementsPage(),
                ),
              );
            },
          ),
        ];

      // ---------------------------------------------------------- 判题
      case 'judge':
        return [
          _settingsCard(
            index: 2,
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
        ];

      // ---------------------------------------------------------- 代码编辑
      case 'editor':
        return [
          _settingsCard(
            index: 10,
            icon: Icons.format_size,
            color: Colors.blueGrey,
            title: '编辑器字体大小',
            subtitle: '代码输入区文字大小（12–22 px）',
            child: ListenableBuilder(
              listenable: settings,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('小'),
                        Expanded(
                          child: Slider(
                            value: settings.editorFontSize.toDouble(),
                            min: 12,
                            max: 22,
                            divisions: 10,
                            label: '${settings.editorFontSize} px',
                            onChanged: (v) =>
                                settings.setEditorFontSize(v.round()),
                          ),
                        ),
                        const Text('大'),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '当前 ${settings.editorFontSize} px',
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
          const SizedBox(height: 12),
          _settingsCard(
            index: 11,
            icon: Icons.space_bar,
            color: Colors.cyan,
            title: '缩进宽度',
            subtitle: '按 Tab 时插入多少个空格（Python 建议 4）',
            child: ListenableBuilder(
              listenable: settings,
              builder: (context, _) {
                return SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 2, label: Text('2')),
                    ButtonSegment(value: 4, label: Text('4')),
                    ButtonSegment(value: 8, label: Text('8')),
                  ],
                  selected: {settings.editorIndentWidth},
                  onSelectionChanged: (s) =>
                      settings.setEditorIndentWidth(s.first),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < availableLanguages.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: _runtimePathCard(availableLanguages[i], index: 12 + i),
            ),
        ];

      // ---------------------------------------------------------- 诊断
      case 'diagnostics':
        return [
          _settingsCard(
            index: 13,
            icon: Icons.bug_report_outlined,
            color: Colors.purple,
            title: '日志中心',
            subtitle: '查看错误日志、导出或清空，便于排查判题/运行环境问题',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LogCenterPage(),
                ),
              );
            },
          ),
        ];

      // ---------------------------------------------------------- 数据
      case 'data':
        return [
          _settingsCard(
            index: 3,
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
            index: 4,
            icon: Icons.file_download_outlined,
            color: Colors.teal,
            title: '导入进度',
            subtitle: '从导出的 JSON 文件合并进度（取并集，不会丢失当前进度）',
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _importJson,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('导入 JSON'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _settingsCard(
            index: 5,
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
        ];

      // ---------------------------------------------------------- 我的进度
      case 'progress':
        return [
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
                                    child: _buildDifficultyBreakdown(diff),
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
        ];

      // ---------------------------------------------------------- 关于
      case 'about':
        return [_buildAbout(context)];

      default:
        return const [];
    }
  }

  /// 主题强调色选择器（色板圆点，点选即切）
  Widget _accentColorPicker(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final opt in kAccentColors)
          InkWell(
            key: ValueKey('accent_${opt.id}'),
            onTap: () => settings.setAccent(opt.id),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: opt.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: settings.accentId == opt.id
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: opt.color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: settings.accentId == opt.id
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 16)
                  : null,
            ),
          ),
      ],
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

  /// 某个语言的运行时路径设置卡片
  ///
  /// 按语言分开：Python 填的是**解释器**，C/C++ 将来填的是**编译器**
  /// （clang / gcc），两者语义不同，共用一个输入框会让人困惑。
  Widget _runtimePathCard(ProgrammingLanguage lang, {required int index}) {
    // 卡片只为 availableLanguages 里的语言构建，而 map 就是按它建的，必然有值
    final controller = _runtimeControllers[lang]!;
    final isCompiler = lang.compiled;
    final hint = isCompiler
        ? r'例如 /usr/bin/clang 或 C:\mingw64\bin\gcc.exe'
        : r'例如 /usr/bin/python3 或 C:\python\python.exe';
    return _settingsCard(
      index: index,
      icon: Icons.terminal,
      color: Colors.deepOrange,
      title: '${lang.displayName} ${isCompiler ? '编译器' : '解释器'}',
      subtitle: '留空则自动查找（含应用内捆绑的运行时）',
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(hintText: hint),
                onSubmitted: (v) => settings.setRuntimePath(lang, v),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () =>
                      settings.setRuntimePath(lang, controller.text),
                  child: const Text('保存路径'),
                ),
              ),
            ],
          );
        },
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
          'Python 练习平台 V1.2\nFlutter (Material 3) + 系统 Python 判题',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          showAboutDialog(
            context: context,
            applicationName: 'Python 练习平台',
            applicationVersion: 'V1.2',
            applicationLegalese: '为学弟学妹准备的 Python 练习与判题工具',
            children: const [
              Text('技术栈：Flutter (Material 3) + 系统 Python 判题\n题库：12 分类 72 道题\n\nV1.2 新增：编辑器字体大小 / 缩进宽度 / 自定义 Python 解释器路径'),
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

  /// 导入 JSON 进度：先让用户选文件，再合并导入。
  Future<void> _importJson() async {
    late List<ListTile> files;
    try {
      files = await _buildImportFileList();
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法读取导入文件：$e')),
      );
      return;
    }
    if (!mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没找到可导入的进度 JSON 文件，请先导出')),
      );
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择要导入的进度文件'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: files,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    // 确认合并（提示不会覆盖当前进度）
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认导入进度？'),
        content: const Text('将以合并方式导入（取并集），不会清除你当前的进度。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final summary = await _import.importFromFile(picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(summary.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  /// 收集可导入的 JSON 文件（导出文件夹 + 下载目录），按修改时间倒序。
  Future<List<ListTile>> _buildImportFileList() async {
    final candidates = <File>[];
    // 导出目录
    try {
      final docs = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${docs.path}/PythonPractice导出');
      if (await exportDir.exists()) {
        await for (final e in exportDir.list()) {
          if (e is File && e.path.toLowerCase().endsWith('.json')) {
            candidates.add(e);
          }
        }
      }
    } catch (_) {}
    // 下载目录
    try {
      final dl = await getDownloadsDirectory();
      if (dl != null && await dl.exists()) {
        await for (final e in dl.list()) {
          if (e is File && e.path.toLowerCase().endsWith('.json')) {
            candidates.add(e);
          }
        }
      }
    } catch (_) {}
    // 按修改时间倒序，去重（同一路径只留一次）
    final seen = <String>{};
    final unique = <File>[];
    for (final f in candidates) {
      if (seen.add(f.path)) unique.add(f);
    }
    unique.sort((a, b) {
      final at = a.statSync().modified;
      final bt = b.statSync().modified;
      return bt.compareTo(at);
    });
    final tiles = <ListTile>[];
    for (final f in unique.take(30)) {
      final stat = f.statSync();
      tiles.add(
        ListTile(
          title: Text(f.uri.pathSegments.last),
          subtitle: Text(
            '${f.parent.path}\n${stat.size ~/ 1024} KB · '
            '${_fmtTime(stat.modified)}',
          ),
          trailing: const Icon(Icons.file_open_outlined),
          onTap: () => Navigator.pop(context, f.path),
        ),
      );
    }
    return tiles;
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
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

/// 窄屏用的分类详情页
///
/// 宽屏时同一个分类的内容直接铺在右栏（见 [_buildDetailPane]），
/// 这里只是把它包一层 AppBar 变成可 push 的独立页面。
class _SettingsDetailPage extends StatelessWidget {
  const _SettingsDetailPage({required this.meta, required this.cards});

  final _CategoryMeta meta;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(meta.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: cards,
      ),
    );
  }
}
