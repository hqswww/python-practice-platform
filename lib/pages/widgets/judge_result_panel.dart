import 'package:flutter/material.dart';

import '../../models/judge_result.dart';
import '../../models/problem.dart';
import 'rich_message_text.dart';

/// 判题结果面板
///
/// 展示判题结果，支持两种模式（由 EditorPage 控制 _showDetailed）：
/// - 简洁模式：只显示每个用例对/错
/// - 详细模式：显示实际输出 vs 期望输出 + 友好错误提示
class JudgeResultPanel extends StatelessWidget {
  final JudgeResult? result;
  final bool isJudging;
  final bool showDetailed;

  /// 判题进行中的提示语要写哪门语言。
  ///
  /// 这里原本写死「正在运行 Python 判题…」—— 有了 C/C++ 之后，
  /// 用 C 写题的人会看到屏幕上说 Python，很荒谬。
  final String languageName;

  const JudgeResultPanel({
    super.key,
    required this.result,
    required this.isJudging,
    required this.showDetailed,
    this.languageName = 'Python',
  });

  @override
  Widget build(BuildContext context) {
    if (isJudging) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('正在运行 $languageName 判题…',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (result == null) {
      return Center(
        child: Text(
          '编写代码后点击“运行并判题”\n结果会显示在这里',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final r = result!;

    // 编译失败时全部用例共享同一条编译器报错 —— 逐用例重复展示
    // 会变成「3 个用例 → 3 块一模一样的报错」，纯噪音。这里只显示一块。
    final isCompileError = r.isCompileFailure;

    // 交错入场：整体动画 0→1，各元素按 index 比例错开
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stagger(t, 0, _headerSummary(context, r)),
            const SizedBox(height: 12),
            if (isCompileError)
              _stagger(t, 1, _compileErrorBlock(context, r.caseResults.first))
            else ...[
              if (r.hasUnmetRequirements)
                _stagger(t, 1, _requirementBlock(context, r.unmetRequirements)),
              for (var i = 0; i < r.caseResults.length; i++) ...[
                _stagger(t, 1 + i * 1.0, _caseTile(context, r.caseResults[i])),
                const SizedBox(height: 8),
              ],
            ],
          ],
        );
      },
    );
  }

