# 📋 项目 Backlog（待办 / 想法池）

> 维护方式：Sakiri 想到什么就丢进来，我（Sakiri-chan）记录、排期。
> 状态：`⬜ 待办` · `🔨 进行中` · `✅ 已完成` · `🔇 搁置`
> 里程碑用 tag 归档（如 `v1.0-final`）。

---

## 🎯 当前版本状态

**v1.5.1** —— 版本号单一维护点在 `lib/app_version.dart`（pubspec 与安装包脚本里的
副本由测试盯着，改一处漏一处会测试失败）。

本版相比 v1.5.0 的主要变化：

| 方向 | 内容 |
|------|------|
| 测试 | **可限定出题范围**：四种模式各自设「从哪些大类出题」+「出到哪个难度」（绿/绿黄/绿黄红） |
| 测试 | 抽题改成**按难度比例分层抽样**，每次卷子的难度结构稳定 |
| 修复 | 测试题池**没按语言过滤** —— 「全题库」显示 216 题，一次 Python 测验里会混进 C/C++ 的题 |

v1.5.0 与更早的内容见下方归档。

---

**v1.5.0**（已发布）—— 版本号单一维护点在 `lib/app_version.dart`（pubspec 与安装包脚本里的
副本由测试盯着，改一处漏一处会测试失败）。

本版相比 v1.4.0 的主要变化：

| 方向 | 内容 |
|------|------|
| 更新 | **自动检查更新**：启动时查 GitHub Releases，有新版弹窗显示更新内容，一键跳到本平台安装包 |
| 设置 | `关于 → 检查更新`：开关（默认开）+「立即检查更新」；可只跳过某一个版本 |

v1.4.0 与更早的内容见下方归档。

---

## 🐛 已知问题 / 待修

### ⬜ 源码语法要求检查是启发式的
- **现状**：`source_check.dart` 靠关键字级文本分析，能挡「压根没用指针」
  「声明了却不用」「只取一个元素就改用数组下标」，**挡不住蓄意伪装**
- **已知盲区**：小写自定义类型名认不出来（`mytype *p` 不算指针声明）——
  宁可漏认也不能把 `a * b` 误认成声明
- **彻底解法**：题目改成「只写函数」，判题注入自己的 `main` 去调它。
  签名不对就编不过，根本不需要启发式。代价是题面模型重构（见 DESIGN.md 十·补二）
- **优先级**：低（现有覆盖已经堵住了实际发生的漏洞）


### ⬜ 两个平台的「实测缺口」
这几处**代码写好了但没人真跑过**，属于发布前该补的验证：

- [ ] **Windows 安装包**：Inno Setup 只能在 Windows 上跑，`.iss` 是静态核对过的
- [x] **Linux 打包**：已在真 Linux 上跑过一次（2026-09），当场发现并修掉了产物路径 bug
      （见下方「踩过的坑 · 构建脚本」）。**改完还没复跑** —— 下次在 Linux 上
      跑一遍 `bash tools/build_linux.sh` 确认到底，顺便看 tarball 能不能解压即用
- [ ] **exe 属性页中文**：右键 `code_workbook.exe` → 属性 → 详细信息，
      「文件说明/产品名称」应显示「编程练习册」而不是问号
      （`llvm-rc` 编译验证通过，但 MSVC 的 `rc.exe` 行为可能不同）
- [ ] **macOS arm64**：universal 包里两份 Python，需要一台 Apple Silicon 机器确认选对了

---

## 💡 待办（按价值排）

### 收尾类
- [ ] 窗口尺寸记忆（重启保留用户拉的大小）
- [ ] `test_page` 的做题界面（题目 + 编辑器）宽屏下仍是单栏；
      改成左右分栏改动较大，等实际用起来觉得挤再说
- [ ] 错题回顾 / 复习模式再增强
- [ ] 设置项备份 / 云同步

### 体积与分发
- [ ] App 198MB / dmg 106MB。想省 54MB 只能做单架构产物，
      代价是另一架构的用户要装 Rosetta 2
- [ ] 是否在 macOS 上改用系统中文字体，省掉 46MB 的 Sarasa
- [ ] **是否买代码签名证书**：macOS 公证（$99/年）、Windows 代码签名。
      不买的话用户首次打开要手动放行一次（dmg 里附了说明），这是**唯一的彻底解法**

