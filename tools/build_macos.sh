#!/usr/bin/env bash
# ============================================================
# 编程练习册 · macOS 一键打包脚本（对标 tools/build_windows.ps1）
#
# 用法（项目根目录）：
#   bash tools/build_macos.sh
#   bash tools/build_macos.sh --skip-python          # 不捆绑，用系统 Python（自用）
#   bash tools/build_macos.sh --sign "Developer ID Application: XXX (TEAMID)"
#
# 它做 6 步：
#   1. flutter build macos --release            → 编译 .app（产物是 universal）
#   2. 探测产物架构 → 决定要带哪几份 python-build-standalone
#   3. 每份解包到 <App>.app/Contents/Frameworks/python-<arch>/
#   4. 裁掉判题用不到的 Tcl/Tk、idlelib 等（每份省 ~12MB）
#   5. 自底向上签名（先签所有嵌套 Mach-O，再签 .app）
#   6. ditto 打成可分发 zip → dist/
#
# 为什么捆绑 Python：
#   macOS 的 /usr/bin/python3 只是 Xcode Command Line Tools 的 shim。
#   目标机器没装 CLT 时，执行它会弹系统安装提示甚至卡住 →
#   跟 Windows 版「免装 Python」一样，必须自带解释器。
#
# 为什么是两份：
#   `flutter build macos --release` 产出的是 universal 二进制（x86_64 + arm64
#   在同一份 .app 里，且 flutter 没有架构开关），而 Python 是单架构的。
#   所以两种架构各带一份，运行时由 python_runtime.dart 按当前架构挑。
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

# ---- 可调参数 ----
PY_VER="${PY_VER:-3.12.14}"            # 与 Windows 版同为 3.12 线
PBS_TAG="${PBS_TAG:-20260901}"         # python-build-standalone 发布 tag
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-编程练习册}"
TRIM="${TRIM:-1}"                      # 1=裁减无用组件
SKIP_PYTHON=0
SIGN_IDENTITY="${SIGN_IDENTITY:--}"    # 默认 ad-hoc（"-"）

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-python) SKIP_PYTHON=1; shift ;;
    --sign)        SIGN_IDENTITY="$2"; shift 2 ;;
    --no-trim)     TRIM=0; shift ;;
    -h|--help)     sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

RELEASE_DIR="build/macos/Build/Products/Release"
DIST_DIR="dist"
CACHE_DIR="build/.pbs-cache"

# ---------------------------------------------------------------- 1. 编译

echo "=== 1/6 编译 macOS Release ==="
command -v flutter >/dev/null 2>&1 || { echo "❌ 找不到 flutter"; exit 1; }
flutter build macos --release

APP="$(find "$RELEASE_DIR" -maxdepth 1 -name '*.app' -print -quit)"
[[ -n "$APP" && -d "$APP" ]] || { echo "❌ 没找到 .app（${RELEASE_DIR}）"; exit 1; }
echo "产物: $APP"

# ------------------------------------------- 1.5 重建完整尺寸的 AppIcon.icns
#
# ⚠️ Xcode 从 asset catalog 编出来的 AppIcon.icns **只到 256×256**
# （实测块只有 ic04/ic07/ic11/ic13；原始 Flutter 工程也一样，不是我们改坏的）。
# 结果是 Finder 大图标视图、App 切换器、Quick Look 下图标发糊。
# 这里用 iconutil 重新打一份 16→1024 的完整阶梯。
#
# 必须放在签名之前：改 Contents/Resources 会让已有签名失效。
ICON_SRC="macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"
if [[ -f "$ICON_SRC" ]] && command -v iconutil >/dev/null 2>&1; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  # sips -z 的参数顺序是「高 宽」，这里都是正方形所以一样
  for spec in "16:icon_16x16" "32:icon_16x16@2x" "32:icon_32x32" "64:icon_32x32@2x" \
              "128:icon_128x128" "256:icon_128x128@2x" "256:icon_256x256" \
              "512:icon_256x256@2x" "512:icon_512x512" "1024:icon_512x512@2x"; do
    px="${spec%%:*}"; nm="${spec##*:}"
    sips -z "$px" "$px" "$ICON_SRC" --out "$ICONSET/$nm.png" >/dev/null 2>&1 || true
  done
  if iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null; then
    echo "✅ 已重建 AppIcon.icns（16→1024 完整尺寸）"
  else
    echo "⚠️  iconutil 失败，沿用 Xcode 生成的 icns"
  fi
  rm -rf "$(dirname "$ICONSET")"
fi

