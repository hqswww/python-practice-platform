/// 判题结果模型
library;

import 'problem.dart';

/// 判题状态
enum JudgeStatus {
  /// 通过（输出与期望一致）
  passed,

  /// 运行出错（语法错误 / 运行时异常）
  runtimeError,

  /// 输出错误（程序正常跑完，但输出不匹配）
  wrongAnswer,

  /// 超时
  timeout,
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

  /// 汇总信息
  int get totalCases => caseResults.length;
  int get passedCases => caseResults.where((r) => r.isPassed).length;
  bool get allPassed => passedCases == totalCases && totalCases > 0;

  const JudgeResult({
    required this.problem,
    required this.caseResults,
    this.hasError = false,
  });
}
