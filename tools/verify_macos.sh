#!/usr/bin/env bash
# ============================================================
# 编程练习册 · macOS 打包产物自动化验收
#
# 用法（项目根目录）：
#   bash tools/verify_macos.sh
#
# 覆盖「不需要人眼」的部分：包结构、架构、签名、图标、判题链路、启动与日志。
# 剩下必须人工点的（UI 交互、进度导出到 Finder、窗口缩放）见脚本末尾清单。
# ============================================================

set -uo pipefail
cd "$(dirname "$0")/.."

RELEASE_DIR="build/macos/Build/Products/Release"
APP="$(find "$RELEASE_DIR" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null)"

PASS=0; FAIL=0; SKIP=0
ok()   { printf "  \033[32m✅\033[0m %s\n" "$1"; PASS=$((PASS+1)); }
bad()  { printf "  \033[31m❌\033[0m %s\n" "$1"; FAIL=$((FAIL+1)); }
skip() { printf "  \033[33m⏭\033[0m  %s\n" "$1"; SKIP=$((SKIP+1)); }
head_() { printf "\n\033[1m%s\033[0m\n" "$1"; }

if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "❌ 没找到 .app，先跑：bash tools/build_macos.sh"
  exit 1
fi
echo "验收对象: $APP"
echo "体积: $(du -sh "$APP" | cut -f1)"

# ---------------------------------------------------------------- 1. 架构
head_ "1. 架构（universal + 两份单架构 Python）"
EXEC_NAME="$(defaults read "$PWD/$APP/Contents/Info.plist" CFBundleExecutable 2>/dev/null)"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/$EXEC_NAME" 2>/dev/null)"
if [[ "$ARCHS" == *x86_64* && "$ARCHS" == *arm64* ]]; then
  ok "主程序是 universal ($ARCHS)"
else
  bad "主程序架构异常: ${ARCHS:-取不到}"
fi

for pair in "x86_64:python-x86_64" "arm64:python-arm64"; do
  want="${pair%%:*}"; dir="${pair##*:}"
  PY="$APP/Contents/Resources/$dir/bin/python3"
  if [[ ! -x "$PY" ]]; then
    bad "$dir/bin/python3 缺失或不可执行"; continue
  fi
  got="$(lipo -archs "$PY" 2>/dev/null)"
  if [[ "$got" == "$want" ]]; then ok "$dir 架构正确 ($got)"
  else bad "$dir 架构不符：期望 $want 实际 $got"; fi
done

# ---------------------------------------------------------------- 2. 签名
head_ "2. 代码签名与 entitlements"
if codesign --verify --deep --strict "$APP" 2>/dev/null; then
  ok "codesign 校验通过（valid on disk / satisfies Designated Requirement）"
else
  bad "签名校验失败 —— 跑 codesign --verify --deep --strict --verbose=2 看详情"
fi

# entitlements 回读：这一项必须查。
# 漏传 --entitlements 时 codesign 照样报"成功"，只有回读才发现内容全是空的。
ENT_JSON="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null | python3 -c "
import sys, plistlib, json
try:
    d = plistlib.loads(sys.stdin.buffer.read())
except Exception:
    print('{}'); raise SystemExit
print(json.dumps({k: (v if isinstance(v, bool) else str(v)) for k, v in d.items()}))
" 2>/dev/null)"
[[ -z "$ENT_JSON" ]] && ENT_JSON="{}"

ent_get() { printf '%s' "$ENT_JSON" | python3 -c "import sys,json;print(json.load(sys.stdin).get('$1'))" 2>/dev/null; }

if [[ "$ENT_JSON" == "{}" ]]; then
  bad "签名里没有 entitlements —— 签名步骤漏传 --entitlements（见 build_macos.sh 第 5 步）"
else
  [[ "$(ent_get com.apple.security.app-sandbox)" == "False" ]] \
    && ok "App Sandbox 已关闭（app-sandbox=False）" \
    || bad "app-sandbox 异常: $(ent_get com.apple.security.app-sandbox)（应为 False）"

  [[ "$(ent_get com.apple.security.cs.disable-library-validation)" == "True" ]] \
    && ok "disable-library-validation=True（Developer ID + 公证后才加载得动捆绑 Python 的 .so）" \
    || bad "disable-library-validation 缺失 —— 带 Hardened Runtime 的构建会加载不了 Python 库"
fi

# 运行时旁证：沙盒若真开着，macOS 会为它建容器目录
if [[ -d "$HOME/Library/Containers/com.sakiri.python-practice" ]]; then
  bad "存在沙盒容器 ~/Library/Containers/com.sakiri.python-practice —— 沙盒没关干净"
else
  ok "无沙盒容器目录（运行时旁证）"
fi

# ---------------------------------------------------------------- 3. 图标
head_ "3. 应用图标"
ICNS="$APP/Contents/Resources/AppIcon.icns"
if [[ -f "$ICNS" ]]; then
  python3 - "$ICNS" <<'PY'
import struct, sys
d = open(sys.argv[1], 'rb').read()
sizes = {'ic10': 1024, 'ic09': 512, 'ic14': 512, 'ic08': 256, 'ic13': 256,
         'ic07': 128, 'ic12': 64, 'ic11': 32, 'ic05': 32, 'ic04': 16}
