/// 题库仓库
///
/// 负责从 `assets/problems/<语言 id>/*.json` 加载题目，按分类组织。
/// 每个 JSON 文件对应一个分类（文件名前缀即分类 key）。
library;

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import '../models/problem.dart';
import '../models/problem_category.dart';
import '../models/programming_language.dart';

/// 分类元数据：文件名 key -> (中文名, 描述)
///
/// 按语言分组；顺序即该语言下的分类展示顺序（对齐 runoob 学习进度）。
/// 新增语言时在这里加一项，并在 `pubspec.yaml` 里加上对应资源目录。
const Map<ProgrammingLanguage, List<Map<String, String>>> _categoryMeta = {
  ProgrammingLanguage.python: [
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
  ],
  // ProgrammingLanguage.c  /  .cpp 待接入：把题库放进
  // assets/problems/c/ 后，在这里补一份同样的分类表即可。
};

/// 某门语言是否已经有题库（用于 UI 里把还没做的语言置灰）
bool hasProblemBank(ProgrammingLanguage language) =>
    (_categoryMeta[language] ?? const []).isNotEmpty;

/// 已经有题库的语言（按枚举声明顺序）
List<ProgrammingLanguage> get availableLanguages =>
    ProgrammingLanguage.values.where(hasProblemBank).toList();

class ProblemRepository {
  /// 加载题目分类。
  ///
  /// [language] 为空时加载**全部**语言（保持既有行为）；
  /// 指定时只加载该语言 —— 语言切换器接上后会用到。
  Future<List<ProblemCategory>> loadCategories({
    ProgrammingLanguage? language,
  }) async {
    final langs =
        language == null ? availableLanguages : <ProgrammingLanguage>[language];
    final result = <ProblemCategory>[];

    for (final lang in langs) {
      for (final meta in _categoryMeta[lang] ?? const []) {
        final key = meta['key']!;
        final problems = await _loadProblems(lang, key);
        // 只加载有题目的分类（避免空分类在前端显示）
        if (problems.isNotEmpty) {
          result.add(ProblemCategory(
            key: key,
            name: meta['name']!,
            description: meta['desc']!,
            language: lang,
            problems: problems,
          ));
        }
      }
    }
    return result;
  }

  /// 加载单个分类文件的所有题目
  Future<List<Problem>> _loadProblems(
    ProgrammingLanguage language,
    String key,
  ) async {
    try {
      final raw = await rootBundle
          .loadString('assets/problems/${language.id}/$key.json');
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Problem.fromJson(
                e as Map<String, dynamic>,
                language: language,
              ))
          .toList();
    } catch (e) {
      // 文件不存在或解析失败，返回空（容忍缺失的分类）
      debugPrint('加载分类 ${language.id}/$key 失败: $e');
      return [];
    }
  }
}
