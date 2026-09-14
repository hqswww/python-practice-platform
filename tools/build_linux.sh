#!/usr/bin/env bash
# ============================================================
# 编程练习册 · Linux 一键打包脚本（对标 build_macos.sh / build_windows.ps1）
#
# 用法（Linux 机器上的项目根目录）：
#   bash tools/build_linux.sh
#   bash tools/build_linux.sh --no-tar        # 只组装目录，不打 tar.gz
#
# 它做 4 步：
#   1. flutter build linux --release          → 编译
#   2. 组装 dist/编程练习册-linux-<arch>/      → 可执行文件 + data/ + lib/
#   3. 放进应用图标与 .desktop 入口（GTK 不看可执行文件里的图标，必须有这些）
#   4. 打 tar.gz → dist/
#
# ⚠️ **本脚本必须在 Linux 上运行**：Flutter 桌面版走的是各平台原生工具链
#    （Linux = GTK3 + CMake + clang），无法在 macOS/Windows 上交叉编译。
#
# ------------------------------------------------------------
# 为什么**不捆绑** Python（与 macOS/Windows 不同）
#
# 这是刻意的，不是漏了：
#   · Linux 桌面发行版自带 python3 —— 查过 Ubuntu 24.04.3 Desktop 的官方安装
#     清单，python3 3.12.3 就在默认安装里。而且本平台判题只用标准库，
#     不涉及 pip / PEP 668 那套麻烦。
#   · 多带一份解释器要给每个发行版、每种架构各加 ~54MB，收益不成正比。
#
# gcc/g++ 则**确实不在**默认安装里（同一份清单里只有 gcc-13-base 这种版本
# 元数据包，没有编译器本体）。这与「Windows 要用户装 MinGW」是同一条既定
# 路线：用系统编译器，不捆进应用。
#
# 好消息是缺件不再需要用户自己猜：# 设置页的「代码编辑 → 编译器/解释器」
# 卡片会做自检，直接显示「未找到编译器」以及 `sudo apt install build-essential`
# 这样的具体命令（见 lib/services/{c_runtime,python_runtime}.dart 的 installHint）。
# ============================================================

# ---------------------------------------------------------------
# 确保用**真正的 bash** 运行本脚本
#
# 本脚本用了 bash 扩展（进程替换 `done < <(...)`、数组、`[[ ]]`、`local`），
# 换 POSIX sh 解析会出问题：
#   · macOS 的 /bin/sh 是 bash 3.2 的 POSIX 模式 → 进程替换直接语法报错；
#     而 bash 是**边解析边执行**的，所以前面几步会正常跑完、错误在中途突然
#     冒出来，看起来像"跑到一半随机坏掉"。
#   · Linux 的 /bin/sh 往往是 dash → `[[ ]]` 会在运行时变成「command not found」，
#     比语法错误更隐蔽。
#
# ⚠️ 不能靠 BASH_VERSION 判断：当 sh 本身就是 bash 时它**照样有值**。
#    要看 posix 选项。带一个环境变量做标记，杜绝万一还能来回 exec 的死循环。
# ---------------------------------------------------------------
if [ -z "${CODE_WORKBOOK_BASH:-}" ]; then
  if [ -z "${BASH_VERSION:-}" ] ||
     [ "$(set -o 2>/dev/null | awk '$1 == "posix" { print $2 }')" = "on" ]; then
    CODE_WORKBOOK_BASH=1
    export CODE_WORKBOOK_BASH
    exec bash "$0" "$@"
  fi
fi

set -euo pipefail

cd "$(dirname "$0")/.."

APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-编程练习册}"
APP_ID="com.sakiri.python-practice"   # 与 linux/CMakeLists.txt 的 APPLICATION_ID 一致
MAKE_TAR=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-tar)  MAKE_TAR=0; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# Linux 专有脚本的护栏：在别的系统上跑只会得到一个看不懂的 CMake 报错
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "❌ 本脚本只能在 Linux 上运行（当前：$(uname -s)）。"
  echo "   Flutter 的 Linux 桌面产物无法在其它系统上交叉编译。"
  exit 1
fi

case "$(uname -m)" in
  x86_64|amd64) ARCH_TAG="x86_64" ;;
  aarch64|arm64) ARCH_TAG="arm64" ;;
  *) ARCH_TAG="$(uname -m)" ;;
esac

# ⚠️ ARCH_TAG 只用来给**分发包命名**（`x86_64` 是 Linux 圈的通用写法），
#    不能拿去拼 Flutter 的构建目录 —— Flutter 用的是自己的架构名 `x64` / `arm64`，
#    两套写法不一样。曾经这里写成 `build/linux/${ARCH_TAG}/release/bundle`，
#    在 x86_64 机器上就是找一个根本不存在的 `build/linux/x86_64/...`，
#    于是被下面的兜底 find 接住，捞起一个**旧的 debug 产物**继续往下走。
#    产物路径统一在编译之后从 release 目录里找（见第 1 步末尾）。

DIST_DIR="dist/${APP_DISPLAY_NAME}-linux-${ARCH_TAG}"
ICON_DIR="linux/resources"
INSTALLER="tools/linux/install.sh"

# ---------------------------------------------------------------- 1. 编译

echo "=== 1/4 编译 Linux Release（${ARCH_TAG}）==="
command -v flutter >/dev/null 2>&1 || { echo "❌ 找不到 flutter"; exit 1; }

if ! flutter doctor 2>/dev/null | grep -q "Linux toolchain.*✓\|Linux toolchain - develop"; then
  echo "ℹ️  flutter doctor 没确认 Linux 工具链；若编译失败，先按提示装："
  echo "     sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev"
fi

flutter build linux --release