### 长期风险
- [ ] **Intel Mac**：Flutter 已警告未来版本不再支持 Intel 构建。
      建议钉住 3.47.3，升级前先确认新版仍发布 x64 包；长期需迁移到 Apple Silicon
- [ ] Homebrew 已放弃 Intel macOS 支持，会影响后续 brew 装包（备选 MacPorts）

### 想法池（未排期）
- [ ] 学习进度导出格式扩展（已有 JSON + CSV）
- [ ] 代码主题（浅色 / 深色编辑器）
- [ ] 更多语言（Rust / Go）：`LanguageRuntime` 继承一次 + 题库 + 分类表登记即可，
      落点清单见 DESIGN.md

---

## ✅ 已完成（按主题归档）

### ℹ️ 关于页与许可证（进行中：A 段已完成）
- [x] 新增 `LICENSE`（MIT，署名 hqswww）并注册进 `LicenseRegistry`
      —— 不注册的话「第三方许可证」页里只有 pub 依赖，看不到本项目自己的
- [x] 「关于」从弹窗升级为正页：名称、版本、更新日志（离线、按版本展开）、
      检查更新、项目主页、问题反馈、第三方许可证、MIT 许可证
- [x] 更新日志 `assets/CHANGELOG.md` 由 `tools/build_changelog.py` 从
      `docs/releases/` 生成；防漂移测试盯着，`--check` 给发布闸门用
- [x] 应用内图标 `assets/app_icon.png` 纳入 `tools/make_icons.py` 同源生成
- [x] 「检查更新」抽成共用组件 `UpdatePanel`（设置页与关于页同一份，避免两处开关显示不一致）
- [x] B 段：底栏「设置」→「我的」；`StatsService` 跨语言聚合 + `buildConclusions`
      纯函数结论（20 条测试，一半在测「什么时候不该下结论」）；设置降为子页面；
      3 处「设置 → X」指路文案改成「我的 → 设置 → X」
- [x] C 段：fl_chart 五张图（三门语言/难度分布/分类/测试趋势/近 30 天）；
      活动记录（按天、只在首次做对时 +1、保留 365 天）；导出导入带上活动记录
      （导入同日取较大值，idempotent）；连续天数「今天还没做」不算断签
- [x] 结论新增：连续练习天数、最近 7 天 vs 上一个 7 天（都要足够数据才说）

### 🎯 测试出题范围（v1.5.1）
- [x] 每种测试模式**各自**设定：从哪些大类出题 + 出到哪个难度档
- [x] 难度档位是**累计**的：难度一=绿、难度二=绿黄、难度三=绿黄红
      （命名刻意不用 easy/medium/hard，那会让人以为「难度二=只出中等」）
- [x] 范围内没有那一级难度时，对应档位**不可选** —— 12 个大类里有 5~7 个没有困难题
- [x] 范围按大类**序号**存（key 各语言不同、序号对应的教学阶段一致），切语言通用
- [x] 抽题按难度比例**分层抽样**（最大余数法）：换种子只换题、不换难度结构
- [x] 题量按题池夹紧（范围只有 6 题时，10 题的模式显示并出 6 题）
- [x] 顺手修掉：测试题池**没按语言过滤**（详见下方「踩过的坑」）

### 🔄 自动检查更新（v1.5.0）
- [x] `lib/services/update_service.dart`：查 `releases/latest`、比语义化版本
      （容忍 `v` 前缀 / `+构建号` / `-beta.1` 预发布）、按扩展名挑本平台安装包
- [x] `lib/services/url_opener.dart`：零依赖打开链接（`open` / `cmd start` / `xdg-open`）
      \+ URL 安全校验（只放行干净的 `https://`）
- [x] 启动时在**首帧之后**静默检查；有新版本才弹窗
- [x] 弹窗：版本对照 + 更新内容（Markdown 收拾过）+「去下载」+「以后再说」+「跳过这个版本」
- [x] 设置页 `关于 → 检查更新`：开关（默认开）+「立即检查更新」+ 当前版本
- [x] 失败一律静默（断网/限流/接口挂了都只写一行日志，绝不打扰用户）
- [x] 覆盖安装不丢进度的前提被测试钉住：Windows 版 `Runner.rc` 的
      `CompanyName` / `ProductName` 不能改（`shared_preferences` 的落盘路径由它们拼出来）