found, pos = set(), 8
while pos < len(d) - 8:
    t = d[pos:pos+4].decode('ascii', 'replace')
    ln = struct.unpack('>I', d[pos+4:pos+8])[0]
    if ln < 8: break
    if t in sizes: found.add(sizes[t])
    pos += ln
need = {16, 32, 128, 256, 512, 1024}
missing = sorted(need - found)
if missing:
    print(f"  ❌ icns 缺少尺寸: {missing}（大尺寸下会发糊）")
    sys.exit(1)
print(f"  ✅ icns 尺寸完整: {sorted(found)}")
PY
  [[ $? -eq 0 ]] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
else
  bad "缺少 AppIcon.icns"
fi

# ------------------------------------------------------- 4. 判题链路（无 GUI）
head_ "4. 判题链路（用捆绑解释器，复现判题引擎的调用方式）"
HOST_DIR="python-x86_64"; [[ "$(uname -m)" == "arm64" ]] && HOST_DIR="python-arm64"
PY="$APP/Contents/Resources/$HOST_DIR/bin/python3"
D="$(mktemp -d)"
cat > "$D/sitecustomize.py" <<'EOF'
import builtins, sys
_orig = builtins.input
def _input(prompt=''):
    if prompt:
        sys.stderr.write(str(prompt)); sys.stderr.flush()
    return _orig()
builtins.input = _input
EOF
cat > "$D/solution.py" <<'EOF'
name = input("请输入姓名：")
nums = list(map(int, input("请输入几个数字：").split()))
print(f"你好，{name}！最大值 {max(nums)}，和 {sum(nums)}")
EOF
OUT="$(printf '沙姬\n3 7 2\n' | PYTHONPATH="$D" PYTHONIOENCODING=utf-8 PYTHONUTF8=1 \
        "$PY" -X utf8 "$D/solution.py" 2>"$D/err")"
ERR="$(cat "$D/err")"
EXPECT="你好，沙姬！最大值 7，和 12"
if [[ "$OUT" == "$EXPECT" ]]; then ok "中文输出正确：$OUT"
else bad "判题输出不符\n      期望: $EXPECT\n      实际: $OUT"; fi
if [[ "$ERR" == *"请输入姓名"* ]]; then ok "input() 提示被正确挪到 stderr（不会污染判题比对）"
else bad "input() 提示未出现在 stderr，实际: $ERR"; fi
if PYTHONPATH="" "$PY" -X utf8 -c "import json,re,math,random,itertools,collections,datetime,decimal,statistics,csv,heapq,bisect" 2>/dev/null; then
  ok "常用标准库齐全（裁减 Tcl/Tk 未误伤）"
else
  bad "标准库导入失败 —— 裁减可能过度"
fi
rm -rf "$D"

# ------------------------------------------------------- 5. 启动 + 运行时日志
head_ "5. 启动与运行时自检"
LOG_DIR="$HOME/Library/Application Support/com.sakiri.python-practice/logs"
OLD_LOG="$(cat "$LOG_DIR"/*.log 2>/dev/null | wc -l | tr -d ' ')"
open "$APP" 2>/dev/null
sleep 10
if pgrep -f "$(basename "$APP")" >/dev/null; then
  ok "应用启动后进程存活（未崩溃）"
else
  bad "应用没能保持运行 —— 可能是崩溃"
fi

NEW_LOG="$(cat "$LOG_DIR"/*.log 2>/dev/null | tail -n +$((OLD_LOG + 1)))"
if printf '%s' "$NEW_LOG" | grep -q "Resources/python-"; then
  ok "运行时解析到捆绑解释器："
  printf '%s\n' "$NEW_LOG" | grep -o "Python [^ ]*python3" | head -1 | sed 's/^/       /'
else
  bad "日志里没看到捆绑解释器路径 —— 可能回退到了系统 python3"
fi
if printf '%s' "$NEW_LOG" | grep -q "$HOME/Library/Application Support/com.sakiri"; then
  ok "日志写在真实 ~/Library/Application Support（不是沙盒容器）"
else
  skip "未能从日志确认沙盒状态"
fi

osascript -e "quit app \"$(defaults read "$PWD/$APP/Contents/Info.plist" CFBundleDisplayName 2>/dev/null)\"" 2>/dev/null
sleep 2; pkill -f "$(basename "$APP")" 2>/dev/null

# ---------------------------------------------------------------- 汇总
head_ "汇总"
echo "  自动通过 $PASS 项，失败 $FAIL 项，跳过 $SKIP 项"
cat <<'EOF'

还需人工确认（脚本替代不了）：
  1. 判题页挑一道「带中文 input 提示」的题写对代码 → 应显示「通过」
  2. 交互终端：能启动、能逐行喂输入
  3. 进度导出 → 打开 Finder 去 ~/文稿/PythonPractice导出/ 看文件在不在
     （这是沙盒是否真关掉的最终证据）
  4. 进度导入 → 设置页能列出「下载」目录里的 JSON
  5. 拖动窗口边缘：设置页应在 840pt 处从单列切换成左右两栏；
     学习页在窄屏应出现汉堡按钮、正文独占整屏
  6. 练习页/成就页：把窗口拉很宽，卡片不应被撑成巨型方块
  7. 图标：Dock 与 Finder 里显示是否正常（换过图标若还是旧的，killall Dock）
  8. 死循环的题应被超时终止，而不是卡死
EOF

[[ $FAIL -eq 0 ]] || exit 1
