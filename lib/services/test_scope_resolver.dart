/// 把「出题范围」落到实际题池上，并按难度比例抽题。
///
/// 这里全是纯函数（不碰文件、不碰界面），所以可以直接测 ——
/// 出题比例这种事只靠眼睛看是看不出对错的。
library;

import 'dart:math';

import '../models/problem.dart';
import '../models/problem_category.dart';
import '../models/test_scope.dart';

/// 一个范围解析出来的结果
class ResolvedScope {
  /// 选中大类里的**全部**题目（还没按难度过滤）
  final List<Problem> inScope;

  /// 实际生效的档位。可能与设置里存的不同 —— 范围缩小后，
  /// 原来那一档可能已经没意义了，这里会自动往下夹。
  final DifficultyTier tier;

  /// 哪几档是**有意义**的（可以给用户选）。
  ///
  /// 规则：难度 k 有意义 ⟺ 范围内存在**恰好 k 级**的题目。
  /// 比如范围内一道困难题都没有，难度三能出的题和难度二完全一样，
  /// 提供它只会让人以为「选了会变难」—— 实际什么也没变。
  final Set<DifficultyTier> enabledTiers;

  /// 按难度分级的题目（只包含 [tier] 允许的部分）
  final Map<Difficulty, List<Problem>> byDifficulty;

  const ResolvedScope({
    required this.inScope,
    required this.tier,
    required this.enabledTiers,
    required this.byDifficulty,
  });

  /// 实际题池（按档位过滤后的全部题目）
  List<Problem> get pool {
    final out = <Problem>[];
    for (final d in Difficulty.values) {
      out.addAll(byDifficulty[d] ?? const []);
    }
    return out;
  }

  int get total => pool.length;
  bool get isEmpty => total == 0;

  /// 某级难度在**实际题池**里的数量（界面上要显示分布）
  int countOf(Difficulty d) => byDifficulty[d]?.length ?? 0;
}

/// 解析范围：选中大类 → 算哪些档有意义 → 夹紧档位 → 过滤出题池。
ResolvedScope resolveTestScope({
  required List<ProblemCategory> categories,
  required TestScope scope,
}) {
  // 1. 按序号挑出选中的大类（语言无关：key 各语言不同，序号一致）
  final inScope = <Problem>[];
  for (final c in categories) {
    final ord = categoryOrdinal(c.key);
    if (ord == null || !scope.ordinals.contains(ord)) continue;
    inScope.addAll(c.problems);
  }

  // 2. 范围内各级难度的数量 → 哪几档有意义
  final inScopeByLevel = <int, int>{};
  for (final p in inScope) {
    inScopeByLevel.update(levelOf(p.difficulty), (v) => v + 1,
        ifAbsent: () => 1);
  }
  final enabled = <DifficultyTier>{
    for (final t in DifficultyTier.values)
      if ((inScopeByLevel[t.level] ?? 0) > 0) t,
  };

  // 3. 夹紧档位：存下来的档位可能因范围变小而失效（比如原来有困难题、
  //    现在只选了没有困难题的大类）。
  var tier = scope.tier;
  if (enabled.isNotEmpty && !enabled.contains(tier)) {
    for (final t in DifficultyTier.values.reversed) {
      if (t.level <= tier.level && enabled.contains(t)) {
        tier = t;
        break;
      }
    }
  }

  // 4. 过滤出题池
  final byDifficulty = <Difficulty, List<Problem>>{};
  for (final p in inScope) {
    if (!tier.allows(p.difficulty)) continue;
    byDifficulty.putIfAbsent(p.difficulty, () => []).add(p);
  }

  return ResolvedScope(
    inScope: inScope,
    tier: tier,
    enabledTiers: enabled,
    byDifficulty: byDifficulty,
  );
}

/// 按难度比例抽题，尽量让抽出来的卷子保持题库自己的难度分布。
///
/// ## 为什么要分层，而不是直接 shuffle 取前 N
///
/// 直接在池子里洗牌取前 N，难度分布是「碰运气」的：池子里 72 题有 12 道困难题，
/// 抽 10 题时有一定概率一道困难题都不出、也可能连出三道 —— 同一份「标准测验」
/// 两次做起来难度完全不一样。分层抽样把每级难度的名额按池子里的占比分好，
/// 每次出的卷子难度结构都稳定。
///
/// ## 名额怎么分
///
/// 最大余数法（Hare 配额）：先按 `count × 该级题数 / 池子总数` 取整，
/// 剩下的名额按小数部分从大到小发。这样「池子里困难题占 1/6」的规律能保留下来，
/// 又不会因为取整丢掉名额。
///
/// 返回的卷子是**打乱**的 —— 不分层的话可能前几道全是简单题、后面全是困难题，
/// 做起来像换了套卷子；按难度从易到难之类的主观排序也不做，就随机打散。
List<Problem> pickQuestionsByDifficulty({
  required List<Problem> pool,
  required int count,
  required Random random,
}) {
  if (pool.isEmpty || count <= 0) return const [];
  if (count >= pool.length) {
    return List.of(pool)..shuffle(random);
  }

  // 按难度分组
  final groups = <Difficulty, List<Problem>>{};
  for (final p in pool) {
    groups.putIfAbsent(p.difficulty, () => []).add(p);
  }

  final total = pool.length;
  final exact = <Difficulty, double>{};
  final take = <Difficulty, int>{};
  var assigned = 0;
  for (final e in groups.entries) {
    final q = count * e.value.length / total;
    exact[e.key] = q;
    // 取整后的名额一定小于该组题数（因为 count < total），不会超发
    take[e.key] = q.floor();
    assigned += take[e.key]!;
  }

  // 剩下的名额按小数部分从大到小发。同分时：题多的组优先，再同就按难度
  // 从低到高 —— 定死顺序，同一个随机种子结果可复现。
  var rest = count - assigned;
  final order = groups.keys.toList()
    ..sort((a, b) {
      final fa = exact[a]! - exact[a]!.floorToDouble();
      final fb = exact[b]! - exact[b]!.floorToDouble();
      final byFrac = fb.compareTo(fa);
      if (byFrac != 0) return byFrac;
      final bySize = groups[b]!.length.compareTo(groups[a]!.length);
      if (bySize != 0) return bySize;
      return levelOf(a).compareTo(levelOf(b));
    });
  for (final d in order) {
    if (rest <= 0) break;
    if (take[d]! >= groups[d]!.length) continue; // 理论上到不了，防御
    take[d] = take[d]! + 1;
    rest--;
  }

  // 每组内部洗牌后取走自己的名额
  final picked = <Problem>[];
  for (final e in groups.entries) {
    final g = List.of(e.value)..shuffle(random);
    picked.addAll(g.take(take[e.key] ?? 0));
  }

  // 最后整体打散：不然同一难度的题会连在一起
  picked.shuffle(random);
  return picked;
}
