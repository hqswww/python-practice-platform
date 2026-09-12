[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
# ============================================================
# 编程练习册 · Windows 一键打包脚本
# （在 Windows 机器上的项目根目录运行）
#
# 用法：
# > cd 项目根目录
# > powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
#
# 它会：
# 1. flutter build windows --release → 编译 exe
# 2. 下载嵌入式 Python 到临时目录
# 3. 把 Python 复制到 Release\python\ （判题引擎按 exe 相对路径找它）
# 4. 把打包结果复制到 dist\编程练习册\ （开箱即用文件夹）
# ============================================================

$ErrorActionPreference = "Stop"

# ---- 可调参数 ----
$PY_MAJOR = "3.12" # 嵌入式 Python 大版本
$PY_VER = "3.12.10" # 完整版本（用于下载 URL）
$RELEASE_DIR = Join-Path $PWD "build\windows\x64\runner\Release"
$DIST_DIR = Join-Path $PWD "dist\编程练习册"

# ============================================================
# 预检：路径里的非 ASCII 字符
#
# Flutter 在 Windows 上有个**已知缺陷**：路径含非 ASCII 字符时构建会失败。
# 常见触发场景就是用户名是中文/带变音符号 —— 项目在
# `C:\Users\笑\Downloads\...`、临时目录在 `C:\Users\笑\AppData\Local\Temp`。
#
# 根因（flutter/flutter#178896，引擎 PR #191360）：
#   引擎改用 C++20 后，`std::filesystem::path` 转字符串的编码变了。
#   读 `.dill` 走的是 C 库 `open()`，它**期望 ANSI 编码的路径**；
#   路径里有当前 ANSI 代码页装不下的 UTF-8 字符时 `open()` 直接失败。
#
# 症状极难自查：报的是
#   `error : Unable to read file: ...\.dart_tool\flutter_build\<hash>\app.dill`
# 加上一句 MSB8066 —— 既没提路径、也没提编码，而且是在编译跑了几十秒之后
# 才冒出来。这里提前查一次，把它翻译成人话。
# ============================================================
function Test-HasNonAscii([string]$text) {
  return $text -match '[^\x00-\x7F]'
}

$badPaths = @()
if (Test-HasNonAscii $PWD.Path) { $badPaths += "项目路径 : $($PWD.Path)" }
if ($env:TEMP -and (Test-HasNonAscii $env:TEMP)) { $badPaths += "临时目录 : $env:TEMP" }
$HAS_NON_ASCII = $badPaths.Count -gt 0

if ($HAS_NON_ASCII) {
  Write-Host ""
  Write-Host "⚠️  检测到路径里有非 ASCII 字符（通常是中文用户名）：" -ForegroundColor Yellow
  foreach ($p in $badPaths) { Write-Host "      $p" -ForegroundColor Yellow }
  Write-Host ""
  Write-Host "    Flutter 3.38 起在 Windows 上有这个已知缺陷：这类路径会让构建报" -ForegroundColor Yellow
  Write-Host "      error : Unable to read file: ...\app.dill" -ForegroundColor DarkGray
  Write-Host "    那不是项目代码的问题。两个办法（任选其一）：" -ForegroundColor Yellow
  Write-Host "      1) 升级 Flutter 到已修复的版本（见 flutter/flutter#178896）"
  Write-Host "      2) 把项目和临时目录都挪到纯英文路径，例如："
  Write-Host "           mkdir D:\dev"
  Write-Host "           把项目复制到 D:\dev\python-practice-platform"
  Write-Host "           `$env:TEMP='D:\dev\tmp'; `$env:TMP='D:\dev\tmp'   # 仅本次会话有效"
  Write-Host ""
  Write-Host "    先照常继续构建；若报的就是上面那句，按上面任一条处理即可。" -ForegroundColor Yellow
  Write-Host ""
}

Write-Host "=== 1/4 编译 Windows Release 版 ===" -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
  if ($HAS_NON_ASCII) {
    Write-Host ""
    Write-Host "构建失败。**先看上面那条非 ASCII 路径的提示** ——" -ForegroundColor Red
    Write-Host "如果报错里出现「Unable to read file ... app.dill」，那就是它，不是代码问题。" -ForegroundColor Red
    Write-Host ""
  }
  throw "flutter build 失败"
}

