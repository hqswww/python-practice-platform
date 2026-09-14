/// 「我的」页的数据层：三门语言的进度聚合 + 基于数据的结论。
///
/// 拆成两半是刻意的：
/// - [StatsService.collect] 只干 IO（读题库、读进度、读测试历史），把结果攒成
///   [OverallStats] 这个纯数据对象
/// - [buildConclusions] 是**纯函数**：只吃数据、吐结论文案
///
/// 这样「数据不足时该说什么话」才能被测试覆盖 —— 那种分支没法靠手点出来，
/// 而说错话的代价比不说大得多（只有 1 次测试却写「正确率在上升」）。
library;

import '../data/problem_repository.dart';
import '../models/problem.dart';
import '../models/programming_language.dart';
import '../models/test_record.dart';
import 'achievement_service.dart';
import 'progress_service.dart';

/// 一个分类的完成度
class CategoryProgress {
  final String key;
  final String name;
  final int solved;
  final int total;

  const CategoryProgress({
    required this.key,
    required this.name,
    required this.solved,
    required this.total,
  });

  double get ratio => total == 0 ? 0 : solved / total;
}

/// 一门语言的进度概况
class LanguageStats {
  final ProgrammingLanguage language;
  final int total;
  final int solved;
  final int wrong;

  /// 错题**按分类**的分布（分类名 → 错题道数），用于「错题集中在哪」
  final Map<String, int> wrongByCategory;

  final int favorite;
  final int unanswered;

  final Map<Difficulty, int> solvedByDifficulty;
  final Map<Difficulty, int> totalByDifficulty;

  /// 全部 12 个分类（按序号），界面画分类完成度用
  final List<CategoryProgress> categories;

  /// 这门语言历次测试的正确率，**按时间正序**（最多保留最近 10 次）
  final List<double> testAccuracies;

  const LanguageStats({
    required this.language,
    required this.total,
    required this.solved,
    required this.wrong,
    required this.wrongByCategory,
    required this.favorite,
    required this.unanswered,
    required this.solvedByDifficulty,
    required this.totalByDifficulty,
    required this.categories,
    required this.testAccuracies,
  });

  double get ratio => total == 0 ? 0 : solved / total;
  bool get started => solved > 0;
}

/// 三门语言加起来的总览
class OverallStats {
  final List<LanguageStats> languages;

  const OverallStats({required this.languages});

  int get total => languages.fold(0, (s, l) => s + l.total);
  int get solved => languages.fold(0, (s, l) => s + l.solved);
  int get wrong => languages.fold(0, (s, l) => s + l.wrong);
  int get favorite => languages.fold(0, (s, l) => s + l.favorite);

  double get ratio => total == 0 ? 0 : solved / total;

  bool get isEmpty => solved == 0;

  /// 已经开工的语言（按已解决数从多到少）
  List<LanguageStats> get startedLanguages =>
      languages.where((l) => l.started).toList()
        ..sort((a, b) => b.solved.compareTo(a.solved));

  /// 一次都没碰过的语言
  List<LanguageStats> get untouchedLanguages =>
      languages.where((l) => !l.started && l.total > 0).toList();

  /// 全部测试正确率，按时间正序（跨语言合并 —— 用户看的是「我最近怎么样」）
  List<double> get allTestAccuracies {
    final all = <double>[];
    for (final l in languages) {
      all.addAll(l.testAccuracies);
    }
    return all;
  }
}

/// 一条结论的「语气」—— 用图标/颜色区分，文案本身不带 emoji
enum ConclusionTone {
  /// 进展、成就
  progress,

  /// 值得注意的薄弱点
  attention,

  /// 可以做的事
  suggestion,
}

class Conclusion {
  final String text;
  final ConclusionTone tone;

  const Conclusion(this.text, this.tone);
}

/// 聚合三门语言的数据
class StatsService {
  final ProgressService _progress;
  final ProblemRepository _repo;

  StatsService({ProgressService? progress, ProblemRepository? repo})
      : _progress = progress ?? ProgressService(),
        _repo = repo ?? ProblemRepository();