- [x] 真实网络验证过：本项目仓库无 Release 时返回「已是最新」；
      另拿 pandoc / cli 的真实 Release 返回体验证了解析与挑包

### 📐 响应式界面
- [x] `lib/pages/widgets/responsive.dart`：断点（`twoPane`=840）+ `AdaptiveMasterDetail`
- [x] **设置页**：宽屏「左分类 + 右详情」；窄屏整页列表、点击进详情
- [x] **练习页**：分类网格按最大宽度自适应列数
- [x] 窗口默认 1180、最小 420×520（模板默认 800 低于断点，启动只会看到单列）
- [x] `MaxWidthBody` + `ContentWidth`（list 900 / article 760 / workspace 1160 / log 1100）
      接入题目列表、收藏、测试历史、测试模式、错题本、日志中心、学习页、成就页
- [x] 学习页窄屏侧栏收进抽屉；成就页网格自适应
- [x] 测试：`responsive_layout_test.dart` + `practice_grid_test.dart` + `responsive_pages_test.dart`

### 🎨 应用图标
- [x] 圆角复用 Flutter 模板的 alpha（Apple squircle），遮罩固化为 `tools/icon_mask_1024.png`
- [x] macOS 7 张（16→1024）+ Windows 多尺寸 `.ico` + **Linux 3 张 png**
- [x] `tools/make_icons.py`（幂等；**不许**改成读自己生成的 1024 图，遮罩会越缩越小）
- [x] `build_macos.sh` 用 iconutil 重打完整 icns（Xcode 原生只到 256×256）

### 🍎 macOS
- [x] `python_runtime.dart` macOS 分支：架构专属捆绑 → 通用捆绑 → Homebrew/MacPorts/Xcode → PATH
- [x] `Abi.current()` 架构探测（universal 包要在两份 Python 之间挑）
- [x] `setup_macos_platform.sh`（生成 `macos/` + 关 App Sandbox）、`build_macos.sh`
- [x] `verify_macos.sh`：14 项自动验收
- [x] **dmg 安装包**（拖拽安装 + 卷内说明文件）+ zip 绿色版
- [x] 环境：Flutter 3.47.3 x64 在 `~/Develop/flutter`；**CocoaPods 不需要**（3.47 走 SPM）
- [x] 全流程实测：universal 双 Python → 裁减 → 签 14 个 Mach-O → `valid on disk`
- [x] 打包产物真机启动，日志确认解析到 `Contents/Resources/python-x86_64/bin/python3`

### 🅲🅲 C 与 C++ 接入
- [x] 多语言地基：语言模型 / 进度主键带语言 + 旧数据迁移 / 运行时抽象 /
      语法高亮按语言 / 顶栏切换器 / 设置页按语言配运行时路径
- [x] `CompiledLanguageRuntime`：**编译一次、所有用例复用产物**；
      `CLanguageRuntime` / `CppLanguageRuntime` 只差四处（扩展名、编译器、标准版本、文案）
- [x] `JudgeStatus.compileError`：编译失败时 UI **只显示一块报错**，
      头部说「编译没通过、一个用例都没跑」而不是误导性的「0/N 通过」
- [x] 编译错误清洗：抹掉临时目录绝对路径、行列号翻成中文
- [x] 运行面板按语言：Python 交互终端 / C·C++ 编译运行，**都能逐步喂 stdin**
- [x] 起步代码按语言给（`ProgrammingLanguage.starterCode`）
- [x] **两门语言各 12 分类 72 题**，全部参考答案经真判题引擎编译并判过
- [x] `tools/BANK_SPEC.md`、`tools/verify_bank.py`、`test/cpp_bank_structure_test.dart`
      等结构守卫

### 🎯 判题看得懂「用没用对语法」（v1.4.0）
- [x] `lib/services/source_check.dart`：具名检查 `pointer.use` / `pointer.walk` /
      `reference.use`，配合 `LanguageRuntime.stripCommentsAndLiterals` 去掉注释与字面量
- [x] `JudgeResult.unmetRequirements` + `outputAllPassed`：输出全对但语法没用上
      也是一种「没通过」，进度不记、下一题按钮不出现
