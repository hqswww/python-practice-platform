#Requires -Version 5.1
<#
.SYNOPSIS
  编程练习册 · C / C++ 编译器一键安装（Windows）

.DESCRIPTION
  给「编程练习册」装上 C / C++ 判题需要的 gcc / g++。

  **不需要管理员权限**：整套工具装到用户目录，PATH 也只改「用户」那一份。

  为什么用 w64devkit 而不是 WinLibs / MSYS2：
    · WinLibs 的 x86_64 压缩包 274MB（解压约 1.5GB），对只想刷题的学生太重
    · MSYS2 要先装它自己（约 100MB），再用 pacman 拉，两步且容易卡在镜像上
    · w64devkit 是单个 61MB 自解压包，gcc / g++ / make / gdb 全都有，够判题用

  为什么不用安装包：MinGW-w64 官方只发压缩包，社区安装器（mingw-get）早已停止维护。

  为什么要单独一个脚本：应用走「用系统编译器」路线，不把编译器捆进包
  （clang + SDK 动辄几百 MB，且许可证不允许再分发）。

.PARAMETER Dir
  安装目录。默认 %LOCALAPPDATA%\code_workbook\w64devkit

.PARAMETER Version
  w64devkit 版本号。默认 2.9.1

.PARAMETER Force
  已经能用了也重装一遍。

.PARAMETER Uninstall
  卸载：删安装目录，并把它的 bin 从用户 PATH 里移除。
  ⚠️ 如果当初用 -Dir 装到了非默认位置，卸载时也要带上同一个 -Dir。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\install_mingw.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\install_mingw.ps1 -Uninstall
#>

