# 📘 编程练习册

一个面向初学者的**本地自习 + 刷题** Flutter 桌面应用（Windows / macOS / Linux）。

支持 **Python / C / C++** 三门语言（顶栏切换），各 12 个分类、72 道题，共 216 道。

> **判题全部在本机完成，不联网、不用注册。**
>
> - Python —— macOS / Windows 用应用内捆绑的解释器（免装）；Linux 用系统的 `python3`
> - C / C++ —— 三平台都走**系统编译器**（clang / gcc / MinGW），不捆进应用
>
> 缺什么不用猜：**首次运行向导**和设置页「代码编辑」都会做自检，
> 直接告诉用户装什么、怎么装；Windows 上还能在向导里一键装编译器。

---

## ✨ 功能

### 三门语言，各自独立

- **Python / C / C++ 是两个独立科目**（不是合并的「C/C++」）：
  题库、进度、错题、收藏、测试历史、成就**按语言分开统计**，顶栏一键切换
- 每门语言 72 道题、12 个分类，难度 easy / medium / hard 三级
  - **Python**：基础语法 → 数据类型 → 运算符 → 条件 → 循环 → 字符串 → 列表 → 元组集合 → 字典 → 函数 → 进阶 → 综合挑战
  - **C**：基础语法 → 数据类型与变量 → 运算符 → 判断与分支 → 循环 → 函数与作用域 → 数组 → 字符串 → 指针 → 结构体与共用体 → 进阶 → 综合挑战
  - **C++**：基础语法 → 变量与数据类型 → 运算符 → 判断与分支 → 循环 → 函数与重载 → 数组与字符串 → 指针与引用 → 类与对象 → 继承与多态 → 模板与 STL → 综合挑战

### 判题

- **解释执行 / 编译运行各按语言来**：Python 是「交互终端」，C / C++ 是「编译运行」
  （先编译、编译一次复用到所有用例）
- **运行面板能逐步喂输入**：程序读到输入时停下来，用户敲一行回车喂一行 ——
  学生能亲眼看到多个 `input()` / `scanf` 各读走了哪一行
- **友好的错误提示**：判题失败时按语言给可操作的方向（段错误查数组越界、
  整数除以 0、编译器报错翻译、环境缺件与代码问题分开说），而不是甩一句「运行错误」
- **判题输入自适应**：`input()` 单行/多行写法自适应，答案对上就算对
- **语法要求检查**：指针/引用题光比输出分不出有没有用对语法
  （`printf("%d\n%d", n, b)` 和 `printf("%d\n%d", n, *p)` 输出一模一样），
  所以这 12 道题会额外核对源码里到底用没用上指针 —— 学生看到的是
  「输出对了，但没按要求用上语法」和具体改法，而不是莫名其妙判过。
  设置页可关（万一误判还有退路）

### 学习与激励

- **每题都有教程**：runoob 风格的分区卡片讲解，边学边练
- **成就与称号系统**：13 个成就 + 6 级称号，判题通过解锁弹窗
- **错题本 + 收藏 + 测试模式 + 进度统计 + 导出**
- **测试能限定出题范围**：四种测试模式（快速 / 标准 / 强化 / 全题库）**各自**设定
  从哪些大类出题、出到哪个难度（绿=简单、绿黄=中等、绿黄红=困难；
  范围内没有困难题时「难度三」自动不可选）。抽题按题库的难度比例分层抽样，
  每次卷子的难度结构都稳定，不会一次全是难题

### 工程

- **自动检查更新**：启动时静默问一次 GitHub Releases，有新版本才弹窗 ——
  弹窗里写清「当前版本 → 最新版本」和更新内容，点「去下载」直接跳到对应平台的
  安装包。不想要可以在「设置 → 关于」关掉，也能只跳过某一个版本。
  **只跳转下载，不自动替换程序**：自动安装要在三个平台各写一套提权/替换逻辑，
  而「下载安装包 → 双击」是用户本来就熟的路径，覆盖安装也不会丢进度
- **环境自检**：首次运行向导 + 设置页两张卡，显示每种语言的运行时是否就绪、
  **实际用的是哪个路径**；缺什么就给出对应平台的具体安装命令
- **响应式界面**：设置页宽屏是「左分类 + 右详情」两栏，窄屏自动变单列点进详情；
  练习页分类网格按宽度自适应列数
- **自定义主题强调色**：6 套色板，即时换肤，保留明暗模式