# ---------------------------------------------------------------- 2. 架构
#
# ⚠️ 关键事实（实测）：`flutter build macos --release` 的产物是
# **universal 二进制**（x86_64 与 arm64 在同一份 .app 里），而且
# `flutter build macos` **没有**架构开关。
# 但捆绑的 Python 是单架构的 → 必须两份都带，按架构分目录放：
#     Contents/Resources/python-x86_64/bin/python3
#     Contents/Resources/python-arm64/bin/python3
# 运行时由 python_runtime.dart 的 currentMacArchDirName()（Abi.current()）
# 挑对应那一份。只带一份的话，另一个架构上会 Bad CPU type in executable。
#
# ⚠️ 放 Resources 而不是 Frameworks（实测踩坑）：codesign 会把
# Frameworks 下**任何目录**当「嵌套代码」解析，Python 这种散文件大树放进去
# 会直接签名失败（"code object is not signed at all" / "bundle format
# unrecognized"）。放 Resources 则按资源封存，只需单独签里面的 Mach-O。

echo
echo "=== 2/6 探测产物架构 ==="
EXEC_NAME="$(defaults read "$PWD/$APP/Contents/Info.plist" CFBundleExecutable)"
MAIN_BIN="$APP/Contents/MacOS/$EXEC_NAME"
[[ -f "$MAIN_BIN" ]] || { echo "❌ 找不到主可执行文件: $MAIN_BIN"; exit 1; }

ARCHS="$(lipo -archs "$MAIN_BIN")"
echo "主程序架构: $ARCHS"

# 架构 → (python-build-standalone triple, 捆绑目录名)
TRIPLES=()
ARCH_DIRS=()
for a in $ARCHS; do
  case "$a" in
    x86_64) TRIPLES+=("x86_64-apple-darwin");  ARCH_DIRS+=("python-x86_64") ;;
    arm64)  TRIPLES+=("aarch64-apple-darwin"); ARCH_DIRS+=("python-arm64") ;;
    *) echo "❌ 未知架构: $a"; exit 1 ;;
  esac
done

if [[ ${#TRIPLES[@]} -gt 1 ]]; then
  ARCH_TAG="universal"
else
  ARCH_TAG="${ARCHS// /}"
fi
echo "将捆绑 ${#TRIPLES[@]} 份 Python ($ARCH_TAG): ${ARCH_DIRS[*]}"

# 本机对应的捆绑目录名（只有这一份能就地执行自检）
host_py_dir() {
  case "$(uname -m)" in
    x86_64) echo "python-x86_64" ;;
    arm64)  echo "python-arm64" ;;
    *)      echo "" ;;
  esac
}

# ------------------------------------------------------- 3+4. 捆绑 + 裁减

