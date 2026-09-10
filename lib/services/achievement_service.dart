import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/problem_repository.dart';
import '../models/achievement.dart';
import '../models/problem.dart';
import 'progress_service.dart';
import 'language_service.dart';

/// 成就数据单独登记，避免把条件判定塞进模型（模型保持「定义即数据」）
final List<Achievement> kAchievements = [
  const Achievement(
    id: 'first_step',
    name: '初露锋芒',
    description: '完成第 1 道题',
    icon: Icons.rocket_launch_outlined,
    color: Colors.green,
    order: 1,
  ),
  const Achievement(
    id: 'ten_solved',
    name: '渐入佳境',
    description: '完成 10 道题',
    icon: Icons.trending_up,
    color: Colors.teal,
    order: 2,
  ),
  const Achievement(
    id: 'half_way',
    name: '半程冲刺',
    description: '完成一半题目（36 题）',
    icon: Icons.flag_outlined,
    color: Colors.lightBlue,
    order: 3,
  ),
  const Achievement(
    id: 'all_done',
    name: '集齐圆满',
    description: '完成全部题目',
    icon: Icons.workspace_premium,
    color: Colors.amber,
    order: 4,
  ),
  const Achievement(
    id: 'easy_clear',
    name: '简单全清',
    description: '完成所有「简单」题',
    icon: Icons.check_circle_outline,
    color: Colors.green,
    order: 5,
  ),
  const Achievement(
    id: 'medium_clear',
    name: '中等攻克',
    description: '完成所有「中等」题',
    icon: Icons.build_circle_outlined,
    color: Colors.orange,
    order: 6,
  ),
  const Achievement(
    id: 'hard_clear',
    name: '艰难险阻',
    description: '完成所有「困难」题',
    icon: Icons.local_fire_department,
    color: Colors.red,
    order: 7,
  ),
  const Achievement(
    id: 'all_difficulty',
    name: '全难度制霸',
    description: '三种难度的题全部完成',
    icon: Icons.military_tech,
    color: Colors.deepPurple,
    order: 8,
  ),
  const Achievement(
    id: 'wrongbook_veteran',
    name: '错题老将',
    description: '错题本里积累了 10 道错题并已复盘',
    icon: Icons.healing_outlined,
    color: Colors.pink,
    order: 9,
  ),
  const Achievement(
    id: 'favorite_ten',
    name: '好题收藏家',
    description: '收藏了 10 道题',
    icon: Icons.bookmark_added,
    color: Colors.indigo,
    order: 10,
  ),
  const Achievement(
    id: 'test_starter',
    name: '试炼登场',
    description: '完成了第 1 次测试',
    icon: Icons.timer_outlined,
    color: Colors.cyan,
    order: 11,
  ),
  const Achievement(
    id: 'test_master',
    name: '刷题狂魔',
    description: '完成 5 次测试',
    icon: Icons.timer,
    color: Colors.lightGreen,
    order: 12,
  ),
  const Achievement(
    id: 'perfect_test',
    name: '完美新手',
    description: '在某次测试中全对',
    icon: Icons.emoji_events_outlined,
    color: Colors.amber,
    order: 13,
  ),
];

/// 称号体系：按解题进度分级的称号列表
class _TitleTier {
  final int threshold;
  final String title;
  final IconData icon;
  final Color color;

  const _TitleTier(this.threshold, this.title, this.icon, this.color);
}

const List<_TitleTier> _titleTiers = [
  _TitleTier(0, '代码小白', Icons.spa_outlined, Colors.grey),
  _TitleTier(5, 'Python 新秀', Icons.eco_outlined, Colors.green),
  _TitleTier(15, '算法学徒', Icons.school_outlined, Colors.teal),
  _TitleTier(30, '进阶开发者', Icons.code, Colors.blue),
  _TitleTier(50, '代码大师', Icons.workspace_premium, Colors.deepPurple),
  _TitleTier(72, '全栈传说', Icons.auto_awesome, Colors.amber),
];

/// 当前称号信息（取已达标最高一级）
class TitleInfo {
  final String title;
  final String nextTitle;
  final int nextNeeded;
  final IconData icon;
  final Color color;

  const TitleInfo({
    required this.title,
    required this.nextTitle,
    required this.nextNeeded,
    required this.icon,
    required this.color,
  });

  bool get maxed => nextNeeded == 0;
}

/// 成就服务
///
/// 从 [ProgressService] + 题库统计出 [ProgressSnapshot]，
/// 据此计算哪些成就达成、当前称号是什么，并记住「已展示过」的成就，
/// 以便在解锁时弹出提示。
class AchievementService {
  final ProgressService _progress = ProgressService();

  static const String _shownPrefix = 'ach_shown_';

