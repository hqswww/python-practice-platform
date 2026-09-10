#!/usr/bin/env bash
# ============================================================
# Python 练习平台 · macOS 脚手架生成 + 关键配置修正
#
# 用法（项目根目录）：
#   bash tools/setup_macos_platform.sh
#
# 它做三件事：
#   1. flutter create --platforms=macos .  → 生成 macos/ 工程（当前只有 linux/ windows/）
#   2. **关闭 App Sandbox**（关键！见下）
#   3. 设定显示名与 Bundle ID
#
# 为什么必须关沙盒：
#   Flutter 的 macOS 模板在 Debug/Release 两份 entitlements 里都默认开启
#   com.apple.security.app-sandbox = true。开启后应用被关进
#   ~/Library/Containers/<bundle-id>/Data/ 这个容器里，导致：
#     · getApplicationDocumentsDirectory() → 容器内 Documents
#       （导出进度后用户在自己的「文稿」里根本找不到文件）
#     · getDownloadsDirectory() → 容器内 Downloads
#       （设置页「导入进度」扫描下载目录永远扫不到东西）
#     · 判题引擎 Process.start(python3) 受限（子进程继承沙盒）
#   本应用是本地自习工具，需要跑外部解释器 + 读写用户可见目录，故关闭沙盒。
# ============================================================

set -euo pipefail

cd "$(dirname "$0")/.."

APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-Python 练习平台}"
BUNDLE_ID="${BUNDLE_ID:-com.sakiri.python-practice}"

echo "=== 1/4 前置检查 ==="
if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ 找不到 flutter。请先安装 Flutter SDK（项目 pubspec.lock 要求 flutter >= 3.44.0）"
  exit 1
fi
echo "flutter: $(command -v flutter)"
flutter --version | head -2

echo
echo "=== 2/4 生成 macos/ 脚手架 ==="
flutter create --platforms=macos .

if [[ ! -d macos ]]; then
  echo "❌ macos/ 未生成，中止"
  exit 1
fi

echo
echo "=== 3/4 关闭 App Sandbox（Debug + Release）==="

# ⚠️ 坑：plutil 的 -replace/-insert 把 key 当「键路径」，"." 是层级分隔符。
# 直接写 `plutil -replace com.apple.security.app-sandbox ...` 会被拆成
# com → apple → security → app-sandbox 四层，报 "Key path not found" 且退出码 1。
# entitlement 的键恰好全是带点的，所以必须有这层转义封装。
plutil_key() { printf '%s' "$1" | sed 's/\./\\./g'; }

set_plist_bool() {
  local file="$1" raw_key="$2" val="$3" k
  k="$(plutil_key "$raw_key")"
  plutil -replace "$k" -bool "$val" "$file" 2>/dev/null \
    || plutil -insert "$k" -bool "$val" "$file"
}

get_plist_bool() {
  plutil -extract "$(plutil_key "$1")" raw -o - "$2" 2>/dev/null || echo "missing"
}

for f in macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements; do
  [[ -f "$f" ]] || { echo "❌ 缺少 $f"; exit 1; }

  # 关沙盒
  set_plist_bool "$f" "com.apple.security.app-sandbox" NO

  # 捆绑 Python 后要加载一批非本团队签名的 .so/.dylib。
  # 若 Release 开了 Hardened Runtime，库校验会拒绝加载 → 必须显式放开。
  # （未开 Hardened Runtime 时该键无效但无害，先写上省得到公证阶段才发现。）
  set_plist_bool "$f" "com.apple.security.cs.disable-library-validation" YES

  echo "--- $f ---"
  plutil -p "$f"

  # 回读校验：这类改动一旦静默失败，要到运行时（导出进度丢进容器）才暴露，
  # 排查成本极高 —— 所以这里直接卡死，绝不允许「以为改了其实没改」。
  sb="$(get_plist_bool com.apple.security.app-sandbox "$f")"
  if [[ "$sb" != "false" ]]; then
    echo "❌ $f 的 app-sandbox 仍是 '$sb'（期望 false）—— 关沙盒失败，中止"
    exit 1
  fi
  echo "✅ 已确认 app-sandbox = false"
done

# 沙盒关了，判题要跑子进程；顺带确认 JIT 许可仍在（Debug 热重载需要）
echo

echo "=== 4/4 显示名 / Bundle ID ==="
if [[ -f macos/Runner/Info.plist ]]; then
  plutil -replace CFBundleDisplayName -string "$APP_DISPLAY_NAME" macos/Runner/Info.plist 2>/dev/null \
    || plutil -insert CFBundleDisplayName -string "$APP_DISPLAY_NAME" macos/Runner/Info.plist
  echo "CFBundleDisplayName = $APP_DISPLAY_NAME"
fi

if [[ -f macos/Runner/Configs/AppInfo.xcconfig ]]; then
  # PRODUCT_NAME 保持 ASCII（工程名），中文名走 CFBundleDisplayName，
  # 避免非 ASCII 产品名把 xcodebuild / 签名流程搞出奇怪问题。
  sed -i '' "s|^PRODUCT_BUNDLE_IDENTIFIER = .*|PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID|" \
    macos/Runner/Configs/AppInfo.xcconfig
  grep -E "^(PRODUCT_NAME|PRODUCT_BUNDLE_IDENTIFIER)" macos/Runner/Configs/AppInfo.xcconfig
fi

echo
echo "=== 收尾：拉依赖 ==="
flutter pub get

cat <<EOF

✅ macOS 平台就绪。下一步：

  flutter run -d macos          # 开发调试
  bash tools/build_macos.sh     # 打可分发 .app（含捆绑 Python）

⚠️  提醒：
  · 若 flutter create 覆盖了 macos/Runner/Info.plist，重跑本脚本即可修回。
  · 捆绑 Python 后必须重新签名，签名由 build_macos.sh 自动完成。
EOF
