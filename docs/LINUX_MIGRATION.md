# 🐧 Linux 迁移手册

> 目标：在 Linux 上打出可分发、解压即用的绿色版；判题走**系统环境**，不捆绑运行时。
> 打包脚本：`tools/build_linux.sh`（组装 + 打 tar.gz）
> 安装到应用菜单：分发目录里的 `install.sh`（用户级，免 sudo）

---

## 一、架构结论（为什么 Linux 不捆绑运行时）

| 项 | 决策 | 原因 |
|----|------|------|
| 构建机 | **必须在 Linux** | Flutter 桌面版走各平台原生工具链（Linux = GTK3 + CMake + clang），无法交叉编译。脚本里有平台护栏，在别的系统上会直接拦下来 |
| Python | **不捆绑**，用系统的 `python3` | Linux 桌面发行版自带；见下方实测清单 |
| C / C++ | **不捆绑**，用系统的 `gcc` / `g++` | 与 Windows 装 MinGW 是同一条既定路线；编译器本来就不适合塞进应用 |
| 分发 | 绿色版 `tar.gz`，可选 `install.sh` 装进应用菜单 | 不依赖发行版打包体系（deb/rpm/Flatpak 各写一份成本太高） |
| 编码 | 判题进程带 `-X utf8` + `PYTHONIOENCODING=utf-8` | 与 Windows / macOS 共用同一套加固，代码在 `python_runtime.dart` |

### 为什么「不捆绑 Python」是有依据的

查了 **Ubuntu 24.04.3 Desktop 的官方安装清单**
（<https://releases.ubuntu.com/24.04/ubuntu-24.04.3-desktop-amd64.manifest>），逐包核对：

| 包 | 在默认安装里？ |
|---|---|
| `python3` (3.12.3) | ✅ **在** |
| `python3.12` / `python3-minimal` | ✅ 在 |
| `gcc` | ❌ **不在** |
| `g++` | ❌ **不在** |
| `build-essential` | ❌ 不在 |
| `make` | ❌ 不在 |
| `libc6-dev`（C 头文件） | ✅ 在 |
| `cpp`（预处理器） | ✅ 在 |
| `gdb`（调试器） | ✅ 在 |

两条结论：

1. **`python3` 不用管** —— 主流桌面发行版（Ubuntu / Debian / Fedora / Mint）都自带，
   而且本平台判题只用标准库、不装第三方包，不涉及 pip / PEP 668 那套麻烦。
   再给它多带一份解释器，等于给每个发行版、每种架构白加 ~54MB。
2. **`gcc` / `g++` 确实要用户自己装** —— 但这是**预期内**的，不是缺口。
   应用会在设置页提前把命令告诉用户（见第四节）。

> ⚠️ 有个容易误判的细节：`libc6-dev`（头文件）、`cpp`（预处理器）、`gdb` 都**在**默认安装里，
> 唯独缺真正的编译器。用户 `ls /usr/include/stdio.h` 有、`cpp --version` 有，
> 很容易以为自己「编译环境齐了」。所以应用里那句明确的提示才重要。

---

## 二、Linux 机器前置环境（一次性安装）

