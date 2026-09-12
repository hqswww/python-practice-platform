import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/services/c_runtime.dart';
import 'package:python_practice/services/interactive_runner.dart';

void main() {
  final cReady = CRuntime.isCompilerAvailable(ProgrammingLanguage.c);
  final cppReady = CRuntime.isCompilerAvailable(ProgrammingLanguage.cpp);
  test('InteractiveRunner: 程序输出流 + input() 逐行喂入能拿到最终输出', () async {
    // 读两个 input，回显拼接
    const code = '''
a = input()
b = input()
print(a + b)
''';
    final runner = InteractiveRunner();
    await runner.start(code);

    // 依次喂入两行
    runner.sendLine('hello ');
    runner.sendLine('world');

    // 收集输出直到进程退出
    final output = StringBuffer();
    final done = Completer<void>();
    final sub = runner.events.listen((e) {
      if (e.kind == RunnerEventKind.output) {
        output.write(e.text);
      } else if (e.kind == RunnerEventKind.exit) {
        done.complete();
      }
    });
    await done.future.timeout(const Duration(seconds: 5));

    expect(output.toString().trimRight(), 'hello world');
    sub.cancel();
  });

  test('InteractiveRunner: stderr 单独推送', () async {
    const code = '''
import sys
sys.stderr.write("boom\\n")
''';
    final runner = InteractiveRunner();
    await runner.start(code);

    final out = StringBuffer();
    final err = StringBuffer();
    final done = Completer<void>();
    final sub = runner.events.listen((e) {
      if (e.kind == RunnerEventKind.output) out.write(e.text);
      if (e.kind == RunnerEventKind.error) err.write(e.text);
      if (e.kind == RunnerEventKind.exit) done.complete();
    });
    await done.future.timeout(const Duration(seconds: 5));
    expect(err.toString(), contains('boom'));
    sub.cancel();
  });

  test('InteractiveRunner: 先订阅 events 再 start 不会崩（回归：空崩溃修复）', () {
    final runner = InteractiveRunner();
    // 未 start 前先订阅（模拟终端面板 initState 时立即订阅）
    final sub = runner.events.listen((_) {});
    expect(runner.events, isA<Stream<RunnerEvent>>());
    sub.cancel();
  });

  test('InteractiveRunner: start 前订阅也能收到事件（回归：重建 controller 丢事件修复）',
      () async {
    final runner = InteractiveRunner();
    // 关键场景：先订阅（UI initState 行为），再 start
    final got = <RunnerEventKind>[];
    final sub = runner.events.listen((e) => got.add(e.kind));
    await runner.start("print('a')");
    await Future.delayed(const Duration(milliseconds: 800));
    expect(got, contains(RunnerEventKind.output));
    expect(got, contains(RunnerEventKind.exit));
    expect(runner.isRunning, false);
    sub.cancel();
  });

  test('InteractiveRunner: 跑完能 stop 清理', () async {
    const code = 'while True: pass\n';
    final runner = InteractiveRunner();
    await runner.start(code);
    expect(runner.isRunning, true);
    await runner.stop().timeout(const Duration(seconds: 3));
    expect(runner.isRunning, false);
  });

  // ============================================================
  // 语言维度必须一路贯到这一层
  //
  // 回归：这个 runner 曾经**写死 Python** —— 无论什么语言都写 runner.py 并
  // 执行 pythonCommand。于是 C / C++ 题目上点「编译运行」，实际起的是
  // Python 解释器去解释 C 代码。下面这些用例真的编译并运行 C / C++，
  // 是唯一能证明那件事被修掉的方式。
  // ============================================================

  group('编译型语言：先编译再运行（不再拿 Python 解释）', () {
    test('C：编译后运行，能逐步喂 stdin', () async {
      if (!cReady) return;
      const code = r'''
#include <stdio.h>
int main(void) {
    int a, b;
    scanf("%d %d", &a, &b);
    printf("%d\n", a + b);
    return 0;
}
''';
      final runner = InteractiveRunner(language: ProgrammingLanguage.c);
      final out = StringBuffer();
      final hints = StringBuffer();
      final done = Completer<void>();
      final sub = runner.events.listen((e) {
        if (e.kind == RunnerEventKind.output) out.write(e.text);
        if (e.kind == RunnerEventKind.error) out.write('[stderr]${e.text}');
        if (e.kind == RunnerEventKind.hint) hints.write(e.text);
        if (e.kind == RunnerEventKind.exit) done.complete();
      });

      expect(await runner.start(code), isTrue, reason: 'C 程序应能编译通过');
      runner.sendLine('3 4');
      await done.future.timeout(const Duration(seconds: 40));

      expect(out.toString().trim(), '7');
      // 命令行回显必须真的是 C 那条链路
      expect(hints.toString(), contains('solution.c'),
          reason: '回显的应该是 C 源文件名：${hints.toString()}');
      expect(hints.toString(), isNot(contains('runner.py')));
      sub.cancel();
    });

    test('C++：同样能编译运行', () async {
      if (!cppReady) return;
      const code = r'''
#include <iostream>
int main() {
    int n;
    std::cin >> n;
    std::cout << n * 2 << std::endl;
    return 0;
}
''';
      final runner = InteractiveRunner(language: ProgrammingLanguage.cpp);
      final out = StringBuffer();
      final done = Completer<void>();
      final sub = runner.events.listen((e) {
        if (e.kind == RunnerEventKind.output) out.write(e.text);
        if (e.kind == RunnerEventKind.error) out.write('[stderr]${e.text}');
        if (e.kind == RunnerEventKind.exit) done.complete();
      });

      expect(await runner.start(code), isTrue);
      runner.sendLine('21');
      await done.future.timeout(const Duration(seconds: 40));
      expect(out.toString().trim(), '42');
      sub.cancel();
    });

    test('编译不过：把编译器报错显示出来，且**不去执行**', () async {
      if (!cReady) return;
      const code = 'int main(void) { return 0 }'; // 少一个分号
      final runner = InteractiveRunner(language: ProgrammingLanguage.c);
      final err = StringBuffer();
      final hints = StringBuffer();
      final done = Completer<int?>();
      final sub = runner.events.listen((e) {
        if (e.kind == RunnerEventKind.error) err.write(e.text);
        if (e.kind == RunnerEventKind.hint) hints.write(e.text);
        if (e.kind == RunnerEventKind.exit) done.complete(e.exitCode);
      });

      expect(await runner.start(code), isFalse,
          reason: '编译失败就不该起运行进程');
      final exitCode = await done.future.timeout(const Duration(seconds: 40));

      expect(exitCode, isNot(0));
      expect(err.toString(), contains('error'),
          reason: '应保留编译器原文：${err.toString()}');
      expect(hints.toString(), contains('没通过编译'));
      expect(runner.isRunning, isFalse);
      sub.cancel();
    });

    test('Python 那条路没被改坏（默认语言仍是 Python）', () async {
      const code = "print(input() + '!')\n";
      final runner = InteractiveRunner(); // 默认 language = python
      final hints = StringBuffer();
      final out = StringBuffer();
      final done = Completer<void>();
      final sub = runner.events.listen((e) {
        if (e.kind == RunnerEventKind.hint) hints.write(e.text);
        if (e.kind == RunnerEventKind.output) out.write(e.text);
        if (e.kind == RunnerEventKind.exit) done.complete();
      });

      expect(await runner.start(code), isTrue, reason: '解释型不该有编译阶段');
      runner.sendLine('hi');
      await done.future.timeout(const Duration(seconds: 15));

      expect(out.toString().trim(), 'hi!');
      expect(hints.toString(), contains('solution.py'));
      sub.cancel();
    });
  });
}
