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

  test('Linux 平台解析为 python3', () {
    if (!Platform.isLinux) return;
    expect(PythonRuntime.resolvePythonCommand(), 'python3');
  });

  test('macOS 解析出的解释器真实存在且可执行', () {
    if (!Platform.isMacOS) return;
    final cmd = PythonRuntime.resolvePythonCommand();
    // 兜底分支（PATH 里也找不到）才可能返回裸命令名，此时跳过路径断言
    if (cmd == 'python3') return;
    expect(cmd.startsWith('/'), isTrue, reason: 'macOS 应解析成绝对路径: $cmd');
    expect(File(cmd).existsSync(), isTrue, reason: '解析出的解释器应存在: $cmd');
  });

  test('macOS 捆绑路径以 Contents 下的绝对相对路径表达', () {
    expect(PythonRuntime.macBundledRelativePaths, isNotEmpty);
    // 首个候选必须是 Resources：codesign 会把 Frameworks 下任何目录当嵌套代码
    // 解析，Python 大树放进去签不过（详见 python_runtime.dart 的注释）
    expect(PythonRuntime.macBundledRelativePaths.first,
        startsWith('Resources/'),
        reason: '首个候选应为可签名的 Resources 布局');
    for (final rel in PythonRuntime.macBundledRelativePaths) {
      expect(rel, endsWith('/bin/python3'));
    }
    expect(PythonRuntime.macFallbackPaths, isNotEmpty);
    for (final p in PythonRuntime.macFallbackPaths) {
      expect(p.startsWith('/'), isTrue, reason: '兜底候选必须是绝对路径: $p');
    }
  });

  test('macOS 架构探测能对应到捆绑目录名', () {
    if (!Platform.isMacOS) return;
    final dir = PythonRuntime.currentMacArchDirName();
    expect(dir, isNotNull, reason: 'macOS 上应能判定运行架构');
    expect(dir,
        anyOf(PythonRuntime.macArchDirArm64, PythonRuntime.macArchDirX64));
    expect(PythonRuntime.macArchDirX64, 'python-x86_64');
    expect(PythonRuntime.macArchDirArm64, 'python-arm64');
  });

  test('捆绑目录常量一致', () {
    expect(PythonRuntime.bundledRelativeDir, 'python');
    expect(PythonRuntime.bundledExeName, 'python.exe');
  });
}