### 打包机需要

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
flutter doctor          # 确认 "Linux toolchain" 是 ✓
```

### 使用者的机器需要

- **`python3`** —— 一般自带，不用管
- **`gcc` / `g++`** —— 想刷 C / C++ 题才需要：

```bash
sudo apt install build-essential     # Debian / Ubuntu / Mint
sudo dnf install gcc gcc-c++         # Fedora
sudo pacman -S base-devel            # Arch
```

**没装也不影响 Python 科目**：应用照常启动，只在设置页对 C / C++ 显示「未找到编译器」。

---

## 三、在 Linux 上一键打包

在项目根目录：

```bash
bash tools/build_linux.sh
```

脚本做 4 步：

1. `flutter build linux --release` 编译
2. 组装 `dist/编程练习册-linux-<arch>/`（可执行文件 + `data/` + `lib/`）
3. 放进图标（128/256/512 PNG）与 `.desktop` 入口
4. 打 `dist/编程练习册-linux-<arch>.tar.gz`

产物结构：

```
编程练习册-linux-x86_64/
├── code_workbook              可执行文件（CMakeLists 的 BINARY_NAME）
├── data/                      Flutter 资源（含三门语言题库）
├── lib/                       Flutter 动态库
├── app_icon_{128,256,512}.png 图标
├── 编程练习册.desktop          入口（Exec/Icon 已填成绝对路径）
└── install.sh                 装进应用菜单（用户级，免 sudo）
```

---

## 四、验证与分发

### 验证清单

1. 解压后 `./code_workbook` 能直接启动
2. **重点测判题**：Python / C / C++ 各挑一题写对代码，应显示「通过」
3. 打开「设置 → 代码编辑」，三张运行时卡片应显示 **已就绪** 与实际使用的路径
4. 故意把一个路径填成 `/nonexistent/gcc` 并保存 → 应立刻变成 **未找到编译器** 并给出安装命令
5. 中文不糊：界面字体、判题比对、日志都正常
6. 响应式：拉窗口宽度，设置页在 840pt 处从单列切成左右两栏

### 分发

把 `dist/编程练习册-linux-<arch>.tar.gz` 发给用户，解压即用。
想让它在应用菜单里出现，跑解压目录里的 `./install.sh`。

### 资源管理器里双击没反应？

从文件管理器双击可执行文件时，部分桌面环境会因为「可执行权限」或安全策略拦一下；
命令行 `./code_workbook` 不会有这个问题。`.desktop` 入口（`install.sh` 装的）也没问题。

---

## 五、常见坑 & 排查

| 症状 | 原因 / 解法 |
|------|------------|
| `flutter build linux` 报找不到 GTK / CMake | 打包机缺开发库，见第二节 |
| 应用菜单里没有条目 | 没跑 `install.sh`；或跑了但没刷新缓存（脚本会自动调 `update-desktop-database`，手动跑一次也行） |
| 图标是通用占位图 | 图标必须按尺寸放进 `~/.local/share/icons/hicolor/<尺寸>x<尺寸>/apps/`，且 `.desktop` 用 `Icon=<APP_ID>` 引用。**GTK 应用不会从可执行文件里读图标** |
| 任务栏里出现两个图标 / 图标对不上窗口 | `.desktop` 的 `StartupWMClass` 要和 GTK 的 prgname（= `APPLICATION_ID` = `com.sakiri.python-practice`）一致 |
| C / C++ 判题报「找不到编译器」 | `sudo apt install build-essential`。设置页会直接给出这条命令 |
| 判题输出中文乱码 | 检查 `PythonRuntime.withUtf8Env` 是否生效（已内置，一般不会是这里） |
| 双击 `.desktop` 提示「不受信任」 | GNOME 需要 `gio set <文件> metadata::trusted true`，或在文件属性里勾「允许作为程序执行」 |

---

## 六、代码侧已完成的迁移准备

- ✅ `flutter create --platforms=linux .` 生成的 `linux/` 脚手架，并已把 Flutter 默认值改成项目实际身份：
  - `BINARY_NAME`：`python_practice` → **`code_workbook`**（与 macOS / Windows 一致）
  - `APPLICATION_ID`：`com.sakiri.python_practice` → **`com.sakiri.python-practice`**（与 macOS 的 bundle id 一致）
  - 窗口标题：`python_practice` → **`编程练习册`**
- ✅ `tools/build_linux.sh` 一键打包（含平台护栏：只能在 Linux 上跑）
- ✅ `tools/linux/install.sh` 用户级安装 / 卸载（`--uninstall`）
- ✅ `tools/make_icons.py` 增加 Linux PNG 输出（128/256/512）
- ✅ 设置页运行时自检（`LanguageRuntime.checkStatus()`）：
  显示「已就绪 + 实际路径」或「未找到 + 安装命令」，保存路径后立刻重算
- ✅ `PythonRuntime.installHint()` —— 补上解释器缺失时的可操作提示
  （原先缺解释器只会显示「程序运行环境有问题，请联系管理员」）
- ✅ `PythonRuntime._whichSync` 的 PATH 分隔符改为按平台取
  （原来写死 `:` 和 `/`，在 Windows 上永远找不到东西）

> ⚠️ **未在本机验证的部分**：本仓库的开发机是 macOS，没有 Linux 环境，
> 所以 `flutter build linux` 这一段**没有实跑过**。
> 组装、`.desktop` 生成、`install.sh` 的安装/防呆/卸载三条路径是用桩程序
> 在 macOS 上跑通的（`PATH` 里放假 `uname` 与假 `flutter`，脚本本身未改动）。
> 首次在真机上跑请按第四节的清单逐项确认。
