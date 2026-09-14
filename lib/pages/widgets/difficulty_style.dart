import 'package:flutter/material.dart';

import '../../models/problem.dart';
import '../../models/test_scope.dart';

/// 难度配色 —— **唯一**的映射处。
///
/// 绿 = 简单、黄 = 中等、红 = 困难。这套颜色同时是用户理解「难度档位」的语言
/// （难度一 = 绿、绿+黄 = 难度二、绿+黄+红 = 难度三），所以必须各处一致：
/// 题目卡片上的难度标签、出题范围弹窗里的档位、范围摘要上的小圆点。
///
/// 原来 learn_page 里两份、problem_panel 里一份各写了一遍，加上新界面就是第四份。
Color difficultyColor(Difficulty d) => switch (d) {
      Difficulty.easy => Colors.green,
      Difficulty.medium => Colors.orange,
      Difficulty.hard => Colors.red,
    };

/// 难度档位的三个点：绿 → 黄 → 红（简单到困难）。
///
/// [maxLevel] 之内的实心，之外的只留描边 —— 这样一眼能看出
/// 「这一档包含了哪几级」，也能看出「还差哪一级没包含」。
class DifficultyDots extends StatelessWidget {
  const DifficultyDots({super.key, required this.maxLevel, this.size = 10});

  /// 允许的最高难度级别（1/2/3）
  final int maxLevel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var level = 1; level <= 3; level++) ...[
          if (level > 1) const SizedBox(width: 3),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: level <= maxLevel
                  ? difficultyColor(difficultyOf(level))
                  : Colors.transparent,
              border: Border.all(color: outline, width: 1.2),
            ),
          ),
        ],
      ],
    );
  }
}
