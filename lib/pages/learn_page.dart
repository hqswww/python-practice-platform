import 'package:flutter/material.dart';

import '../models/problem.dart';
import '../models/problem_category.dart';
import 'widgets/responsive.dart';

/// 学习板块：按题库顺序，把题目组织成"正经学习笔记"排版。
///
/// 布局：左侧分类+题目导航树，右侧当前题的 Markdown 式笔记。
class LearnPage extends StatefulWidget {
  final List<ProblemCategory> categories;

  const LearnPage({super.key, required this.categories});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

/// 扁平化的学习条目（跨分类编号，用于上一篇/下一篇导航）
class _LearnEntry {
  final ProblemCategory category;
  final Problem problem;
  _LearnEntry(this.category, this.problem);
}

class _LearnPageState extends State<LearnPage> {
  /// 所有条目按顺序拍平
  late final List<_LearnEntry> _entries;

  /// 当前选中的条目索引
  int _index = 0;

  /// 当前展开的分类 key（左侧列表折叠/展开）
  late final Set<String> _expandedCategories;

  @override
  void initState() {
    super.initState();
    _entries = [
      for (final cat in widget.categories)
        for (final p in cat.problems) _LearnEntry(cat, p),
    ];
    _expandedCategories = {for (final c in widget.categories) c.key};
    if (widget.categories.isNotEmpty && widget.categories.first.problems.isNotEmpty) {
      _index = 0;
    }
  }

  _LearnEntry get _current => _entries[_index];

  void _goTo(int i) {
    if (i < 0 || i >= _entries.length) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('学习笔记')),
        body: const Center(child: Text('暂无学习内容')),
      );
    }

    final current = _current;
    // 窗口是否够宽到并排放「侧栏 + 正文」。
    // 这里用 MediaQuery 而不是 LayoutBuilder：Scaffold 的 drawer 参数在
    // build 阶段就要定，LayoutBuilder 的约束那时还拿不到。
    // 学习页占满窗口宽度，两者数值一致。
    final wide = isTwoPaneWidth(MediaQuery.sizeOf(context).width);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('学习笔记', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '${current.category.name} · ${current.problem.title}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      // 窄屏：侧栏收进抽屉。原来固定 230px 侧栏会把正文挤到只剩 ~190px。
      // 宽屏：侧栏常驻，不需要抽屉（AppBar 也就不会出现汉堡按钮）。
      drawer: wide
          ? null
          : Drawer(
              child: Builder(
                builder: (drawerContext) => SafeArea(
                  child: _buildSidebar(
                    onSelect: () => Navigator.of(drawerContext).pop(),
                  ),
                ),
              ),
            ),
      body: wide
          ? Row(
              key: const ValueKey('bodyRow'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左侧导航（分类+题目树）
                SizedBox(
                  width: 230,
                  child: _buildSidebar(),
                ),
                // 分隔线
                const VerticalDivider(width: 1, thickness: 1),
                // 右侧笔记
                Expanded(
                  child: _buildNoteContent(current.problem),
                ),
              ],
            )
          : SizedBox.expand(
              key: const ValueKey('bodyRow'),
              child: _buildNoteContent(current.problem),
            ),
    );
  }

  // ---------- 左侧导航树 ----------

  /// 侧栏（分类 + 题目树）
  ///
  /// [onSelect] 在窄屏抽屉里用来「选完自动收起」——宽屏常驻侧栏时传 null。
  Widget _buildSidebar({VoidCallback? onSelect}) {
    final kids = <Widget>[];
    for (final cat in widget.categories) {
      kids.add(_CategoryHeader(
        category: cat,
        expanded: _expandedCategories.contains(cat.key),
        onTap: () => setState(() {
          if (!_expandedCategories.add(cat.key)) {
            _expandedCategories.remove(cat.key);
          }
        }),
      ));
      if (_expandedCategories.contains(cat.key)) {
        for (final p in cat.problems) {
          kids.add(_buildProblemTile(cat, p, onSelect: onSelect));
        }
      }
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: kids,
    );
  }

  Widget _buildProblemTile(ProblemCategory cat, Problem p,
      {VoidCallback? onSelect}) {
    final selected = _entries[_index].problem.id == p.id;
    final color = switch (p.difficulty) {
      Difficulty.easy => Colors.green,
      Difficulty.medium => Colors.orange,
      Difficulty.hard => Colors.red,
    };
    return InkWell(
      onTap: () {
        final idx = _entries.indexWhere((e) => e.problem.id == p.id);
        _goTo(idx);
        onSelect?.call();
      },
      child: Container(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '${p.id}',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w400,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 右侧笔记内容 ----------

  Widget _buildNoteContent(Problem p) {
    final scheme = Theme.of(context).colorScheme;
    return MaxWidthBody(
      maxWidth: ContentWidth.article,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 笔记头部卡片
          _NoteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _difficultyChip(p.difficulty),
                    const SizedBox(width: 8),
                    Text(
                      '#${p.id}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  p.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 3,
                  width: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
  
          const SizedBox(height: 16),
  
          // 📖 详细教程（runoob 风格分节）
          if (p.hasTutorial) ...[
            _NoteCard(
              child: _NoteSection(
                icon: Icons.school_outlined,
                title: '详细教程',
                child: Builder(builder: (context) {
                  final scheme = Theme.of(context).colorScheme;
                  final children = <Widget>[];
                  for (var i = 0; i < p.tutorial.length; i++) {
                    final sec = p.tutorial[i];
                    children.add(Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sec.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ));
                    if (sec.body.isNotEmpty) {
                      children.add(const SizedBox(height: 8));
                      children.add(_NoteParagraph(sec.body));
                    }
                    if (sec.code.isNotEmpty) {
                      children.add(const SizedBox(height: 10));
                      children.add(_CodeBlock(label: '代码', code: sec.code));
                    }
                    if (sec.output.isNotEmpty) {
                      children.add(const SizedBox(height: 8));
                      children.add(_CodeBlock(label: '运行结果', code: sec.output));
                    }
                    if (i < p.tutorial.length - 1) {
                      children.add(const SizedBox(height: 16));
                      children.add(Divider(height: 1));
                      children.add(const SizedBox(height: 16));
                    }
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
          ],
  
          // 题目描述卡片
          if (p.description.isNotEmpty)
            _NoteCard(
              child: _NoteSection(
                icon: Icons.menu_book_outlined,
                title: '题目',
                child: _NoteParagraph(p.description),
              ),
            ),
  
          if (p.description.isNotEmpty) const SizedBox(height: 16),
  
          // 输入/输出格式（并排卡片）
          if (p.inputFormat.isNotEmpty || p.outputFormat.isNotEmpty)
            _NoteCard(
              child: _NoteSection(
                icon: Icons.keyboard_alt_outlined,
                title: '输入 / 输出格式',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.inputFormat.isNotEmpty)
                      Expanded(
                        child: _FormatBox(
                          title: '输入',
                          content: p.inputFormat.isEmpty ? '（无）' : p.inputFormat,
                        ),
                      ),
                    if (p.inputFormat.isNotEmpty && p.outputFormat.isNotEmpty)
                      const SizedBox(width: 12),
                    if (p.outputFormat.isNotEmpty)
                      Expanded(
                        child: _FormatBox(
                          title: '输出',
                          content: p.outputFormat.isEmpty ? '（无）' : p.outputFormat,
                        ),
                      ),
                  ],
                ),
              ),
            ),
  
          if (p.inputFormat.isNotEmpty || p.outputFormat.isNotEmpty)
            const SizedBox(height: 16),
  
          // 示例（代码块风格）
          if (p.sampleInput.isNotEmpty || p.sampleOutput.isNotEmpty)
            _NoteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _NoteSectionHeader(icon: Icons.terminal, title: '示例'),
                  const SizedBox(height: 10),
                  _CodeBlock(
                    label: '输入',
                    code: p.sampleInput.isEmpty ? '(无)' : p.sampleInput,
                  ),
                  const SizedBox(height: 10),
                  _CodeBlock(
                    label: '输出',
                    code: p.sampleOutput.isEmpty ? '(无)' : p.sampleOutput,
                  ),
                ],
              ),
            ),
  
          if (p.sampleInput.isNotEmpty || p.sampleOutput.isNotEmpty)
            const SizedBox(height: 16),
  
          // 提示（折叠）
          if (p.hints.isNotEmpty) ...[
            _HintCard(hints: p.hints),
            if (p.solution.isNotEmpty) const SizedBox(height: 16),
          ],
  
          // 参考代码（折叠）
          if (p.solution.isNotEmpty) _SolutionCard(solution: p.solution),
  
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _difficultyChip(Difficulty d) {
    final color = switch (d) {
      Difficulty.easy => Colors.green,
      Difficulty.medium => Colors.orange,
      Difficulty.hard => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        d.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------- 子组件 -------------

/// 左侧分类头
class _CategoryHeader extends StatelessWidget {
  final ProblemCategory category;
  final bool expanded;
  final VoidCallback onTap;

  const _CategoryHeader({
    required this.category,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_more : Icons.chevron_right,
              size: 18,
              color: scheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${category.problems.length}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

/// 笔记小节包装
class _NoteSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _NoteSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoteSectionHeader(icon: icon, title: title),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _NoteSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _NoteSectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: scheme.primary,
          ),
        ),
      ],
    );
  }
}

/// 段落文字
class _NoteParagraph extends StatelessWidget {
  final String text;
  const _NoteParagraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        height: 1.6,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
      ),
    );
  }
}

