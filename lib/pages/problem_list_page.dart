import 'package:flutter/material.dart';

import '../models/problem.dart';
import '../models/problem_category.dart';
import '../services/progress_service.dart';
import 'editor_page.dart';
import 'widgets/responsive.dart';

/// 题目列表页：展示某分类下的所有题目（带完成状态）
class ProblemListPage extends StatefulWidget {
  final ProblemCategory category;

  const ProblemListPage({super.key, required this.category});

  @override
  State<ProblemListPage> createState() => _ProblemListPageState();
}

class _ProblemListPageState extends State<ProblemListPage> {
  final ProgressService _progress = ProgressService();

  /// 已解决的题目 id 集合
  Set<int> _solvedIds = {};

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final ids = widget.category.problems.map((p) => p.id).toList();
    final map = await _progress.solvedMap(ids);
    if (!mounted) return;
    setState(() {
      _solvedIds = map.entries.where((e) => e.value).map((e) => e.key).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category.name} · ${widget.category.problems.length} 题'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: MaxWidthBody(
        maxWidth: ContentWidth.list,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: widget.category.problems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final problem = widget.category.problems[index];
            return _ProblemTile(
              problem: problem,
              allProblems: widget.category.problems,
              index: index,
              solved: _solvedIds.contains(problem.id),
              onEntered: _loadStatus,
            );
          },
        ),
      ),
    );
  }
}

class _ProblemTile extends StatelessWidget {
  final Problem problem;
  final List<Problem> allProblems;
  final int index;
  final bool solved;
  final VoidCallback onEntered;

  const _ProblemTile({
    required this.problem,
    required this.allProblems,
    required this.index,
    required this.solved,
    required this.onEntered,
  });

  @override
  Widget build(BuildContext context) {
    final diffColor = _difficultyColor(problem.difficulty);
    return Card(
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: solved
              ? Colors.green.withValues(alpha: 0.18)
              : diffColor.withValues(alpha: 0.15),
          child: solved
              ? const Icon(Icons.check, color: Colors.green, size: 20)
              : Text(
                  '${problem.id}',
                  style:
                      TextStyle(color: diffColor, fontWeight: FontWeight.bold),
                ),
        ),
        title: Text(problem.title),
        subtitle: Text(problem.description,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: diffColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                problem.difficulty.label,
                style: TextStyle(color: diffColor, fontSize: 12),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditorPage(
                problem: problem,
                allProblems: allProblems,
                index: index,
              ),
            ),
          );
          // 从编辑器返回后刷新完成状态
          onEntered();
        },
      ),
    );
  }

  Color _difficultyColor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.red;
    }
  }
}
