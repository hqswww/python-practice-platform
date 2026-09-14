# 🗺️ 项目结构地图 — 编程练习册

> 一句话：**学生选题 → 写代码 → 本机判题 → 比对输出 → 对/错反馈 + 进度记录**
>
> 「本机判题」按语言分两条路：**Python** 解释执行（macOS / Windows 用捆绑解释器），
> **C / C++** 先编译再运行（用系统编译器）。
>
> 本地图帮你在源码里快速定位「某个功能在哪」。文件后面标 ⭐ 的是核心/重点。

---

## 一、顶层文件（先认识项目证件）

| 文件 | 作用 |
|------|------|
| `pubspec.yaml` ⭐ | 项目「身份证」：名字、依赖包、资源（题库 + 中文字体）都在这登记 |
| `lib/app_version.dart` ⭐ | **版本号的单一维护点**。pubspec 与安装包脚本里的副本由测试盯着不许漂 |
| `DESIGN.md` ⭐ | 设计文档：技术决策、题库格式、判题反馈、UI 动画 |
| `PROJECT_MAP.md` | 本地图 —— 想改代码先看这个 |
| `PROJECT_BACKLOG.md` | 待办清单 + 想法池（下一步要做什么） |
| `README.md` | 使用/运行/构建说明，功能一览 |
| `analysis_options.yaml` | 代码规范检查（flutter_lints）配置 |

---

## 二、源码核心 `lib/`

### 📂 `lib/models/` — 数据的「模具」（定义结构，不干活）

| 文件 | 作用 |
|------|------|
| `programming_language.dart` ⭐⭐ | **语言的单一事实来源**：id / 显示名 / 扩展名 / 是否编译型 / 运行面板标题 / 起步代码。加语言从这里开始 |
| `problem.dart` ⭐ | 题目模型。`language` 是**必填**（刻意不给默认值：漏传会静默变成 Python 题）；`sourceRequirements` 是「这题必须用上某个语法」的声明 |
| `problem_category.dart` | 分类模型：对应 `assets/problems/<语言>/01_xxx.json` 一个文件 |
| `test_scope.dart` | 测试出题范围模型：难度档位（累计的「最高允许难度」）+ 按**序号**记的大类集合 |
| `judge_result.dart` ⭐ | 判题结果模型：`JudgeStatus`（passed / wrongAnswer / runtimeError / timeout / **compileError**）+ 逐用例结果。`allPassed` = 输出全对 **且** 语法要求都满足；只想问输出时用 `outputAllPassed` |
| `test_record.dart` | 测试记录模型：一次测试的逐题作答项（带 language，历史可按语言过滤） |
| `achievement.dart` | 成就状态模型（锁定/解锁） |

### 📂 `lib/services/` — 干活的「引擎层」

**判题链路（核心）**

| 文件 | 作用 |
|------|------|
| `judge_engine.dart` ⭐⭐ | **项目心脏**：编译（仅编译型）→ 喂输入 → 比输出 → 报结果。超时会**真的杀掉进程**；环境故障与代码问题分开报 |
| `language_runtime.dart` ⭐⭐ | **「怎么把一段源码跑起来」的抽象**：`LanguageRuntime` / `PythonLanguageRuntime` / `CompiledLanguageRuntime` + 报错翻译、诊断清洗、自检。加语言时继承一次即可 |
| `python_runtime.dart` ⭐ | **找 Python 解释器**：macOS / Windows 捆绑路径、PATH 回退、`-X utf8` 加固、安装指引 |
| `c_runtime.dart` ⭐ | **找 C / C++ 编译器**：按平台给候选路径（Windows 含 w64devkit 的安装位置）、`-B` 参数、安装指引 |
| `temp_workspace.dart` ⭐ | **判题工作目录**。Windows 上刻意避开用户目录（中文用户名会让 `as`/`ld` 找不到文件） |
| `update_service.dart` | **自动检查更新**：查 GitHub Releases、比版本号、挑本平台安装包。失败静默不抛异常 |
| `url_opener.dart` | 用系统默认程序打开链接（`open`/`cmd start`/`xdg-open`，零依赖）+ URL 安全校验 |
| `mine_page.dart` | **「我的」页**（底栏第 4 个）：跨语言数据总览 + 结论 + 设置/关于入口 |
| `stats_service.dart` ⭐ | **数据聚合与结论**：collect() 干 IO、buildConclusions() 是纯函数（结论规则全靠它可测） |
| `stat_charts.dart` | 「我的」页的五张 fl_chart 图 + 数据不足时的占位 |
| `about_page.dart` | **「关于」页**：名称/版本/更新日志/检查更新/项目链接/许可证。更新日志读 `assets/CHANGELOG.md`（生成物） |
| `test_scope_resolver.dart` | **测试出题范围**：按序号挑大类 → 算哪几档难度有意义 → 按难度比例分层抽样（纯函数，好测） |
| `source_check.dart` ⭐ | **源码语法要求检查**：判题只比对输出，「用不用指针」在输出上完全看不出来 —— 这里到源码里核对（启发式，不是语义分析） |
| `runtime_installer.dart` | 一键安装编译器：找随包的 `install_mingw.ps1`、跑它、给退路（下载页/安装命令） |
| `interactive_runner.dart` ⭐ | 运行面板的进程管理：**按语言**决定编译与否，流式 I/O + 逐步喂 stdin |

