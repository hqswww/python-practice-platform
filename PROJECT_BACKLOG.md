# 📋 项目 Backlog（待办 / 想法池）

> 维护方式：Sakiri 想到什么就丢进来，我（Sakiri-chan）记录、排期。
> 状态：`⬜ 待办` · `🔨 进行中` · `✅ 已完成` · `🔇 搁置`
> 里程碑用 tag 归档（如 `v1.0-final`）。

---

## 🎯 当前版本状态

**v1.4.0** —— 版本号单一维护点在 `lib/app_version.dart`（pubspec 与安装包脚本里的
副本由测试盯着，改一处漏一处会测试失败）。

本版相比 v1.3.0 的主要变化：

| 方向 | 内容 |
|------|------|
| 判题 | **源码语法要求检查**：指针/引用题不再能靠「输出一样」蒙混过关（12 道题已覆盖） |
| 设置 | 新增「源码语法要求检查」开关（默认开），误判时学生有退路 |
| 修正 | 判题结果面板里写死的「正在运行 **Python** 判题…」改成按科目显示 |

v1.3.0 的内容见下方归档。

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
- [ ] **Linux 打包**：`build_linux.sh` 从未在真 Linux 上跑过
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

## 🚀 发布流程（改完一轮怎么发新版）

1. 攒一批改动，测完：`flutter test` 全过 + `flutter analyze` 无新增 + build 成功
2. **升版本号**（改 `lib/app_version.dart`，测试会告诉你 pubspec 与
   `windows_installer.iss` 里那两份漏没漏）
3. 更新 `README.md` 的版本段与 `PROJECT_BACKLOG.md` 的状态
4. 提交 + 打 tag（如 `v1.3.0`）+ `git push --tags`
5. 在 Windows 上重跑 `tools\build_windows.ps1` → 绿色版目录 + `Setup.exe`
6. 在 macOS 上重跑 `tools/build_macos.sh` → dmg + zip
7. 分发：Windows 发 `Setup.exe`，macOS 发 dmg，Linux 发 tar.gz

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
