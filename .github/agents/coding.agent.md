---
name: coding
description: 在「编程练习册」仓库里改代码 —— 动手前先读这里的约定，尤其是几条「绝不能改」的规矩。
argument-hint: 要做的改动，或要回答的问题。
---

# 编程练习册 · 编码约定

面向初学者的**本地判题**刷题应用：Flutter 桌面端，三门语言（Python / C / C++），
分发到 Windows / macOS / Linux。判题全部在本机完成、不联网。

**动手前先读**：`PROJECT_MAP.md`（代码在哪）、`README.md`（功能与构建）、
`PROJECT_BACKLOG.md`（已知问题与踩过的坑）。

---

## 🔴 绝不能改（改了会伤到用户数据）

| 标识 | 为什么 |
|------|--------|
| macOS `PRODUCT_BUNDLE_IDENTIFIER = com.sakiri.python-practice` | 它是 `~/Library/Preferences/<id>.plist` 与用户进度存储的**定位键**。改了，老用户的进度不是丢了而是**找不到**了 |
| Dart 包名 `python_practice` | 21 个文件 import 它；改包名要同步改所有 import 与平台脚手架，收益为零 |
| Inno Setup 的 `AppId` GUID | Inno 用它识别「是不是同一个应用」：升级安装、卸载、控制面板条目都认它。改了等于变成另一个软件 |
| 题库文件的分类 key 与 id 段 | 进度键是「语言_题号」，撞号会让两道题共享进度，而且**不会报错** |
| Windows `Runner.rc` 的 `CompanyName` / `ProductName` | Windows 版**用户进度的定位键**：`shared_preferences` 的落盘路径就是从这两项拼出来的，改了老用户会「找不到自己的进度」 |
| `LICENSE` 的署名 / `assets/CHANGELOG.md` | 前者跟着每个安装包发出去、GitHub 也认它；后者是 `docs/releases/` 的生成物，**手改会被一致性问题覆盖**（改 `docs/releases/` 再跑生成脚本） |
| Windows `.ps1` 的 UTF-8 BOM | Windows PowerShell 5.1 读无 BOM 的脚本按 ANSI 解码，中文全成乱码甚至语法报错 |

以上几条都有测试盯着（`test/platform_identity_test.dart`、`test/version_consistency_test.dart` 等），
不要绕过它们。

---

## 约定

- **一切面向中文**：注释、文档、提交信息、界面文案都用中文
- **提交信息**写清「改了什么 + 为什么」（尤其是根因），不要只写「修复 bug」
- **改完必须过闸门**：`flutter test` 全过 + `flutter analyze` 无新增问题 + build 成功
- **推送前先让用户确认**（远端是公开仓库，推送即公开且不易撤回）
- **别把「没验证过」说成「验证过」**：本机（macOS）跑不了的东西 ——
  Windows 安装包、Linux 打包、MSVC 的 `rc.exe` 行为 —— 要明确标注「未实测」
- **测试要有牙**：写完回归测试后，把实现临时改回坏的样子，确认测试**真的会失败**；
  只会通过的测试等于没写

## 这个项目踩过的坑（改相关代码前务必看）

- **Windows 用户名可能是中文**（本项目的开发机路径就是 `C:\Users\笑\...`）。
  凡涉及路径一律在代码里防御，**不能靠「让用户挪到英文路径」解决**：
  判题工作目录已改走纯 ASCII（`lib/services/temp_workspace.dart`），
  Windows 编译参数加 `-B <编译器目录>` 让 gcc 找得到 `as`/`ld`。
- **`sh scripts.sh` 会失败**：macOS 的 `/bin/sh` 是 bash 的 POSIX 模式（进程替换直接语法报错），
  Linux 的常是 dash（`[[ ]]` 变成 command not found）。所有脚本都带
  「用真正的 bash 重跑自己」的守卫 —— 注意**不能**用 `BASH_VERSION` 判断。
- **签名之后别往应用包里加文件**：捆绑 Python 写 `__pycache__` 就会让签名失效。
- **编码陷阱**：PowerShell 要 BOM、`ditto` 写 zip 不设 UTF-8 标志位、
  Dart 的 `RegExp` 不支持内联 `(?m)`（.NET 支持，两个引擎不一样）。

完整清单见 `PROJECT_BACKLOG.md` 的「踩过的坑」一节。