**状态与数据**

| 文件 | 作用 |
|------|------|
| `progress_service.dart` | 进度存储：键是 `{前缀}{语言}_{题号}`，含旧数据迁移 |
| `language_service.dart` | 当前语言（`ValueNotifier`，顶栏切换器与各页都监听它） |
| `settings_service.dart` | 全局设置单例：主题、强调色、字号、超时、各语言的运行时路径、源码语法要求检查开关 |
| `achievement_service.dart` | 成就系统：判题通过解锁成就/称号 |
| `export_service.dart` / `import_service.dart` | 进度导出 / 导入 |
| `error_log_service.dart` | 全局错误收集 + 日志中心的数据源（环境信息含三门语言的运行时路径） |

### 📂 `lib/pages/` — 用户看得见的「界面层」

**入口 + 板块**

| 文件 | 作用 |
|------|------|
| `main.dart` ⭐ | 程序入口。首次运行先进 `setup_wizard_page`，之后是底部 NavigationBar 的四个板块 |
| `setup_wizard_page.dart` ⭐ | **首次运行向导**：欢迎 → 运行环境自检（可一键装编译器）→ 个性化 → 完成 |
| `learn_page.dart` | 「学习」板块：每题的分区教程卡片（runoob 风格） |
| `practice_page.dart` | 「练习」板块：分类网格 → 题目列表 → 做题 |
| `test_page.dart` ⭐ | 「测试」板块：随机抽题组卷 + 计时器。最大的页面 |
| `settings_page.dart` ⭐ | 设置页：主题、编辑器、**运行时自检卡片**、日志中心、数据导入导出 |

**功能页**

| 文件 | 作用 |
|------|------|
| `problem_list_page.dart` | 题目列表页（某分类下的题） |
| `editor_page.dart` | 代码编辑器页（左右分栏：题目在左、编辑器在右） |
| `wrong_book_page.dart` | 错题本：做错的题 + 「未作答」标记 + 专项重练 |
| `favorite_page.dart` | 收藏 / 待复习页 |
| `test_history_page.dart` | 测试历史 + 统计概览 + 逐题回看 |
| `achievements_page.dart` | 成就 + 称号展示 |
| `log_center_page.dart` | 日志中心：查看/导出/清空错误日志 |

**复用小组件 `pages/widgets/`**

| 文件 | 作用 |
|------|------|
| `python_code_field.dart` ⭐ | **自研编辑器**：语法高亮 + 行号，零第三方依赖 |
| `language_syntax.dart` ⭐ | 各语言的关键字/注释/字符串规则；`LanguageSyntax.of(language)` 按语言取 |
| `language_switcher.dart` | 顶栏语言切换器（只有一门语言时不可点） |
| `interactive_terminal.dart` | 运行面板 UI（Python 是交互终端；C/C++ 是编译运行） |
| `problem_panel.dart` | 题目展示面板 |
| `judge_result_panel.dart` | 判题结果面板（对/错/详细提示） |
| `runtime_status_row.dart` | 运行时自检结果那一行（「已就绪 + 实际路径」/「未找到 + 安装命令」） |
| `rich_message_text.dart` | 把提示里的 `**加粗**`、`` `代码` `` 渲染出来（面板是普通 Text，不解析 Markdown） |
| `accent_color_picker.dart` | 主题色板（设置页与向导共用） |
| `responsive.dart` ⭐ | **响应式布局**：断点（`Breakpoints.twoPane`=840）+ 自适应左右分栏 + 内容最大宽度 |

### 📂 `lib/data/`

| 文件 | 作用 |
|------|------|
| `problem_repository.dart` ⭐ | 题库仓库：从 `assets/problems/<语言>/*.json` 加载，分类表 `_categoryMeta` **按语言分组**（登记漏了分类表，那门语言就会少一块，且不会报错） |

---

## 三、题库 `assets/`

### `assets/problems/<语言>/` — 每门语言 12 个分类、72 道题

**按语言分目录**：`python/`、`c/`、`cpp/`。加语言时新建目录、在 `pubspec.yaml`
登记（**Flutter 的资源声明不递归**）、再在 `problem_repository.dart` 的分类表里补一份。
编写规格见 `tools/BANK_SPEC.md`（含**出题禁区**：文件读写、打印地址、时间随机都不出）。