- [x] 结果面板橙色块：「输出对了，但没按要求用上语法」+ 具体要求 + 怎么改 + 逃生门提示
- [x] 设置页「源码语法要求检查」开关（默认开，`load()` 会读回）
- [x] 题库 12 道题声明要求：C 901~906、C++ 801~806
- [x] 题库自检新增硬规矩：**参考答案必须满足自己声明的每一条要求**
      （这条测试当场抓出过一个把 `*(p + i)` 漏判的检查 bug）
- [x] 端到端回归：学生报上来的那段「不用指针」代码在 901 上必须判不过，
      关掉开关后必须又能判过

### 🎨 深浅两套主题下的可读性（v1.4.0）
学生报的两个问题，本质是同一类：**颜色写死成只在一种主题下才看得见**。

- [x] **深色模式下判题结果的说明文字是黑的** —— 面板里 `Colors.black54`
      写死了三处，深色底上对比度只有 **1.13**
- [x] **浅色模式下终端输入框的字看不见** —— 根因不是白字写错，而是全局
      `InputDecorationTheme` 的 `filled: true` 在终端自己画的深色衬底上
      又刷了一层浅灰（对比度 **1.00**，等于隐形）。修的是输入框本身
      （`filled: false`），不是把字改成黑的 —— 终端就该是深底浅字
- [x] 顺带体检出**相反方向**的问题：`Colors.grey` / `grey[500]` 做次级文字在
      **浅色**主题下只有 **2.55**，`grey[700]` / `grey[800]` 在**深色**主题下
      只有 3.00 / 1.85。35 处硬编码灰全部换成 `colorScheme.onSurfaceVariant`
      （浅色 8.87 / 深色 10.97）
- [x] 主题抽到 `lib/theme.dart`，测试用的是**界面真正在用的那份**主题，
      而不是抄一份（抄的那种改了颜色测试还按旧值判，等于没测）
- [x] `test/theme_contrast_test.dart`：两套主题下都不许出现「写反的文字色」
      （深色主题出现近黑字 / 浅色主题出现近白字），并按 WCAG 算输入框的对比度

### 🪟 Windows
- [x] 绿色版 + **Inno Setup 单文件安装包**（免管理员、中文界面、卸载不删进度）
- [x] `install_mingw.ps1`：C/C++ 编译器一键安装（免管理员、校验 SHA256、装完真编译验证）
- [x] **中文用户名路径**全线防御（详见下方「踩过的坑」）
- [x] `build_windows.ps1` 加非 ASCII 路径预检，把看不懂的报错翻译成人话

### 🐧 Linux
- [x] `build_linux.sh` + `install.sh`（用户级安装/卸载、`hicolor` 图标、`.desktop`）
- [x] 应用身份统一：`BINARY_NAME` / `APPLICATION_ID` / 窗口标题
- [x] 查证「不捆绑运行时」的依据：Ubuntu 24.04 Desktop 清单里 `python3` 自带，
      但 `gcc`/`g++`/`make`/`build-essential` 都不在

### 🧭 上手与诊断
- [x] **首次运行向导**：欢迎 → 运行环境自检（可一键装编译器 / 给下载页 / 手动填路径）→
      个性化 → 完成。**与设置页共用同一份存储**，不做两套配置
- [x] 设置页运行时卡片：显示「已就绪 + 实际路径」或「未找到 + 安装命令」
- [x] 日志中心 + 全局错误收集（环境信息含三门语言各自的运行时路径）
- [x] 判题提示：**环境故障与代码问题分开报**（`cannot execute 'as'` 不再说成「代码没通过编译」）
- [x] 提示里的 `**加粗**` 与 `` `代码` `` 真正渲染出来（面板是普通 Text，不解析 Markdown）

---

## 🔥 踩过的坑（都已修，留着别再踩）

### 编码类（这个项目被咬过四次）
- **PowerShell 脚本必须存 UTF-8 with BOM**：Windows PowerShell 5.1 读无 BOM 的 `.ps1`
  按系统 ANSI 代码页（中文系统 = GBK）解码 → 满屏乱码，严重时乱码字节里撞出引号直接语法报错。
  实测：同一行中文按 GBK 解出来是 `缂栫▼缁冧範鍐?路`，那个 `?` 就是「字节解不出来」。
  ⚠️ 任何一次用普通编辑器存盘都会把 BOM 丢掉，所以有测试盯着。
