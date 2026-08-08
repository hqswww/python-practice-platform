import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/services/interactive_runner.dart';

void main() {
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

  test('InteractiveRunner: 跑完能 stop 清理', () async {
    const code = 'while True: pass\n';
    final runner = InteractiveRunner();
    await runner.start(code);
    expect(runner.isRunning, true);
    await runner.stop().timeout(const Duration(seconds: 3));
    expect(runner.isRunning, false);
  });
}
