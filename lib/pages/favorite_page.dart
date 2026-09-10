import 'package:flutter/material.dart';

import '../models/problem.dart';
import '../models/programming_language.dart';
import '../models/problem_category.dart';
import '../services/progress_service.dart';
import 'editor_page.dart';
import 'widgets/responsive.dart';

/// 收藏与复习页：列出所有被收藏（⭐）的题目，点开即进入编辑器复习
class FavoritePage extends StatefulWidget {
  final List<ProblemCategory> categories;

  const FavoritePage({super.key, required this.categories});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final ProgressService _progress = ProgressService();

  late Future<List<Problem>> _future;
  List<Problem> _favorites = [];

  /// 全部题目（用于反查收藏 id → Problem）
  List<Problem> get _allProblems =>
      widget.categories.expand((c) => c.problems).toList();

  /// 本页所属语言。收藏是**按语言分开**统计的 ——
  /// 传进来的 categories 已被仓库按语言过滤，所以取第一个即可。
  ProgrammingLanguage get _lang => widget.categories.isEmpty
      ? ProgrammingLanguage.python
      : widget.categories.first.language;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _loadFavorites();
  }

  Future<List<Problem>> _loadFavorites() async {
    final ids = await _progress.favoriteIds(_lang);
    // 保持题库顺序（并按原分类顺序展示）
    final result = _allProblems.where((p) => ids.contains(p.id)).toList();
    _favorites = result;
    return result;
  }

  void _open(List<Problem> favs, int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorPage(
          problem: favs[index],
          allProblems: favs,
          index: index,
        ),
      ),
    );
    // 返回后收藏可能变化，刷新
    _reload();
  }

  void _reload() {
    setState(() => _future = _loadFavorites());
  }

  Future<void> _toggle(Problem problem) async {
    final now =
        await _progress.toggleFavorite(problem.language, problem.id);
    if (!mounted) return;
    setState(() => _favorites.removeWhere((p) => p.id == problem.id));
    if (!now) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            duration: Duration(milliseconds: 1200),
            content: Text('已取消收藏')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏与复习'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Problem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final favs = snapshot.data ?? [];
          if (favs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_border, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('还没有收藏任何题目', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('在题目右上角点 ⭐ 就能收藏，方便复习～',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }
          return MaxWidthBody(
            maxWidth: ContentWidth.list,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: favs.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _header(favs.length);
                }
                final idx = i - 1;
                final p = favs[idx];
                return _favTile(p, favs, idx);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _header(int count) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.bookmark, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '共收藏 $count 道题 · 点击题目即可开始复习，右上角 ⭐ 可取消收藏',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _open(_favorites, 0),
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始复习'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favTile(Problem p, List<Problem> favs, int index) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _difficultyColor(theme, p).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.code,
              size: 18, color: _difficultyColor(theme, p)),
        ),
        title: Text(p.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${p.id} · ${_difficultyLabel(p)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          tooltip: '取消收藏',
          icon: const Icon(Icons.star, color: Colors.amber),
          onPressed: () => _toggle(p),
        ),
        onTap: () => _open(favs, index),
      ),
    );
  }

  Color _difficultyColor(ThemeData theme, Problem p) {
    switch (p.difficulty) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.red;
    }
  }

  String _difficultyLabel(Problem p) => p.difficulty.label;
}
