# 🪟 Windows 迁移手册

> 目标：把「编程练习册」在 Windows 上打出可分发、免装 Python 的 `.exe`。
> 本手册 = 阶段 A（Linux 侧已备好代码/脚本）+ 阶段 B（Windows 虚拟机实操）。

---

## 一、架构结论（为什么这样设计）

| 项 | 决策 | 原因 |
|----|------|------|
| 构建机 | **必须在 Windows** | Flutter Windows 桌面 = C++/MSVC 工具链，无法 Linux 交叉编译 |
| Python | **嵌入式 Python**（`python-3.13-embed-amd64.zip`） | 免装、体积小(~10MB)、够判题用 |
| Python 位置 | 放在 `exe同目录/python/` | 判题引擎按**相对 exe 路径**找，不依赖系统 PATH |
| 编码 | 进程加 `-X utf8` + `PYTHONIOENCODING=utf-8` | Windows Python 默认可能 GBK，中文输出会比对错 |
| 分发 | 整目录拷贝（绿色版） | 无需安装，双击即用 |

---

## 二、Windows 机器前置环境（一次性安装）

1. **Flutter SDK**（Windows）
   - 下载：https://docs.flutter.dev/get-started/install/windows
   - 解压到 `C:\flutter`，把 `C:\flutter\bin` 加入 PATH
   - `flutter doctor` 确认无红叉

2. **Visual Studio**（C++ 桌面开发套件）
   - 装 **Visual Studio 2022 Community**
   - 勾选「**使用 C++ 的桌面开发**」工作负载（含 MSVC 编译器和 Windows SDK）
   - 这是 Flutter Windows 编译的硬依赖，缺失会报 `Unable to find suitable Visual Studio toolchain`

3. 确认：
   ```powershell
   flutter doctor
   flutter --version   # 应显示 windows 平台可用
   ```

---

## 三、在 Windows 上一键打包

把整个项目文件夹（含 `windows/`、`lib/`、`assets/`、`tools/`）拷到 Windows 机器。

