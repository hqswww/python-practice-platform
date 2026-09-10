import 'package:flutter/material.dart';

import '../models/problem.dart';
import '../services/judge_engine.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import 'widgets/interactive_terminal.dart';
import 'widgets/python_code_field.dart';
import 'widgets/responsive.dart';
import '../services/language_service.dart';

/// 错题本：从错题中自由选题重练，做对即移出错题本
class WrongBookPage extends StatefulWidget {
  /// 当前错题（题目 id -> 错误次数）
  final Map<int, int> wrongMap;
  final List<Problem> allProblems;

  const WrongBookPage({
    super.key,
    required this.wrongMap,
    required this.allProblems,
  });

  @override
  State<WrongBookPage> createState() => _WrongBookPageState();
}

class _WrongBookPageState extends State<WrongBookPage> {
  final ProgressService _progress = ProgressService();
  late List<Problem> _questions;
  late Map<int, int> _wrongCounts;
  Set<int> _unanswered = {};
  int _index = 0;
  final Map<int, String> _drafts = {};
  final Map<int, _Rec> _recs = {};

  @override
  void initState() {
    super.initState();
    // 只保留当前仍是错题的题目，维持错误次数排序（高错在前）
    final wantedIds = widget.wrongMap.keys.toSet();
    final byId = {for (final p in widget.allProblems) p.id: p};
    _questions = wantedIds.map((id) => byId[id]).whereType<Problem>().toList();
    _wrongCounts = {
      for (final e in widget.wrongMap.entries)
        if (byId.containsKey(e.key)) e.key: e.value,
    };
    // 加载未作答标记，供界面区分展示
    _progress
        .unansweredSet(
            languageService.value, _questions.map((q) => q.id).toList())
        .then((s) {
      if (mounted) setState(() => _unanswered = s);
    });
  }

  Future<void> _judge(String code) async {
    final p = _questions[_index];
    final engine = JudgeEngine(timeoutMs: settings.timeoutMs);
    final result = await engine.judge(p, code);
    final passed = result.allPassed;
    final rec = _Rec(
      passed: passed,
      passedCases: result.passedCases,
      totalCases: result.totalCases,
      timeMs: result.caseResults.fold<int>(0, (s, r) => s + r.timeMs),
    );
    if (passed) {
      // 做对：标记解决 + 移出错题本
      await _progress.markSolved(p.language, p.id);
      if (!mounted) return;
      setState(() {
        _drafts[p.id] = code;
        _recs[p.id] = rec;
        // 从列表移除该题
        _questions = _questions.where((q) => q.id != p.id).toList();
        _wrongCounts.remove(p.id);
        if (_questions.isEmpty) {
          _index = 0;
          _showDone();
        } else if (_index >= _questions.length) {
          _index = _questions.length - 1;
        }
      });
    } else {
      await _progress.recordWrong(p.language, p.id);
      if (!mounted) return;
      setState(() {
        _unanswered.remove(p.id); // 已作答（但判错），不再算“未作答”
        _drafts[p.id] = code;
        _recs[p.id] = rec;
      });
    }
  }

  bool _isEmpty() => _questions.isEmpty;