/// 笔记区块通用卡片容器（统一圆角/衬底/内边距）
class _NoteCard extends StatelessWidget {
  final Widget child;

  const _NoteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }
}

/// 输入/输出格式子内容框（卡片内部的两栏）
class _FormatBox extends StatelessWidget {
  final String title;
  final String content;

  const _FormatBox({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

/// 等宽代码块（带标签）
class _CodeBlock extends StatelessWidget {
  final String label;
  final String code;

  const _CodeBlock({required this.label, required this.code});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 提示卡片（可展开）
class _HintCard extends StatefulWidget {
  final List<String> hints;

  const _HintCard({required this.hints});

  @override
  State<_HintCard> createState() => _HintCardState();
}

class _HintCardState extends State<_HintCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _NoteCard(
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
          title: Text('提示', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          _expanded ? '共 ${widget.hints.length} 条' : '点击展开逐步思路',
          style: const TextStyle(fontSize: 12),
        ),
        initiallyExpanded: _expanded,
        onExpansionChanged: (v) => setState(() => _expanded = v),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.hints.length; i++)                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8, top: 1),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.hints[i],
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }
}

/// 参考代码折叠块
class _SolutionCard extends StatefulWidget {
  final String solution;

  const _SolutionCard({required this.solution});

  @override
  State<_SolutionCard> createState() => _SolutionCardState();
}

class _SolutionCardState extends State<_SolutionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _NoteCard(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ExpansionTile(
            leading: Icon(Icons.terminal, color: scheme.primary),
          title: Text(
            '参考代码',
            style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary),
          ),
          trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          onExpansionChanged: (v) => setState(() => _expanded = v),
          children: [
            // 代码区：深色衬底，更像 IDE
            Container(
              width: double.infinity,
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                widget.solution,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  height: 1.6,
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