  /// 交错动画包装：按 [index] 延迟滑入
  Widget _stagger(double t, double index, Widget child) {
    // 每个元素的进入区间：index*0.15 ~ index*0.15+0.35
    final start = (index * 0.14).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    double local;
    if (t <= start) {
      local = 0;
    } else if (t >= end) {
      local = 1;
    } else {
      local = (t - start) / (end - start);
    }
    final curved = Curves.easeOutCubic.transform(local);
    return Opacity(
      opacity: curved,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - curved)),
        child: child,
      ),
    );
  }

  Widget _headerSummary(BuildContext context, JudgeResult result) {
    // 副标题这类「次级说明」必须取主题的 onSurfaceVariant。
    // 原来写死 Colors.black54 在深色主题下就是黑字压深底 —— 学生说看不清。
    final subtle = Theme.of(context).colorScheme.onSurfaceVariant;
    final compileFailed = result.isCompileFailure;
    // 输出全对、只是没按要求用上语法 —— 这不是「做错了」，而是「还没练到」，
    // 用红色会让学生以为答案算错了，用橙色更贴近实情。
    final unmet = result.hasUnmetRequirements;
    final color = result.allPassed
        ? Colors.green
        : unmet
            ? Colors.orange
            : Colors.red;
    final icon = result.allPassed
        ? Icons.check_circle
        : compileFailed
            ? Icons.build_circle_outlined
            : unmet
                ? Icons.rule
                : Icons.cancel;
    // 编译失败要说「编译没通过」，不能说「0/N 通过」——
    // 后者听起来像跑了但没过，实际是一个用例都没跑。
    final title = result.allPassed
        ? '全部通过！'
        : compileFailed
            ? '编译没通过'
            : unmet
                ? '输出对了，但没按要求用上语法'
                : '${result.passedCases}/${result.totalCases} 通过';

    // 「没达要求」时也要把「输出其实是对的」说清楚：学生的第一反应会是
    // 「输出明明对啊」，不讲明白他会以为是判题坏了。
    final subtitle = result.allPassed
        ? '干得漂亮！代码正确 🎉'
        : compileFailed
            ? '代码没能编译成可执行文件，所以一个用例都没跑'
            : unmet
                ? '${result.totalCases} 个用例的输出都正确 —— 但这题要练的语法还没用上'
                : '还有 ${result.totalCases - result.passedCases} 个用例没过，继续加油！';

    final card = Card(
      color: color.withValues(alpha: 0.1),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: subtle),
        ),
      ),
    );

    // 全部通过时：头部图标轻微弹跳庆祝
    if (result.allPassed) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        builder: (context, t, child) {
          return Transform.scale(scale: 0.9 + 0.1 * t, child: child);
        },
        child: card,
      );
    }
    return card;
  }

  /// 「输出对了，但题面要求的语法没用上」区块。
  ///
  /// 为什么值得单独一块：学生的第一反应一定是「输出明明对啊」。
  /// 所以这里必须把三件事讲清楚 —— 输出确实算对了、为什么还判不过、
  /// 以及具体要改成什么样。
  Widget _requirementBlock(BuildContext context, List<SourceRequirement> unmet) {
    const color = Colors.orange;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.rule, color: color),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '还差一点：本题要求的语法没用上',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '判题除了比对输出，还会核对本题要练的语法 —— '
              '有些写法输出一模一样，但练不到东西。你的输出没问题，'
              '把下面这几点补上就能通过了：',
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.5),
            ),
            const SizedBox(height: 12),
            for (final req in unmet) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '· ${req.label}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    RichMessageText(req.hint,
                        style: const TextStyle(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
            ],
            Text(
              '如果确认自己的写法没问题，可以在「设置 → 判题」里关掉'
              '「源码语法要求检查」—— 那样就只比对输出。',
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  /// 编译失败区块：一块搞定，不逐用例重复
  Widget _compileErrorBlock(BuildContext context, TestCaseResult cr) {
    const color = Colors.red;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.build_circle_outlined, color: color),
                SizedBox(width: 8),
                Text(
                  '代码没通过编译',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '编译型语言要先编译成可执行文件再运行。编译没过就不会执行，'
              '所有测试用例都不算数 —— 先按下面的报错把代码改对。',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5),
            ),
            const SizedBox(height: 12),
            _messageBox(cr.message, color),
          ],
        ),
      ),
    );
  }

  Widget _caseTile(BuildContext context, TestCaseResult cr) {
    final color = cr.isPassed ? Colors.green : Colors.red;
    final icon = cr.isPassed
        ? Icons.check_circle_outline
        : Icons.cancel_outlined;

    return Card(
      elevation: 1,
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Row(
          children: [
            Text(
              // 用状态自己的名字（超时/运行错误/答案错误…），
              // 比笼统的「未通过」更有信息量
              cr.isPassed ? '通过' : cr.status.label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${cr.timeMs}ms',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        subtitle: _caseInput(cr),
        // 详细模式才展开显示对比；简洁模式收着
        initiallyExpanded: showDetailed && !cr.isPassed,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 友好错误提示（最优先展示）
                if (!cr.isPassed && cr.message.isNotEmpty)
                  _messageBox(cr.message, color),
                if (showDetailed) ...[
                  _outputBlock(context, '实际输出', cr.actualOutput, monospace: true),
                  _outputBlock(context, '期望输出', cr.testCase.output,
                      monospace: true),
                ],
                if (!showDetailed && cr.stderr.isNotEmpty)
                  _outputBlock(context, '错误信息', cr.stderr, monospace: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _caseInput(TestCaseResult cr) {
    final input = cr.testCase.input;
    return Text(
      '输入: ${input.isEmpty ? '(无)' : input.replaceAll('\n', ' ⏎ ')}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _messageBox(String message, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      // 用 RichMessageText 而不是 Text：提示里写着 **加粗** 和 `代码`，
      // 普通 Text 会把星号和反引号原样显示出来，看着像 bug。
      child: RichMessageText(message,
          style: const TextStyle(fontSize: 13, height: 1.5)),
    );
  }

  Widget _outputBlock(
    BuildContext context, String label, String content,
    {bool monospace = false}) {
    final textStyle = monospace
        ? const TextStyle(fontFamily: 'monospace', fontSize: 13)
        : const TextStyle(fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              // onSurface@5% 而不是 black@5%：浅色主题下两者一模一样，
              // 深色主题下前者是「稍微亮一点」、后者是黑压黑（等于没画分层）。
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(content.isEmpty ? '(空)' : content, style: textStyle),
          ),
        ],
      ),
    );
  }
}