[CmdletBinding()]
param(
  [string]$Dir = "",
  [string]$Version = "2.9.1",
  [switch]$Force,
  [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# PowerShell 7.4+ 默认把 $PSNativeCommandUseErrorActionPreference 设为 $true：
# 原生命令（gcc）只要往 stderr 写东西并返回非零，就会被当成**终止性错误抛出**，
# 于是下面 `if ($LASTEXITCODE -ne 0)` 那套判断根本轮不到执行。5.1 没这个行为。
# 这里显式关掉，让两个版本表现一致。
if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {
  $PSNativeCommandUseErrorActionPreference = $false
}

# ============================================================
# 中文编码 —— 这个脚本必须能正确显示中文
#
# 两个层面，缺一个就是乱码：
#
# 1. **本文件自身的编码**：Windows PowerShell 5.1 读没有 BOM 的 .ps1 时，
#    会按系统 ANSI 代码页（中文系统是 GBK）解码。UTF-8 的中文被当 GBK 读，
#    就成了「缂栫▼缁冧範鍐屻€」这种。**所以本文件必须存成 UTF-8 with BOM**，
#    BOM 是 5.1 判断编码的唯一可靠依据。（PowerShell 7 默认就按 UTF-8 读，
#    有 BOM 同样正确，所以这一条对两个版本都成立。）
# 2. **输出到控制台**：默认按控制台代码页编码，中文会花。显式设成 UTF-8。
#
# ⚠️ 第 2 条要 try/catch：被应用以「重定向输出」方式调用时没有真正的控制台，
#    给 [Console]::OutputEncoding 赋值会抛 IOException（句柄无效）。
#    那种情况下本来也不要求控制台显示，忽略即可 —— 但绝不能让脚本因此中断。
# ============================================================
try {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
  # 无控制台（输出被重定向）时会走到这里，属正常情况
}

function Write-Step($text) { Write-Host "`n=== $text ===" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "  ✅ $text" -ForegroundColor Green }
function Write-Warn2($text){ Write-Host "  ⚠️  $text" -ForegroundColor Yellow }
function Write-Err($text)  { Write-Host "  ❌ $text" -ForegroundColor Red }

if (-not $Dir) {
  $Dir = Join-Path $env:LOCALAPPDATA "code_workbook\w64devkit"
}
$Dir = [System.IO.Path]::GetFullPath($Dir)
$BinDir = Join-Path $Dir "bin"
$MarkerFile = Join-Path $Dir ".installed-by-code-workbook"

# ============================================================
# PATH 读写
#
# ⚠️ 这里有个很容易踩的坑：不要用
#      [Environment]::SetEnvironmentVariable('Path', $v, 'User')
#    它会把用户 PATH 写成 REG_SZ，而 Windows 原生的用户 PATH 是 REG_EXPAND_SZ
#    （里面常有 %USERPROFILE%\... 这种变量）。写成 REG_SZ 之后那些变量**不再展开**，
#    用户 PATH 里依赖变量的目录会集体失效 —— 这是个会伤到系统的破坏性改动。
#
#    正确做法：直接操作注册表，并把原来的 ValueKind 原样写回去。
# ============================================================
function Get-UserPath {
  $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment", $false)
  if ($null -eq $key) { return "" }
  try {
    # DoNotExpandEnvironmentNames：拿原始文本，别把 %USERPROFILE% 展开成实际路径
    return [string]$key.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
  } finally {
    $key.Close()
  }
}

function Set-UserPath([string]$value) {
  $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment", $true)
  if ($null -eq $key) { throw "打不开注册表的 HKCU\Environment" }
  try {
    # 读原来的类型；值不存在时 GetValueKind 会抛，兜底成 ExpandString
    $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
    try { $kind = $key.GetValueKind("Path") } catch { }
    $key.SetValue("Path", $value, $kind)
  } finally {
    $key.Close()
  }
}

function Add-ToUserPath([string]$entry) {
  $current = Get-UserPath
  $parts = @()
  if ($current) { $parts = $current.Split(';') | Where-Object { $_ -ne "" } }
  # 不区分大小写地查重，且比较前去掉尾部反斜杠
  $exists = $parts | Where-Object { $_.TrimEnd('\') -ieq $entry.TrimEnd('\') }
  if ($exists) { Write-Host "  ℹ️  用户 PATH 里已经有这一项"; return $false }
  $new = (@($parts) + $entry) -join ';'
  Set-UserPath $new
  Write-Ok "已加入用户 PATH：$entry"
  return $true
}

function Remove-FromUserPath([string]$entry) {
  $current = Get-UserPath
  if (-not $current) { return $false }
  $parts = $current.Split(';') | Where-Object { $_ -ne "" -and $_.TrimEnd('\') -ine $entry.TrimEnd('\') }
  if ($parts.Count -eq $current.Split(';').Count) { return $false }
  Set-UserPath ($parts -join ';')
  Write-Ok "已从用户 PATH 移除：$entry"
  return $true
}

# 本进程也加上，这样后面能直接验证（新开的窗口才需要 PATH 重启生效）
function Use-Locally([string]$entry) {
  if ($env:Path -notlike "*$entry*") { $env:Path = "$entry;$env:Path" }
}

function Find-Gcc {
  $cmd = Get-Command gcc.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidate = Join-Path $BinDir "gcc.exe"
  if (Test-Path $candidate) { return $candidate }
  return $null
}

# ============================================================
# 卸载
# ============================================================
if ($Uninstall) {
  Write-Step "卸载"
  $removed = Remove-FromUserPath $BinDir
  if (Test-Path $Dir) {
    Remove-Item -Recurse -Force $Dir
    Write-Ok "已删除 $Dir"
  } else {
    Write-Host "  ℹ️  安装目录不存在，跳过"
  }
  if (-not $removed) { Write-Host "  ℹ️  用户 PATH 里本来就没有这一项" }
  Write-Host "`n✅ 卸载完成。已打开的命令行窗口需要重开才会生效。"
  exit 0
}

# ============================================================
# 1. 已经能用就不折腾
# ============================================================
Write-Step "1/4 检查现有编译器"
$existing = Find-Gcc
if ($existing -and -not $Force) {
  Use-Locally (Split-Path $existing -Parent)
  try {
    $ver = (& $existing --version 2>&1 | Select-Object -First 1)
    Write-Ok "已经有一个可用的 gcc，不用装："
    Write-Host "     $existing"
    Write-Host "     $ver"
    Write-Host "`n（确实想重装就加 -Force）"
    exit 0
  } catch {
    Write-Warn2 "找到 $existing 但执行失败，继续安装。"
  }
}

$arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
$fileName = "w64devkit-$arch-$Version.7z.exe"
$url = "https://github.com/skeeto/w64devkit/releases/download/v$Version/$fileName"
$sha256 = if ($arch -eq "x64") {
  "9208c19755cd4964b7915b9afcf02c66d493a4c870c4b3e83f6c538d9c1237a5"
} else {
  "91017cbbb8766cb9b3094a9a461213ed809e9f06aa678257bf9bec32fed6b157"
}

Write-Host "  平台：$arch    目标：$Dir"

# ============================================================
# 2. 下载
# ============================================================
Write-Step "2/4 下载 w64devkit $Version（约 61MB，gcc + g++ + make + gdb）"
$zip = Join-Path $env:TEMP $fileName

$needDownload = $true
if (Test-Path $zip) {
  $h = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
  if ($h -eq $sha256) {
    Write-Host "  ℹ️  临时目录里已有完好的安装包，跳过下载"
    $needDownload = $false
  } else {
    Write-Warn2 "临时文件校验不过（可能上次没下完），重新下载"
    Remove-Item $zip -Force
  }
}

if ($needDownload) {
  Write-Host "  下载：$url"
  # GitHub 在大陆可能很慢；给个提示而不是让人干等
  Write-Host "  （如果一直卡住，可手动下载后用 -Dir 指向解压位置，或直接双击该 exe 解压）"
  $oldProgress = $ProgressPreference
  # 关掉进度条：Invoke-WebRequest 的进度渲染会让下载慢好几倍
  $ProgressPreference = 'SilentlyContinue'
  try {
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
  } finally {
    $ProgressPreference = $oldProgress
  }
  Write-Ok "下载完成：$zip"
}

Write-Host "  校验 SHA256…"
$actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $sha256) {
  Write-Err "校验失败！"
  Write-Host "     期望 $sha256"
  Write-Host "     实际 $actual"
  Write-Host "  文件可能损坏或被篡改，已删除。请重跑本脚本。"
  Remove-Item $zip -Force
  exit 1
}
Write-Ok "校验通过"

# ⚠️ 下载来的文件会被打上「来自 Internet」标记（Mark-of-the-Web），
#    直接执行会被 SmartScreen 拦下并报「此文件来自其他计算机，可能被阻止」。
#    跟我们要不要信任它无关 —— 我们刚刚校验过 SHA256，所以才解除标记。
try { Unblock-File -Path $zip } catch { }

# ============================================================
# 3. 解压
# ============================================================
Write-Step "3/4 解压到 $Dir"
if (Test-Path $Dir) { Remove-Item -Recurse -Force $Dir }
New-Item -ItemType Directory -Path $Dir -Force | Out-Null

# w64devkit 的发布物是 7-Zip 自解压包，支持 -y（不问）和 -o（指定目录）
$proc = Start-Process -FilePath $zip -ArgumentList @("-y", "-o`"$Dir`"") -Wait -PassThru
if ($proc.ExitCode -ne 0) {
  Write-Warn2 "静默解压返回了 $($proc.ExitCode)，检查一下解压结果"
}

# 包里可能直接是 bin/，也可能是 w64devkit/bin/ —— 两种都认
if (-not (Test-Path $BinDir)) {
  $nested = Join-Path $Dir "w64devkit\bin"
  if (Test-Path $nested) {
    $BinDir = $nested
  }
}

if (-not (Test-Path (Join-Path $BinDir "gcc.exe"))) {
  Write-Err "解压后没找到 gcc.exe"
  Write-Host "  安装包已经下好了，位置：$zip"
  Write-Host "  请**双击它**，在图形界面里把它解压到：$Dir"
  Write-Host "  解压完回到「编程练习册」的设置页点「重新检测」即可。"
  exit 1
}
Write-Ok "解压完成：$BinDir"

# 留个标记，方便以后认出这个目录是谁装的
Set-Content -Path $MarkerFile -Value "installed-by=code-workbook`nversion=$Version" -Encoding UTF8

# ============================================================
# 4. 写 PATH + 验证
# ============================================================
Write-Step "4/4 配置 PATH 并验证"
Add-ToUserPath $BinDir | Out-Null
Use-Locally $BinDir

$gcc = Join-Path $BinDir "gcc.exe"
$gpp = Join-Path $BinDir "g++.exe"

Write-Host "  gcc --version:"
& $gcc --version 2>&1 | Select-Object -First 1 | ForEach-Object { Write-Host "     $_" }
Write-Host "  g++ --version:"
& $gpp --version 2>&1 | Select-Object -First 1 | ForEach-Object { Write-Host "     $_" }

# 真编一个 C 和一个 C++ 程序 —— 只跑 --version 不足以证明能编译
$probe = Join-Path $env:TEMP "code_workbook_probe_$PID"
New-Item -ItemType Directory -Path $probe -Force | Out-Null
try {
  Set-Content -Path (Join-Path $probe "t.c") -Value "#include <stdio.h>`nint main(void){printf(\"c ok\");return 0;}" -Encoding ASCII
  Set-Content -Path (Join-Path $probe "t.cpp") -Value "#include <iostream>`nint main(){std::cout<<\"cpp ok\";return 0;}" -Encoding ASCII
  & $gcc (Join-Path $probe "t.c") -o (Join-Path $probe "t.exe")
  if ($LASTEXITCODE -ne 0) { throw "C 编译失败" }
  & $gpp (Join-Path $probe "t.cpp") -o (Join-Path $probe "tpp.exe")
  if ($LASTEXITCODE -ne 0) { throw "C++ 编译失败" }
  $outC = & (Join-Path $probe "t.exe")
  $outCpp = & (Join-Path $probe "tpp.exe")
  Write-Ok "实测编译运行：C → 「$outC」，C++ → 「$outCpp」"
} catch {
  Write-Err "编译器装上了但实测编译失败：$_"
  exit 1
} finally {
  Remove-Item -Recurse -Force $probe -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "✅ 安装完成！" -ForegroundColor Green
Write-Host "   编译器位置：$BinDir"
Write-Host "   gcc / g++ / make / gdb 都在这个目录里。"
Write-Host ""
Write-Host "接下来：" -ForegroundColor Cyan
Write-Host "   1. 回到「编程练习册」→ 设置 → 代码编辑，点该语言的「重新检测」"
Write-Host "      （已经开着的应用读不到新的 PATH，重开应用也行）"
Write-Host "   2. 若应用仍说找不到，把这一行填进「C 编译器」输入框再保存："
Write-Host "      $gcc"
Write-Host ""
Write-Host "卸载：powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Uninstall"
Write-Host "⚠️  已打开的命令行窗口里的 PATH 不会自动更新，重开一个即可。"