bundle_python() {
  local triple="$1" arch_dir="$2"
  local asset="cpython-${PY_VER}+${PBS_TAG}-${triple}-install_only_stripped.tar.gz"
  local tarball="$CACHE_DIR/$asset"
  local url="https://github.com/astral-sh/python-build-standalone/releases/download/${PBS_TAG}/${asset}"

  echo "--- $arch_dir ($triple) ---"
  if [[ -f "$tarball" ]]; then
    echo "  命中缓存: $asset"
  else
    echo "  下载: $url"
    curl -fSL --retry 3 --connect-timeout 20 -o "$tarball.part" "$url" \
      || { echo "  ❌ 下载失败，检查网络或 PY_VER/PBS_TAG"; rm -f "$tarball.part"; return 1; }
    mv "$tarball.part" "$tarball"
  fi

  local stage
  stage="$(mktemp -d)"
  tar xzf "$tarball" -C "$stage"
  if [[ ! -d "$stage/python" ]]; then
    echo "  ❌ 压缩包结构与预期不符（应为 python/ 顶层）"; rm -rf "$stage"; return 1
  fi

  local dest="$APP/Contents/Resources/$arch_dir"
  rm -rf "$dest"
  mkdir -p "$APP/Contents/Resources"
  mv "$stage/python" "$dest"
  rm -rf "$stage"
  echo "  已放入: $dest"

  # 裁掉判题用不到的组件（Tcl/Tk 约 8MB，idlelib/2to3 等约 4MB）
  if [[ "$TRIM" == "1" ]]; then
    local site
    site="$(find "$dest/lib" -maxdepth 1 -type d -name 'python3.*' -print -quit)"
    for p in "$dest/lib"/libtcl*.dylib "$dest/lib"/libtk*.dylib \
             "$dest/lib"/tcl* "$dest/lib"/tk* "$dest/lib"/itcl* \
             "$dest/lib"/thread* "$dest/lib"/tdbc* \
             "$dest/include" "$dest/share" \
             "$dest/bin"/idle3* "$dest/bin"/2to3* \
             "$dest/bin"/pydoc3* "$dest/bin"/tclsh* "$dest/bin"/wish*; do
      [[ -e "$p" ]] && rm -rf "$p"
    done
    if [[ -n "$site" ]]; then
      for p in idlelib tkinter turtledemo lib2to3 turtle.py test; do
        [[ -e "$site/$p" ]] && rm -rf "$site/$p"
      done
    fi
  fi
  echo "  体积: $(du -sh "$dest" | cut -f1)"

  # 冒烟测试：只有本机架构那一份能就地跑，另一份必然 Bad CPU type（正常）
  #
  # ⚠️ 必须带 -B（不写字节码缓存）。Python 默认会往自己的 lib 目录写
  # `__pycache__/*.pyc`，而这里跑的解释器**就在 .app 里面** —— 跑一下就等于
  # 改了应用包。签名会把包内资源封存，事后新增文件会让
  # `codesign --verify` 报「a sealed resource is missing or invalid」。
  # 虽然应用侧也设了 PYTHONDONTWRITEBYTECODE（见 python_runtime.dart），
  # 但这一句是构建脚本直接调解释器，得自己带上，否则包里会带一堆没用的缓存。
  if [[ "$arch_dir" == "$(host_py_dir)" ]]; then
    if PYTHONPATH="" PYTHONDONTWRITEBYTECODE=1 \
        "$dest/bin/python3" -B -X utf8 -c "print('ok')" >/dev/null 2>&1; then
      echo "  ✅ 本机架构解释器可执行（含 -X utf8）"
    else
      echo "  ⚠️  本机架构解释器自检未通过（签名前可能被 Gatekeeper 拦，签名后复查）"
    fi
  else
    echo "  ℹ️  非本机架构，跳过执行自检（本机跑不了，属正常）"
  fi
}

if [[ "$SKIP_PYTHON" == "1" ]]; then
  echo
  echo "=== 3+4/6 跳过捆绑 Python（--skip-python）==="
  echo "   注意：目标机器没装 Command Line Tools 时判题会失败（只能回退系统 python3）。"
else
  echo
  echo "=== 3+4/6 下载并捆绑 Python $PY_VER ==="
  mkdir -p "$CACHE_DIR"
  for i in "${!TRIPLES[@]}"; do
    bundle_python "${TRIPLES[$i]}" "${ARCH_DIRS[$i]}" || exit 1
  done
fi

# ---------------------------------------------------------------- 5. 签名

echo
echo "=== 5/6 代码签名（identity: ${SIGN_IDENTITY}）==="
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "使用 ad-hoc 签名（本地可分发自用；对外分发建议用 Developer ID + 公证）"
  TS_FLAG="--timestamp=none"
  RUNTIME_FLAG=""
else
  echo "使用 Developer ID 签名；公证需要 --options runtime"
  TS_FLAG="--timestamp"
  RUNTIME_FLAG="--options runtime"
fi

# ⚠️ 必须显式带上 entitlements。
# `codesign --force` 重新签名会把 Xcode 原本应用的 entitlements **整个丢掉**——
# 不传这个参数，最终产物 `codesign -d --entitlements -` 就是空的（实测确认过）。
# 后果分两种情况：
#   · app-sandbox=false 丢了无所谓：entitlements 里 false 等价于不存在，沙盒仍是关的
#   · 但 disable-library-validation=true 丢了会出事：走 Developer ID + 公证时会开
#     Hardened Runtime，捆绑 Python 的 .so/.dylib 不是同一团队签的，库校验会拒绝
#     加载 → 判题直接跑不起来。而这个坑 ad-hoc 本地测试**测不出来**。
ENT_FILE="macos/Runner/Release.entitlements"
if [[ -f "$ENT_FILE" ]]; then
  echo "签名附带 entitlements: $ENT_FILE"
else
  echo "⚠️  找不到 $ENT_FILE，将以无 entitlements 方式签名"
  ENT_FILE=""
fi

MACHO_LIST="$(mktemp)"
trap 'rm -f "$MACHO_LIST"' EXIT

