import 'package:flutter/material.dart';

import '../models/judge_result.dart';
import '../models/achievement.dart';
import '../models/problem.dart';
import '../services/achievement_service.dart';
import '../services/judge_engine.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import 'widgets/problem_panel.dart';
import 'widgets/judge_result_panel.dart';
import 'widgets/python_code_field.dart';
import 'widgets/interactive_terminal.dart';

/// 编辑器判题页：左(题目描述) 右(代码编辑器 + 判题结果)
///
/// [allProblems] 当前分类的全部题目（用于”上一题/下一题“导航）
/// [index] 当前题目在 [allProblems] 中的下标
class EditorPage extends StatefulWidget {
  final Problem problem;
  final List<Problem>? allProblems;
  final int? index;

  const EditorPage({
    super.key,
    required this.problem,
    this.allProblems,
    this.index,
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final TextEditingController _codeController = TextEditingController();
  final ScrollController _leftScroll = ScrollController();

  bool _isJudging = false;
  JudgeResult? _lastResult;
  int _judgeRun = 0;

  /// 是否显示详细模式（实际输出 vs 期望输出）
  bool _showDetailed = true;

  /// 是否展开参考代码（仅判题通过后可看）
  bool _showSolution = false;

  /// 是否已收藏本题
  bool _isFavorite = false;

  /// 是否展开交互式终端面板
  bool _showTerminal = false;

  @override
  void initState() {
    super.initState();
    // 预填一段示例代码模板，学生可改
    _codeController.text = _templateFor(widget.problem);
    // 读取收藏状态
    ProgressService().isFavorite(widget.problem.language, widget.problem.id).then((v) {
      if (mounted) setState(() => _isFavorite = v);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _leftScroll.dispose();
    super.dispose();
  }

  /// 起步代码按**题目所属语言**给（定义在 ProgrammingLanguage 上）。
  /// 这里曾经写死了 Python 模板，C/C++ 题目也会被塞进 `#` 注释。
  String _templateFor(Problem p) => p.language.starterCode(
        hasSampleInput: p.sampleInput.isNotEmpty,
      );

  Future<void> _runJudge() async {
    setState(() {
      _isJudging = true;
      _lastResult = null;
      _showSolution = false;
      _judgeRun++; // 触发结果面板过渡动画
    });
    // 使用当前设置里的超时时间创建引擎
    final engine = JudgeEngine(
      timeoutMs: settings.timeoutMs,
      enforceSourceRequirements: settings.strictSourceCheck,
    );
    final result = await engine.judge(widget.problem, _codeController.text);
    if (!mounted) return;
    setState(() {
      _isJudging = false;
      _lastResult = result;
    });
    // 判题通过：记录进度
    if (result.allPassed) {
      await ProgressService()
          .markSolved(widget.problem.language, widget.problem.id);
      await _checkAchievements();
    }
  }

  /// 判题通过后检查新解锁的成就并弹窗庆祝
  Future<void> _checkAchievements() async {
    final svc = AchievementService();
    final snap = await svc.snapshot();
    final newly = await svc.popNewlyUnlocked(snap);
    if (!mounted || newly.isEmpty) return;
    final title = svc.getTitle(snap.solvedCount);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AchievementUnlockDialog(
        achievements: newly,
        title: title,
      ),
    );
  }

  bool get _hasNext =>
      widget.allProblems != null &&
      widget.index != null &&
      widget.index! + 1 < widget.allProblems!.length;

  String _titleText() {
    if (widget.allProblems != null && widget.index != null) {
      return '题 ${widget.index! + 1}/${widget.allProblems!.length} · ${widget.problem.title}';
    }
    return widget.problem.title;
  }

  /// 跳转到下一题
  void _goNext() {
    if (!_hasNext) return;
    final next = widget.allProblems![widget.index! + 1];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EditorPage(
          problem: next,
          allProblems: widget.allProblems,
          index: widget.index! + 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleText()),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          // 收藏/取消收藏本题
          IconButton(
            tooltip: _isFavorite ? '取消收藏' : '收藏本题，方便以后复习',
            onPressed: () async {
              final now = await ProgressService()
                  .toggleFavorite(widget.problem.language, widget.problem.id);
              if (!mounted) return;
              setState(() => _isFavorite = now);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                duration: const Duration(milliseconds: 1200),
                content: Text(now ? '⭐ 已收藏本题' : '已取消收藏'),
              ));
            },
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : null,
            ),
          ),
          // 判题通过且有下一题时显示”下一题“按钮
          if (_lastResult?.allPassed == true && _hasNext)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _goNext,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('下一题'),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 宽屏左右分栏，窄屏上下堆叠
          final wide = constraints.maxWidth > 900;
          final left = ProblemPanel(
            problem: widget.problem,
            scrollController: _leftScroll,
          );
          final right = _buildEditorPanel(context);

          if (wide) {
            return Row(
              children: [
                SizedBox(width: constraints.maxWidth * 0.42, child: left),
                const VerticalDivider(width: 1),
                Expanded(child: right),
              ],
            );
          }
          return Column(children: [left, right]);
        },
      ),
    );
  }

  Widget _buildEditorPanel(BuildContext context) {
    // 全滚动布局：编辑器、结果、终端都在同一个滚动流里（网页式下滑），互不遮挡。
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // 代码编辑器（语法高亮 + 行号）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: PythonCodeField(
            controller: _codeController,
            language: widget.problem.language,
            minLines: 10,
            hintText: '在这里输入 ${widget.problem.language.displayName} 代码…',
          ),
        ),
        // 操作栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // 详细/简洁模式切换
              const Icon(Icons.visibility_outlined, size: 18),
              const SizedBox(width: 4),
              const Text('详情'),
              Switch(
                value: _showDetailed,
                onChanged: _isJudging
                    ? null
                    : (v) => setState(() => _showDetailed = v),
              ),
              const SizedBox(width: 4),
              // 交互式终端开关
              OutlinedButton.icon(
                onPressed: _isJudging
                    ? null
                    : () => setState(() => _showTerminal = !_showTerminal),
                icon: Icon(
                  _showTerminal ? Icons.terminal : Icons.terminal_outlined,
                  size: 16,
                ),
                label: Text(_showTerminal
                    ? '收起'
                    : widget.problem.language.runPanelTitle),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Spacer(),
              // 重置代码到模板
              OutlinedButton.icon(
                onPressed: _isJudging
                    ? null
                    : () => setState(
                        () =>
                            _codeController.text = _templateFor(widget.problem),
                      ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重置'),
              ),
              const SizedBox(width: 8),
              // 运行判题
              FilledButton.icon(
                onPressed: _isJudging ? null : _runJudge,
                icon: _isJudging
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isJudging ? '判题中…' : '运行并判题'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 判题通过后可“查看参考代码”按钮
        if (_lastResult?.allPassed == true)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    setState(() => _showSolution = !_showSolution),
                icon: Icon(
                  _showSolution
                      ? Icons.expand_less
                      : Icons.menu_book_outlined,
                  size: 18,
                ),
                label: Text(_showSolution ? '收起参考代码' : '查看参考代码'),
              ),
            ),
          ),
        // 参考代码展开区
        if (_showSolution)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _buildSolutionCard(context),
          ),
        const SizedBox(height: 8),
        // 判题结果面板（自适应高度，随内容收缩；滚动由外层 SingleChildScrollView 负责）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child: JudgeResultPanel(
              key: ValueKey('judge_$_judgeRun'),
              result: _lastResult,
              isJudging: _isJudging,
              showDetailed: _showDetailed,
              languageName: widget.problem.language.displayName,
            ),
          ),
        ),
        // 交互式终端：展开时作为页面内容的一部分排在下方（网页式下滑）
        if (_showTerminal)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: InteractiveTerminal(
              // 必须把语言带上：曾经没有这个参数，C/C++ 题目上起的是 Python
              language: widget.problem.language,
              getCode: () => _codeController.text,
              sampleInput: widget.problem.sampleInput,
              isJudging: _isJudging,
              onJudge: _runJudge,
            ),
          ),
      ],
    ),
    );
  }

  /// 参考代码展示卡片（带注释题解）。仅判题通过后可看。
  Widget _buildSolutionCard(BuildContext context) {
    final theme = Theme.of(context);
    final solution = widget.problem.solution.trim();
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_objects_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                const Text('参考代码',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Text('(注释即解题思路)',
                    style: TextStyle(
                        fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            // 参考代码（只读，等宽字体）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: SelectableText(
                solution.isEmpty ? '（本题暂未提供参考代码）' : solution,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '参考代码里的注释就是解题思路。先对照你的代码，找出差异，再独立重写一遍效果最佳。',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 判题通过时展示新解锁成就的庆祝弹窗
class _AchievementUnlockDialog extends StatelessWidget {
  final List<Achievement> achievements;
  final TitleInfo title;

  const _AchievementUnlockDialog({
    required this.achievements,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.celebration, color: Colors.amber),
          SizedBox(width: 8),
          Text('🎉 新成就解锁！'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in achievements)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(a.icon, color: a.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          a.description,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(title.icon, color: title.color, size: 20),
              const SizedBox(width: 6),
              Text(
                '当前称号：${title.title}',
                style: TextStyle(
                  color: title.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('太棒了！'),
        ),
      ],
    );
  }
}
