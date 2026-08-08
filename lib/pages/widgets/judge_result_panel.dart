import 'package:flutter/material.dart';

import '../../models/judge_result.dart';

/// 判题结果面板
///
/// 展示判题结果，支持两种模式（由 EditorPage 控制 _showDetailed）：
/// - 简洁模式：只显示每个用例对/错
/// - 详细模式：显示实际输出 vs 期望输出 + 友好错误提示
class JudgeResultPanel extends StatelessWidget {
  final JudgeResult? result;
  final bool isJudging;
  final bool showDetailed;

  const JudgeResultPanel({
    super.key,
    required this.result,
    required this.isJudging,
    required this.showDetailed,
  });

  @override
  Widget build(BuildContext context) {
    if (isJudging) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在运行 Python 判题…', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (result == null) {
      return const Center(
        child: Text(
          '编写代码后点击“运行并判题”\n结果会显示在这里',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final r = result!;
    // 交错入场：整体动画 0→1，各元素按 index 比例错开
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stagger(t, 0, _headerSummary(r)),
            const SizedBox(height: 12),
            for (var i = 0; i < r.caseResults.length; i++) ...[
              _stagger(t, 1 + i * 1.0, _caseTile(context, r.caseResults[i])),
              const SizedBox(height: 8),
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

  Widget _headerSummary(JudgeResult result) {
    final color = result.allPassed ? Colors.green : Colors.red;
    final icon = result.allPassed ? Icons.check_circle : Icons.cancel;
    final title = result.allPassed
        ? '全部通过！'
        : '${result.passedCases}/${result.totalCases} 通过';

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
          result.allPassed
              ? '干得漂亮！代码正确 🎉'
              : '还有 ${result.totalCases - result.passedCases} 个用例没过，继续加油！',
          style: const TextStyle(color: Colors.black54),
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
              cr.isPassed ? '通过' : '未通过',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${cr.timeMs}ms',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                  _outputBlock('实际输出', cr.actualOutput, monospace: true),
                  _outputBlock('期望输出', cr.testCase.output, monospace: true),
                ],
                if (!showDetailed && cr.stderr.isNotEmpty)
                  _outputBlock('错误信息', cr.stderr, monospace: true),
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
      child: Text(message, style: const TextStyle(fontSize: 13, height: 1.5)),
    );
  }

  Widget _outputBlock(String label, String content, {bool monospace = false}) {
    final textStyle = monospace
        ? const TextStyle(fontFamily: 'monospace', fontSize: 13)
        : const TextStyle(fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(content.isEmpty ? '(空)' : content, style: textStyle),
          ),
        ],
      ),
    );
  }
}
