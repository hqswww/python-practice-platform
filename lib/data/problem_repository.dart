/// 题库仓库
///
/// 负责从 assets/problems/*.json 加载题目，按分类组织。
/// 每个 JSON 文件对应一个分类（文件名前缀即分类 key）。
library;

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import '../models/problem.dart';
import '../models/problem_category.dart';

/// 分类元数据：文件名 key -> (中文名, 描述)
/// 顺序即分类展示顺序（对齐 runoob 学习进度）
const List<Map<String, String>> _categoryMeta = [
  {'key': '01_syntax', 'name': '基础语法', 'desc': '变量、输入输出、print、类型转换'},
  {'key': '02_datatype', 'name': '数据类型', 'desc': '整数、浮点数、类型转换、运算'},
  {'key': '03_operators', 'name': '运算符', 'desc': '算术、比较、逻辑、幂运算'},
  {'key': '04_conditionals', 'name': '条件判断', 'desc': 'if / elif / else 分支逻辑'},
  {'key': '05_loops', 'name': '循环', 'desc': 'for / while / break / continue'},
  {'key': '06_strings', 'name': '字符串', 'desc': '切片、拼接、大小写、统计'},
  {'key': '07_lists', 'name': '列表', 'desc': '增删改查、切片、推导式'},
  {'key': '08_tuples_sets', 'name': '元组与集合', 'desc': 'tuple / set 的用法'},
  {'key': '09_dicts', 'name': '字典', 'desc': '键值对存取、遍历'},
  {'key': '10_functions', 'name': '函数', 'desc': '定义、参数、返回值、作用域'},
  {'key': '11_advanced', 'name': '进阶', 'desc': '迭代器、生成器、异常、文件'},
  {'key': '12_challenges', 'name': '综合挑战', 'desc': '跨知识点应用题'},
];

class ProblemRepository {
  /// 加载全部题目分类（按 _categoryMeta 顺序）
  Future<List<ProblemCategory>> loadCategories() async {
    final List<ProblemCategory> result = [];

    for (final meta in _categoryMeta) {
      final key = meta['key']!;
      final problems = await _loadProblems(key);
      // 只加载有题目的分类（避免空分类在前端显示）
      if (problems.isNotEmpty) {
        result.add(ProblemCategory(
          key: key,
          name: meta['name']!,
          description: meta['desc']!,
          problems: problems,
        ));
      }
    }
    return result;
  }

  /// 加载单个分类文件的所有题目
  Future<List<Problem>> _loadProblems(String key) async {
    try {
      final raw = await rootBundle.loadString('assets/problems/$key.json');
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Problem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 文件不存在或解析失败，返回空（容忍缺失的分类）
      debugPrint('加载分类 $key 失败: $e');
      return [];
    }
  }
}
