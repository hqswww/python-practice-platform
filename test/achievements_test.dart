import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/models/achievement.dart';
import 'package:python_practice/models/problem.dart';
import 'package:python_practice/services/achievement_service.dart';

void main() {
  final svc = AchievementService();

  ProgressSnapshot makeSnap({
    int solved = 0,
    int total = 72,
    Map<Difficulty, int>? solvedDiff,
    Map<Difficulty, int>? totalDiff,
    int wrong = 0,
    int favorite = 0,
    int test = 0,
    bool perfect = false,
  }) {
    return ProgressSnapshot(
      solvedCount: solved,
      totalCount: total,
      solvedByDifficulty: solvedDiff ??
          {
            Difficulty.easy: 0,
            Difficulty.medium: 0,
            Difficulty.hard: 0,
          },
      totalByDifficulty: totalDiff ??
          {
            Difficulty.easy: 30,
            Difficulty.medium: 30,
            Difficulty.hard: 12,
          },
      wrongCount: wrong,
      favoriteCount: favorite,
      testCount: test,
      hasPerfectTest: perfect,
      totalCorrectInTests: 0,
    );
  }

  test('称号按解题数分级', () {
    expect(svc.getTitle(0).title, '代码小白');
    expect(svc.getTitle(5).title, 'Python 新秀');
    expect(svc.getTitle(15).title, '算法学徒');
    expect(svc.getTitle(30).title, '进阶开发者');
    expect(svc.getTitle(50).title, '代码大师');
    expect(svc.getTitle(72).title, '全栈传说');
    expect(svc.getTitle(72).maxed, isTrue);
    // 下一档提示
    expect(svc.getTitle(10).nextTitle, '算法学徒');
    expect(svc.getTitle(10).nextNeeded, 5);
  });

  test('解题类成就判定', () {
    final s0 = makeSnap(solved: 0);
    expect(svc.isUnlockedAchievement(kAchievements[0], s0), isFalse);

    final s1 = makeSnap(solved: 1);
    expect(svc.isUnlockedAchievement(kAchievements[0], s1), isTrue);

    final s10 = makeSnap(solved: 10);
    expect(svc.isUnlockedAchievement(kAchievements[1], s10), isTrue);

    final sAll = makeSnap(solved: 72);
    final allDone = kAchievements.firstWhere((a) => a.id == 'all_done');
    expect(svc.isUnlockedAchievement(allDone, sAll), isTrue);
  });

  test('难度制霸成就：需对应难度全清', () {
    final sEasyDone = makeSnap(
      solvedDiff: {
        Difficulty.easy: 30,
        Difficulty.medium: 0,
        Difficulty.hard: 0,
      },
    );
    final easyClear =
        kAchievements.firstWhere((a) => a.id == 'easy_clear');
    expect(svc.isUnlockedAchievement(easyClear, sEasyDone), isTrue);

    // 中等没全清，但全难度制霸不该解锁
    final allDiff = kAchievements.firstWhere((a) => a.id == 'all_difficulty');
    expect(svc.isUnlockedAchievement(allDiff, sEasyDone), isFalse);

    // 三难度都清
    final allClear = makeSnap(
      solvedDiff: {
        Difficulty.easy: 30,
        Difficulty.medium: 30,
        Difficulty.hard: 12,
      },
    );
    expect(svc.isUnlockedAchievement(allDiff, allClear), isTrue);
  });

  test('测试与收藏类成就', () {
    final sTest = makeSnap(test: 5);
    final starter = kAchievements.firstWhere((a) => a.id == 'test_starter');
    final master = kAchievements.firstWhere((a) => a.id == 'test_master');
    expect(svc.isUnlockedAchievement(starter, sTest), isTrue);
    expect(svc.isUnlockedAchievement(master, sTest), isTrue);

    final sFav = makeSnap(favorite: 10);
    final fav = kAchievements.firstWhere((a) => a.id == 'favorite_ten');
    expect(svc.isUnlockedAchievement(fav, sFav), isTrue);

    final sPerfect = makeSnap(test: 1, perfect: true);
    final perf = kAchievements.firstWhere((a) => a.id == 'perfect_test');
    expect(svc.isUnlockedAchievement(perf, sPerfect), isTrue);
  });
}
