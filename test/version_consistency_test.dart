import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/app_version.dart';

/// 版本号一致性。
///
/// 版本号原先散在四个地方（pubspec、设置页「关于」、错误日志头、Windows 安装包
/// 脚本），改一次要记得改四处。这不是假想的风险 —— 实际就漂过：
/// 「关于」对话框里写着 V1.2，而 pubspec 已经是别的版本了。
///
/// 现在 Dart 侧只认 [appVersion] 一个常量，pubspec 与安装包脚本那两份由这里盯着。
void main() {
  test('appVersion 形如 X.Y.Z', () {
    expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(appVersion), isTrue,
        reason: '实际：$appVersion');
  });

  test('pubspec.yaml 与 app_version.dart 一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    // ⚠️ Dart 的 RegExp 不支持内联标志 (?m)，多行要用构造参数
    //   （.NET / PowerShell 里可以写 (?m)，两个引擎不一样）
    final m = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
        .firstMatch(pubspec);
    expect(m, isNotNull, reason: 'pubspec.yaml 里没找到 version: 行');
    expect(m!.group(1), appVersion,
        reason: 'pubspec.yaml 是 ${m.group(1)}，lib/app_version.dart 是 $appVersion —— '
            '发的包和界面显示的版本号会对不上');
  });

  test('Windows 安装包脚本与 app_version.dart 一致', () {
    final iss = File('tools/windows_installer.iss').readAsStringSync();
    final m = RegExp(r'#define AppVersion "([^"]+)"').firstMatch(iss);
    expect(m, isNotNull, reason: 'installer.iss 里没找到 AppVersion 定义');
    expect(m!.group(1), appVersion,
        reason: '安装包会带错版本号，控制面板里的版本与「关于」对不上');
  });

  group('界面代码不写死版本号', () {
    // 写死就会出现「关于里 V1.2、日志里 V1.3」这种前后矛盾，
    // 而且是静默的 —— 编译不会报错、测试不查也发现不了。
    for (final path in [
      'lib/pages/settings_page.dart',
      'lib/services/error_log_service.dart',
    ]) {
      test(path, () {
        final text = File(path).readAsStringSync();
        expect(text, contains('appVersion'),
            reason: '$path 展示版本号时应使用 appVersion 常量');
        expect(RegExp(r'V\d+\.\d+').hasMatch(text), isFalse,
            reason: '$path 里出现了写死的版本号（形如 V1.2）');
      });
    }
  });
}