  /// 读一次全部数据。三份题库都是本地 JSON，很快；但界面要有 loading 态。
  Future<OverallStats> collect() async {
    final list = <LanguageStats>[];
    for (final lang in availableLanguages) {
      list.add(await _collectOne(lang));
    }
    return OverallStats(languages: list);
  }

  Future<LanguageStats> _collectOne(ProgrammingLanguage lang) async {
    final cats = await _repo.loadCategories(language: lang);
    final problems = <Problem>[];
    final categories = <CategoryProgress>[];
    for (final c in cats) {
      problems.addAll(c.problems);
      categories.add(CategoryProgress(
        key: c.key,
        name: c.name,
        solved: 0,
        total: c.problems.length,
      ));
    }

    final ids = problems.map((p) => p.id).toList();
    final solvedMap = await _progress.solvedMap(lang, ids);
    final wrongMap = await _progress.allWrong(lang);
    final favorites = await _progress.favoriteIds(lang);
    final unanswered = await _progress.unansweredSet(lang, ids);

    final solvedByDiff = <Difficulty, int>{for (final d in Difficulty.values) d: 0};
    final totalByDiff = <Difficulty, int>{for (final d in Difficulty.values) d: 0};
    final wrongByCategory = <String, int>{};
    final solvedPerCategory = <String, int>{};
    final totalPerCategory = <String, int>{};

    var solved = 0;
    for (final c in cats) {
      var catSolved = 0;
      for (final p in c.problems) {
        totalByDiff[p.difficulty] = totalByDiff[p.difficulty]! + 1;
        totalPerCategory[c.key] = (totalPerCategory[c.key] ?? 0) + 1;
        if (solvedMap[p.id] == true) {
          solved++;
          catSolved++;
          solvedByDiff[p.difficulty] = solvedByDiff[p.difficulty]! + 1;
        }
        if (wrongMap.containsKey(p.id)) {
          wrongByCategory[c.name] = (wrongByCategory[c.name] ?? 0) + 1;
        }
      }
      solvedPerCategory[c.key] = catSolved;
    }

    final records = await _progress.testRecords(language: lang);
    // 按时间正序，只留最近 10 次：看趋势不需要更久的历史
    final sorted = List<TestRecord>.of(records)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final accuracies = <double>[
      for (final r in sorted)
        if (r.totalCount > 0) r.correctCount / r.totalCount,
    ];
    final recent = accuracies.length <= 10
        ? accuracies
        : accuracies.sublist(accuracies.length - 10);

    return LanguageStats(
      language: lang,
      total: problems.length,
      solved: solved,
      wrong: wrongMap.length,
      wrongByCategory: wrongByCategory,
      favorite: favorites.length,
      unanswered: unanswered.length,
      solvedByDifficulty: solvedByDiff,
      totalByDifficulty: totalByDiff,
      categories: [
        for (final c in categories)
          CategoryProgress(
            key: c.key,
            name: c.name,
            solved: solvedPerCategory[c.key] ?? 0,
            total: totalPerCategory[c.key] ?? c.total,
          ),
      ],
      testAccuracies: recent,
    );
  }
}

// --------------------------------------------------------------- 结论（纯函数）