在**项目根目录**打开 PowerShell，运行：

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
```

脚本自动完成 5 步：
1. `flutter build windows --release` 编译 exe
2. 下载嵌入式 Python
3. 配置 `.pth`（可选开启 site-packages）
4. 组装到 `dist\编程练习册\`（exe + data + lib + python/ + install_mingw.ps1）
5. 打包安装程序 `dist\编程练习册-Setup.exe`（装了 Inno Setup 才会做）

### 两个产物，按场景挑

| 产物 | 形态 | 适合 |
|------|------|------|
| `dist\编程练习册\` | 绿色版目录 | 解压即用、放 U 盘、不想装东西 |
| `dist\编程练习册-Setup.exe` | **安装包** | 发给同学：一路下一步，有开始菜单项和卸载器 |

安装包的特点：

- **免管理员**：装到 `%LOCALAPPDATA%\Programs\编程练习册`，和绿色版一个精神。
  想装给所有用户的话，向导里可以选（那时才提权）
- 中文安装界面（语言包随仓库带，见下）
- **卸载不删用户进度**：进度存在 `%APPDATA%` 下，不属于安装目录。
  顺手删掉的话，用户重装一次就发现进度没了 —— 那是数据丢失，不是清理
- 安装包要装 **Inno Setup 6.5.0+** 才能构建，缺失时脚本只警告、不影响绿色版：
  ```powershell
  winget install JRSoftware.InnoSetup
  ```

> ⚠️ **安装包照样会被 SmartScreen 拦**（"Windows 保护了你的电脑"）——
> 那需要买代码签名证书，和 macOS 的公证是同一类成本。
> 安装包解决的是「装起来方便」，不是「系统信任」。

### 为什么语言包要随仓库带

`tools/inno/ChineseSimplified.isl` 是从
[kira-96/Inno-Setup-Chinese-Simplified-Translation](https://github.com/kira-96/Inno-Setup-Chinese-Simplified-Translation)
取来的（MIT，版权声明随文件一起放在 `tools/inno/`）。

Inno Setup 官方的翻译虽然「通常随安装包提供」，但**不同版本带的不一样**，
而且中文翻译更新得比官方版本快。钉在仓库里可以保证：构建结果可复现、
不用联网下载、翻译改动能在 git 里看到。

---

## 四、验证与分发

### 验证（关键！）
1. 双击 `dist\编程练习册\编程练习册.exe` 能启动
2. **重点测判题**：随便挑一题写对代码提交，应显示「通过」而非乱码/报错
   - 中文输出的题尤其要测（验证编码加固是否生效）
3. 测试交互终端、成就、主题色是否正常

### 分发
把整个 `编程练习册` 文件夹打包成 zip 发给用户。
用户双击 exe，**无需安装 Python**。

### C / C++ 的编译器（用户侧）

Python 是捆绑的，但 C / C++ 走**系统编译器**，用户机器上不一定有。
两条路，都已经接好：

1. **应用内一键安装**：首次运行向导（或「设置 → 关于 → 重新运行设置向导」）
   里，对缺编译器的语言直接点「一键安装」。它调用的是随包分发的
   `install_mingw.ps1`（`build_windows.ps1` 会把它拷进分发目录）。
2. **手动跑脚本**：`powershell -ExecutionPolicy Bypass -File install_mingw.ps1`

脚本的特点（`tools/install_mingw.ps1`）：

- **不需要管理员权限**：整套工具解压到 `%LOCALAPPDATA%\code_workbook\w64devkit`，
  PATH 也只改**用户**那一份（不碰系统 PATH，不用 UAC）
- 用 **w64devkit 2.9.1**（单个 61MB 自解压包，含 gcc / g++ / make / gdb）。
  没选 WinLibs 是因为它的 x86_64 压缩包 274MB、解压约 1.5GB，对只想刷题的学生太重
- 下完先校验 **SHA256**，再 `Unblock-File` 解除「来自 Internet」标记
  （不解除的话 SmartScreen 会以「此文件来自其他计算机」为由拦住执行）
- 装完**真编一个 C 和一个 C++ 程序**跑一遍 —— 只跑 `gcc --version` 不足以证明能编译
- `-Uninstall` 可完整卸载（删目录 + 从用户 PATH 移除）
- **幂等**：已经有能用的 gcc 就直接跳过（想强制重装加 `-Force`）

> ⚠️ 应用进程读不到新写入的 PATH（Windows 只对新开的进程生效）。
> 所以 `c_runtime.dart` 的 Windows 兜底路径里**显式列了** w64devkit 的默认安装位置，
> 装完点「重新检测」立刻就能认出来，不用重启应用。

---

## 五、PowerShell 脚本的中文编码（踩过的坑）

**`.ps1` 含中文时，必须存成 UTF-8 with BOM。**

Windows PowerShell 5.1 读**没有 BOM** 的 `.ps1` 时，按系统 ANSI 代码页解码；
中文系统上是 GBK，于是 UTF-8 的中文被当 GBK 读 —— 轻则输出乱码
（「编程练习册」变成「缂栫▼缁冧範鍐屻€」），重则乱码字节里撞出引号导致**语法报错**。

BOM 是 5.1 判断编码的唯一可靠依据。PowerShell 7 默认按 UTF-8 读，有 BOM 同样正确，
所以「加 BOM」对两个版本都成立。

本仓库的两个 `.ps1` 都已加 BOM（`ef bb bf`）。检查方法：

```bash
head -c 3 tools/install_mingw.ps1 | xxd -p     # 应输出 efbbbf
```

另一个层面是**输出到控制台**的编码，需要显式设置：

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
```

⚠️ 这两行要包在 `try/catch` 里：被应用以「重定向输出」方式调用时没有真正的控制台，
给 `[Console]::OutputEncoding` 赋值会抛 IOException（句柄无效）。那种情况下本来
也不要求控制台显示，忽略即可 —— 但绝不能让脚本因此中断。

---

## 六、常见坑 & 排查

| 症状 | 原因 / 解法 |
|------|------------|
| `flutter build windows` 报找不到 VS | 没装 Visual Studio C++ 工作负载 |
| 判题输出乱码（中文变 `鍜嬪挓`） | 编码未生效 → 检查 `PythonRuntime.withUtf8Env`（已内置） |
| **脚本自己的中文输出乱码** | `.ps1` 没存成 UTF-8 with BOM → 见第五节 |
| 用户机器说「找不到 python」 | 打包时 `python/` 没拷全 → 重跑 build 脚本 |
| 判题 `ModuleNotFoundError` | 嵌入式 Python 缺第三方库 → 需手动把包放进 `python/Lib/site-packages/` |
| C / C++ 提示「找不到编译器」 | 跑首次运行向导里的「一键安装」，或 `install_mingw.ps1` |
| 装完编译器应用还是说找不到 | 点该语言的「重新检测」；仍不行就把 `gcc.exe` 完整路径填进设置页 |
| 下载安装包被 SmartScreen 拦 | 脚本已 `Unblock-File`；手动下载的话右键属性勾「解除锁定」 |
| **构建报 `Unable to read file: ...app.dill`** | 路径含非 ASCII 字符（多是中文用户名）→ 见第六节 |
| **判 C/C++ 报「找不到文件」但代码没问题** | 同一根因，只是发生在编译器而不是 Flutter 里 → 见第六节 |

