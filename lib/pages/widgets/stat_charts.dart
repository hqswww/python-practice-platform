import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/problem.dart';
import '../../services/stats_service.dart';
import 'difficulty_style.dart';

/// 「我的」页的图表（fl_chart 封装）。
///
/// 每个图都做成「自己算好数据、只负责画」的小组件：数据来自
/// [OverallStats]，口径与结论卡完全一致 —— 图和结论对不上的话，
/// 用户会先怀疑数据，再怀疑整个应用。
///
/// 配色约定：难度沿用 [difficultyColor]（绿/黄/红），其余用主题色。
/// 图表**不引入新颜色**，否则「关于」「我的」两页的视觉语言会打架。

/// 图表统一高度：太矮看不清，太高会把整页拉得很长
const double kChartHeight = 180;

/// 三门语言完成度对比（横向条形）
///
/// 用条形而不是饼图：饼图看「占比」，而这里用户真正关心的是
/// 「哪门落后了、差多少」—— 横向条形更容易比较长度。
class LanguageProgressChart extends StatelessWidget {
  const LanguageProgressChart({super.key, required this.stats});

  final OverallStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final languages = stats.languages;
    if (languages.isEmpty) return const SizedBox.shrink();

    final maxY = languages
        .map((l) => l.total.toDouble())
        .fold<double>(1, (a, b) => a > b ? a : b);

    return SizedBox(
      height: kChartHeight,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${languages[group.x].language.displayName}\n'
                '${rod.toY.toInt()} / ${languages[group.x].total}',
                TextStyle(color: scheme.onInverseSurface, fontSize: 12),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: maxY / 4,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: TextStyle(
                        fontSize: 10, color: scheme.onSurfaceVariant)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= languages.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(languages[i].language.displayName,
                        style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < languages.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: languages[i].solved.toDouble(),
                  width: 26,
                  borderRadius: BorderRadius.circular(6),
                  color: scheme.primary,
                  // 背景淡淡的柱子表示「总题数」，一眼看出还剩多少
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: languages[i].total.toDouble(),
                    color: scheme.surfaceContainerHighest,
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// 难度分布（环形）：已完成的题里，简单/中等/困难各占多少
///
/// 只看**已完成**的题 —— 那是「我做到了什么」，而不是「题库里有什么」。
class DifficultyPieChart extends StatelessWidget {
  const DifficultyPieChart({super.key, required this.stats});

  final OverallStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final solved = <Difficulty, int>{
      for (final d in Difficulty.values)
        d: stats.languages
            .fold(0, (s, l) => s + (l.solvedByDifficulty[d] ?? 0)),
    };
    final totalSolved = solved.values.fold(0, (a, b) => a + b);
    if (totalSolved == 0) {
      return _EmptyChart(text: '还没有做对的题\n做完一道这里就有分布了');
    }

    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 38,
              sections: [
                for (final d in Difficulty.values)
                  if ((solved[d] ?? 0) > 0)
                    PieChartSectionData(
                      value: (solved[d] ?? 0).toDouble(),
                      color: difficultyColor(d),
                      radius: 26,
                      showTitle: false,
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final d in Difficulty.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: difficultyColor(d),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(d.label, style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      Text(
                        '${solved[d] ?? 0} 题'
                        '（${((solved[d] ?? 0) / totalSolved * 100).round()}%）',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 分类完成度（横向条形，12 个大类）
///
/// 用条形而不是沿用原来的进度条：12 行条形能直接比长短，
/// 一眼看出哪几个大类拖后腿。
class CategoryBarChart extends StatelessWidget {
  const CategoryBarChart({super.key, required this.languageStats});

  final LanguageStats languageStats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cats = languageStats.categories;
    if (cats.isEmpty) return _EmptyChart(text: '这门语言还没有分类数据');

    final height = (cats.length * 26.0).clamp(kChartHeight, 340.0);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: 6,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) {
                final c = cats[group.x];
                return BarTooltipItem(
                  '${c.name}\n${c.solved} / ${c.total}',
                  TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 92,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= cats.length) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        cats[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: const AxisTitles(),
          ),
          barGroups: [
            for (var i = 0; i < cats.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: cats[i].solved.toDouble(),
                    width: 12,
                    borderRadius: BorderRadius.circular(3),
                    color: cats[i].ratio >= 1
                        ? difficultyColor(Difficulty.easy)
                        : scheme.primary,
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 6,
                      color: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 最近若干次测试的正确率（折线）
class TestTrendChart extends StatelessWidget {
  const TestTrendChart({super.key, required this.stats, this.maxPoints = 10});

  final OverallStats stats;
  final int maxPoints;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 跨语言合并后**按真实时间**正序（OverallStats 保证的）；超过 maxPoints 只取最近的
    final points = stats.allTestAccuracies;
    if (points.length < 2) {
      return _EmptyChart(
        text: points.isEmpty
            ? '还没有测试记录\n去「测试」做一次就有曲线了'
            : '只做过 1 次测试\n再做一次就能连成线',
      );
    }
    final shown = points.length <= maxPoints
        ? points
        : points.sublist(points.length - maxPoints);

    return SizedBox(
      height: kChartHeight,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 1,
          minX: 0,
          maxX: (shown.length - 1).toDouble(),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '第 ${s.x.toInt() + 1} 次\n${(s.y * 100).round()}%',
                    TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                  ),
              ],
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.25,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 0.5,
                getTitlesWidget: (v, _) => Text('${(v * 100).round()}%',
                    style: TextStyle(
                        fontSize: 10, color: scheme.onSurfaceVariant)),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < shown.length; i++)
                  FlSpot(i.toDouble(), shown[i]),
              ],
              isCurved: false,
              color: scheme.primary,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: scheme.primary,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 近 30 天练习量（柱状，活动记录）
///
/// 这根柱子是**活动记录**唯一的展示出口 —— 它也是「连续天数」那条结论的佐证。
class DailyActivityChart extends StatelessWidget {
  const DailyActivityChart({super.key, required this.stats, this.days = 30});

  final OverallStats stats;
  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final merged = stats.mergedActivity;
    if (merged.isEmpty) {
      return _EmptyChart(
          text: '还没有练习记录\n做对第一道题就会开始记录');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final series = <int>[
      for (var i = days - 1; i >= 0; i--)
        merged[today.subtract(Duration(days: i))] ?? 0,
    ];
    final maxY = series.fold<int>(0, (a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      height: kChartHeight,
      child: BarChart(
        BarChartData(
          maxY: maxY < 1 ? 1 : maxY,
          alignment: BarChartAlignment.spaceBetween,
          barTouchData: BarTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                // 只标首尾，30 个日期全标会糊成一片
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i != 0 && i != days - 1) return const SizedBox.shrink();
                  final d = today.subtract(Duration(days: days - 1 - i));
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${d.month}/${d.day}',
                        style: TextStyle(
                            fontSize: 10, color: scheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(),
          ),
          barGroups: [
            for (var i = 0; i < series.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: series[i].toDouble(),
                    width: 5,
                    borderRadius: BorderRadius.circular(2),
                    color: series[i] > 0
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 数据不够时图表区的占位。**不能画一张空图** —— 一条平线会让人以为
/// 「我一直在 0」，而实际是还没有数据。
class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: kChartHeight,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