/// 从总览里算出「总结性结论」。
///
/// **只写数据撑得住的结论**：每一条都有前置条件，数据不够时给的是
/// 「再做 N 次就能看趋势」这类实话，而不是硬凑一句听起来漂亮的。
/// 最多返回 4 条 —— 说太多就没人看了。
List<Conclusion> buildConclusions(OverallStats stats) {
  final out = <Conclusion>[];

  if (stats.isEmpty) {
    return const [
      Conclusion('还没有做题记录。去「练习」里挑一道开始吧，做完会自动记在这里。',
          ConclusionTone.suggestion),
    ];
  }

  // ① 整体进度 + 称号
  final title = AchievementService().getTitle(stats.solved);
  final percent = (stats.ratio * 100).round();
  out.add(Conclusion(
    '已完成 ${stats.solved} / ${stats.total} 题（$percent%），当前称号「${title.title}」。',
    ConclusionTone.progress,
  ));

  // ② 哪门语言领先 / 落后（至少两门开工才有得比）
  final started = stats.startedLanguages;
  if (started.length >= 2) {
    final best = started.first;
    final worst = started.last;
    final gap = best.solved - worst.solved;
    if (gap >= 5) {
      out.add(Conclusion(
        '${best.language.displayName} 的进度最快（${best.solved}/${best.total}），'
        '比 ${worst.language.displayName} 多 $gap 题。',
        ConclusionTone.progress,
      ));
    }
  }

  // ③ 错题集中在哪（错题太少就不下结论 —— 「集中」至少要有几道才成立）
  final hot = _hottestWrongCategories(stats);
  if (hot.isNotEmpty) {
    final parts = hot.map((e) => '「${e.$1}」${e.$2} 道').join('、');
    out.add(Conclusion(
      '错题集中在 $parts，可以去错题本专项重练。',
      ConclusionTone.attention,
    ));
  }

  // ④ 测试正确率趋势：**至少 3 次**才谈得上趋势
  final acc = stats.allTestAccuracies;
  if (acc.length >= 3) {
    final half = acc.length ~/ 2;
    final earlier = acc.sublist(0, half);
    final later = acc.sublist(acc.length - half);
    final a = _avg(earlier);
    final b = _avg(later);
    final diff = ((b - a) * 100).round();
    if (diff >= 5) {
      out.add(Conclusion(
        '最近 ${later.length} 次测试的平均正确率 ${_pct(b)}，'
        '比之前高 $diff 个百分点，在进步。',
        ConclusionTone.progress,
      ));
    } else if (diff <= -5) {
      out.add(Conclusion(
        '最近 ${later.length} 次测试的平均正确率 ${_pct(b)}，'
        '比之前低 ${-diff} 个百分点 —— 可以回头看看错题。',
        ConclusionTone.attention,
      ));
    } else {
      out.add(Conclusion(
        '最近 ${later.length} 次测试的平均正确率 ${_pct(b)}，和之前差不多，比较稳。',
        ConclusionTone.progress,
      ));
    }
  } else if (acc.isNotEmpty) {
    out.add(Conclusion(
      '做了 ${acc.length} 次测试，再做 ${3 - acc.length} 次就能看出正确率的趋势。',
      ConclusionTone.suggestion,
    ));
  } else {
    out.add(const Conclusion(
      '还没做过测试。测试会按难度比例自动组卷，能检验是不是真的掌握了。',
      ConclusionTone.suggestion,
    ));
  }

  // ⑤ 还没开始的语言（最多提一门，免得像催作业）
  if (out.length < 4) {
    final untouched = stats.untouchedLanguages;
    if (untouched.isNotEmpty && started.isNotEmpty) {
      final l = untouched.first;
      final gap = started.first.solved - 0;
      if (gap >= 5) {
        out.add(Conclusion(
          '${l.language.displayName} 还没开始（${l.total} 题等着）。',
          ConclusionTone.suggestion,
        ));
      }
    }
  }

  // ⑥ 困难题进度（做得动才提，一道没做的时候提它没意义）
  if (out.length < 4) {
    var hardSolved = 0, hardTotal = 0;
    for (final l in stats.languages) {
      hardSolved += l.solvedByDifficulty[Difficulty.hard] ?? 0;
      hardTotal += l.totalByDifficulty[Difficulty.hard] ?? 0;
    }
    if (hardTotal > 0 && hardSolved > 0 && hardSolved < hardTotal) {
      out.add(Conclusion(
        '困难题做了 $hardSolved / $hardTotal，剩下的可以留到复习时啃。',
        ConclusionTone.suggestion,
      ));
    }
  }

  return out.take(4).toList();
}

/// 找出错题最集中的分类（最多两个，且各自至少 2 道）。
///
/// 阈值 2 是有意的：只有 1 道错题就说「集中」是过度解读。
List<(String, int)> _hottestWrongCategories(OverallStats stats) {
  if (stats.wrong < 3) return const [];
  final merged = <String, int>{};
  for (final l in stats.languages) {
    l.wrongByCategory.forEach((name, n) {
      merged[name] = (merged[name] ?? 0) + n;
    });
  }
  final sorted = merged.entries.where((e) => e.value >= 2).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in sorted.take(2)) (e.key, e.value)];
}

double _avg(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

String _pct(double v) => '${(v * 100).round()}%';