## 🚀 运行 / 构建

```bash
# 开发运行
flutter run -d linux      # 或 -d windows / -d macos

# Windows 发布（需 Windows 机器 + Flutter + VS2022 C++ 工作负载）
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
#   → dist\编程练习册\            绿色版目录（解压即用）
#   → dist\编程练习册-Setup.exe    安装包（免管理员；需 Inno Setup 6.5+）

# macOS 发布（需 macOS 机器 + Flutter + CocoaPods）
bash tools/setup_macos_platform.sh   # 首次：生成 macos/ 脚手架 + 关闭 App Sandbox
bash tools/build_macos.sh            # 打包：捆绑 Python + 签名 + 出 dmg/zip
#   → dist/编程练习册-macOS-universal.dmg   安装包（拖进 Applications）
#   → dist/编程练习册-macOS-universal.zip   绿色版

# Linux 发布（需在 Linux 上跑；绿色版 tar.gz，不捆绑运行时）
bash tools/build_linux.sh
```

> **关于安装包**：能省掉「解压到哪、怎么建快捷方式」这些麻烦，但**不解决**
> 「系统信任」问题 —— 没买签名证书的话，macOS 会提示「来自身份不明的开发者」、
> Windows 会弹 SmartScreen，用户要手动放行一次。dmg 里附了说明文件讲这一步。

> 三平台**不能交叉编译**（各自走原生工具链），打包脚本里有平台护栏会直接拦下来。
>
> 使用者机器上的运行时要求：Linux 桌面发行版自带 `python3`，但 `gcc`/`g++` 要自己装
> （`sudo apt install build-essential`）；Windows 要装 MinGW-w64（向导里可一键装）；
> macOS 要 `xcode-select --install`。详见 `docs/` 下各平台迁移手册。

## 📂 项目结构

- `lib/` — Flutter 源码（models / services / pages / widgets）
- `assets/problems/` — 题库 JSON，按语言分目录（`python/` `c/` `cpp/`），各 72 道
- `tools/` — 题库校验（`verify_bank.py`）、图标生成（`make_icons.py`）、
  三平台打包脚本（`build_windows.ps1` / `build_macos.sh` / `build_linux.sh`）、
  Windows 安装包脚本（`windows_installer.iss`）、C/C++ 编译器一键安装（`install_mingw.ps1`）
- `docs/WINDOWS_MIGRATION.md` — Windows 手册（含中文路径、PowerShell 编码等坑）
- `docs/MACOS_MIGRATION.md` — macOS 手册（App Sandbox、签名、公证、dmg）
- `docs/LINUX_MIGRATION.md` — Linux 手册（为什么用系统环境、`.desktop` 与图标）
- `tools/BANK_SPEC.md` — 题库编写规格（分类、id 段、出题禁区）
- `docs/releases/` — 每次发布的 Release 正文（也就是应用更新弹窗里显示的「更新内容」）
- [PROJECT_MAP.md](PROJECT_MAP.md) — 项目结构地图（想改代码先看这个）
- [DESIGN.md](DESIGN.md) — 设计文档
- [PROJECT_BACKLOG.md](PROJECT_BACKLOG.md) — 待办 / 想法池

## 🔖 版本

- **v1.5.1** — 测试可限定出题范围（每种模式各自设大类与难度档）；修「测试题池
  没按语言过滤」（原来一道 Python 测试里会混进 C/C++ 的题）
- v1.5.0 — 自动检查更新：启动时查 GitHub Releases，有新版弹窗显示更新内容，
  一键跳到对应平台的安装包（`设置 → 关于` 可关，也可只跳过某个版本）
- v1.4.0 — 源码语法要求检查：指针题不再能靠「输出一样」蒙混过关
  （新增 `设置 → 判题 → 源码语法要求检查` 开关）；深浅主题下的文字可读性修复
  （深色模式判题结果为黑字、浅色模式终端输入框白字隐形）
- v1.3.0 — 安装包分发（Windows `Setup.exe` / macOS `dmg`）、首次运行向导、
  C++ 接入、Windows 中文路径防御、判题提示改进
- v1.0-final — 正式版（P1-P3 全 + Windows 迁移）
- v0.6-tutorials-all — 72 题教程铺完

> 版本号的**单一维护点**是 `lib/app_version.dart`；`pubspec.yaml` 与
> `tools/windows_installer.iss` 里各有一份副本，由测试盯着不许漂。
