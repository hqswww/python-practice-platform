/// 题目数据模型
///
/// 对应 assets/problems/*.json 中的一道题。
/// JSON 字段与模型字段一一对应（见 DESIGN.md 第四节）。
library;

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
    this.solution = '',
  });

  factory Problem.fromJson(Map<String, dynamic> json) {
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
      solution: (json['solution'] ?? '') as String,
    );
  }
}
