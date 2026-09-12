import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 三平台的应用身份一致性。
///
/// 这类漂移**不会让任何代码报错**，只会让用户看到不一致的东西 —— 实际就发生过：
/// Linux 的窗口标题和可执行文件名一直是 Flutter 模板塞进去的 Dart 包名
/// `python_practice`，而 macOS / Windows 早就叫 `code_workbook` / 「编程练习册」了，
/// 直到要出 Linux 包时才被发现。
///
/// 这些断言读的是 CMake / Xcode / GTK 的配置文件，编译期不会校验它们，
/// 只能靠测试兜住。
void main() {
  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '找不到 $path（测试的工作目录应是项目根目录）');
    return f.readAsStringSync();
  }

  group('可执行文件名三平台一致', () {
    test('都是 code_workbook', () {
      expect(read('linux/CMakeLists.txt'),
          contains('set(BINARY_NAME "code_workbook")'),
          reason: 'Linux 的 BINARY_NAME 决定用户拿到的可执行文件名');
      expect(read('windows/CMakeLists.txt'),
          contains('set(BINARY_NAME "code_workbook")'));
      expect(read('macos/Runner/Configs/AppInfo.xcconfig'),
          contains('PRODUCT_NAME = code_workbook'));
    });

    test('Linux 窗口标题不再是 Dart 包名', () {
      final cc = read('linux/runner/my_application.cc');
      expect(cc, isNot(contains('"python_practice"')),
          reason: '标题栏上出现下划线英文包名很难看，且与 macOS 不一致');
      expect(cc, contains('编程练习册'));
    });
  });

  group('绝不能改的标识（改了会伤到用户数据）', () {
    test('macOS Bundle ID —— 它是用户进度的定位键', () {
      // ~/Library/Preferences/<BundleID>.plist 以及沙盒外的
      // ~/Library/Application Support/<BundleID>/ 都按这个 id 存。
      // 改了 id，老用户的进度、错题、收藏、成就不是丢了，而是**找不到**了
      // —— 表现和丢数据一模一样。
      expect(read('macos/Runner/Configs/AppInfo.xcconfig'),
          contains('PRODUCT_BUNDLE_IDENTIFIER = com.sakiri.python-practice'));
    });

    test('Linux APPLICATION_ID 与 macOS Bundle ID 用同一个字符串', () {
      // .desktop 入口、单实例、StartupWMClass 都按它找应用；
      // 两边不一致会让任务栏图标对不上窗口。
      expect(read('linux/CMakeLists.txt'),
          contains('set(APPLICATION_ID "com.sakiri.python-practice")'),
          reason: '注意是连字符，不是下划线');
    });

    test('Dart 包名 python_practice —— 21 个文件 import 它', () {
      expect(read('pubspec.yaml'), contains('name: python_practice'),
          reason: '改包名要同步改所有 import 和平台脚手架，收益为零');
    });
  });

  test('build_linux.sh 有平台护栏（Flutter 桌面版不能交叉编译）', () {
    final sh = read('tools/build_linux.sh');
    expect(sh, contains('uname -s'), reason: '护栏要按 uname 判断');
    expect(sh, contains('只能在 Linux 上运行'));
  });
}
