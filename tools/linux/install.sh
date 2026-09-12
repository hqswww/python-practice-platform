#!/usr/bin/env bash
# ============================================================
# 把「编程练习册」装进当前用户的应用菜单（**不需要 root**）
#
# 用法（在解压出来的目录里）：
#   ./install.sh              # 安装
#   ./install.sh --uninstall  # 卸载（连同图标和菜单项一起清掉）
#
# 装到哪：
#   ~/.local/share/code_workbook/                        应用本体
#   ~/.local/share/applications/<APP_ID>.desktop         应用菜单入口
#   ~/.local/share/icons/hicolor/*/apps/<APP_ID>.png      图标（按尺寸放三份）
#
# 为什么不装到 /usr/local：
#   · 不用 sudo
#   · 卸载干净 —— 全部落在用户目录里，删掉这几处就没了
#   · 符合 XDG 规范（freedesktop.org），GNOME/KDE/XFCE 都认
#
# ⚠️ 图标必须按尺寸放进 hicolor 主题目录，并在 .desktop 里用
#   `Icon=<APP_ID>` 引用。GTK 应用不会从可执行文件里读图标 ——
#   这就是 Linux 上「图标没生效」最常见的原因。
# ============================================================

set -euo pipefail

APP_ID="com.sakiri.python-practice"
APP_NAME="编程练习册"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.local/share/code_workbook"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_ROOT="$HOME/.local/share/icons/hicolor"

ACTION="${1:-install}"

uninstall() {
  echo "正在卸载…"
  rm -rf "$DEST"
  rm -f "$DESKTOP_DIR/$APP_ID.desktop"
  for size in 128 256 512; do
    rm -f "$ICON_ROOT/${size}x${size}/apps/$APP_ID.png"
  done
  refresh_caches
  echo "✅ 已卸载（应用本体、菜单项、图标都已清掉）"
}

refresh_caches() {
  command -v update-desktop-database >/dev/null 2>&1 &&
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 &&
    gtk-update-icon-cache -f -t "$ICON_ROOT" >/dev/null 2>&1 || true
}

case "$ACTION" in
  --uninstall|-u) uninstall; exit 0 ;;
  install|--install) ;;
  *) echo "用法: $0 [--uninstall]"; exit 1 ;;
esac

# ------------------------------------------------------------ 前置检查

[[ -x "$SRC/code_workbook" ]] || {
  echo "❌ 当前目录里没有可执行文件 code_workbook。"
  echo "   请在**解压后**的分发目录里运行本脚本（当前：${SRC}）"
  exit 1
}

# 图标缺失不算致命，但要提醒 —— 否则菜单里就是个通用占位图标
ICON_OK=1
for size in 128 256 512; do
  [[ -f "$SRC/app_icon_${size}.png" ]] || ICON_OK=0
done
[[ "$ICON_OK" == "1" ]] || echo "⚠️  缺部分图标文件，菜单里可能显示默认图标"

# ⚠️ 安装时会把本脚本一起复制进 ${DEST}，好让用户随时能用它卸载。
# 但这带来一个危险情形：$SRC == $DEST 时，下述「先 rm -rf 再 cp」会把正在
# 复制的源删掉 —— 应用直接没了。必须先挡掉。
if [[ "$SRC" == "$DEST" ]]; then
  echo "❌ 这里已经是安装好的副本（${DEST}），不能从它自己重新安装。"
  echo "   卸载：$0 --uninstall"
  echo "   重装：回到解压出来的分发目录，再跑那里的 ./install.sh"
  exit 1
fi

# ---------------------------------------------------------------- 装本体

echo "=== 1/3 复制应用本体 ==="
rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$SRC"/. "$DEST"/
# 分发目录里的 .desktop 写的是**解压时**的绝对路径，装完位置变了，
# 删掉由下面重新生成。install.sh 则要留下 —— 用户靠它卸载。
rm -f "$DEST/${APP_NAME}.desktop"
chmod +x "$DEST/code_workbook" "$DEST/install.sh" 2>/dev/null || true
echo "  ✅ $DEST"

# ------------------------------------------------------------------ 装图标

if [[ "$ICON_OK" == "1" ]]; then
  echo "=== 2/3 安装图标 ==="
  for size in 128 256 512; do
    target="$ICON_ROOT/${size}x${size}/apps"
    mkdir -p "$target"
    cp "$SRC/app_icon_${size}.png" "$target/$APP_ID.png"
  done
  echo "  ✅ $ICON_ROOT/*/apps/$APP_ID.png"
else
  echo "=== 2/3 跳过图标（文件不全）==="
fi

# ------------------------------------------------------------ 装菜单入口

echo "=== 3/3 写入应用菜单入口 ==="
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/$APP_ID.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=${APP_NAME}
GenericName=编程练习
Comment=本地判题的编程练习与刷题工具（Python / C / C++）
Exec="${DEST}/code_workbook"
Icon=${APP_ID}
Terminal=false
Categories=Education;Development;
Keywords=编程;练习;Python;C;C++;刷题;
StartupWMClass=${APP_ID}
DESKTOP
chmod +x "$DESKTOP_DIR/$APP_ID.desktop"
refresh_caches
echo "  ✅ $DESKTOP_DIR/$APP_ID.desktop"

echo
echo "✅ 安装完成！在应用菜单里搜索「${APP_NAME}」或「编程」即可启动。"
echo "   卸载：\"$DEST/install.sh\" --uninstall"
echo
echo "提示：判题用**系统环境**。如果应用里提示找不到编译器，"
echo "      到「设置 → 代码编辑」看它给出的具体安装命令。"
