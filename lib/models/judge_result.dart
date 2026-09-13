/// 判题结果模型
library;

import 'problem.dart';

/// 判题状态
///
/// 顺序即「严重程度」：编译错误最靠前 —— 编译都过不去，就谈不上运行时错误。
enum JudgeStatus {
  /// 编译失败（仅编译型语言，如 C/C++）
  ///
  /// 这是编译型语言特有的状态：一次编译失败会让**全部**用例都变成这个状态，
  /// UI 上不该逐用例重复展示同一条编译器报错。
  compileError,

  /// 通过（输出与期望一致）
  passed,

  /// 运行出错（语法错误 / 运行时异常）
  runtimeError,

  /// 输出错误（程序正常跑完，但输出不匹配）
  wrongAnswer,

  /// 超时
  timeout,
}

/// 判题状态的中文名（UI 与日志共用，避免两处各写一套）
extension JudgeStatusLabel on JudgeStatus {
  String get label => switch (this) {
        JudgeStatus.compileError => '编译错误',
        JudgeStatus.passed => '通过',
        JudgeStatus.runtimeError => '运行错误',
        JudgeStatus.wrongAnswer => '答案错误',
        JudgeStatus.timeout => '超时',
      };
}

/// 单个测试用例的判题结果
class TestCaseResult {
  final TestCase testCase;
  final JudgeStatus status;

  /// 学生代码的实际输出（用于展示 + 智能提示分析）
  final String actualOutput;

  /// 程序 stderr（如 traceback 错误堆栈）
  final String stderr;

  /// 运行耗时（毫秒）
  final int timeMs;

  /// 对当前用例的友好错误提示（无则空字符串）
  final String message;

  const TestCaseResult({
    required this.testCase,
    required this.status,
    required this.actualOutput,
    required this.stderr,
    required this.timeMs,
    this.message = '',
  });

  bool get isPassed => status == JudgeStatus.passed;
}

/// 一道题整体判题的结果（汇总所有用例）
class JudgeResult {
  final Problem problem;

  /// 每个用例的结果
  final List<TestCaseResult> caseResults;

  /// 代码是否有编译/运行错误（任一用例内存 stderr 等）
  final bool hasError;

  /// 没被满足的**源码语法要求**（见 [SourceRequirement]）；空表示都满足或没要求。
  ///
  /// 只在「输出全对」时才会非空 —— 输出都不对时，先让学生解决输出问题，
  /// 同时甩两条互不相干的结论只会让人不知道该先改哪个。
  final List<SourceRequirement> unmetRequirements;

  /// 汇总信息
  int get totalCases => caseResults.length;
  int get passedCases => caseResults.where((r) => r.isPassed).length;

  /// 所有用例的输出都对（**不看**语法要求）
  bool get outputAllPassed => passedCases == totalCases && totalCases > 0;

  /// 真正算通过：输出全对，**并且**语法要求都满足。
  ///
  /// 进度记录、错题本、测试模式都认这一个 —— 所以「输出对了但没用指针」
  /// 不会把题目标记成已解决，这正是引入源码检查的目的。
  bool get allPassed => outputAllPassed && unmetRequirements.isEmpty;

  /// 是不是「输出全对，但没按要求用上某个语法」
  bool get hasUnmetRequirements => unmetRequirements.isNotEmpty;

  /// 是否「整份代码没编译过」——所有用例都是编译错误。
  ///
  /// 编译型语言特有：编译失败时一个用例都没跑，UI 显示「0/3 通过」会误导
  /// （像是跑了但没过）。放在模型层，免得每个展示处各判一次。
  bool get isCompileFailure =>
      caseResults.isNotEmpty &&
      caseResults.every((c) => c.status == JudgeStatus.compileError);

  /// 编译失败的报错原文（所有用例共享同一条）；非编译失败返回空串
  String get compileErrorMessage =>
      isCompileFailure ? caseResults.first.message : '';

  const JudgeResult({
    required this.problem,
    required this.caseResults,
    this.hasError = false,
    this.unmetRequirements = const [],
  });
}
