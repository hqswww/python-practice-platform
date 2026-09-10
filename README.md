# 🐍 Python 练习平台

一个面向 Python 初学者的**本地自习 + 刷题** Flutter 桌面应用（Linux / Windows / macOS）。

> 现状：**v1.0-final** — P1/P2/P3 全部完成，Windows 绿色版 .exe（免装 Python）已可分发。
> macOS 适配进行中：脚手架脚本、捆绑 Python 打包脚本与迁移手册已就位（见 `docs/MACOS_MIGRATION.md`）。

---

## ✨ 功能

- **72 道题**，12 个分类（基础语法 → 数据类型 → 运算符 → 条件 → 循环 → 字符串 → 列表 → 元组集合 → 字典 → 函数 → 进阶 → 综合挑战），难度 easy/medium/hard 三级
- **判题引擎**：内置 Python 实时运行，比对输出；支持交互终端（A主B辅）
- **判题输入自适应**：`input()` 单行/多行写法自适应，答案对上就算对
- **学习页详细教程**：72 题全覆盖，runoob 风格分区卡片讲解
- **成就与称号系统**：13 个成就 + 6 级称号，判题通过解锁弹窗
- **自定义主题强调色**：6 套色板，即时换肤，保留明暗模式
- **错题本 + 收藏 + 测试模式 + 进度统计 + 导出**
- **响应式界面**：窗口拉伸时布局跟着变——设置页宽屏是「左分类 + 右详情」两栏，窄屏自动变单列点进详情；练习页分类网格按宽度自适应列数

## 🚀 运行 / 构建

```bash
# Linux 开发
flutter run -d linux

# Windows 发布（需 Windows 机器 + Flutter + VS2022 C++ 工作负载）
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1

# macOS 发布（需 macOS 机器 + Flutter + CocoaPods）
bash tools/setup_macos_platform.sh   # 首次：生成 macos/ 脚手架 + 关闭 App Sandbox
bash tools/build_macos.sh            # 打包：捆绑 Python + 签名 + 出 zip
```

## 📂 项目结构

- `lib/` — Flutter 源码（models / services / pages / widgets）
- `assets/problems/` — 72 道题题库 JSON
- `tools/` — 教程批量脚本、Windows / macOS 打包脚本
- `docs/WINDOWS_MIGRATION.md` — Windows 迁移手册
- `docs/MACOS_MIGRATION.md` — macOS 迁移手册（含 App Sandbox 坑与公证流程）
- `PROJECT_BACKLOG.md` — 待办 / 想法池

## 🔖 版本

- v1.0-final — 正式版（P1-P3 全 + Windows 迁移）
- v0.6-tutorials-all — 72 题教程铺完

> macOS：打包链路已备好，但 `macos/` 脚手架需先跑
> `bash tools/setup_macos_platform.sh` 生成（依赖 Flutter SDK + CocoaPods）。

详细设计见 [DESIGN.md](DESIGN.md)、待办见 [PROJECT_BACKLOG.md](PROJECT_BACKLOG.md)。