```
<语言>/01_xxx.json … 12_challenges.json   各 6 题，共 72 题
```

| 语言 | 12 个分类 |
|------|-----------|
| `python/` | 基础语法 / 数据类型 / 运算符 / 条件判断 / 循环 / 字符串 / 列表 / 元组与集合 / 字典 / 函数 / 进阶 / 综合挑战 |
| `c/` | 基础语法 / 数据类型与变量 / 运算符 / 判断与分支 / 循环 / 函数与作用域 / 数组 / 字符串 / 指针 / 结构体与共用体 / 进阶 / 综合挑战 |
| `cpp/` | 基础语法 / 变量与数据类型 / 运算符 / 判断与分支 / 循环 / 函数与重载 / 数组与字符串 / 指针与引用 / 类与对象 / 继承与多态 / 模板与 STL / 综合挑战 |

**id 段按分类序号走**（`NN*100+1..6`），三门语言各自独立 —— 进度键是「语言_题号」，
撞号会让两道题共享进度。

**每题 JSON 格式：** `id / title / difficulty / description / input_format / output_format / sample_input / sample_output / test_cases[] / hints[] / solution / tutorial[]`

### `assets/fonts/`
- `SarasaGothicSC-Regular.ttf` / `SarasaGothicSC-Bold.ttf` — 中文字体（在 pubspec.yaml 注册）

---

## 四、其他目录

| 目录 | 作用 |
|------|------|
| `test/` | Flutter 自动测试（判题链路、语言维度、响应式、题库结构守卫、深浅主题对比度等） |
| `tools/` | 题库校验（`verify_bank.py`）、图标生成（`make_icons.py`）、三平台打包脚本、`install_mingw.ps1`、`windows_installer.iss`、`inno/`（安装包中文语言包） |
| `LICENSE` / `assets/CHANGELOG.md` | MIT 许可证 / 更新日志（生成物）。两个都打包进应用，「关于」页用 |
| `docs/` | `WINDOWS_MIGRATION.md` / `MACOS_MIGRATION.md` / `LINUX_MIGRATION.md`；`releases/` 里是每次发布的 Release 正文（＝应用更新弹窗里的「更新内容」） |
| `windows/` `macos/` `linux/` | Flutter 三平台构建配置 |
| `dist/` | 打包产物（dmg / zip / Setup.exe / tar.gz） |
| `build/` | 编译中间产物（不用管，gitignore） |

---

## 🎨 主题

`lib/theme.dart` 是**唯一的主题定义处**（`buildAppTheme`），`main.dart` 只是调用它。
单独一个文件是为了测试能拿到界面真正在用的那份主题 ——
`test/theme_contrast_test.dart` 靠它做深浅两套主题的可读性断言。

颜色规矩见 DESIGN.md「主题与颜色的规矩」：次级文字用 `onSurfaceVariant`、
自带宽底色的输入框写 `filled: false`、衬底用 `onSurface.withValues(alpha:)`。

## 🎯 一条主线串起来（怎么找代码）

```
想知道题目长啥样？        → assets/problems/<语言>/01_xxx.json + lib/models/problem.dart
想知道怎么判对错？        → lib/services/judge_engine.dart      ← 心脏！
想知道某门语言怎么跑？    → lib/services/language_runtime.dart  ← 语言差异都收在这
想知道「用了没用上指针」怎么判？→ lib/services/source_check.dart（判题只比输出时分不出，得看源码）
想让应用提示新版本？      → lib/services/update_service.dart（只跳转下载，不自动安装）
想知道编译器/解释器怎么找？→ python_runtime.dart / c_runtime.dart
判题临时目录放哪？        → lib/services/temp_workspace.dart（Windows 中文路径的防御在这）
想知道界面在哪儿？        → lib/pages/*.dart（按板块找）
想加一门新语言？          → models/programming_language.dart 起手，五处落点见 DESIGN.md
想知道进度怎么存？        → lib/services/progress_service.dart（键带语言）
想改窗口拉伸时的布局？    → lib/pages/widgets/responsive.dart（断点 + 自适应分栏）
想改顶栏语言切换？        → lib/pages/widgets/language_switcher.dart + language_service.dart

Windows 要打包？          → tools/build_windows.ps1 + docs/WINDOWS_MIGRATION.md
macOS 要打包？            → tools/setup_macos_platform.sh → tools/build_macos.sh
                            + docs/MACOS_MIGRATION.md（App Sandbox 坑必看！）
Linux 要打包？            → tools/build_linux.sh + docs/LINUX_MIGRATION.md
题库要校验？              → python3 tools/verify_bank.py --lang <c|cpp>
出题规则全忘了？          → tools/BANK_SPEC.md
架构决策全忘了？          → 回看 DESIGN.md
```

---

*本地图由沙姬酱（电子猫娘管家）整理，2026-08-10，2026-09 随三语言与安装包更新。*
