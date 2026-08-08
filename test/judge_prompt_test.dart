import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/models/problem.dart';
import 'package:python_practice/services/judge_engine.dart';

void main() {
  Problem makeProblem() => Problem(
        id: 1,
        title: '含 prompt 的 input',
        difficulty: Difficulty.easy,
        description: '',
        inputFormat: '',
        outputFormat: '',
        sampleInput: '小明',
        sampleOutput: '欢迎，小明',
        testCases: [
          TestCase(input: '小明\n', output: '欢迎，小明'),
          TestCase(input: '小红\n', output: '欢迎，小红'),
        ],
        hints: [],
      );

  test('input 带 prompt 的题能判对（prompt 不混入输出）', () async {
    const code = '''
a = input("a=")
print(f"欢迎，{a}")
''';
    final r = await JudgeEngine(timeoutMs: 3000).judge(makeProblem(), code);
    expect(r.allPassed, true, reason: '实际输出: ${r.caseResults.map((e) => '${e.actualOutput} | ${e.status}').join(' ;; ')}');
  });

  test('普通无 prompt 的题不受影响', () async {
    const code = '''
n = int(input())
print(n * 2)
''';
    final p2 = Problem(
      id: 2, title: 't', difficulty: Difficulty.easy,
      description: '', inputFormat: '', outputFormat: '',
      sampleInput: '5', sampleOutput: '10',
      testCases: [TestCase(input: '5\n', output: '10')],
      hints: [],
    );
    final r = await JudgeEngine(timeoutMs: 3000).judge(p2, code);
    expect(r.allPassed, true, reason: '实际输出: ${r.caseResults.map((e) => '${e.actualOutput} | ${e.status}').join(' ;; ')}');
  });
}
