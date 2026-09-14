import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/models/problem.dart';
import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/services/stats_service.dart';

/// 「我的」页的结论规则。
///
/// 这一套测试盯的是**有没有说错话**：数据不够时不能说「正确率在上升」，
/// 只有一道错题不能说「错题集中在某处」。这类错话没法靠手点发现，
/// 只能把各种数据组合喂进来试。
void main() {
  LanguageStats lang(
    ProgrammingLanguage l, {
    int total = 72,
    int solved = 0,
    int wrong = 0,
    Map<String, int> wrongByCategory = const {},
    int favorite = 0,
    int hardSolved = 0,
    int hardTotal = 12,
    List<double> accuracies = const [],
  }) =>
      LanguageStats(
        language: l,
        total: total,
        solved: solved,
        wrong: wrong,
        wrongByCategory: wrongByCategory,
        favorite: favorite,
        unanswered: 0,
        solvedByDifficulty: {
          Difficulty.easy: solved,
          Difficulty.medium: 0,
          Difficulty.hard: hardSolved,
        },
        totalByDifficulty: {
          Difficulty.easy: total - hardTotal,
          Difficulty.medium: 0,
          Difficulty.hard: hardTotal,
        },
        categories: const [],
        testAccuracies: accuracies,
      );

  OverallStats stats(List<LanguageStats> ls) => OverallStats(languages: ls);

  /// 把结论拼成一段文字，方便用 contains 断言
  String textOf(OverallStats s) =>
      buildConclusions(s).map((c) => c.text).join('\n');

  group('完全没有数据时', () {
    test('只给一句引导，不说任何"结论"', () {
      final out = buildConclusions(stats([
        lang(ProgrammingLanguage.python),
        lang(ProgrammingLanguage.c),
        lang(ProgrammingLanguage.cpp),
      ]));
      expect(out, hasLength(1));
      expect(out.single.text, contains('还没有做题记录'));
      expect(out.single.text, contains('练习'));
      expect(out.single.tone, ConclusionTone.suggestion);
    });
  });

  group('整体进度', () {
    test('总进度与称号', () {
      final t = textOf(stats([lang(ProgrammingLanguage.python, solved: 30)]));
      expect(t, contains('已完成 30 / 72 题'));
      expect(t, contains('%'));
      expect(t, contains('称号'));
    });

    test('三门语言的总数会合起来', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 10),
        lang(ProgrammingLanguage.c, solved: 5),
        lang(ProgrammingLanguage.cpp),
      ]));
      expect(t, contains('已完成 15 / 216 题'));
    });
  });

  group('语言之间的进度对比', () {
    test('差距明显时指出最快的那门', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 30),
        lang(ProgrammingLanguage.c, solved: 10),
      ]));
      expect(t, contains('Python'));
      expect(t, contains('最快'));
      expect(t, contains('多 20 题'));
    });

    test('差距不到 5 题就不比 —— 免得像在制造焦虑', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 10),
        lang(ProgrammingLanguage.c, solved: 8),
      ]));
      expect(t, isNot(contains('最快')));
    });

    test('只有一门开工时不比', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 30),
        lang(ProgrammingLanguage.c),
      ]));
      expect(t, isNot(contains('最快')));
    });

    test('落后太多时会提一句还没开始的语言', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 30),
        lang(ProgrammingLanguage.c),
        lang(ProgrammingLanguage.cpp),
      ]));
      expect(t, contains('还没开始'));
    });

    test('刚做几道题就不提别的语言 —— 免得像催作业', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 2),
        lang(ProgrammingLanguage.c),
      ]));
      expect(t, isNot(contains('还没开始')));
    });
  });

  group('错题集中度', () {
    test('错题够多且集中在某两个分类时才说', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.c, solved: 20, wrong: 5, wrongByCategory: {
          '指针': 3,
          '数组': 2,
        }),
      ]));
      expect(t, contains('错题集中在'));
      expect(t, contains('指针'));
      expect(t, contains('数组'));
    });

    test('只有一道错题时不说「集中」—— 那是过度解读', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.c, solved: 20, wrong: 1,
            wrongByCategory: {'指针': 1}),
      ]));
      expect(t, isNot(contains('错题集中')));
    });

    test('错题很分散（每个分类都只有 1 道）也不说集中', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.c, solved: 20, wrong: 4, wrongByCategory: {
          '指针': 1,
          '数组': 1,
          '字符串': 1,
          '函数与作用域': 1,
        }),
      ]));
      expect(t, isNot(contains('错题集中')));
    });
  });

  group('测试正确率趋势（最容易说错话的地方）', () {
    test('只有 2 次测试时明确说「再做 1 次才能看趋势」，不硬下结论', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 10, accuracies: [0.4, 0.9]),
      ]));
      expect(t, contains('做了 2 次测试'));
      expect(t, contains('再做 1 次'));
      expect(t, isNot(contains('在进步')));
      expect(t, isNot(contains('下降')));
    });

    test('一次都没测过就直说，并说明测试能干什么', () {
      final t = textOf(stats([lang(ProgrammingLanguage.python, solved: 10)]));
      expect(t, contains('还没做过测试'));
    });

    test('4 次测试、后半段明显更高 → 说在进步', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 10,
            accuracies: [0.4, 0.5, 0.8, 0.9]),
      ]));
      expect(t, contains('在进步'));
      expect(t, contains('高'));
    });

    test('后半段明显更低 → 指向错题，而不是硬夸', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 10,
            accuracies: [0.9, 0.8, 0.5, 0.4]),
      ]));
      expect(t, contains('低'));
      expect(t, contains('错题'));
      expect(t, isNot(contains('在进步')));
    });

    test('基本持平 → 说稳，不编趋势', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 10,
            accuracies: [0.7, 0.72, 0.71, 0.73]),
      ]));
      expect(t, contains('比较稳'));
      expect(t, isNot(contains('在进步')));
    });

    test('跨语言的测试记录会合起来看（用户关心的是「我最近怎么样」）', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 10, accuracies: [0.5, 0.5]),
        lang(ProgrammingLanguage.c, solved: 10, accuracies: [0.9]),
      ]));
      // 3 次了，可以谈趋势
      expect(t, isNot(contains('再做')));
    });
  });

  group('困难题与收尾', () {
    test('做了困难题但没做完 → 提一句还剩多少', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 30, hardSolved: 2, hardTotal: 6),
      ]));
      expect(t, contains('困难题做了 2 / 6'));
    });

    test('一道困难题都没做 → 不提（提了也没用）', () {
      final t = textOf(stats([
        lang(ProgrammingLanguage.python, solved: 30, hardSolved: 0, hardTotal: 6),
      ]));
      expect(t, isNot(contains('困难题')));
    });

    test('最多 4 条 —— 说太多没人看', () {
      final out = buildConclusions(stats([
        lang(ProgrammingLanguage.python, solved: 30, wrong: 5,
            wrongByCategory: {'列表': 4, '字典': 3},
            hardSolved: 2, hardTotal: 6,
            accuracies: [0.4, 0.5, 0.8, 0.9]),
        lang(ProgrammingLanguage.c, solved: 5),
      ]));
      expect(out.length, lessThanOrEqualTo(4));
      expect(out, isNotEmpty);
    });
  });
}
