# 🗺️ 项目结构地图 — 编程练习册

> 一句话：**学生选题 → 写代码 → 内置 Python 判题 → 比对输出 → 对/错反馈 + 进度记录**
>
> 本地图帮你在源码里快速定位「某个功能在哪」。文件后面标 ⭐ 的是核心/重点。

---

## 一、顶层文件（先认识项目证件）

| 文件 | 作用 |
|------|------|
| `pubspec.yaml` ⭐ | 项目「身份证」：名字、依赖包、资源（题库 + 中文字体）都在这登记 |
| `DESIGN.md` ⭐ | **整个项目的设计文档**：技术决策、题库格式、判题反馈、UI 动画全记录 |
| `README.md` | 使用/运行/构建说明，功能一览 |
| `PROJECT_BACKLOG.md` | 待办清单 + 想法池（下一步要做什么） |
| `analysis_options.yaml` | 代码规范检查（flutter_lints）配置 |

---

## 二、源码核心 `lib/`（三大块）

### 📂 `lib/models/` — 数据的「模具」（定义结构，不干活）

| 文件 | 作用 |
|------|------|
| `problem.dart` ⭐ | **题目模型**：id/标题/难度/描述/输入输出格式/测试用例/提示。对应 JSON 里一道题 |
| `problem_category.dart` | 分类模型：对应 `assets/problems/01_syntax.json` 一个文件 |
| `judge_result.dart` ⭐ | 判题结果模型：`JudgeStatus` 状态枚举（passed/wrongAnswer/runtimeError/timeout）+ 每个用例结果 |
| `test_record.dart` | 测试记录模型：一次测试的逐题作答项（用于历史回看） |
| `achievement.dart` | 成就状态模型（锁定/解锁） |

### 📂 `lib/services/` — 干活的「引擎层」（核心逻辑）

| 文件 | 作用 |
|------|------|
| `judge_engine.dart` ⭐⭐ | **项目心脏！判题引擎**：写代码→跑 Python→喂输入→比输出→报结果。带友好错误提示 + EOFError 自适应重试 |
| `python_runtime.dart` ⭐ | **找 Python 解释器**（Linux 用 python3 / Windows 用捆绑 exe）+ UTF-8 加固。Windows 迁移关键 |
| `interactive_runner.dart` ⭐ | 交互式 Python 终端运行器：常驻进程 + 流式 I/O，模拟真实 REPL |
| `progress_service.dart` | 进度存储（shared_preferences）：做对自动标记、持久化 |
| `settings_service.dart` | 全局设置单例：主题明暗/强调色/判题超时等 |
| `achievement_service.dart` | 成就系统：判题通过解锁成就/称号 |
| `export_service.dart` | 进度导出（JSON/CSV 写入文档目录） |
| `import_service.dart` | 进度导入（读回 JSON） |

### 📂 `lib/pages/` — 用户看得见的「界面层」

**入口 + 三大板块：**
| 文件 | 作用 |
|------|------|
| `main.dart` ⭐ | 程序入口：加载设置→启动。底部 NavigationBar 组织三大板块 |

**三大主板块：**
| 文件 | 作用 |
|------|------|
| `learn_page.dart` | 「学习」板块：72 题全覆盖的分区教程卡片（runoob 风格） |
| `practice_page.dart` | 「练习」板块：分类网格→题目列表→做题 |
| `test_page.dart` ⭐ | 「测试」板块：随机抽题组卷 + 计时器，1248 行，最大的页面 |

**功能页：**
| 文件 | 作用 |
|------|------|
| `problem_list_page.dart` | 题目列表页（某分类下的题） |
| `editor_page.dart` | 代码编辑器页（左右分栏：题目在左、编辑器在右） |
| `wrong_book_page.dart` | 错题本：做错的题 + 「未作答」标记 + 专项重练 |
| `favorite_page.dart` | 收藏/待复习页 |
| `test_history_page.dart` | 测试历史 + 统计概览 + 逐题回看 |
| `settings_page.dart` | 设置页：主题/超时/进度统计/清除进度 |
| `achievements_page.dart` | 成就 + 称号展示 |

