import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/services/python_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UTF-8 参数与编码环境变量', () {
    expect(PythonRuntime.utf8Args, ['-X', 'utf8']);
    final env = PythonRuntime.withUtf8Env({'A': '1'});
    expect(env['PYTHONIOENCODING'], 'utf-8');
    expect(env['PYTHONUTF8'], '1');
    expect(env['A'], '1');
  });

  test('非 Windows 平台解析为 python3', () {
    if (Platform.isWindows) return; // 该测试基于 Linux 假设的解析逻辑
    expect(PythonRuntime.resolvePythonCommand(), 'python3');
  });

  test('捆绑目录常量一致', () {
    expect(PythonRuntime.bundledRelativeDir, 'python');
    expect(PythonRuntime.bundledExeName, 'python.exe');
  });
}