Write-Host "=== 2/4 下载嵌入式 Python $PY_VER ===" -ForegroundColor Cyan
$PY_ZIP = Join-Path $env:TEMP "python-embed.zip"
$PY_URL = "https://www.python.org/ftp/python/$PY_VER/python-$PY_VER-embed-amd64.zip"
if (-not (Test-Path $PY_ZIP)) {
 Write-Host "正在下载: $PY_URL" -ForegroundColor Yellow
 try {
 Invoke-WebRequest -Uri $PY_URL -OutFile $PY_ZIP
 }
 catch {
 throw "Python 下载失败，请检查网络或版本号: $PY_VER"
 }
}

if (-not (Test-Path $PY_ZIP)) {
 throw "Python 压缩包不存在: $PY_ZIP"
}
$PY_TMP = Join-Path $env:TEMP "py_embed_$PID"
if (Test-Path $PY_TMP) { Remove-Item -Recurse -Force $PY_TMP }
Expand-Archive -Path $PY_ZIP -DestinationPath $PY_TMP -Force

Write-Host "=== 3/4 配置嵌入式 Python（开启 site-packages + 自动 sitecustomize）===" -ForegroundColor Cyan
# 嵌入式 Python 默认没有 site-packages（import 不出第三方库）且 stdlib 精简。
# 打开 python312._pth 里的 import site，让它能加载标准库/第三方包。
$PTH = Get-ChildItem -Path $PY_TMP -Filter "python*._pth" | Select-Object -First 1
if ($PTH) {
 $content = Get-Content $PTH.FullName
 # 去掉 import site 前导 # （若无）
 $content = $content -replace "^#import site", "import site"
 Set-Content -Path $PTH.FullName -Value $content -Encoding ASCII
}

Write-Host "=== 4/4 组装分发目录 ===" -ForegroundColor Cyan
if (Test-Path $DIST_DIR) { Remove-Item -Recurse -Force $DIST_DIR }
New-Item -ItemType Directory -Path $DIST_DIR -Force | Out-Null

# exe + data + dll 等
Copy-Item -Path "$RELEASE_DIR\*" -Destination $DIST_DIR -Recurse -Force

# 捆绑 Python
New-Item -ItemType Directory -Path "$DIST_DIR\python" -Force | Out-Null
Copy-Item -Path "$PY_TMP\*" -Destination "$DIST_DIR\python" -Recurse -Force

# 把 C/C++ 编译器的一键安装脚本一起发出去。
# 应用启动时会找 exe 同目录下的 install_mingw.ps1（见 runtime_installer.dart），
# 找到就在首次运行向导 / 设置页给出「一键安装」按钮；找不到就只给下载页指引。
# 注意 Python 是捆绑的，C/C++ 走系统编译器 —— 所以这个脚本是必要的补充。
$MINGW = Join-Path $PWD "tools\install_mingw.ps1"
if (Test-Path $MINGW) {
  Copy-Item -Path $MINGW -Destination $DIST_DIR -Force
  Write-Host " 已附带编译器安装脚本: install_mingw.ps1"
} else {
  Write-Host " 未找到 tools\install_mingw.ps1，分发版将只能引导用户手动安装编译器" -ForegroundColor Yellow
}

# 清理临时 python 解压目录
Remove-Item -Recurse -Force $PY_TMP

Write-Host "`n✅ 完成！分发目录: $DIST_DIR" -ForegroundColor Green
Write-Host " 直接把整个『编程练习册』文件夹拷给用户即可。"
Write-Host " 用户双击 code_workbook.exe 即可运行（判题用捆绑 python 无需装 Python）。"
Write-Host " C / C++ 需要编译器：首次运行向导里可一键安装，或跑 install_mingw.ps1。"
