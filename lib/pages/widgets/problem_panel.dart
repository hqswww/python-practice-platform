import 'package:flutter/material.dart';

import '../../models/problem.dart';

/// 题目描述面板：题干、输入/输出格式、示例、提示
class ProblemPanel extends StatefulWidget {
  final Problem problem;
  final ScrollController scrollController;

  const ProblemPanel({
    super.key,
    required this.problem,
    required this.scrollController,
  });

  @override
  State<ProblemPanel> createState() => _ProblemPanelState();
}

class _ProblemPanelState extends State<ProblemPanel> {
  /// 当前揭示到第几个提示（0 = 未揭示）
  int _revealedHints = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.problem;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // 难度 + 题号
        Row(
          children: [
            _difficultyChip(p.difficulty),
            const SizedBox(width: 8),
            Text('#${p.id}', style: textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 12),
        Text(p.title, style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        _section('题目描述', p.description),
        _section('输入格式', p.inputFormat),
        _section('输出格式', p.outputFormat),
        if (p.sampleInput.isNotEmpty || p.sampleOutput.isNotEmpty)
          _sampleBox(p),
        const SizedBox(height: 8),
        _hintSection(p),
      ],
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
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _section(String title, String body) {
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }

  Widget _sampleBox(Problem p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('示例',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),
          if (p.sampleInput.isNotEmpty)
            _codeLine('输入', p.sampleInput),
          if (p.sampleOutput.isNotEmpty)
            _codeLine('输出', p.sampleOutput),
        ],
      ),
    );
  }

  Widget _codeLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label：', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _hintSection(Problem p) {
    if (p.hints.isEmpty) return const SizedBox.shrink();
    final allShown = _revealedHints >= p.hints.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber),
            const SizedBox(width: 4),
            const Text('提示', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (!allShown)
              TextButton(
                onPressed: () => setState(() => _revealedHints++),
                child: const Text('▶ 再看一条'),
              )
            else
              IconButton(
                onPressed: () => setState(() => _revealedHints = 0),
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: '重置提示',
              ),
          ],
        ),
        for (var i = 0; i < _revealedHints; i++)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11)),
                ),
                Expanded(child: Text(p.hints[i])),
              ],
            ),
          ),
        if (!allShown && _revealedHints > 0)
          Text(
            '还有 ${p.hints.length - _revealedHints} 条',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
      ],
    );
  }
}