# 收集候选 Mach-O。
# 刻意**不用** `find "$APP" -print0 | file` 全树扫描：Python 树有几千个 .py，
# 逐文件调 `file` 会慢到几分钟。按位置/扩展名精准定位就够了。
collect_candidates() {
  # Flutter 自己的 framework + 主程序（文件少，直接全收）
  find "$APP/Contents/MacOS" "$APP/Contents/Frameworks" -type f -print0 2>/dev/null
  # 捆绑 Python 里的二进制
  local d
  for d in "$APP/Contents/Resources"/python-*; do
    [[ -d "$d" ]] || continue
    find "$d/bin" -type f ! -name '*.py' -print0 2>/dev/null
    find "$d/lib" -maxdepth 1 -type f -name '*.dylib' -print0 2>/dev/null
    find "$d" -type f -name '*.so' -print0 2>/dev/null
  done
}

CAND=0
while IFS= read -r -d '' f; do
  if file -b "$f" 2>/dev/null | grep -q "Mach-O"; then
    printf '%s\0' "$f" >> "$MACHO_LIST"
    CAND=$((CAND + 1))
  fi
done < <(collect_candidates)
echo "待签名 Mach-O: $CAND 个"

SIGNED=0
while IFS= read -r -d '' f; do
  # shellcheck disable=SC2086
  if ! err="$(codesign --force $TS_FLAG $RUNTIME_FLAG --sign "$SIGN_IDENTITY" "$f" 2>&1)"; then
    echo "❌ 签名失败: ${f#$APP/}"
    printf '%s\n' "$err" | sed 's/^/    /'
    exit 1
  fi
  SIGNED=$((SIGNED + 1))
done < "$MACHO_LIST"
echo "已签名嵌套二进制: $SIGNED 个"

# 最后签 .app 本体（不带 --deep，让它重新封存整个 bundle 的 CodeResources）
# entitlements 加在这一步：签 bundle 时会一并应用到主可执行文件，是标准做法；
# 嵌套的 .dylib/.so 不需要各自的 entitlements。
# shellcheck disable=SC2086
if [[ -n "$ENT_FILE" ]]; then
  codesign --force $TS_FLAG $RUNTIME_FLAG --entitlements "$ENT_FILE" \
    --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force $TS_FLAG $RUNTIME_FLAG --sign "$SIGN_IDENTITY" "$APP"
fi
echo "✅ 签名完成"

# 回读校验：entitlements 必须真的嵌进去了。
# 这里踩过坑——漏传 --entitlements 时签名照样"成功"，只有回读才发现是空的。
echo "--- entitlements 回读 ---"
if codesign -d --entitlements - --xml "$APP" 2>/dev/null | \
   python3 -c "import sys,plistlib;d=plistlib.loads(sys.stdin.buffer.read());print('  app-sandbox =',d.get('com.apple.security.app-sandbox'));print('  disable-library-validation =',d.get('com.apple.security.cs.disable-library-validation'))" 2>/dev/null; then
  :
else
  echo "  ⚠️  未能读出嵌入的 entitlements（ad-hoc 下可能被省略），请人工核对"
fi

echo "--- 校验 ---"
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | tail -3 || true

# ---------------------------------------------------------------- 6. 打包

echo
echo "=== 6/6 打包（dmg 安装包 + zip 绿色版）==="
mkdir -p "$DIST_DIR"
NAME_SAFE="编程练习册"
ZIP="$DIST_DIR/${NAME_SAFE}-macOS-${ARCH_TAG}.zip"
DMG="$DIST_DIR/${NAME_SAFE}-macOS-${ARCH_TAG}.dmg"

# ---- 6a. dmg 安装包（主要分发形式）----
#
# 做成「打开后把图标拖进 Applications」的经典形式：
#   卷里放 .app 本体 + 一个指向 /Applications 的符号链接当作落点，
#   再附一份首次打开的说明（Gatekeeper 那道坎得让**最终用户**看得到，
#   写在构建脚本的输出里他们看不到）。
#
# 不做的两件事，都是有意的：
#   · **不做花哨的窗口布局**（自定义背景图、图标坐标）：那要靠 AppleScript
#     驱动 Finder，在无 GUI 会话里会挂住。收益只是好看，风险是构建立不起来。
#   · **不压缩时用 UDBZ**：UDZO 通用性最好，体积差别不大。
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# ⚠️ 打包时把 .app 改名成中文，让「磁盘上的名字 / Finder 显示的名字 / 说明文案」
#    三处一致。
#
# Xcode 产出的是 `code_workbook.app`（PRODUCT_NAME，为了跟 Windows/Linux 的可执行
# 文件名统一）。Finder 靠 CFBundleDisplayName 显示成「编程练习册」，所以用户平时
# 看不出差别 —— 但**终端里、脚本里、说明文档里**那个名字是 code_workbook.app，
# 而分发提示写的是 `/Applications/编程练习册.app`，指向了一个不存在的路径。
#
# 改名是安全的，已实测：签名覆盖的是包**内容**，不含目录名；
# CFBundleExecutable 与 Contents/MacOS/ 里的文件名都没动，仍然对得上。
APP_NAME="编程练习册.app"
# 必须用 ditto 复制：cp -R 会破坏 .app 的符号链接/扩展属性，进而弄坏签名
ditto "$APP" "$STAGE/$APP_NAME"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/首次打开请先读我.txt" <<'NOTE'
编程练习册 —— 首次打开说明
================================

