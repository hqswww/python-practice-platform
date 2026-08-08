import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/data/problem_repository.dart';
import 'package:python_practice/services/judge_engine.dart';

/// 判题引擎对真实题库参考答案的集成验证
///
/// 用真实题目 + 官方参考答案跑一遍判题，确认：
/// - 引擎能正常起 Python（含 `-X utf8` 参数）
/// - 参考答案不会产生 runtime error（题库数据自洽）
/// 覆盖多个不同分类间隔取材。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('判题引擎对真实题库参考答案可正常跑通（含 -X utf8）', () async {
    final cats = await ProblemRepository().loadCategories();
    final probs = cats.expand((c) => c.problems).toList();
    final engine = JudgeEngine(timeoutMs: 3000);

    // 跨分类抽样（0,12,24,36,48,60 → 6 题，分属不同类）
    var checked = 0;
    for (var i = 0; i < probs.length && checked < 5; i += 12) {
      final p = probs[i];
      final r = await engine.judge(p, p.solution);
      expect(r.caseResults, isNotEmpty, reason: '题 ${p.id} 无测试用例');
      for (final c in r.caseResults) {
        if (c.status.toString().contains('Runtime')) {
          fail('题 ${p.id} 参考答案竟然 runtime error: ${c.stderr}');
        }
      }
      checked++;
      // ignore: avoid_print
      print('  题 ${p.id} ${p.title} 判题 OK（${r.caseResults.length} 用例）');
    }
    expect(checked, 5);
  });
}
