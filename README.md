# 🐍 编程练习册

一个面向初学者的**本地自习 + 刷题** Flutter 桌面应用（Linux / Windows / macOS）。

支持 **Python / C / C++** 三门语言（顶栏切换），各 12 个分类、72 道题，共 216 道。

> 现状：三平台打包链路均已就位（`build_windows.ps1` / `build_linux.sh` / `build_macos.sh`）。
> 判题**全部走本机环境**，不联网：
> - Python —— macOS / Windows 用应用内捆绑的解释器（免装）；Linux 用系统的 `python3`
> - C / C++ —— 三平台都用**系统编译器**（clang / gcc / MinGW），不捆进应用
>
> 缺什么不用猜：设置页「代码编辑 → 编译器/解释器」会做自检，直接告诉用户装什么、怎么装。

---

## ✨ 功能

- **多语言**：Python / C / C++ 各自独立的题库、进度、成就；顶栏一键切换
- **每门语言 72 道题**，12 个分类，难度 easy/medium/hard 三级
  - Python：基础语法 → 数据类型 → 运算符 → 条件 → 循环 → 字符串 → 列表 → 元组集合 → 字典 → 函数 → 进阶 → 综合挑战
  - C：基础语法 → 数据类型与变量 → 运算符 → 判断与分支 → 循环 → 函数与作用域 → 数组 → 字符串 → 指针 → 结构体与共用体 → 进阶 → 综合挑战
  - C++：基础语法 → 变量与数据类型 → 运算符 → 判断与分支 → 循环 → 函数与重载 → 数组与字符串 → 指针与引用 → 类与对象 → 继承与多态 → 模板与 STL → 综合挑战
- **判题引擎**：Python 解释执行；C / C++ 走系统编译器、编译一次复用产物；
  支持运行面板（Python 是交互终端，编译型语言是编译运行）
- **环境自检**：设置页直接显示每种语言的运行时是否就绪、实际用的是哪个路径；
  缺编译器时给出对应平台的具体安装命令，而不是等判题时才报一句「环境有问题」
- **判题输入自适应**：`input()` 单行/多行写法自适应，答案对上就算对
- **学习页详细教程**：每题都有 runoob 风格的分区卡片讲解
- **成就与称号系统**：13 个成就 + 6 级称号，判题通过解锁弹窗
- **自定义主题强调色**：6 套色板，即时换肤，保留明暗模式
- **错题本 + 收藏 + 测试模式 + 进度统计 + 导出**
- **响应式界面**：窗口拉伸时布局跟着变——设置页宽屏是「左分类 + 右详情」两栏，窄屏自动变单列点进详情；练习页分类网格按宽度自适应列数

## 🚀 运行 / 构建

```bash
# 开发运行
flutter run -d linux      # 或 -d windows / -d macos

# Linux 发布（需在 Linux 上跑；产物是绿色版 tar.gz，不捆绑运行时）
bash tools/build_linux.sh

# Windows 发布（需 Windows 机器 + Flutter + VS2022 C++ 工作负载）
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1

# macOS 发布（需 macOS 机器 + Flutter + CocoaPods）
bash tools/setup_macos_platform.sh   # 首次：生成 macos/ 脚手架 + 关闭 App Sandbox
bash tools/build_macos.sh            # 打包：捆绑 Python + 签名 + 出 zip
```

> 三平台**不能交叉编译**（各自走原生工具链），打包脚本里有平台护栏会直接拦下来。
>
> 判题需要本机有运行时。Linux 桌面发行版自带 `python3`，但 `gcc`/`g++` 要自己装
> （`sudo apt install build-essential`）；Windows 要装 MinGW-w64。
> 应用会在设置页提前告知，见 `docs/LINUX_MIGRATION.md` / `docs/WINDOWS_MIGRATION.md`。

## 📂 项目结构

- `lib/` — Flutter 源码（models / services / pages / widgets）
- `assets/problems/` — 题库 JSON，按语言分目录（`python/` `c/` `cpp/`），各 72 道
- `tools/` — 题库批量脚本与校验（`verify_bank.py`）、图标生成（`make_icons.py`）、
  三平台打包脚本（`build_linux.sh` / `build_windows.ps1` / `build_macos.sh`）
- `docs/LINUX_MIGRATION.md` — Linux 迁移手册（为什么用系统环境、`.desktop` 与图标）
- `docs/WINDOWS_MIGRATION.md` — Windows 迁移手册
- `docs/MACOS_MIGRATION.md` — macOS 迁移手册（含 App Sandbox 坑与公证流程）
- `tools/BANK_SPEC.md` — 题库编写规格（分类、id 段、出题禁区）
- `PROJECT_BACKLOG.md` — 待办 / 想法池

## 🔖 版本

- v1.0-final — 正式版（P1-P3 全 + Windows 迁移）
- v0.6-tutorials-all — 72 题教程铺完

> 三平台打包链路均已就位。macOS 的 `macos/` 脚手架若需重建，
> 先跑 `bash tools/setup_macos_platform.sh`（依赖 Flutter SDK + CocoaPods）。

详细设计见 [DESIGN.md](DESIGN.md)、待办见 [PROJECT_BACKLOG.md](PROJECT_BACKLOG.md)。
