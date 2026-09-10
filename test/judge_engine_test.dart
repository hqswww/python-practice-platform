import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/models/problem.dart';
import 'package:python_practice/models/judge_result.dart';
import 'package:python_practice/services/judge_engine.dart';
import 'package:python_practice/models/programming_language.dart';

void main() {
  const codeCorrect = 'a, b = map(int, input().split())\nprint(a + b)\n';
  const codeWrong = 'a, b = map(int, input().split())\nprint(a - b)\n';
  const codeSyntaxError = 'print(1 + \n';
  const codeFormatExtraSpace = 'a, b = map(int, input().split())\nprint(" " + str(a + b) + " ")\n';

  final problem = Problem(
    language: ProgrammingLanguage.python,
    id: 1,
    title: '两数之和',
    difficulty: Difficulty.easy,
    description: '读入两个整数输出和',
    inputFormat: '一行两个整数',
    outputFormat: '输出和',
    sampleInput: '3 5',
    sampleOutput: '8',
    testCases: [
      TestCase(input: '3 5', output: '8'),
      TestCase(input: '-1 10', output: '9'),
      TestCase(input: '0 0', output: '0'),
      TestCase(input: '5 5', output: '10'),
    ],
    hints: [],
  );

  final engine = JudgeEngine(pythonCommand: 'python3');

  group('JudgeEngine', () {
    test('正确代码全部通过', () async {
      final result = await engine.judge(problem, codeCorrect);
      expect(result.allPassed, isTrue);
      expect(result.passedCases, 4);
    });

    test('错误代码能抓到至少一个用例判错', () async {
      final result = await engine.judge(problem, codeWrong);
      expect(result.allPassed, isFalse);
      expect(result.passedCases, lessThan(result.totalCases));
    });

    test('语法错误识别为 runtimeError', () async {
      final result = await engine.judge(problem, codeSyntaxError);
      expect(result.hasError, isTrue);
      expect(result.caseResults.first.status, JudgeStatus.runtimeError);
    });

    test('格式问题给出友好提示', () async {
      final result = await engine.judge(problem, codeFormatExtraSpace);
      expect(result.allPassed, isFalse);
      // 内容（去空白）一致，应给出格式提示而非"错误"（status 为 wrongAnswer 且 message 含"格式"）
      final r = result.caseResults.first;
      expect(r.status, JudgeStatus.wrongAnswer);
      expect(r.message, contains('格式'));
    });

    test('全角/半角标点等价：期望全角！，输出半角! 也该判对', () async {
      final p = Problem(
        language: ProgrammingLanguage.python,
        id: 999,
        title: '标点容错',
        difficulty: Difficulty.easy,
        description: '',
        inputFormat: '',
        outputFormat: '',
        sampleInput: '',
        sampleOutput: '',
        testCases: [TestCase(input: '悟空', output: '欢迎，悟空！')],
        hints: [],
      );
      // 学生用半角逗号和半角感叹号，期望是全角
      const codeHalf = 'name = input()\nprint(f"欢迎,{name}!")';
      final result = await engine.judge(p, codeHalf);
      expect(result.allPassed, isTrue);
    });
  });
}