  /// 全部错题清完
  void _showDone() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('🎉 错题全部解决！')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('错题本重练')),
      body: _isEmpty() ? _buildEmpty() : _buildFlow(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
          const SizedBox(height: 12),
          Text(
            '没有错题啦！',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '做错或未作答的题会收集到这里，做对后自动清除。',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildFlow() {
    final p = _questions[_index];
    return Column(
      children: [
        _buildNav(),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _WrongQuestionView(
              key: ValueKey(p.id),
              problem: p,
              initialCode: _drafts[p.id] ?? '',
              wrongCount: _wrongCounts[p.id] ?? 0,
              isUnanswered: _unanswered.contains(p.id),
              number: _index + 1,
              total: _questions.length,
              feedback: _recs[p.id] == null
                  ? null
                  : (_recs[p.id]!.passed
                        ? '✔ 做对了！已从错题本移除。'
                        : '✘ 还有用例没过（${_recs[p.id]!.passedCases}/${_recs[p.id]!.totalCases} · ${_recs[p.id]!.timeMs}ms），继续改。'),
              onJudge: _judge,
              onSave: (c) => _drafts[p.id] = c,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNav() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: '上一题',
            onPressed: _index > 0 ? () => setState(() => _index--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_index + 1} / ${_questions.length}  剩 ${_wrongCounts.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '下一题',
            onPressed: _index < _questions.length - 1
                ? () => setState(() => _index++)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// 轻量判题详情
class _Rec {
  final bool passed;
  final int passedCases;
  final int totalCases;
  final int timeMs;
  const _Rec({
    required this.passed,
    required this.passedCases,
    required this.totalCases,
    required this.timeMs,
  });
}

class _WrongQuestionView extends StatefulWidget {
  final Problem problem;
  final String initialCode;
  final int wrongCount;
  final bool isUnanswered;
  final int number;
  final int total;
  final String? feedback;
  final Future<void> Function(String code) onJudge;
  final void Function(String code) onSave;

  const _WrongQuestionView({
    super.key,
    required this.problem,
    required this.initialCode,
    required this.wrongCount,
    required this.isUnanswered,
    required this.number,
    required this.total,
    this.feedback,
    required this.onJudge,
    required this.onSave,
  });

  @override
  State<_WrongQuestionView> createState() => _WrongQuestionViewState();
}

class _WrongQuestionViewState extends State<_WrongQuestionView> {
  late final TextEditingController _controller;
  bool _judging = false;
  bool _showTerminal = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode);
    _controller.addListener(() => widget.onSave(_controller.text));
  }

  @override
  void didUpdateWidget(covariant _WrongQuestionView old) {
    super.didUpdateWidget(old);
    if (old.initialCode != widget.initialCode &&
        _controller.text != widget.initialCode) {
      _controller.value = TextEditingValue(
        text: widget.initialCode,
        selection: TextSelection.collapsed(offset: widget.initialCode.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('还没写代码呢～')));
      return;
    }
    setState(() => _judging = true);
    await widget.onJudge(_controller.text);
    if (!mounted) return;
    setState(() => _judging = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.problem;
    return MaxWidthBody(
      maxWidth: ContentWidth.workspace,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '第 ${widget.number}/${widget.total} 题',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.isUnanswered ? '未作答' : '错了 ${widget.wrongCount} 次',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(p.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(p.description),
            const SizedBox(height: 8),
            if (p.sampleInput.isNotEmpty)
              Text('示例输入: ${p.sampleInput.replaceAll('\n', ' ⏎ ')}'),
            if (p.sampleOutput.isNotEmpty)
              Text('示例输出: ${p.sampleOutput.replaceAll('\n', ' ⏎ ')}'),
            const SizedBox(height: 12),
            PythonCodeField(
              controller: _controller,
              language: p.language,
              minLines: 8,
              hintText: '在此输入代码…',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // 交互式终端开关
                OutlinedButton.icon(
                  onPressed: _judging
                      ? null
                      : () => setState(() => _showTerminal = !_showTerminal),
                  icon: Icon(
                    _showTerminal ? Icons.terminal : Icons.terminal_outlined,
                    size: 16,
                  ),
                  label: Text(_showTerminal ? '收起' : p.language.runPanelTitle),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _judging ? null : _submit,
                  icon: _judging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_judging ? '判题中…' : '判题'),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: widget.feedback == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(widget.feedback),
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            (widget.feedback!.startsWith('✔')
                                    ? Colors.green
                                    : Colors.orange)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              (widget.feedback!.startsWith('✔')
                                      ? Colors.green
                                      : Colors.orange)
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.feedback!.startsWith('✔')
                                ? Icons.check_circle
                                : Icons.info_outline,
                            color: widget.feedback!.startsWith('✔')
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.feedback!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          // 交互式终端：展开时作为页面内容的一部分排在下方（网页式下滑）
          if (_showTerminal)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InteractiveTerminal(
                getCode: () => _controller.text,
                sampleInput: widget.problem.sampleInput,
                isJudging: _judging,
                onJudge: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