  /// 计算进度快照
  Future<ProgressSnapshot> snapshot() async {
    final lang = languageService.value;
    final cats =
        await ProblemRepository().loadCategories(language: lang);
    final all = <Problem>[];
    for (final c in cats) {
      all.addAll(c.problems);
    }
    final ids = all.map((p) => p.id).toList();
    final solvedMap = await _progress.solvedMap(lang, ids);

    final solvedByDiff = <Difficulty, int>{
      for (final d in Difficulty.values) d: 0,
    };
    final totalByDiff = <Difficulty, int>{
      for (final d in Difficulty.values) d: 0,
    };
    var solved = 0;
    for (final p in all) {
      totalByDiff[p.difficulty] = totalByDiff[p.difficulty]! + 1;
      if (solvedMap[p.id] == true) {
        solved++;
        solvedByDiff[p.difficulty] = solvedByDiff[p.difficulty]! + 1;
      }
    }

    // 收藏 / 错题 / 测试历史
    final favoriteCount = await _progress.favoriteCount(lang);
    final wrongCount = await _progress.wrongCount(lang);
    final records = await _progress.testRecords(language: lang);
    var testCount = 0;
    var hasPerfect = false;
    var totalCorrect = 0;
    for (final r in records) {
      testCount++;
      totalCorrect += r.correctCount;
      if (r.totalCount > 0 && r.correctCount == r.totalCount) {
        hasPerfect = true;
      }
    }

    return ProgressSnapshot(
      solvedCount: solved,
      totalCount: all.length,
      solvedByDifficulty: solvedByDiff,
      totalByDifficulty: totalByDiff,
      wrongCount: wrongCount,
      favoriteCount: favoriteCount,
      testCount: testCount,
      hasPerfectTest: hasPerfect,
      totalCorrectInTests: totalCorrect,
    );
  }

  /// 判断某个成就是否达成
  bool isUnlockedAchievement(Achievement a, ProgressSnapshot s) {
    switch (a.id) {
      case 'first_step':
        return s.solvedCount >= 1;
      case 'ten_solved':
        return s.solvedCount >= 10;
      case 'half_way':
        return s.solvedCount >= (s.totalCount ~/ 2);
      case 'all_done':
        return s.solvedCount >= s.totalCount && s.totalCount > 0;
      case 'easy_clear':
        return _diffCleared(Difficulty.easy, s);
      case 'medium_clear':
        return _diffCleared(Difficulty.medium, s);
      case 'hard_clear':
        return _diffCleared(Difficulty.hard, s);
      case 'all_difficulty':
        return Difficulty.values.every((d) => _diffCleared(d, s));
      case 'wrongbook_veteran':
        return s.wrongCount >= 10;
      case 'favorite_ten':
        return s.favoriteCount >= 10;
      case 'test_starter':
        return s.testCount >= 1;
      case 'test_master':
        return s.testCount >= 5;
      case 'perfect_test':
        return s.hasPerfectTest;
      default:
        return false;
    }
  }

  bool _diffCleared(Difficulty d, ProgressSnapshot s) {
    final total = s.totalByDifficulty[d] ?? 0;
    final solved = s.solvedByDifficulty[d] ?? 0;
    return total > 0 && solved >= total;
  }

  /// 根据解题数算当前称号
  TitleInfo getTitle(int solvedCount) {
    // 找当前达标的最高档
    _TitleTier current = _titleTiers.first;
    for (final t in _titleTiers) {
      if (solvedCount >= t.threshold) current = t;
    }
    // 找下一档
    _TitleTier? next;
    for (final t in _titleTiers) {
      if (t.threshold > solvedCount) {
        next = t;
        break;
      }
    }
    return TitleInfo(
      title: current.title,
      nextTitle: next?.title ?? current.title,
      nextNeeded: next == null ? 0 : next.threshold - solvedCount,
      icon: current.icon,
      color: current.color,
    );
  }

  /// 返回「新解锁且尚未展示过」的成就 id 列表，并标记为已展示
  ///
  /// [snap] 为当前进度快照。任何达成 but 未标记 shown 的成就都会返回。
  Future<List<Achievement>> popNewlyUnlocked(
      ProgressSnapshot snap) async {
    final prefs = await SharedPreferences.getInstance();
    final newly = <Achievement>[];
    for (final a in kAchievements) {
      if (!isUnlockedAchievement(a, snap)) continue;
      final key = '$_shownPrefix${a.id}';
      if (!(prefs.getBool(key) ?? false)) {
        newly.add(a);
        await prefs.setBool(key, true);
      }
    }
    return newly;
  }

  /// 计算某成就的展示用进度（0~1），用于进度环
  static double progressOf(Achievement a, ProgressSnapshot s) {
    switch (a.id) {
      case 'first_step':
        return _ratio(s.solvedCount, 1);
      case 'ten_solved':
        return _ratio(s.solvedCount, 10);
      case 'half_way':
        return _ratio(s.solvedCount, s.totalCount ~/ 2);
      case 'all_done':
        return _ratio(s.solvedCount, s.totalCount);
      case 'easy_clear':
        return _diffProgress(Difficulty.easy, s);
      case 'medium_clear':
        return _diffProgress(Difficulty.medium, s);
      case 'hard_clear':
        return _diffProgress(Difficulty.hard, s);
      case 'all_difficulty': {
        final vals = Difficulty.values
            .map((d) => _diffProgress(d, s))
            .toList();
        return vals.reduce(min);
      }
      case 'wrongbook_veteran':
        return _ratio(s.wrongCount, 10);
      case 'favorite_ten':
        return _ratio(s.favoriteCount, 10);
      case 'test_starter':
        return _ratio(s.testCount, 1);
      case 'test_master':
        return _ratio(s.testCount, 5);
      case 'perfect_test':
        return s.hasPerfectTest ? 1.0 : 0.0;
      default:
        return 0.0;
    }
  }

  static double _ratio(int cur, int target) {
    if (target <= 0) return 0.0;
    return (cur / target).clamp(0.0, 1.0);
  }

  static double _diffProgress(Difficulty d, ProgressSnapshot s) {
    final total = s.totalByDifficulty[d] ?? 0;
    final solved = s.solvedByDifficulty[d] ?? 0;
    return total == 0 ? 0.0 : (solved / total).clamp(0.0, 1.0);
  }
}
