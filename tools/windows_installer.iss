; ============================================================
; 编程练习册 · Windows 安装包（Inno Setup 脚本）
;
; 由 tools/build_windows.ps1 调用 ISCC.exe 编译，产出
; dist\编程练习册-Setup.exe —— 一个免管理员的单文件安装包。
;
; 手动编译：
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" tools\windows_installer.iss
;
; 前置条件：先跑过 build_windows.ps1，让 dist\编程练习册\ 存在。
;
; ⚠️ 要求 Inno Setup 6.5.0 或更高
;    （随仓库带的简体中文语言包 tools\inno\ChineseSimplified.isl 是按 6.5.0 写的；
;      另外 ArchitecturesInstallIn64BitMode 用的 x64compatible 也是 6.3+ 的写法）
;
; 设计要点：
;   · **免管理员**：装到 %LOCALAPPDATA%\Programs\，和绿色版一个精神
;   · 整个 dist 目录原样打进去 —— exe + data + lib + python/ + install_mingw.ps1
;     其中 python\ 是捆绑的解释器（判题免装 Python）
;     install_mingw.ps1 必须一起带上：首次运行向导的「一键安装」靠它在 exe 旁边找
;   · 不删用户数据：卸载时保留进度（在 %APPDATA% 下），重装能接着用
; ============================================================

#define AppName "编程练习册"
#define AppExeName "code_workbook.exe"
#define AppPublisher "sakiri"

; ⚠️ 版本号在这里维护。
; build_windows.ps1 会拿 pubspec.yaml 的版本跟它比对，不一致会打警告 ——
; 单一事实来源仍然是 pubspec.yaml，这里是打包用的副本。
#define AppVersion "1.5.2"

; ⚠️ **这个 GUID 绝对不能改**。Inno 用它识别「这是不是同一个应用」：
;    升级安装要认它、卸载要认它、控制面板里的条目也认它。
;    改了等于变成另一个软件 —— 老用户装新版会得到两份并存，
;    卸载也清不掉旧的。（和 macOS 的 Bundle ID 是同一类东西）
#define AppId "{{CCAA5D7C-47D3-4F51-AF55-A566213C04E3}"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
VersionInfoVersion={#AppVersion}
VersionInfoDescription={#AppName} 安装程序

; 免管理员：只装给当前用户
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
; 用户仍可在向导里选「为所有用户安装」，那时才提权
PrivilegesRequiredOverridesAllowed=dialog

; 64 位应用（Inno 6.3+ 的写法）
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

; 禁用「选择开始菜单文件夹」那一页：对普通用户没意义，少一步
DisableProgramGroupPage=yes
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

OutputDir=..\dist
OutputBaseFilename={#AppName}-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}

[Languages]
; 中文放第一个：Inno 会按系统语言挑，挑不到就用第一个
Name: "chinese"; MessagesFile: "inno\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务："; Flags: unchecked

[Files]
; 整个分发目录原样打进去。
; ignoreversion：反复构建时不要因为时间戳报警告。
Source: "..\dist\{#AppName}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\卸载 {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "立即启动 {#AppName}"; Flags: nowait postinstall skipifsilent

; ⚠️ 刻意**不写** [UninstallDelete] 去删用户数据。
; 进度、设置存在 %APPDATA% 下（SharedPreferences），不属于安装目录；
; 卸载时顺手删掉的话，用户重装一次就发现进度全没了 —— 那是数据丢失，不是清理。
; 真要清进度，应用内「设置 → 数据」有清空进度的入口，让用户自己按。
