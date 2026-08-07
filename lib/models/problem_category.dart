/// 题目分类模型
///
/// 对应 assets/problems/ 下的一个 JSON 文件。
/// 每个文件是一类题目（如 01_syntax.json 是基础语法）。
library;

import 'problem.dart';

/// 一个题目分类，内含加载后的题目列表
class ProblemCategory {
  /// 分类标识（对应文件名前缀，如 01_syntax）
  final String key;

  /// 分类显示名（中文，如"基础语法"）
  final String name;

  /// 分类说明（简短描述，展示在分类卡片上）
  final String description;

  final List<Problem> problems;

  ProblemCategory({
    required this.key,
    required this.name,
    required this.description,
    required this.problems,
  });

  /// 从分类内题目数统计难度分布（界面可能用到）
  int get easyCount => problems.where((p) => p.difficulty == Difficulty.easy).length;
  int get mediumCount =>
      problems.where((p) => p.difficulty == Difficulty.medium).length;
  int get hardCount => problems.where((p) => p.difficulty == Difficulty.hard).length;
}