- **`ditto -c -k` 写 zip 不设 UTF-8 标志位**（实测 2438 个条目一个都没设）：
  macOS 自己解压没问题，Windows 资源管理器 / Linux `unzip` 会按 CP437 解出乱码。
  所以 zip 里刻意保留 ASCII 应用名，dmg 里才用中文名。
- **`$VAR` 紧跟全角字符会被 bash 吃进变量名** → 必须写 `${VAR}`（`$DEST）` 报 unbound variable）。
- **判题进程强制 UTF-8**：`-X utf8` + `PYTHONIOENCODING`，否则中文系统上比对会错。

### Windows 非 ASCII 路径（两条独立根因，都只在 Windows 上发作）
- **Flutter 引擎**：改用 C++20 后 `std::filesystem::path` 转字符串的编码变了；
  读 `.dill` 走 C 库 `open()`，期望 ANSI 路径 → 路径含非 ASCII 直接失败
  （flutter/flutter#178896，修复 PR #191360）。报的是
  `Unable to read file: ...app.dill` + MSB8066，**既没提路径也没提编码**。
- **MinGW 工具链**：`as.exe` / `ld.exe` **不带 UTF-8 清单**（实测 w64devkit 2.9.1 的
  244 个 exe 只有 8 个带，`gcc.exe`/`g++.exe` 有、`as`/`ld` 没有）→ 路径含中文时
  可能在汇编/链接那步失败。报 `cannot execute 'as'`，**裸名**说明所有搜索位置都没找到。
- 防御写法：判题工作目录与编译器 `TMP` 走纯 ASCII 位置（`temp_workspace.dart`）+
  Windows 编译参数加 `-B <编译器目录>`。**不能靠「让用户把目录挪到英文路径」解决** ——
  编译路径开发者可控，用户名不是。

### 签名与打包
- **Flutter macOS 模板默认开 App Sandbox** → 必须关（否则导出/导入失灵）
- **`codesign` 把 `Frameworks/` 下任何目录当嵌套代码** → 捆绑 Python 必须放 `Resources/`
- **`codesign --force` 会剥掉 entitlements**（不传 `--entitlements` 时静默丢失）→ 必须回读校验
- **Xcode 编出的 `AppIcon.icns` 只到 256×256** → 签名前用 iconutil 重打完整阶梯
- **签名后往包里加文件 = 签名失效**：捆绑 Python 运行时写 `__pycache__` 就会这样，
  连跑两次验收脚本必然失败。应用侧已设 `PYTHONDONTWRITEBYTECODE`，脚本侧加 `-B`。
  （验收脚本曾因此报错两次，一度被当成间歇性 bug 查 —— 实际是用户手动关了应用窗口）
- **`sh scripts.sh` 会失败**：macOS 的 `/bin/sh` 是 bash 的 POSIX 模式，进程替换
  `<( )` 直接语法报错；Linux 的 `/bin/sh` 常是 dash，`[[ ]]` 会变成 command not found。
  所有脚本都加了「用真正的 bash 重跑自己」的守卫。
  ⚠️ 不能用 `BASH_VERSION` 判断 —— sh 本身就是 bash 时它照样有值，要看 posix 选项。
- **`plutil` 把 `.` 当键路径分隔符** → 改 entitlements 必须转义点。

### 判题引擎
- **超时后进程根本没被杀**（既有 bug）：每次超时只返回结果，学生的 `while(1)`
  在后台一直跑吃满 CPU，而提示语写着「已强制终止」——已修（`_killQuietly` + SIGKILL）
- **给 stdout/stderr 各加 `.timeout` 会留下无人 await 的 future**，
  超时后它们再抛异常就是「未处理的异步异常」直接搞崩 —— 只给 `exitCode` 加超时
- **除零被误报成「崩溃/指针问题」**：`exitCode < 0` 一刀切把 SIGFPE(-8) 也吞了，
  而「Floating point exception」是 **shell** 打印的、判题不走 shell 所以永远不出现
  （实测：除零的 C 程序经 Dart 启动后 `exitCode == -8` 且 **stderr 为空**）。
  现在按端口码分类，Windows 的 `0xC0000094` 等也一并认。
- **运行面板只能跑一次**：runner 每次结束就 close 掉事件流，而面板只在 `initState`
  订阅一次 → 第二次 `start()` 新建 controller，界面还订阅着旧的。
  表现是「界面从空闲变成运行中，但什么都没发生」。