---

## 六、非 ASCII 路径（中文用户名）

这是个**很容易被误判成「代码有问题」**的坑，单独说清楚。

### 症状

- `flutter build windows` 跑到一半报
  `error : Unable to read file: ...\.dart_tool\flutter_build\<hash>\app.dill`，外加 MSB8066
- 或者判题时 C / C++ 报「找不到源文件」，但代码明明是对的

两者**都不是项目代码的问题**，根源都是**路径里有非 ASCII 字符** ——
最常见的就是用户名是中文：`C:\Users\笑\...`。

### 为什么

| 环节 | 问题 |
|------|------|
| Flutter 引擎 | 改用 C++20 后 `std::filesystem::path` 转字符串的编码变了；读 `.dill` 走 C 库 `open()`，它期望 ANSI 编码的路径 → 非 ASCII 路径直接失败。见 flutter/flutter#178896（修复 PR #191360） |
| MinGW 编译链 | `as.exe` / `ld.exe` **不带 UTF-8 清单**，仍按系统 ANSI 代码页解析路径。实测 w64devkit 2.9.1 的 244 个 exe 里只有 8 个带清单（`gcc.exe`/`g++.exe` 有，`as.exe`/`ld.exe` 没有）。见 niXman/mingw-builds-binaries#61 |

### 已经做了什么

**编译期**（开发机）：
- `tools/build_windows.ps1` 加了预检，开跑前就查项目路径和 `%TEMP%`，
  命中直接说明原因和两个办法，不必等几十秒后对着 MSB8066 猜

**运行期**（用户机器 —— 这个更要紧，用户名不受我们控制）：
- `lib/services/temp_workspace.dart`：Windows 上判题的工作目录**刻意避开用户目录**，
  优先 `%ProgramData%\code_workbook\tmp`，其次 `%SystemRoot%\Temp\code_workbook`
- 编译型语言的 `compileSpec` 把 `TMPDIR`/`TMP`/`TEMP` 一起指过去，
  让 gcc 的中间文件（`.s` / `.o`）也落在 ASCII 路径下 —— **`as`/`ld` 正是最怕
  非 ASCII 的那一环**
- 系统临时目录本身就是纯 ASCII 时行为完全不变；Linux / macOS 不做任何改动

> 这条防御**不依赖「某个工具链有没有把清单打全」**，因为整条链根本看不到
> 非 ASCII 路径。这也是选它、而不是「换个 MinGW 分发版」的原因。

### 开发者侧的两个办法

1. **升级 Flutter** 到已修复的版本（`flutter/flutter#178896` 已标记 fixed）
2. **把项目和临时目录都挪到纯英文路径**：
   ```powershell
   mkdir D:\dev
   # 把项目复制到 D:\dev\python-practice-platform
   $env:TEMP='D:\dev\tmp'; $env:TMP='D:\dev\tmp'
   ```
   只挪项目可能不够 —— `%TEMP%` 同样在用户目录下，要一起改。

---

## 七、代码侧已完成的迁移准备

- ✅ `flutter create --platforms=windows .` 生成的 `windows/` 脚手架
- ✅ `lib/services/python_runtime.dart`：
  - `resolvePythonCommand()` — Windows 优先找捆绑 python
  - `withUtf8Env()` / `utf8Args`（`-X utf8`）— 强制 UTF-8，避免 GBK 下判题比对错
  - `isCommandAvailable()` / `installHint()` — 给设置页与向导用的自检与指引
- ✅ `judge_engine.dart` / `interactive_runner.dart` 接上 `PythonRuntime`
- ✅ `tools/build_windows.ps1` 一键打包（含把 `install_mingw.ps1` 拷进分发目录）
- ✅ `tools/install_mingw.ps1` C / C++ 编译器一键安装 / 卸载（免管理员权限）
- ✅ **首次运行向导**（`lib/pages/setup_wizard_page.dart`）：第一次打开就检查三门语言
  的运行环境，缺什么现场装或给指引；改的主题色 / 字号 / 缩进 / 默认语言都和设置页
  共用同一份存储，之后随时能在「设置 → 关于 → 重新运行设置向导」重进
- ✅ 设置页的运行时卡片显示「已就绪 + 实际路径」或「未找到 + 安装命令」

> ⚠️ **未在本机验证的部分**：本仓库的开发机是 macOS，没有 Windows 环境，
> 所以 `flutter build windows`、`install_mingw.ps1` 的实际执行、
> 以及一键安装的端到端链路**都没有实跑过**。脚本已做 BOM 编码修正与
> SHA256 校验等静态防护，但首次在真机上跑请按第四节的验证清单逐项确认。
