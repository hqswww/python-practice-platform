import 'package:flutter/material.dart';

import '../models/judge_result.dart';
import '../models/problem.dart';
import '../services/judge_engine.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import 'widgets/problem_panel.dart';
import 'widgets/judge_result_panel.dart';
import 'widgets/python_code_field.dart';

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

  @override
  void initState() {
    super.initState();
    // 预填一段示例代码模板，学生可改
    _codeController.text = _templateFor(widget.problem);
    // 读取收藏状态
    ProgressService().isFavorite(widget.problem.id).then((v) {
      if (mounted) setState(() => _isFavorite = v);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _leftScroll.dispose();
    super.dispose();
  }

  String _templateFor(Problem p) {
    // 有样例输入时给一个 input() 模板，否则空模板
    if (p.sampleInput.isNotEmpty) {
      return '# 在此编写你的代码\n'
          'data = input().split()\n'
          '# 根据题目提示处理 data，然后 print 输出结果\n';
    }
    return '# 在此编写你的代码\n';
  }

  Future<void> _runJudge() async {
    setState(() {
      _isJudging = true;
      _lastResult = null;
      _showSolution = false;
      _judgeRun++; // 触发结果面板过渡动画
    });
    // 使用当前设置里的超时时间创建引擎
    final engine = JudgeEngine(timeoutMs: settings.timeoutMs);
    final result = await engine.judge(widget.problem, _codeController.text);
    if (!mounted) return;
    setState(() {
      _isJudging = false;
      _lastResult = result;
    });
    // 判题通过：记录进度
    if (result.allPassed) {
      await ProgressService().markSolved(widget.problem.id);
    }
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
                  .toggleFavorite(widget.problem.id);
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
    return Column(
      children: [
        // 代码编辑器（语法高亮 + 行号）
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: PythonCodeField(
            controller: _codeController,
            minLines: 10,
            hintText: '在这里输入 Python 代码…',
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
        // 判题结果面板（可滚动）——结果切换时带动画过渡
        Expanded(
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
            ),
          ),
        ),
      ],
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
