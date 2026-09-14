/// 应用版本号（**单一维护点**）
///
/// 版本号原先散在四个地方 —— pubspec.yaml、设置页「关于」、错误日志头、
/// 以及 Windows 安装包脚本 —— 改一次要记得改四处，漏掉哪处都会让用户看到
/// 前后矛盾的版本号（「关于」里写着 V1.2，日志里却是别的）。
///
/// 现在 Dart 侧只认这一个常量；pubspec 与安装包脚本那两份由
/// `test/version_consistency_test.dart` 盯着不许漂。
///
/// ⚠️ 发新版时要一起改的四处（测试会告诉你漏了哪个）：
///   1. 这里
///   2. `pubspec.yaml` 的 `version:`（形如 `1.5.2+7`，`+` 后面是构建号）
///   3. `tools/windows_installer.iss` 的 `#define AppVersion`
///   4. `README.md` 的「版本」段（写给用户看的变更摘要）
library;

/// 语义化版本，形如 `1.3.0`。**不带 `v` 前缀**，展示时自己加。
const String appVersion = '1.5.2';