- **只比对输出，分不出用没用对语法**：901「用指针读取变量的值」期望输出是同一个数
  打两遍，于是 `int b = a; printf("%d\n%d", a, b);`（一个指针都没有）照样判过。
  这是方法的边界，不是 bug —— 现在补了一层源码检查（见「已完成」）。
  写这层检查时踩到的三个点：
  - **必须先去掉注释和字面量**：学生把 `// int *p = &n;` 注释掉留在文件里是常事，
    直接匹配原文会把它算成「用过指针」，判过了而实际运行的那份代码里没有指针
  - **`*` 有三种含义**：`int *p`（声明）、`a * p`（乘法）、`*p`（解引用）。
    判据是看星号**前面那个字符**；`return *p;` 要单独特判成关键字，
    不然会被当成乘法漏掉
  - **`*(p + i)` 不是 `*p` 也不是 `p[i]`**：漏掉这一种，连题库 806 的参考答案
    都判不过 —— 被「参考答案必须满足自己声明的每一条要求」那条测试当场抓住

### 主题与颜色
- **全局 `InputDecorationTheme` 的 `filled: true` 会连「自己画了底色」的输入框
  一起刷**。交互终端的输入栏自己铺了一层深色衬底、文字写死浅色，浅色模式下
  被主题又刷上一层浅灰 → 白字落浅灰，对比度 1.00，等于隐形。
  **自带宽底色的输入框必须显式写 `filled: false`**。
  这个坑绕了一圈才找到：一开始以为是「输入栏底色跟着主题跑」（看着像），
  实际是「主题底色盖在上面」。
- **同一个灰色在两种主题下的表现可以完全相反**：`Colors.grey` / `grey[500]`
  做次级文字，深色主题下 6.94（够用）、**浅色主题下只有 2.55**；
  `grey[700]` / `grey[800]` 反过来，深色主题下 3.00 / 1.85。
  所以「次级文字」一律用 `colorScheme.onSurfaceVariant`（浅 8.87 / 深 10.97），
  不要按「看着差不多」挑一个灰。
- **`Colors.black.withValues(alpha: 0.05)` 做衬底在深色主题下等于没画**（黑压黑）。
  浅色主题下两者等价、深色主题下差很多的写法，用
  `colorScheme.onSurface.withValues(alpha: ...)`。
- **判断「这个颜色在两套主题下都行吗」靠算，不靠看**。WCAG 对比度公式
  `(亮+0.05)/(暗+0.05)`，见 `test/theme_contrast_test.dart`。

### 自动更新（v1.5.0 踩的）
- **GitHub API 对没有 `User-Agent` 的请求直接 403** —— 不是限流，是「你不告诉我你是谁」。
  用 `curl` 手测时 curl 会自己带 UA，所以很容易在代码里漏掉而这个坑只在应用里发作
- **仓库还没有 Release 时 `releases/latest` 返回 404**。这不是错误，是「没什么可更新的」——
  报成「检查失败」会让用户以为网络坏了（这个项目现在的状态就是这样）
- **`shared_preferences` 在 Windows 上的落盘路径是从 exe 的版本资源拼的**
  （`%APPDATA%\<CompanyName>\<ProductName>\`）。改这两个字段等于让老用户
  「找不到自己的进度」——跟 macOS 改 bundle id 是同一类事故，已有测试钉住
- **`Process.run(url)` 在 Windows 上打不开浏览器**：dart:io 走 CreateProcess，
  而打开 URL 要 ShellExecute。常见解法是 `cmd /c start`，但那条路对本项目**特别危险**：
  安装包名字是中文 → GitHub 给的链接是百分号转义的 → cmd 会把 `%E7%` 这样的片段
  当变量去展开，链接被悄悄改坏，用户只看到打不开的页面。
  改用 `rundll32 url.dll,FileProtocolHandler`（不经过命令行解析）。
  ⚠️ 这一条**没有在真 Windows 上实测**，只做了静态推理
- **URL 安全校验要先过 `Uri` 规范化再判断**：`Uri.parse(...).toString()` 会把中文
  转义成 `%XX`。不先规范化的话，我们自己发的「编程练习册-Setup.exe」链接
  （带中文）会被判成不合法，「去下载」永远只能退化成手动复制网址。
  反过来，`&` `;` `(` `)` `'` `$` 这些字符 **Uri 转义不掉**，会原样进命令行，
  必须自己挡 —— 这两类要分开对待，一刀切会错一头