安装
----
把左边的「编程练习册」拖到右边的 Applications（应用程序）文件夹即可。

第一次打开被系统拦住？
----------------------
本应用没有购买 Apple 开发者签名证书，macOS 第一次打开时会提示
「来自身份不明的开发者」或「无法验证开发者」。这是正常的，按下面任一种做即可：

  方法一（推荐）
    在「应用程序」里找到它 → 右键（或按住 Control 点击）→ 选「打开」
    → 弹窗里再点一次「打开」。以后就正常了。

  方法二
    打开「系统设置 → 隐私与安全性」，往下找到被拦的提示，
    点「仍要打开」。

需要 C / C++ 判题的话
--------------------
Python 判题自带解释器，无需任何安装。
C / C++ 用的是你电脑上的编译器，没装的话打开应用后
在「设置 → 代码编辑」里会看到提示和安装命令（xcode-select --install）。
NOTE

rm -f "$DMG"
hdiutil create -volname "$NAME_SAFE" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG" >/dev/null

# 有真实签名身份时把 dmg 也签上（公证要求这一步；ad-hoc 签了也无害）
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" $TS_FLAG "$DMG" 2>/dev/null &&
    echo "  ✅ 已签名 dmg" || echo "  ⚠️  dmg 签名失败（不影响使用）"
fi

# ---- 6b. zip 绿色版（保留：有人偏好解压即用、不进 Applications）----
#
# ⚠️ 这里刻意**不**改名，用的是 Xcode 原始产物 `code_workbook.app`。
#
# 原因是个编码陷阱：`ditto -c -k` 写 zip 时用的是 UTF-8 字节，但**不设 UTF-8
# 标志位**（实测 2438 个条目一个都没设）。macOS 自己的归档工具按 UTF-8 解释，
# 解出来名字是对的；但 Windows 资源管理器、Linux 的 unzip 会按 CP437 解，
# 中文名就成了「τ╝ûτ¿ïτ╗âΣ╣áσåî.app」那种乱码。
#
# zip 本来就是给 macOS 用户解压即用的，ASCII 名不影响观感 ——
# Finder 靠 CFBundleDisplayName 显示的仍然是「编程练习册」。
# dmg 那边没这个问题（磁盘文件系统原生支持 Unicode，不经过 zip 编码层），
# 所以 dmg 里用中文名。
rm -f "$ZIP"
# ditto 才能正确保留符号链接与扩展属性（用 zip 命令会破坏 .app）
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo
echo "✅ 完成！"
echo "  App : $APP  ($(du -sh "$APP" | cut -f1))"
echo "  Dmg : $DMG  ($(du -sh "$DMG" | cut -f1))   ← 发给用户的安装包"
echo "  Zip : $ZIP  ($(du -sh "$ZIP" | cut -f1))   ← 绿色版，解压即用"
cat <<'EOF'

分发提示：
  1. **dmg 是给别人用的那个**：双击打开 → 把图标拖进 Applications → 完成。
     卷里附了「首次打开请先读我.txt」，把 Gatekeeper 那步写清楚了 ——
     用户看不到构建脚本的输出，这一步得留在包里。
  2. 未公证的包首次打开会被 Gatekeeper 拦（"来自身份不明的开发者"）。
     让对方右键 →「打开」，或执行：
         xattr -dr com.apple.quarantine "/Applications/编程练习册.app"
     ⚠️ 安装包本身不能免掉这道坎 —— 那是签名证书的事，不是打包形式的事。
  3. 想彻底免提示，需要 Apple Developer 账号（$99/年）走 codesign + notarytool 公证，
     用 --sign "Developer ID Application: ..." 重跑本脚本（dmg 会一并签名），
     再 notarytool submit 那个 dmg。
  4. universal 包会同时带 x86_64 与 arm64 两份 Python，所以体积比单架构大约一倍。
     只想给一种架构的人用时，可在 Xcode 里把 ARCHS 设成单一架构后重跑本脚本，
     体积能省下一份 Python（约 54MB）。
EOF
