import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/models/judge_result.dart';
import 'package:python_practice/models/problem.dart';
import 'package:python_practice/services/judge_engine.dart';

Problem _make203() => Problem(
      id: 203,
      title: '余数和整除',
      difficulty: Difficulty.easy,
      description: '',
      inputFormat: 'a b 一行',
      outputFormat: 'q r',
      sampleInput: '17 5',
      sampleOutput: '3 2',
      testCases: [
        TestCase(input: '17 5', output: '3 2'),
        TestCase(input: '20 4', output: '5 0'),
        TestCase(input: '9 2', output: '4 1'),
      ],
      hints: [],
    );

void main() {
  // 方案X：判题输入自适应——不管用户怎么读输入，答案对就判对

  test('单行 split 读法通过', () async {
    const code = 'a,b=map(int,input().split())\nprint(f"{a//b} {a%b}")';
    final r = await JudgeEngine(timeoutMs: 4000).judge(_make203(), code);
    expect(r.allPassed, true,
        reason: r.caseResults.map((c) => '${c.actualOutput}|${c.status}').join(' ;; '));
  });

  test('分行多次 input 读法也通过（自适应拆分兜底）', () async {
    const code = '''
a=input("a=")
b=input("b=")
a=int(a); b=int(b)
print(f"{a//b} {a%b}")
''';
    final r = await JudgeEngine(timeoutMs: 4000).judge(_make203(), code);
    expect(r.allPassed, true,
        reason: r.caseResults.map((c) => '${c.actualOutput}|${c.status}').join(' ;; '));
  });

  test('真正读法错误的代码仍判 runtimeError（不误判）', () async {
    // 读两个数但只给一个 input()，且对结果用过——仍应报错而非通过
    const code = '''
a=int(input())
b=int(input())
print(f"{a//b} {a%b}")
''';
    // 用单 token 输入（本来就该读不到 b）→ 应判 runtimeError
    final p = Problem(
      id: 1, title: 't', difficulty: Difficulty.easy,
      description: '', inputFormat: '', outputFormat: '',
      sampleInput: 'x', sampleOutput: 'y',
      testCases: [TestCase(input: '17\n', output: '3 2')],
      hints: [],
    );
    final r = await JudgeEngine(timeoutMs: 4000).judge(p, code);
    expect(r.caseResults.first.status, JudgeStatus.runtimeError,
        reason: '输入只有一个数却读两次，应报错：${r.caseResults.first.message}');
  });

  test('普通无输入争议的题不受影响', () async {
    const code = 'n=int(input())\nprint(n*2)';
    final p = Problem(
      id: 2, title: 't', difficulty: Difficulty.easy,
      description: '', inputFormat: '', outputFormat: '',
      sampleInput: '5', sampleOutput: '10',
      testCases: [TestCase(input: '5\n', output: '10')],
      hints: [],
    );
    final r = await JudgeEngine(timeoutMs: 4000).judge(p, code);
    expect(r.allPassed, true);
  });
}