# 产物路径只从 **release** 目录里找，且必须唯一。
#
# 不写死架构目录名：Flutter 用的是 x64 / arm64，跟 `uname -m` 的
# x86_64 / aarch64 不是一套写法（这就是上面注释里那个 bug 的来源）。
#
# ⚠️ 这里**刻意不做 `find ... -name bundle` 那种宽松兜底**。踩过一次：
#    路径拼错 → 找不到 → 兜底 find 捞到了 build/linux/x64/**debug**/bundle ——
#    一个几天前 `flutter run` 留下的旧产物。后面的步骤全都"成功"了，
#    只是打出来的是一个 debug 版的旧程序。**宁可直接失败，也不能发错东西。**
BUNDLE_DIR=""
for d in build/linux/*/release/bundle; do
  [[ -d "$d" ]] || continue
  if [[ -n "$BUNDLE_DIR" ]]; then
    echo "❌ 找到多个 release 产物，不知道该用哪个："
    echo "     $BUNDLE_DIR"
    echo "     $d"
    echo "   先清掉再来一次：rm -rf build/linux"
    exit 1
  fi
  BUNDLE_DIR="$d"
done

[[ -n "$BUNDLE_DIR" ]] || {
  echo "❌ 没找到 release 产物（找过 build/linux/*/release/bundle）。"
  echo "   上面 flutter build 的输出里应当有一行「✓ Built build/linux/<arch>/release/bundle/…」，"
  echo "   对照一下它到底写在哪儿。"
  exit 1
}
echo "产物: $BUNDLE_DIR"
ls -1 "$BUNDLE_DIR"

# ------------------------------------------------------------- 2. 组装目录

echo "=== 2/4 组装分发目录 ==="
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -a "$BUNDLE_DIR"/. "$DIST_DIR"/

EXE="$DIST_DIR/code_workbook"     # linux/CMakeLists.txt 里的 BINARY_NAME
[[ -x "$EXE" ]] || { echo "❌ 可执行文件不在预期位置：$EXE"; exit 1; }

# ------------------------------------------------- 3. 图标 + .desktop 入口

echo "=== 3/4 放入图标与桌面入口 ==="
if ! ls "$ICON_DIR"/app_icon_*.png >/dev/null 2>&1; then
  echo "❌ 缺 Linux 图标（${ICON_DIR}/app_icon_*.png）。"
  echo "   先生成：uv run --with pillow python tools/make_icons.py"
  exit 1
fi

ICON_ABS="$(cd "$DIST_DIR" && pwd)/app_icon_512.png"
EXE_ABS="$(cd "$DIST_DIR" && pwd)/code_workbook"

# 图标放在应用目录里（而不是装到 hicolor 主题）：绿色版解压即用，
# 不写系统目录。想进应用菜单就跑随包附带的 install.sh。
#
# StartupWMClass 要和 GTK 的 prgname（= APPLICATION_ID）一致，任务栏才能把
# 窗口和这个 .desktop 对上，否则托盘里会多出一个无名图标。
# .desktop 里刻意不写注释行：规范虽允许 `#`，但各家解析器宽严不一，
# 这几句说明留在本脚本里就够了。
cp "$ICON_DIR"/app_icon_*.png "$DIST_DIR"/

cat > "$DIST_DIR/${APP_DISPLAY_NAME}.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=${APP_DISPLAY_NAME}
GenericName=编程练习
Comment=本地判题的编程练习与刷题工具（Python / C / C++）
Exec="${EXE_ABS}"
Icon=${ICON_ABS}
Terminal=false
Categories=Education;Development;
Keywords=编程;练习;Python;C;C++;刷题;
StartupWMClass=${APP_ID}
DESKTOP
echo "  ✅ ${APP_DISPLAY_NAME}.desktop（Exec/Icon 已填成解压后的绝对路径）"

if [[ -f "$INSTALLER" ]]; then
  cp "$INSTALLER" "$DIST_DIR/install.sh"
  chmod 755 "$DIST_DIR/install.sh"   # 显式 755：cp 会带上源文件权限
  echo "  ✅ install.sh（想把应用放进应用菜单就跑它）"
fi

# --------------------------------------------------------------- 4. 打包

echo "=== 4/4 打包 ==="
if [[ "$MAKE_TAR" == "1" ]]; then
  TARBALL="dist/${APP_DISPLAY_NAME}-linux-${ARCH_TAG}.tar.gz"
  rm -f "$TARBALL"
  # tar 而不是 zip：Linux 上要保留可执行位，zip 容易把权限丢掉
  tar -czf "$TARBALL" -C dist "$(basename "$DIST_DIR")"
  echo "  ✅ $TARBALL"
fi

echo
echo "✅ 完成！"
echo "  目录 : $DIST_DIR  ($(du -sh "$DIST_DIR" | cut -f1))"
[[ "$MAKE_TAR" == "1" ]] && echo "  压缩 : ${TARBALL:-}  ($(du -sh "$TARBALL" | cut -f1))"
echo
echo "分发提示："
echo "  1. 解压后直接跑 ./code_workbook 即可，无需安装任何东西。"
echo "  2. 想让它在应用菜单里出现，跑解压目录里的 ./install.sh"
echo "     （装到 ~/.local/share，不需要 root）。"
echo "  3. 判题依赖**系统环境**，缺什么应用会在「设置 → 代码编辑」里直接告诉你："
echo "     · python3 —— 主流桌面发行版自带，一般不用管"
echo "     · gcc / g++ —— Ubuntu/Debian 要 sudo apt install build-essential"
echo "  4. 首次从文件管理器双击可能因「可执行权限」被拦，右键属性里勾上即可；"
echo "     命令行跑则不会有这个问题。"
