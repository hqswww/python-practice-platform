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
  // C 分类对齐 runoob 的 C 教程目录（见 tools/BANK_SPEC.md）。
  // 题库文件缺失的分类会被自动跳过（loadCategories 只收有题目的分类），
  // 所以这里可以先把 12 个分类一次性登记好，边写边补齐。
  ProgrammingLanguage.c: [
    {'key': '01_basics', 'name': '基础语法', 'desc': '程序结构、printf、scanf、变量、注释'},
    {'key': '02_datatype', 'name': '数据类型与变量', 'desc': 'int/float/double/char、常量、sizeof、类型转换'},
    {'key': '03_operators', 'name': '运算符', 'desc': '算术、关系、逻辑、位运算、优先级'},
    {'key': '04_conditionals', 'name': '判断与分支', 'desc': 'if / else if / else、switch'},
    {'key': '05_loops', 'name': '循环', 'desc': 'for / while / do-while、break / continue'},
    {'key': '06_functions', 'name': '函数与作用域', 'desc': '定义、参数、返回值、递归、作用域'},
    {'key': '07_arrays', 'name': '数组', 'desc': '一维/二维数组、遍历、查找、排序'},
    {'key': '08_strings', 'name': '字符串', 'desc': 'char 数组、string.h 常用函数'},
    {'key': '09_pointers', 'name': '指针', 'desc': '指针基础、指针与数组、指针与函数'},
    {'key': '10_structs', 'name': '结构体与共用体', 'desc': 'struct / union / enum / typedef'},
    // desc 里不写「文件读写」：判题没有稳定的文件路径可用，出不了可判题的
    // 文件题。分类实际覆盖宏、条件编译、malloc/free、函数指针、static。
    {'key': '11_advanced', 'name': '进阶', 'desc': '预处理器、宏、malloc/free、函数指针、static'},
    {'key': '12_challenges', 'name': '综合挑战', 'desc': '跨知识点应用题'},
  ],
  // C++ 分类对齐 runoob 的 C++ 教程目录（见 tools/BANK_SPEC.md）。
  //
  // 这里的分类表是在题库文件全部落地后才登记的 —— LanguageService 用
  // 「该语言有没有分类」判断它是否可选，提前登记会让语言切换器把 C++ 显示成
  // 可选，用户切过去却看到空科目。
  //
  // 分类 key 与 C 同名（都叫 01_basics）不冲突：题库路径带语言目录，
  // key 只在同一语言内需要唯一。id 段按分类序号走，与 C 一致。
  ProgrammingLanguage.cpp: [
    {'key': '01_basics', 'name': '基础语法', 'desc': 'iostream、cout/cin、变量、注释'},
    {'key': '02_datatype', 'name': '变量与数据类型', 'desc': 'auto、bool、const、初始化列表、类型转换'},
    {'key': '03_operators', 'name': '运算符与表达式', 'desc': '算术、关系、逻辑、位运算、优先级'},
    {'key': '04_conditionals', 'name': '判断与分支', 'desc': 'if / else if / else、switch、三元运算符'},
    {'key': '05_loops', 'name': '循环', 'desc': 'for / while / do-while、范围 for、break / continue'},
    {'key': '06_functions', 'name': '函数与重载', 'desc': '定义、默认参数、重载、引用传参、递归'},
    {'key': '07_arrays', 'name': '数组与字符串', 'desc': '数组遍历、std::string、vector 初步'},
    {'key': '08_pointers', 'name': '指针与引用', 'desc': '取地址、解引用、引用传参、指针与数组'},
    {'key': '09_classes', 'name': '类与对象', 'desc': '类、构造/析构、封装、this、const 成员函数'},
    {'key': '10_inheritance', 'name': '继承与多态', 'desc': '继承、虚函数、override、抽象类'},
    {'key': '11_stl', 'name': '模板与 STL', 'desc': '函数模板、vector / map / set、sort'},
    {'key': '12_challenges', 'name': '综合挑战', 'desc': '跨知识点应用题'},
  ],
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