- 顺带：用 `dart:io` 的 `HttpClient` 时 `findProxyFromEnvironment` 要显式设，
  否则国内直连 GitHub 常常不通

### 多语言遗留
- **`loadCategories()` 不带语言参数 = 加载全部语言**。多语言重构时 practice_page
  跟着改了，**TestPage 漏了** —— 于是「全题库」显示 216 题（3×72），
  一次 Python 测验里会混进 C 和 C++ 的题（题面/编辑器/编译器都跟着那道题的语言走，
  所以看起来"能用"，只是完全不是用户想要的）。
  找出来的方式：往测试页 UI 上打一行「模式按钮上的题量」，一眼看到 216。
  **教训**：这种「参数可选、缺省是"全部"」的 API 最容易漏 —— 漏了不报错、不崩溃，
  只是静默地把范围放大。要么别给这种缺省，要么加一条断言。

### 构建脚本
- **`uname -m` 的架构名 ≠ Flutter 的构建目录名**：脚本用 `uname -m` 得到 `x86_64`
  去拼 `build/linux/${ARCH_TAG}/release/bundle`，而 Flutter 用的是**它自己的**
  `x64` / `arm64`。路径永远不存在 → 被兜底 `find ... -name bundle` 接住 →
  捞到几天前 `flutter run` 留下的 `build/linux/x64/**debug**/bundle`。
  后面每一步都"成功"，只是打出来的是个 **debug 版的旧程序**，最后卡在
  「可执行文件不在预期位置」——因为那个旧产物里的可执行文件还叫 `python_practice`。
  **两个教训**：架构名只用来给分发包命名；兜底搜索必须限定在 `release` 里，
  宁可报错也不能捞到近似的东西（"成功但发错"比"失败"贵得多）。
  这条是**真机跑出来的**，静态审了两个月没发现。

### 测试与工具
- **rootBundle 在同一个测试文件里只能成功加载一次**；每个语言的结构守卫要单独一个文件
- **一条测试里判完整个题库会把 flutter_tools 搞崩**（72 题 33 秒 → `Bad state:
  Cannot close sink while adding stream`）→ 拆成每分类一条
- **普通 `test()` 读 assets 要自己 `TestWidgetsFlutterBinding.ensureInitialized()`**，
  否则题库静默变成空数组，看起来像「题库没有分类」
- **`settings` 是全局单例、其 `SharedPreferences` 实例是缓存的**：
  `setMockInitialValues` 之后直接 `load()` 读不到新值 → 用例单独跑过、一起跑挂
- **Dart 的 `RegExp` 不支持内联 `(?m)`**（.NET/PowerShell 支持，两个引擎不一样），
  多行要用构造参数
- **子 agent 跑不了 `flutter test`**（回环 socket 被拒 + pub 无网络）→
  委派 Flutter 改动时测试闸门必须留在父会话跑

---

## 🧪 怎么测「更新提示」（造一个报旧版本的包）

要看到更新弹窗，**装在机器上的版本必须比 GitHub 上的 tag 旧**。开发机上跑的
就是最新代码，自己不会提示自己，所以要么找一台装着旧版的机器，要么造一个包。

造的办法：把版本号改小、别的不动，编译一个出来（**编完必须改回来**）：

```bash
# 1. 三处版本号一起改成旧版本（不一致会被 version_consistency_test 抓住）
#    lib/app_version.dart      const String appVersion = '1.4.0';
#    pubspec.yaml               version: 1.4.0+99     ← 构建号给个显眼的数，一眼认出是测试包
#    tools/windows_installer.iss  #define AppVersion "1.4.0"
# 2. 构建
bash tools/build_macos.sh          # 或 Windows 上 tools\build_windows.ps1
# 3. 把产物改成一眼能认出的名字，免得跟正式包混在一起
mv dist/编程练习册-macOS-universal.dmg dist/更新测试-报1.4.0.dmg
# 4. ⚠️ 改回来！git status 必须是干净的
git checkout -- lib/app_version.dart pubspec.yaml tools/windows_installer.iss
```

然后：**先在 GitHub 上发好 Release**（tag 要是 `v1.5.0` 这种比测试包新的），
再打开测试包 → 应当弹「发现新版本」。

