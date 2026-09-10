import 'package:flutter/material.dart';

import '../models/problem.dart';
import '../models/problem_category.dart';
import '../services/progress_service.dart';
import 'favorite_page.dart';
import 'problem_list_page.dart';
import 'wrong_book_page.dart';
import '../services/language_service.dart';

/// 练习板块：展示所有分类 + 整体进度
class PracticePage extends StatefulWidget {
  final List<ProblemCategory> categories;

  const PracticePage({super.key, required this.categories});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final ProgressService _progress = ProgressService();

  /// 各分类的已解决数量映射（按分类 key）
  Map<String, int> _solvedByCategory = {};
  int _totalReviewed = 0;
  int _wrongCount = 0;
  int _favCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  List<Problem> get _allProblems =>
      widget.categories.expand((c) => c.problems).toList();

  Future<void> _loadProgress() async {
    final map = <String, int>{};
    var done = 0;
    for (final cat in widget.categories) {
      final solved = await _progress.solvedMap(
        cat.language,
        cat.problems.map((p) => p.id).toList(),
      );
      final count = solved.values.where((v) => v).length;
      map[cat.key] = count;
      done += count;
    }
    final wrongCount = await _progress.wrongCount(languageService.value);
    final favCount = await _progress.favoriteCount(languageService.value);
    if (!mounted) return;
    setState(() {
      _solvedByCategory = map;
      _totalReviewed = done;
      _wrongCount = wrongCount;
      _favCount = favCount;
    });
  }

  void _openWrongBook() async {
    final wrong = await _progress.allWrong(languageService.value);
    if (!mounted) return;
    if (wrong.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('📖 错题本是空的，去做测试攒点错题吧～')));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WrongBookPage(wrongMap: wrong, allProblems: _allProblems),
      ),
    );
    // 返回后刷新（错题可能被清掉）
    _loadProgress();
  }

  void _openFavorites() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FavoritePage(categories: widget.categories),
      ),
    );
    // 返回后刷新（收藏可能变化）
    _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Python 练习平台'),
        actions: [
          IconButton(
            tooltip: '刷新进度',
            onPressed: _loadProgress,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      // 分类网格入场交错动画
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 整体进度横幅（淡入上移）
              _stagger(
                t,
                0.1,
                _OverallProgressCard(
                  total: widget.categories.fold<int>(
                    0,
                    (sum, c) => sum + c.problems.length,
                  ),
                  solved: _totalReviewed,
                ),
              ),
              const SizedBox(height: 16),
              // 错题本入口（带错题数角标）
              _stagger(
                t,
                1.5,
                _WrongBookEntryCard(
                  wrongCount: _wrongCount,
                  onTap: _openWrongBook,
                ),
              ),
              const SizedBox(height: 12),
              // 收藏与复习入口
              _stagger(
                t,
                2.0,
                _FavoriteEntryCard(
                  favCount: _favCount,
                  onTap: _openFavorites,
                ),
              ),
              const SizedBox(height: 16),
              // 分类网格（每卡片交错滑入）
              //
              // 用 MaxCrossAxisExtent 而不是固定 3 列：桌面窗口可以拉很宽，
              // 固定列数会让卡片在大窗口下被撑成巨型方块、小窗口下挤成一团。
              // 按「每张卡片最多 280 宽」反推列数，卡片尺寸就始终保持在合理区间。
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.6,
                ),
                itemCount: widget.categories.length,
                itemBuilder: (context, index) {
                  final cat = widget.categories[index];
                  return _stagger(
                    t,
                    3 + index * 1.0,
                    _CategoryCard(
                      category: cat,
                      solvedCount: _solvedByCategory[cat.key] ?? 0,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// 交错入场：淡入 + 上移，按 [index] 延迟
  Widget _stagger(double t, double index, Widget child) {
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.35).clamp(0.0, 1.0);
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
        offset: Offset(0, 16 * (1 - curved)),
        child: child,
      ),
    );
  }
}

/// 整体进度卡片（顶部）
class _OverallProgressCard extends StatelessWidget {
  final int total;
  final int solved;

  const _OverallProgressCard({required this.total, required this.solved});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : solved / total;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 环形进度
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                  Center(
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    solved == total
                        ? '🎉 全部通关！太强了！'
                        : '继续加油，向 {total} 题全通冲刺！'.replaceAll(
                            '{total}',
                            '$total',
                          ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已完成 $solved / $total 题',
                    style: TextStyle(color: scheme.primary),
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

/// 错题本入口卡片（带错题数角标 + hover 缩放）
class _WrongBookEntryCard extends StatefulWidget {
  final int wrongCount;
  final VoidCallback onTap;

  const _WrongBookEntryCard({required this.wrongCount, required this.onTap});

  @override
  State<_WrongBookEntryCard> createState() => _WrongBookEntryCardState();
}

class _WrongBookEntryCardState extends State<_WrongBookEntryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.wrongCount;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: _hovered ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Card(
          elevation: _hovered ? 4 : 1,
          color: count > 0
              ? Colors.orange.withValues(alpha: 0.12)
              : scheme.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.book,
                    color: count > 0 ? Colors.orange : scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '错题本',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          count > 0 ? '有 $count 道错题等你重练' : '测试中做错的题会收集到这里',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 收藏与复习入口卡片
class _FavoriteEntryCard extends StatefulWidget {
  final int favCount;
  final VoidCallback onTap;

  const _FavoriteEntryCard({required this.favCount, required this.onTap});

  @override
  State<_FavoriteEntryCard> createState() => _FavoriteEntryCardState();
}

class _FavoriteEntryCardState extends State<_FavoriteEntryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.favCount;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: _hovered ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Card(
          elevation: _hovered ? 4 : 1,
          color: count > 0
              ? Colors.amber.withValues(alpha: 0.12)
              : scheme.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.star,
                    color: count > 0 ? Colors.amber : scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '收藏与复习',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          count > 0 ? '有 $count 道收藏题可复习' : '在题目右上角点 ⭐ 收藏，方便复习',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final ProblemCategory category;
  final int solvedCount;

  const _CategoryCard({required this.category, required this.solvedCount});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final solvedCount = widget.solvedCount;
    final total = category.problems.length;
    final complete = solvedCount == total && total > 0;
    return AnimatedScale(
      scale: _hovered ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Card(
          elevation: _hovered ? 5 : 2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProblemListPage(category: category),
                ),
              );
            },
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        category.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          category.description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        complete
                            ? '✅ 已完成 $solvedCount/$total'
                            : '已完成 $solvedCount/$total 题',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: complete
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
                // 右上角完成标记
                if (complete)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
