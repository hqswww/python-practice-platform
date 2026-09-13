/// 题目数据模型
///
/// 对应 assets/problems/*.json 中的一道题。
/// JSON 字段与模型字段一一对应（见 DESIGN.md 第四节）。
library;

import 'programming_language.dart';

/// 难度分级：easy / medium / hard
enum Difficulty {
  easy('easy'),
  medium('medium'),
  hard('hard');

  const Difficulty(this.value);
  final String value;

  static Difficulty fromString(String? s) {
    switch (s) {
      case 'hard':
        return Difficulty.hard;
      case 'medium':
        return Difficulty.medium;
      default:
        return Difficulty.easy;
    }
  }

  /// 难度对应的中文标签（界面展示用）
  String get label {
    switch (this) {
      case Difficulty.easy:
        return '简单';
      case Difficulty.medium:
        return '中等';
      case Difficulty.hard:
        return '困难';
    }
  }
}

/// 单个测试用例：给程序一组输入，期望得到特定输出
class TestCase {
  final String input;
  final String output;

  TestCase({required this.input, required this.output});

  factory TestCase.fromJson(Map<String, dynamic> json) {
    return TestCase(
      input: (json['input'] ?? '') as String,
      output: (json['output'] ?? '') as String,
    );
  }
}

/// 一道题对**源码本身**的要求（不是对输出的要求）。
///
/// ## 为什么需要它
///
/// 判题只看 stdout。可有些题目的输出**用不用那个语法都长得一样** —— 最典型的是
/// 指针入门题「用指针读取变量的值」：期望输出是同一个数打两遍，
/// 那么 `printf("%d\n%d", a, b)`（b 是 a 的普通拷贝）跟 `printf("%d\n%d", n, *p)`
/// 输出完全一致。学生在练什么，判题一点都看不出来。
///
/// 这不是判题引擎的 bug，是「只比对输出」这种判题方式的固有边界：
/// 输出层面无法分辨，就只能去源码层面看。
///
/// ## 它是什么、不是什么
///
/// 这是**启发式检查**（关键字级别的文本分析），不是编译器级的语义分析：
/// 它挡得住「压根没用指针」，挡不住蓄意伪装（声明一个指针然后不用它 ——
/// 这种由检查里的「必须真的用上」那一半来挡）。
/// 每道题的要求都必须在题库的参考答案上自证成立（有测试盯着），
/// 否则就会出现「照抄参考答案都判不过」这种最坏的情况。
///
/// [check] 是检查名（见 `lib/services/source_check.dart` 的 `kSourceChecks`），
/// [label] 和 [hint] 是给学生看的：前者说明要求什么，后者说明怎么改。
class SourceRequirement {
  /// 检查名，必须存在于 `kSourceChecks` 里（写错会被题库自检测试抓住）
  final String check;

  /// 人话版要求，如「用 *p 解引用指针」
  final String label;

  /// 没做到时给出的具体改法（会显示在判题结果里）
  final String hint;

  const SourceRequirement({
    required this.check,
    required this.label,
    required this.hint,
  });

  factory SourceRequirement.fromJson(Map<String, dynamic> json) {
    return SourceRequirement(
      check: (json['check'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      hint: (json['hint'] ?? '') as String,
    );
  }
}

/// 教程分节：一段讲解（runoob 风格），可含代码与运行结果
class TutorialSection {
  final String title; // 小节标题，如 "print() 是什么"
  final String body; // 讲解文字（可含换行）
  final String code; // 代码片段（可空）
  final String output; // 运行结果（可空）

  TutorialSection({
    required this.title,
    required this.body,
    this.code = '',
    this.output = '',
  });

  factory TutorialSection.fromJson(Map<String, dynamic> json) {
    return TutorialSection(
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      code: (json['code'] ?? '') as String,
      output: (json['output'] ?? '') as String,
    );
  }
}

/// 一道完整的题目
class Problem {
  final int id;
  final String title;
  final Difficulty difficulty;
  final String description;
  final String inputFormat;
  final String outputFormat;
  final String sampleInput;
  final String sampleOutput;
  final List<TestCase> testCases;

  /// 多级提示，逐步揭示（hints[0] 最浅，最后最接近答案）
  final List<String> hints;

  /// 参考代码（含详细注释作详解）；未提供时为空字符串
  final String solution;

  /// 详细教程（runoob 风格分节）；未提供时为空列表
  final List<TutorialSection> tutorial;

  /// 对源码的语法要求（如「必须真的解引用指针」）；未声明时为空列表。
  ///
  /// 见 [SourceRequirement] 的说明：只比对输出时，有些题目用不用某个语法
  /// 输出完全一样，必须在源码层面补一道检查。
  final List<SourceRequirement> sourceRequirements;

  /// 这道题属于哪门语言。
  ///
  /// **必填**，刻意不给默认值：给默认值的话，将来新加的 C 题忘了传
  /// 就会静默变成 Python 题（进度键、判题运行时、语法高亮全跟着错），
  /// 而且这种错很难在测试里发现。宁可让每个构造点都显式写出来。
  final ProgrammingLanguage language;

  /// 是否有可展示的详细教程
  bool get hasTutorial => tutorial.isNotEmpty;

  /// 进度存储键里用的唯一标识：语言 + 题号。
  /// 题号只在同一语言内唯一，跨语言会撞（比如 C 和 Python 都有 101 题）。
  String get progressKey => '${language.id}_$id';

  Problem({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.description,
    required this.inputFormat,
    required this.outputFormat,
    required this.sampleInput,
    required this.sampleOutput,
    required this.testCases,
    required this.hints,
    required this.language,
    this.solution = '',
    this.tutorial = const [],
    this.sourceRequirements = const [],
  });

  factory Problem.fromJson(
    Map<String, dynamic> json, {
    ProgrammingLanguage? language,
  }) {
    return Problem(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      difficulty: Difficulty.fromString(json['difficulty'] as String?),
      description: (json['description'] ?? '') as String,
      inputFormat: (json['input_format'] ?? '') as String,
      outputFormat: (json['output_format'] ?? '') as String,
      sampleInput: (json['sample_input'] ?? '') as String,
      sampleOutput: (json['sample_output'] ?? '') as String,
      testCases: (json['test_cases'] as List<dynamic>? ?? [])
          .map((e) => TestCase.fromJson(e as Map<String, dynamic>))
          .toList(),
      hints: (json['hints'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      language: language ?? ProgrammingLanguage.fromId(json['language'] as String?),
      solution: (json['solution'] ?? '') as String,
      tutorial: (json['tutorial'] as List<dynamic>? ?? [])
          .map((e) => TutorialSection.fromJson(e as Map<String, dynamic>))
          .toList(),
      sourceRequirements: (json['source_requirements'] as List<dynamic>? ?? [])
          .map((e) => SourceRequirement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
