import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/models/problem.dart';
import 'package:python_practice/models/problem_category.dart';
import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/models/test_scope.dart';
import 'package:python_practice/services/test_scope_resolver.dart';

/// 测试出题范围：范围解析 + 按难度比例抽题。
///
/// 这两件事只靠眼睛看是看不出对错的 —— 「这次抽到的困难题是不是偏多」
/// 单看一次考试毫无意义，得统计。所以算法做成纯函数，这里直接喂数据和种子。
void main() {
  var nextId = 1;
  Problem prob(Difficulty d, {ProgrammingLanguage lang = ProgrammingLanguage.python}) =>
      Problem(
        id: nextId++,
        title: '题',
        difficulty: d,
        description: '',
        inputFormat: '',
        outputFormat: '',
        sampleInput: '',
        sampleOutput: '',
        testCases: const [],
        hints: const [],
        language: lang,
      );

  /// 造一个分类：按难度配数量。key 用 `NN_xxx` 格式（题库结构守卫保证的真实格式）
  ProblemCategory cat(
    int ordinal, {
    required int easy,
    required int medium,
    required int hard,
    String? keyOverride,
  }) {
    final key = keyOverride ?? '${ordinal.toString().padLeft(2, '0')}_x';
    return ProblemCategory(
      key: key,
      name: '大类$ordinal',
      description: '',
      language: ProgrammingLanguage.python,
      problems: [
        for (var i = 0; i < easy; i++) prob(Difficulty.easy),
        for (var i = 0; i < medium; i++) prob(Difficulty.medium),
        for (var i = 0; i < hard; i++) prob(Difficulty.hard),
      ],
    );
  }

  /// 按难度统计一批题
  Map<Difficulty, int> dist(Iterable<Problem> ps) {
    final m = <Difficulty, int>{};
    for (final p in ps) {
      m.update(p.difficulty, (v) => v + 1, ifAbsent: () => 1);
    }
    return m;
  }

  group('难度级别映射', () {
    test('简单 1 / 中等 2 / 困难 3，来回都对得上', () {
      // 刻意不依赖 Difficulty.index：那是枚举声明顺序，改顺序就会静默错
      for (final d in Difficulty.values) {
        expect(difficultyOf(levelOf(d)), d);
      }
      expect(levelOf(Difficulty.easy), 1);
      expect(levelOf(Difficulty.medium), 2);
      expect(levelOf(Difficulty.hard), 3);
    });

    test('分类 key 的序号：01_syntax → 1', () {
      expect(categoryOrdinal('01_syntax'), 1);
      expect(categoryOrdinal('09_pointers'), 9);
      expect(categoryOrdinal('12_challenges'), 12);
      expect(categoryOrdinal('乱写的'), isNull);
      expect(categoryOrdinal(''), isNull);
    });
  });

  group('难度档位语义（累计的，不是「只出某一级」）', () {
    test('档位一 = 只出简单', () {
      expect(DifficultyTier.one.allows(Difficulty.easy), isTrue);
      expect(DifficultyTier.one.allows(Difficulty.medium), isFalse);
      expect(DifficultyTier.one.allows(Difficulty.hard), isFalse);
    });

    test('档位二 = 简单 + 中等', () {
      expect(DifficultyTier.two.allows(Difficulty.easy), isTrue);
      expect(DifficultyTier.two.allows(Difficulty.medium), isTrue);
      expect(DifficultyTier.two.allows(Difficulty.hard), isFalse);
    });

    test('档位三 = 全部难度', () {
      for (final d in Difficulty.values) {
        expect(DifficultyTier.three.allows(d), isTrue);
      }
    });

    test('每一档「新引入」的难度就是它自己那一级', () {
      expect(DifficultyTier.one.introduces, Difficulty.easy);
      expect(DifficultyTier.two.introduces, Difficulty.medium);
      expect(DifficultyTier.three.introduces, Difficulty.hard);
    });

    test('坏数据/缺数据回落到档位三（不限难度，最宽）', () {
      // 宽一点只会让范围更大；窄了会让学生莫名其妙做不了题
      expect(DifficultyTier.fromLevel(null), DifficultyTier.three);
      expect(DifficultyTier.fromLevel(0), DifficultyTier.three);
      expect(DifficultyTier.fromLevel(99), DifficultyTier.three);
      expect(DifficultyTier.fromLevel(2), DifficultyTier.two);
    });
  });

  group('TestScope 归一化', () {
    test('去掉越界序号', () {
      expect(TestScope.normalizeOrdinals([1, 13, 0, -2, 5]), {1, 5});
    });

    test('空集合兜底成「全部」', () {
      // 空范围等于一道题都不能出，比「全部」危险得多
      expect(TestScope.normalizeOrdinals(const []), kAllOrdinals);
      expect(TestScope.normalizeOrdinals(const [99]), kAllOrdinals);
    });

    test('默认范围 = 全部大类 + 不限难度', () {
      expect(TestScope.defaults.ordinals, kAllOrdinals);
      expect(TestScope.defaults.tier, DifficultyTier.three);
      expect(TestScope.defaults.isDefault, isTrue);
      expect(
          TestScope.defaults.copyWith(tier: DifficultyTier.one).isDefault,
          isFalse);
      expect(TestScope.defaults.copyWith(ordinals: {1}).isDefault, isFalse);
    });
  });

  group('范围解析：大类 → 题池', () {
    final cats = [
      cat(1, easy: 3, medium: 0, hard: 0), // 只有简单题
      cat(2, easy: 2, medium: 2, hard: 0), // 没有困难题
      cat(3, easy: 1, medium: 1, hard: 1), // 三级都有
    ];

    test('按序号挑大类（key 长什么样不影响）', () {
      // 这是「切语言也能用」的关键：python 的 01 是 01_syntax、
      // C 的是 01_basics，但序号 1 都指第一阶段
      final scope = TestScope(ordinals: {1}, tier: DifficultyTier.three);
      final r = resolveTestScope(categories: cats, scope: scope);
      expect(r.total, 3);
      expect(r.countOf(Difficulty.easy), 3);
    });

    test('多个大类会合起来', () {
      final r = resolveTestScope(
        categories: cats,
        scope: const TestScope(ordinals: {1, 3}, tier: DifficultyTier.three),
      );
      expect(r.total, 3 + 3);
    });

    test('范围内没有困难题 → 档位三不可选', () {
      // 这就是用户提的规则：选了只有简单/中等的大类，
      // 「难度三」和「难度二」能出的题一模一样，提供它只会误导
      final r = resolveTestScope(
        categories: cats,
        scope: const TestScope(ordinals: {2}, tier: DifficultyTier.three),
      );
      expect(r.enabledTiers, {DifficultyTier.one, DifficultyTier.two});
      expect(r.enabledTiers.contains(DifficultyTier.three), isFalse);
    });

    test('范围里只有简单题 → 只剩档位一可选', () {
      final r = resolveTestScope(
        categories: cats,
        scope: const TestScope(ordinals: {1}, tier: DifficultyTier.three),
      );
      expect(r.enabledTiers, {DifficultyTier.one});
    });

    test('存下来的档位失效时自动往下夹', () {
      // 用户先把范围设成「含困难题的大类 + 难度三」，之后把那个大类去掉 ——
      // 存的还是难度三，但实际只能按难度二出题
      final r = resolveTestScope(
        categories: cats,
        scope: const TestScope(ordinals: {2}, tier: DifficultyTier.three),
      );
      expect(r.tier, DifficultyTier.two, reason: '不夹的话会「选了难度三、按难度二出题」');
    });

    test('档位一之下题池只有简单题', () {
      final r = resolveTestScope(
        categories: cats,
        scope: const TestScope(ordinals: {3}, tier: DifficultyTier.one),
      );
      expect(r.total, 1);
      expect(r.countOf(Difficulty.easy), 1);
      expect(r.countOf(Difficulty.medium), 0);
      expect(r.countOf(Difficulty.hard), 0);
    });

    test('一个题都没有的范围是 empty（界面据此禁用开始按钮）', () {
      final r = resolveTestScope(
        categories: cats,
        scope: const TestScope(ordinals: {9}, tier: DifficultyTier.three),
      );
      expect(r.isEmpty, isTrue);
      expect(r.total, 0);
    });

    test('按序号挑不到时就只是空池，不会崩', () {
      final r = resolveTestScope(
        categories: [cat(7, easy: 1, medium: 0, hard: 0)],
        scope: const TestScope(ordinals: {1}, tier: DifficultyTier.three),
      );
      expect(r.isEmpty, isTrue);
    });
  });

  group('按难度比例抽题', () {
    /// 真实题库的分布（python：34 简单 / 32 中等 / 6 困难），用它验比例
    List<Problem> realishPool() => [
          for (var i = 0; i < 34; i++) prob(Difficulty.easy),
          for (var i = 0; i < 32; i++) prob(Difficulty.medium),
          for (var i = 0; i < 6; i++) prob(Difficulty.hard),
        ];

    test('数量正确、不重复', () {
      final pool = realishPool();
      final picked = pickQuestionsByDifficulty(
          pool: pool, count: 10, random: Random(1));
      expect(picked, hasLength(10));
      expect(picked.map((p) => p.id).toSet(), hasLength(10),
          reason: '同一道题不能在一份卷子里出现两次');
    });

    test('比例跟题库一致：10 题 → 5 简单 / 4 中等 / 1 困难', () {
      // 手算：10×34/72=4.72、10×32/72=4.44、10×6/72=0.83
      // 取整得 4/4/0（共 8），剩下 2 个名额按小数部分发给困难(.83)和简单(.72)
      final picked = pickQuestionsByDifficulty(
          pool: realishPool(), count: 10, random: Random(7));
      expect(dist(picked), {
        Difficulty.easy: 5,
        Difficulty.medium: 4,
        Difficulty.hard: 1,
      });
    });

    test('换种子只换题、不换难度结构（这正是分层抽样的目的）', () {
      // 直接洗牌取前 N 的话，每次的难度结构会飘 —— 同一份「标准测验」
      // 做两次难度完全不一样。分层之后：名额是算出来的，换种子只换具体的题。
      //
      // 手算（8 题）：8×34/72=3.78、8×32/72=3.56、8×6/72=0.67
      // 取整 3/3/0（共 6），剩 2 个名额按小数部分发给简单(.78)和困难(.67)
      // → 4 简单 / 3 中等 / 1 困难
      const expected = {
        Difficulty.easy: 4,
        Difficulty.medium: 3,
        Difficulty.hard: 1,
      };
      final seen = <int>{};
      for (final seed in [1, 2, 3, 42, 99]) {
        final picked = pickQuestionsByDifficulty(
            pool: realishPool(), count: 8, random: Random(seed));
        expect(dist(picked), expected, reason: '种子 $seed 时结构变了');
        // 顺便确认题确实换了（否则这条测试等于没测种子）
        seen.add(Object.hashAll(picked.map((p) => p.id)));
      }
      expect(seen.length, greaterThan(1), reason: '不同种子抽出来的题竟然完全一样');
    });

    test('要的比池子多 → 全都给，不重复', () {
      final pool = [prob(Difficulty.easy), prob(Difficulty.medium)];
      final picked =
          pickQuestionsByDifficulty(pool: pool, count: 5, random: Random(1));
      expect(picked, hasLength(2));
      expect(picked.map((p) => p.id).toSet(), hasLength(2));
    });

    test('要 0 题 / 空池 → 空', () {
      expect(
          pickQuestionsByDifficulty(
              pool: realishPool(), count: 0, random: Random(1)),
          isEmpty);
      expect(
          pickQuestionsByDifficulty(
              pool: const [], count: 5, random: Random(1)),
          isEmpty);
    });

    test('池子里只有一种难度 → 全给那一种（不会去凑别的）', () {
      final pool = [for (var i = 0; i < 5; i++) prob(Difficulty.medium)];
      final picked =
          pickQuestionsByDifficulty(pool: pool, count: 3, random: Random(2));
      expect(picked, hasLength(3));
      expect(picked.every((p) => p.difficulty == Difficulty.medium), isTrue);
    });

    test('稀有难度不会被过度抽取（池子里只有 1 道困难题，最多出 1 道）', () {
      // 名额可能算到 2，但池子里只有 1 道 —— 不能超发
      final pool = [
        for (var i = 0; i < 20; i++) prob(Difficulty.easy),
        prob(Difficulty.hard),
      ];
      for (final seed in [1, 2, 3, 4, 5]) {
        final picked = pickQuestionsByDifficulty(
            pool: pool, count: 10, random: Random(seed));
        expect(picked, hasLength(10));
        expect(dist(picked)[Difficulty.hard] ?? 0, lessThanOrEqualTo(1));
      }
    });

    test('整体是被打散的，不是「先简单后困难」地排好', () {
      // 不单独排序是为了避免「前半份简单后半份难」的卷子；
      // 只要在一次抽取里出现过「难度回落」就说明打散生效了
      var sawDescend = false;
      for (var seed = 0; seed < 40 && !sawDescend; seed++) {
        final picked = pickQuestionsByDifficulty(
            pool: realishPool(), count: 12, random: Random(seed));
        final levels = picked.map((p) => levelOf(p.difficulty)).toList();
        for (var i = 1; i < levels.length; i++) {
          if (levels[i] < levels[i - 1]) sawDescend = true;
        }
      }
      expect(sawDescend, isTrue, reason: '看起来结果是按难度排好序的，没有被随机打散');
    });
  });
}