自检点（哪一步不对会静默失败，所以值得逐个确认）：
- Release 的 tag 与 `appVersion` 比是不是更大？tag 写成 `1.5.0`（没 v）也能认
- Release **不是草稿、也不是 Pre-release** —— `releases/latest` 会跳过这两种
- 系统时间对不对（HTTPS 握手会失败，然后被静默当成「检查失败」）
- 想直接看结果：设置页 `关于 → 检查更新 → 立即检查更新`，它会把失败原因说出来

启动那条链路由 `test/update_startup_test.dart` 覆盖（有版本就弹、关掉开关不弹、
断网静默、跳过的版本不再弹）—— 这几条一旦坏了都是静默的，所以才专门测。

---

## 🚀 发布流程（改完一轮怎么发新版）

1. 攒一批改动，测完：`flutter test` 全过 + `flutter analyze` 无新增 + build 成功
2. **升版本号**（改 `lib/app_version.dart`，测试会告诉你 pubspec 与
   `windows_installer.iss` 里那两份漏没漏）
3. 更新 `README.md` 的版本段与 `PROJECT_BACKLOG.md` 的状态
4. 提交 + 打 tag（如 `v1.5.0`，**必须带 `v` 前缀** —— 应用侧的版本比较虽然两种都认，
   但统一写法免得混乱）+ `git push --tags`
5. 在 Windows 上重跑 `tools\build_windows.ps1` → 绿色版目录 + `Setup.exe`
6. 在 macOS 上重跑 `tools/build_macos.sh` → dmg + zip
7. 分发：Windows 发 `Setup.exe`，macOS 发 dmg，Linux 发 tar.gz
8. **⭐ 在 GitHub 上建 Release 并挂上这些安装包** —— 这是自动更新功能的开关：
   没有 Release，应用检查到的永远是「已是最新」。
   - tag 用 `v1.5.0`（与 `appVersion` 一致，否则会提示一个不存在的版本）
   - **正文就是用户看到的「更新内容」**：先写进 `docs/releases/<版本>.md`（在 git 里
     留一份，下次照着改），发布时整篇复制过去。第一份见 `docs/releases/v1.5.0.md`
   - 写完**跑一次 `python3 tools/build_changelog.py`** —— 应用内「关于 → 更新日志」
     读的是生成物 `assets/CHANGELOG.md`，不跑的话新版本不会出现在里面
     （有测试盯着，`--check` 模式给闸门用）
   - 正文写法：写给人看，分「新增 / 修复 / 变化」列要点。
     `#` 标题、``` 围栏、`- ` 列表会在弹窗里被收拾成纯文本，`**加粗**` 和
     `` `代码` `` 会被渲染 —— 写 Markdown 没问题，但**别用表格、图片、`>` 引用和
     `[链接](url)`**（这几样在弹窗里会原样露出符号）
   - 附件名带 `.dmg` / `.exe` / `.tar.gz` 后缀即可，中文名不影响（应用按后缀挑）

---

## 🔧 维护备忘

- **改代码**：小步 commit + 可回滚（GitHub 远程是保险箱）
- **推送到线上仓库前先让 Sakiri 确认**（远端是公开仓库，推送即公开且不易撤回）
- **远程仓库**：`https://github.com/hqswww/python-practice-platform.git`（HTTPS，**不是** SSH）
  - 推送靠 macOS 钥匙串凭据（`credential.helper=osxkeychain`）。
    首次要输用户名 + **Personal Access Token**（不是密码，GitHub 已不支持密码推送）
  - `~/.ssh/` 下没有密钥，所以 `git@github.com:...` 那种写法目前用不了
  - 偶发 `Error in the HTTP2 framing layer` —— 纯瞬时网络问题，重试即可
- **判题走哪条路**：Linux = 系统 `python3`；Windows = 捆绑 `python\python.exe`；
  macOS = 捆绑 `Contents/Resources/python-<arch>/bin/python3`（按 `Abi.current()` 挑）
  C/C++ 三平台都用系统编译器
- **题库要校验**：`python3 tools/verify_bank.py --lang <c|cpp>`（真编译真跑）
- **macOS 验收**：`bash tools/verify_macos.sh`（14 项；⚠️ 跑的时候别手动关应用窗口，
  那会让「进程存活」那项误报失败）
