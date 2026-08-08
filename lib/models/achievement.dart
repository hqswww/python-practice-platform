import 'package:flutter/material.dart';

import 'problem.dart';

/// 成就状态
enum AchievementStatus { locked, unlocked }

/// 一个成就的定义
///
/// [checkProgress] 接收用户当前各维度进度快照，返回是否达成。
/// 达成与否由 [AchievementService] 计算，模型只负责「定义」。
class Achievement {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  /// 用于排序的优先级（决定展示顺序）
  final int order;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.order,
  });
}

/// 用户进度快照：把各维度统计一次性算出，供所有成就判定复用
class ProgressSnapshot {
  /// 已解决题目数
  final int solvedCount;

  /// 总题数
  final int totalCount;

  /// 各难度已解决数
  final Map<Difficulty, int> solvedByDifficulty;

  /// 各难度总数
  final Map<Difficulty, int> totalByDifficulty;

  /// 错题数
  final int wrongCount;

  /// 收藏数
  final int favoriteCount;

  /// 测试次数
  final int testCount;

  /// 是否有过「全对测试」（某次测试 100%）
  final bool hasPerfectTest;

  /// 测试总分（猜对次数累计），用于「题海战绩」一类的成就
  final int totalCorrectInTests;

  const ProgressSnapshot({
    required this.solvedCount,
    required this.totalCount,
    required this.solvedByDifficulty,
    required this.totalByDifficulty,
    required this.wrongCount,
    required this.favoriteCount,
    required this.testCount,
    required this.hasPerfectTest,
    required this.totalCorrectInTests,
  });
}
