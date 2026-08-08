import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../services/achievement_service.dart';

/// 成就与称号页面
///
/// 顶部展示当前称号 + 下一档进度，下方为成就宫格（解锁/未解锁）。
class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final AchievementService _svc = AchievementService();
  Future<ProgressSnapshot>? _snapFuture;

  @override
  void initState() {
    super.initState();
    _snapFuture = _svc.snapshot();
  }

  void _refresh() {
    setState(() {
      _snapFuture = _svc.snapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成就与称号'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<ProgressSnapshot>(
        future: _snapFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final snap = snapshot.data ?? const ProgressSnapshot(
            solvedCount: 0,
            totalCount: 0,
            solvedByDifficulty: {},
            totalByDifficulty: {},
            wrongCount: 0,
            favoriteCount: 0,
            testCount: 0,
            hasPerfectTest: false,
            totalCorrectInTests: 0,
          );
          final title = _svc.getTitle(snap.solvedCount);
          final unlocked = kAchievements
              .where((a) => _svc.isUnlockedAchievement(a, snap))
              .length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---- 当前称号卡片 ----
              _titleCard(context, title, snapshot: snap),
              const SizedBox(height: 20),
              // ---- 成就统计 ----
              Row(
                children: [
                  Text(
                    '成就',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '$unlocked / ${kAchievements.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ---- 成就宫格 ----
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: kAchievements.length,
                itemBuilder: (context, i) {
                  final a = kAchievements[i];
                  return _achievementTile(context, a, snap);
                },
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  /// 当前称号卡片
  Widget _titleCard(BuildContext context, TitleInfo title,
      {required ProgressSnapshot snapshot}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 称号图标
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: title.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(title.icon, color: title.color, size: 44),
            ),
            const SizedBox(height: 12),
            Text(
              title.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: title.color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '已完成 ${snapshot.solvedCount} / ${snapshot.totalCount} 题',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // 下一档进度
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: snapshot.totalCount == 0
                    ? 0
                    : (snapshot.solvedCount / snapshot.totalCount).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title.maxed
                  ? '🏆 已达成最高称号！'
                  : '再完成 ${title.nextNeeded} 题晋升「${title.nextTitle}」',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  /// 单个成就宫格
  Widget _achievementTile(
      BuildContext context, Achievement a, ProgressSnapshot snap) {
    final unlocked = _svc.isUnlockedAchievement(a, snap);
    final progress = AchievementService.progressOf(a, snap);
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: a.description,
      child: Card(
        elevation: unlocked ? 2 : 0,
        color: unlocked
            ? a.color.withValues(alpha: 0.08)
            : scheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 图标：解锁彩色，锁定灰色
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      color: unlocked ? a.color : Colors.grey,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  Icon(
                    unlocked ? a.icon : Icons.lock_outline,
                    color: unlocked ? a.color : Colors.grey,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                a.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: unlocked
                      ? a.color
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                unlocked ? '已解锁' : '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 10,
                  color: unlocked ? a.color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