**复用小组件 `pages/widgets/`：**
| 文件 | 作用 |
|------|------|
| `python_code_field.dart` ⭐ | **自研编辑器**：语法高亮 + 行号，零第三方依赖 |
| `interactive_terminal.dart` | 交互式终端 UI（配 interactive_runner 用） |
| `problem_panel.dart` | 题目展示面板 |
| `judge_result_panel.dart` | 判题结果面板（对/错/详细提示） |
| `responsive.dart` ⭐ | **响应式布局**：窗口宽度断点（`Breakpoints.twoPane`=840）+ 自适应左右分栏组件。窗口拉伸时 UI 跟着变 |

### 📂 `lib/data/`
| 文件 | 作用 |
|------|------|
| `problem_repository.dart` ⭐ | 题库仓库：从 `assets/problems/*.json` 加载题目，按分类组织 |

---

## 三、题库 `assets/`

### `assets/problems/<语言>/` — 每门语言 72 道题，12 个分类 JSON

**按语言分目录**（`python/`、`c/`）。加语言时新建目录并在 `pubspec.yaml` 登记，
再在 `lib/data/problem_repository.dart` 的分类表里补一份。编写规格见 `tools/C_BANK_SPEC.md`。
```
01_syntax.json      基础语法(缩进/注释/print/变量)
02_datatype.json    数据类型与转换
03_operators.json   运算符
04_conditionals.json 条件 if/elif/else
05_loops.json       循环 for/while
06_strings.json     字符串
07_lists.json       列表
08_tuples_sets.json 元组+集合
09_dicts.json       字典
10_functions.json   函数
11_advanced.json    进阶(迭代器/生成器/异常)
12_challenges.json  综合挑战
```
**每题 JSON 格式：** `id / title / difficulty / description / input_format / output_format / sample_input / sample_output / test_cases[] / hints[]`

### `assets/fonts/`
- `SarasaGothicSC-Regular.ttf` / `SarasaGothicSC-Bold.ttf` — 中文字体（在 pubspec.yaml 注册）

---

## 四、其他目录

| 目录 | 作用 |
|------|------|
| `test/` | Flutter 自动测试（判题引擎、进度、响应式布局等 63 项） |
| `tools/` | 教程批量脚本、打包脚本（`build_windows.ps1` / `build_macos.sh` / `setup_macos_platform.sh`） |
| `docs/` | 文档：`WINDOWS_MIGRATION.md`、`MACOS_MIGRATION.md` 迁移手册 |
| `linux/` `windows/` | Flutter 平台构建配置 |
| `macos/` | Flutter macOS 构建配置（**需先跑 `tools/setup_macos_platform.sh` 生成**） |
| `build/` | 编译产物（不用管，gitignore） |

---

## 🎯 一条主线串起来（怎么找代码）

```
想知道题目长啥样？        → assets/problems/01_syntax.json  +  lib/models/problem.dart
想知道怎么判对错？        → lib/services/judge_engine.dart ← 心脏！
想知道界面在哪儿？        → lib/pages/*.dart（按三大板块找）
想知道进度怎么存？        → lib/services/progress_service.dart
想加新功能/改界面？       → 先看 lib/pages/，再找对应 service/model
想解释器怎么找？          → lib/services/python_runtime.dart（Win/macOS 捆绑逻辑都在这）
想改窗口拉伸时的布局？    → lib/pages/widgets/responsive.dart（断点 + 自适应分栏）

Windows 要打包？          → tools/build_windows.ps1 + docs/WINDOWS_MIGRATION.md
macOS 要打包？            → tools/setup_macos_platform.sh → tools/build_macos.sh
                            + docs/MACOS_MIGRATION.md（App Sandbox 坑必看！）
规则全忘了？              → 回看 DESIGN.md（项目圣经）
```

---

*本地图由沙姬酱（电子猫娘管家）整理，2026-08-10。*
