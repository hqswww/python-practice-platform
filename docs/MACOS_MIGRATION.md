# 🍎 macOS 迁移手册

> 目标：把「编程练习册」在 macOS 上打出**可分发、免装 Python** 的 `.app`（对标 Windows 绿色版）。
> 本手册 = 环境准备 + 关键差异 + 一键流程 + 排查表。**所有结论均为实测**（2026-09-10，Intel Mac + Xcode 26.3）。

---

## 一、架构结论（为什么这样设计）

| 项 | 决策 | 原因 |
|----|------|------|
| 构建机 | **必须在 macOS 本机** | Flutter macOS 桌面 = Xcode/clang 工具链，无法交叉编译 |
| 脚手架 | `flutter create --platforms=macos .` | 项目原本只有 `linux/` `windows/`，缺 `macos/` |
| Python | **python-build-standalone**（`install_only_stripped`，3.12.14） | 对标 Windows 的嵌入式 Python；免装、可重定位 |
| Python 数量 | **两份**（x86_64 + arm64） | 见下：Flutter 产物是 universal，而 Python 是单架构的 |
| Python 位置 | `<App>.app/Contents/Resources/python-<arch>/bin/python3` | **不能放 Frameworks**（codesign 会拒签，见第四节） |
| **App Sandbox** | **必须关闭** | 不关会同时打坏判题和进度导入导出（见第三节） |
| 编码 | 沿用 `-X utf8` + `PYTHONIOENCODING=utf-8` | 与 Windows 同一套加固，macOS 一样适用 |
| 分发 | 打 zip（`ditto`） | 保留符号链接与扩展属性；用 `zip` 命令会破坏 `.app` |

**与 Windows 的关键差异：**

| | Windows | macOS |
|---|---|---|
| 产物 | `编程练习册.exe` + 同目录 `python/` | `编程练习册.app`（Python 在 `Contents/Resources/` 内） |
| 解释器兜底 | `python.exe` | **不能靠 PATH**：`.app` 从 Finder 启动只有 `/usr/bin:/bin:/usr/sbin:/sbin` |
| 系统 Python | 通常没装 | `/usr/bin/python3` 是 Xcode CLT 的 **shim**，没装 CLT 时会弹安装提示 |
| 签名 | 无 | **必须签名**；且嵌套代码的位置有讲究（Frameworks 放不了 Python 大树） |
| 架构 | x64 | **universal**（`flutter build macos` 没有架构开关，两种架构在同一份 `.app` 里） |
| 包体 | ~110MB | **198MB**（App）/ **82MB**（zip）——两份 Python 的代价 |

**为什么是两份 Python：**

`flutter build macos --release` 产出的主程序、`FlutterMacOS.framework`、`App.framework`
**全是 universal 二进制**（实测 `lipo -archs` = `x86_64 arm64`），而且 `flutter build macos`
**没有** `--target-platform` 之类的架构开关。但 python-build-standalone 是单架构的。
所以两个架构各带一份，运行时由 `python_runtime.dart` 的 `currentMacArchDirName()`
（`Abi.current()`，兜底嗅探 `Platform.version`）挑对应的那一份：

```
Contents/Resources/python-x86_64/bin/python3   ← Intel
Contents/Resources/python-arm64/bin/python3    ← Apple Silicon
```

只带一份的话，另一个架构上会 `Bad CPU type in executable`。

---

## 二、前置环境（一次性安装）

> ⚠️ 以下命令请自行执行（本次检查未改动你的环境）。

### 1. CocoaPods —— ✅ **实测不需要，可跳过**

Flutter 3.47 默认启用 **Swift Package Manager**（`flutter doctor` 里可见
`enable-swift-package-manager` flag）。本项目两个插件都已被 SPM 接管，
**不装 CocoaPods 也能正常构建和运行**。

实测结论（临时工程 + `shared_preferences` + `path_provider`）：

| 检查项 | 结果 |
|---|---|
| `flutter build macos --release` | ✅ 成功（37MB `.app`） |
| `macos/Pods` 目录 | 不存在 → **CocoaPods 全程未参与** |
| 依赖解析方式 | `macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage` |
| 运行时 `getApplicationDocumentsDirectory()` | ✅ 返回真实 `~/Documents` |
| 运行时 `getDownloadsDirectory()` | ✅ 返回真实 `~/Downloads` |
| 运行时 `SharedPreferences` | ✅ 读写正常 |

> `path_provider_foundation 2.6.0` 已经迁移成**纯 Dart FFI 实现**（走 `package:objective_c`，
> 包里既没有 `darwin/` 也没有 podspec）——所以它压根不需要任何原生包管理器。

`flutter doctor` 仍会报 **"CocoaPods not installed. Without CocoaPods, plugins will not
work on iOS or macOS."** —— **这条提示对 Flutter 3.47 已经过时，可以直接无视。**

> 什么时候才真需要装？只有当某个插件既没有 SPM 支持、又没有迁移成 FFI 实现时。
> 到那时 `flutter build` 会明确报错，再装也不迟：
> `brew install cocoapods`（见下方 Homebrew 警告）。

> ⚠️ **Homebrew 已放弃 Intel x86_64 macOS 支持**（2026-09 起，2025-08 公告）。
> `brew` 会打印一段明确警告，并推荐改用 MacPorts。目前 brew 仍能装上
> （走 USTC 镜像的 bottle），但属于「不受支持」状态。
> 若将来 brew 装不了，备选路线是 MacPorts 的 ruby33：`sudo port install ruby33` 再 `gem install cocoapods`。
> （MacPorts 本身没有 `cocoapods` port，已确认。）

### 2. Flutter SDK

`pubspec.lock` 要求 **flutter >= 3.44.0、dart >= 3.12.2**，别装旧版。

**选定版本：Flutter 3.47.3 / Dart 3.13.3**（查官方发布清单时的当前 stable）。

> ⚠️ **架构必须选对**：同一个 3.47.3 有两个包，官方清单里 `dart_sdk_arch` 字段区分。
> 本机是 Intel（`uname -m` = `x86_64`），**必须用不带 `arm64` 字样的那个**，拿错直接跑不起来。
>
> | 包 | 架构 |
> |---|---|
> | `flutter_macos_3.47.3-stable.zip` | x64 ← **本机用这个** |
> | `flutter_macos_arm64_3.47.3-stable.zip` | arm64 |
>
> 另：别装 `3.48.x` —— 那是 beta 渠道。

```bash
mkdir -p ~/development && cd ~/development

curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.47.3-stable.zip

# 校验官方 sha256
echo "cd1e1a877db74b8928251225d38469077994e904b1b5bb359f3376c43ac0495c  flutter_macos_3.47.3-stable.zip" \
  | shasum -a 256 -c -

unzip -q flutter_macos_3.47.3-stable.zip

# 加进 PATH（写成 ~/.zshrc 持久化）
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
export PATH="$PATH:$HOME/development/flutter/bin"

flutter --version          # 期望 Flutter 3.47.3 / Dart 3.13.3
flutter config --enable-macos-desktop
flutter doctor -v
```

安装方式取舍：

- **官方 zip**（上面这个）——确定性最强，版本与校验和可核对 ← 推荐
- `git clone --depth 1 -b stable` —— 好处是以后能 `flutter upgrade`，今天拉到的同样是 3.47.3
- `brew install --cask flutter` —— 最省事，但版本可能滞后，装完务必 `flutter --version` 确认 ≥3.44.0

`flutter doctor` 里 **Android toolchain / Chrome / Android Studio 报红可以无视**——本项目只做 macOS 桌面。

> 📌 已核实：**3.47.3 这个 tag 的 macOS 模板依然默认 `app-sandbox = true`**
> （Debug/Release 两份 entitlement 都是），所以第四节的关沙盒步骤是必须项，不是可选项。

### 3. Xcode

**本机已就绪，无需操作。** 本次检查确认：

- Xcode 26.3（Build 17C528），`xcode-select -p` = `/Applications/Xcode.app/Contents/Developer`
- **许可已接受**（`xcodebuild -checkFirstLaunchStatus` 退出码 0，不会卡 "agree to the license"）
- macOS 26.2 SDK 可用，`xcrun clang` 正常

---

## 三、🔴 关键差异：App Sandbox 必须关闭

Flutter 的 macOS 模板在 **Debug 和 Release 两份 entitlements 里都默认开启**沙盒：

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

开启后应用被关进 `~/Library/Containers/<bundle-id>/Data/`，对这个项目会造成三处实际故障：

| 故障 | 涉及代码 | 现象 |
|------|---------|------|
| 导出进度丢在容器里 | `lib/services/export_service.dart:114`<br>`getApplicationDocumentsDirectory()` | 用户在自己的「文稿」里**找不到**导出文件 |
| 导入列表永远为空 | `lib/pages/settings_page.dart:809`<br>`getDownloadsDirectory()` | 扫描下载目录扫不到任何 JSON |
| 判题受沙盒限制 | `judge_engine.dart` / `interactive_runner.dart`<br>`Process.start(python3)` | 子进程继承沙盒，执行系统解释器受限 |

→ **结论**：本应用是本地自习工具，需要跑外部解释器 + 读写用户可见目录，**必须关闭沙盒**。

`tools/setup_macos_platform.sh` 已自动处理，并把 `app-sandbox` 设为 `NO`、补上
`com.apple.security.cs.disable-library-validation = YES`（捆绑 Python 要加载一批非本团队签名的
`.so`/`.dylib`，若 Release 开了 Hardened Runtime 会被库校验拒绝）。

---

## 四、🔴 签名：捆绑 Python 必须放 `Resources`，不能放 `Frameworks`

这是整个适配中**最隐蔽的坑**，踩了两轮才定位。

`codesign` 会把 `Contents/Frameworks/` 下的**任何目录**都当作「嵌套代码」来解析，
要求它是合法的 framework / bundle。Python 是几千个散文件的大目录树，放进去必然签名失败：

```
code object is not signed at all
  In subcomponent: .../Frameworks/python-arm64/lib/pkgconfig/python-3.12.pc
bundle format unrecognized, invalid, or unsuitable
  In subcomponent: .../Frameworks/python-arm64/lib/python3.12
```

注意连 `.pc` 这种纯文本文件都被要求签名 —— 而且**签主可执行文件时会被连带拒绝**
（codesign 会校验整个 bundle 的嵌套代码，所以「先把里面的 Mach-O 都签了」也救不了）。

改成 `Contents/Resources/` 后立刻通过：Resources 的内容按「资源」用哈希封存，
不参与嵌套代码校验，只需单独签里面的 Mach-O 即可。

**实测**：universal 包共需签 **14 个 Mach-O**：

| 来源 | 数量 |
|---|---|
| `Contents/Resources/python-<arch>/` 里的解释器、dylib、`.so` | 10（两种架构各 5） |
| `Contents/MacOS/python_practice` | 1 |
| Flutter 的 `FlutterMacOS` / `App` / `objective_c` framework | 3（`flutter build` 已签，脚本会重签） |

`build_macos.sh` 的签名顺序：**先签这些嵌套 Mach-O → 再签 `.app` 本体**
（本体不带 `--deep`，让 codesign 重新封存整个 bundle 的 `CodeResources`）。

> ⚠️ 脚本里**不要**用 `find "$APP" -print0 | file` 全树扫描来找 Mach-O：
> Python 树有几千个 `.py`，逐文件调 `file` 会慢到几分钟（实测超时）。
> 按位置/扩展名精准定位即可（现脚本已这样做）。

签名结果校验：

```bash
codesign --verify --deep --strict --verbose=2 "<App>.app"
# 期望：valid on disk / satisfies its Designated Requirement
```

---

## 五、一键流程

```bash
# ① 生成 macos/ 脚手架 + 关沙盒 + 设显示名/Bundle ID（只需跑一次）
bash tools/setup_macos_platform.sh

# ② 开发调试
flutter run -d macos

# ③ 打可分发 .app（含捆绑 Python）
bash tools/build_macos.sh

# 可选参数
bash tools/build_macos.sh --skip-python      # 不捆绑，用系统 Python（自己用够了）
bash tools/build_macos.sh --no-trim          # 不裁减体积
bash tools/build_macos.sh --sign "Developer ID Application: 你的名字 (TEAMID)"
```

`build_macos.sh` 的 6 步：

1. `flutter build macos --release`
2. `lipo -archs` 探测产物架构 → 决定要带哪几份 `python-build-standalone`
3. 每份解包到 `<App>.app/Contents/Resources/python-<arch>/`（**不是 Frameworks**，见第四节）
4. 每份裁掉 Tcl/Tk、idlelib、2to3 等判题用不到的组件（各约 12MB）
5. **自底向上签名**（先签 14 个嵌套 Mach-O，再签 `.app` 本体）
6. `ditto` 打成 `dist/编程练习册-macOS-<arch|universal>.zip`

> 架构：`flutter build macos` 产出 universal（两种架构都在），且**没有架构开关**。
> 所以脚本会把两份 Python 都带上，运行时按 `Abi.current()` 挑。
> 想省体积只能改 Xcode 的 `ARCHS` 做单架构产物，代价是另一架构要跑 Rosetta 2。

---

## 六、验证清单（关键！）

1. **判题**：挑一题写对代码提交，应显示「通过」而非报错
   - 尤其测**带中文 `input()` 提示**的题（验证 prompt 转 stderr + UTF-8 加固）
   - 再测**中文输出**的题（验证不出现乱码）
2. **交互终端**：能启动、能逐行喂输入
3. **进度导出** → 文件应出现在 `~/文稿/PythonPractice导出/`（**不是**容器里）
4. **进度导入** → 设置页能列出下载目录里的 JSON
5. **退出码与超时**：死循环题目应被超时终止而不是卡死
6. **错误日志**：`lib/services/error_log_service.dart` 的平台行应显示
   `macOS (...) / Dart ... / Python <解析到的解释器绝对路径>`

打包后冒烟测试（换台机器更准）：

```bash
# 断掉开发环境依赖，直接跑产物
open "build/macos/Build/Products/Release/python_practice.app"

# 检查捆绑解释器（注意是 Resources 且带架构后缀）
APP="build/macos/Build/Products/Release/python_practice.app"
"$APP/Contents/Resources/python-x86_64/bin/python3" -V   # Intel
"$APP/Contents/Resources/python-arm64/bin/python3"  -V   # Apple Silicon

# 校验签名
codesign --verify --deep --strict --verbose=2 "$APP"

# 看应用日志确认运行时真的解析到了捆绑解释器
cat ~/Library/Application\ Support/com.sakiri.python-practice/logs/*.log
```

---

## 七、常见坑 & 排查

| 症状 | 原因 / 解法 |
|------|------------|
| `flutter doctor` 报 CocoaPods 缺失 | **可无视**，本项目走 SPM（见第二节实测） |
| 改 entitlements 后毫无效果、`plutil` 报 `Key path not found` | **plutil 把 `.` 当键路径分隔符**。`com.apple.security.*` 这类键必须转义成 `com\.apple\.security\.*` 或用 PlistBuddy。`setup_macos_platform.sh` 已封装 `plutil_key()` 并带回读校验 |
| bash 报 `SIGN_IDENTITY\xef...: unbound variable`（变量名后带乱码） | **`$VAR` 后面紧跟中文/全角字符**时，bash 会把多字节字节吃进变量名。写成 `${VAR}` 界定。两个脚本已全部改正 |
| 签名报 `code object is not signed at all` / `bundle format unrecognized` | **Python 放错位置**：`Contents/Frameworks/` 会被 codesign 当嵌套代码解析 → 必须放 `Contents/Resources/`（见第四节） |
| 签主可执行文件时被连带拒绝（报某个 `.pc` 或 `lib/python3.12`） | 同上，Python 还在 Frameworks 下 |
| 签名脚本卡住几分钟 | 用了 `find "$APP" -exec file` 全树扫 Mach-O；Python 有几千个 `.py` → 按位置/扩展名精准定位 |
| 签名报 `Invalid Signature` / 公证报 `nested code` | 嵌套 Mach-O 未签或顺序错 → 先签所有嵌套 Mach-O，再签 `.app` 本体（不带 `--deep`） |
| 判题报「找不到 Python」 | 捆绑没成功 → 查 `<App>.app/Contents/Resources/python-<arch>/bin/python3` 是否存在；或去设置页手动指定解释器 |
| 判题报错但系统有 Python | `.app` 从 Finder 启动没有 Homebrew/MacPorts 的 PATH → 已在 `python_runtime.dart` 里显式探测绝对路径兜底 |
| 目标机器报 `Bad CPU type in executable` | 该架构的 Python 没带全 → 确认 `Resources/` 下 `python-x86_64` 与 `python-arm64` 都在（见第一节） |
| 中文变乱码 | 编码加固未生效 → 检查 `PythonRuntime.withUtf8Env`（已内置） |
| 导出文件「找不到」/ 导入列表为空 | 沙盒没关干净 → 重跑 `tools/setup_macos_platform.sh`，它会回读校验并中止 |
| 换了图标但 Finder/Dock 还是旧的 | macOS 图标缓存。`touch "<App>.app"` 后重开；顽固时 `killall Dock`，或把 app 换个目录再放回 |
| 大尺寸下图标发糊 | `.icns` 缺 512/1024 块 → 确认走了 `build_macos.sh` 的 iconutil 步骤（Xcode 原生产物只到 256）|
| 首次打开提示「来自身份不明的开发者」 | 未公证（正常）→ 右键「打开」，或 `xattr -dr com.apple.quarantine "<App>.app"` |
| `flutter` 一执行就 `Bad CPU type in executable` | 装成了 arm64 包 → 换 `flutter_macos_3.47.3-stable.zip`（x64） |
| `Unable to find a suitable Xcode` | `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| `pod: command not found` 且确实需要 CocoaPods | `brew install cocoapods`（注意 Homebrew 已不支持 Intel macOS，会有警告） |
| `flutter test` 里 python_runtime 用例失败 | macOS 解析逻辑已变 → 见 `test/python_runtime_test.dart`（已同步更新） |
| 重跑 `flutter create --platforms=macos .` 后 Windows 构建异常 | 它会挤掉 `.metadata` 里的 `windows` 平台记录 → 检查并恢复（本项目已恢复并加注释） |

---

## 八、代码侧已完成的迁移准备

- ✅ `lib/services/python_runtime.dart` 新增 macOS 分支：
  - `macBundledRelativePaths` — **`Resources` 优先、`Frameworks` 回退**
    （顺序由 codesign 行为决定，见第四节）
  - `currentMacArchDirName()` — 用 `Abi.current()` 判架构（兜底嗅探 `Platform.version`），
    universal 包据此在 `python-x86_64` / `python-arm64` 之间挑
  - `macFallbackPaths` — 显式探测 `/opt/homebrew`、`/usr/local`、`/opt/local`、`/usr/bin`
    的 `python3`，解决「Finder 启动的 .app 没有 PATH」问题
  - `_whichSync()` — 自实现 `which`，最后再扫一遍 PATH
  - 解析优先级：设置页自定义路径 → 架构专属捆绑 → 通用捆绑 → 绝对路径兜底 → PATH → 友好报错
  - **Windows / Linux 分支逻辑保持不变**
- ✅ `lib/services/error_log_service.dart` — 平台行补 macOS 版本号，并带上
  **实际解析到的 Python 解释器路径**（判题失败最常见的原因就是解释器指错）
- ✅ `test/python_runtime_test.dart` — 原「非 Windows 平台解析为 python3」断言在 macOS 上
  已不成立，改为分平台断言 + 架构探测断言 + 校验兜底候选均为绝对路径
- ✅ `.metadata` — 补回被 `flutter create` 挤掉的 `windows` 平台记录
- ✅ `tools/setup_macos_platform.sh` — 生成脚手架 + 关沙盒（带回读校验）+ 设显示名/Bundle ID
- ✅ `tools/build_macos.sh` — 一键打包（捆绑 Python + 裁减 + 签名 + 打 zip）

---

## 九、应用图标

图标源图要求与处理流程（当前用的是 `~/Documents/icon.png` 的左上方形区域）：

| 步骤 | 做法 | 为什么 |
|------|------|--------|
| 方形化 | 裁成正方形再缩到 1024 | 原图 1260×1122 非方形，图标必须方形 |
| 圆角 | **复用 Flutter 模板的 alpha 通道** | Apple 的连续曲率圆角（squircle）手算难对齐；直接沿用模板像素级一致 |
| 尺寸 | 16/32/64/128/256/512/1024 | 对应 `AppIcon.appiconset` 的 10 条声明 |
| Windows | 生成多尺寸 `.ico` | `windows/runner/resources/app_icon.ico` |

> ⚠️ Xcode 从 asset catalog 编出的 `AppIcon.icns` **只到 256×256**
> （实测只有 `ic04/ic07/ic11/ic13` 四个块；**原始 Flutter 工程也一样**，不是配置问题）。
> 结果大尺寸下图标发糊。`build_macos.sh` 里加了 1.5 步用 `iconutil`
> 重打一份 16→1024 的完整 icns —— **必须放在签名之前**，否则改
> `Contents/Resources` 会让签名失效。

### 重新生成图标

一条命令（默认取 `~/Documents/icon.png` 的左上方形区域）：

```bash
uv run --with pillow python tools/make_icons.py
uv run --with pillow python tools/make_icons.py <源图> --region center   # 换区域
bash tools/build_macos.sh          # 重新打包（会自动重打完整尺寸的 .icns）
```

`tools/make_icons.py` 会一次写好 macos 的 7 张 + windows 的 `.ico`。
圆角遮罩取自 **`tools/icon_mask_1024.png`**（从 Flutter 模板图标的 alpha 通道提取并固化），
所以脚本可以反复重跑、结果完全一致。

> ⚠️ 别把遮罩来源改成「当前 `app_icon_1024.png` 的 alpha」：脚本跑第二遍时
> 那张图已经是自己生成的产物了，遮罩会越缩越小。这个坑已经写进脚本注释。

---

## 十、分发与公证

### 分发产物：dmg（主要）+ zip（备选）

`build_macos.sh` 现在一次产出两个：

| 产物 | 用途 | 应用在里面的名字 |
|------|------|------------------|
| `dist/编程练习册-macOS-universal.dmg` | **发给别人的那个**，拖拽安装 | `编程练习册.app` |
| `dist/编程练习册-macOS-universal.zip` | 解压即用的绿色版 | `code_workbook.app` |

dmg 的形态就是经典的「左边应用、右边 Applications」：卷里放 `.app` 本体、
一个指向 `/Applications` 的符号链接当落点，外加一份
`首次打开请先读我.txt` —— **Gatekeeper 那步必须让最终用户看得到**，
写在构建脚本的输出里他们看不到。

> **为什么 dmg 里用中文名、zip 里用 ASCII 名？**
> 不是疏漏，是躲一个编码陷阱：`ditto -c -k` 写 zip 时用的是 UTF-8 字节，
> 但**不设 UTF-8 标志位**（实测 2438 个条目一个都没设）。macOS 自己的归档工具
> 按 UTF-8 解释，解出来名字是对的；而 Windows 资源管理器、Linux 的 `unzip`
> 会按 CP437 解，中文名会变成 `τ╝ûτ¿ïτ╗âΣ╣áσåî.app` 那种乱码。
> dmg 不经过 zip 编码层（磁盘文件系统原生支持 Unicode），所以用中文名没有风险。
> Finder 两边都显示「编程练习册」（靠 `CFBundleDisplayName`）。

改名是安全的，已实测：签名覆盖的是包**内容**，不含目录名；
`CFBundleExecutable` 与 `Contents/MacOS/` 里的文件名都没动，仍然对得上。

### 首次打开会被拦（安装包也躲不掉）

**不公证也能分发**，但对方首次打开会被 Gatekeeper 拦 ——
**换成 dmg 并不能免掉这一步**，那是签名证书的事，不是打包形式的事：

```bash
# 让对方执行（或右键 →「打开」）
xattr -dr com.apple.quarantine "/Applications/编程练习册.app"
```

**要彻底免提示**（推荐正式分发时做）：

1. 需要 Apple Developer 账号（$99/年）
2. 用 Developer ID 重新签名：
   ```bash
   bash tools/build_macos.sh --sign "Developer ID Application: 你的名字 (TEAMID)"
   ```
   有真实身份时脚本会**连 dmg 一起签**（公证要求这一步）。
3. 公证 **dmg**（分发的是它，就公证它）：
   ```bash
   xcrun notarytool submit dist/编程练习册-macOS-universal.dmg \
     --apple-id "你的AppleID" --team-id "TEAMID" --password "App专用密码" --wait
   xcrun stapler staple dist/编程练习册-macOS-universal.dmg
   ```

> Windows 那边同样要面对 SmartScreen，同样需要买证书。
> 两个平台的「未知开发者」提示是同一类成本。

---

## 十一、体积参考（实测值）

| 项 | 大小 |
|----|------|
| 更纱黑体 Regular+Bold（已在仓库） | 46 MB |
| python-build-standalone 3.12.14（原始，单架构） | 66 MB |
| └ 裁减后（去 Tcl/Tk、idlelib、2to3 等） | **54 MB** |
| └ ×2（universal 要两份） | **108 MB** |
| **最终 `.app`** | **198 MB** |
| **最终分发 zip** | **82 MB** |

裁减已实测不会影响判题：`json/re/math/random/itertools/functools/collections/datetime/decimal/fractions/statistics/string/os/csv/heapq/bisect` 全部可正常导入，中文与 emoji 输出正常。

> 想省掉一份 Python（约 54MB）只有一个办法：把产物做成单架构
> （`flutter build macos` 没有架构开关，需在 Xcode 里把 `ARCHS` 设成单一架构），
> 代价是另一种架构的用户要跑 Rosetta 2。

> 参考：产物已实测**完全可重定位**——捆绑解释器的 `LC_RPATH` 是 `@executable_path/../lib`，
> 无绝对路径泄漏，搬进 `.app` 后照常运行。

---

## 十二、环境实测结论（2026-09-10）

本机：macOS 26.0 (25A354) / Intel x86_64 / Xcode 26.3 / Flutter 3.47.3 (`~/Develop/flutter`)

| 检查项 | 结论 |
|---|---|
| `flutter build macos --release`（纯工程） | ✅ 成功，38.7MB `.app` |
| `flutter build macos --release`（含两个插件） | ✅ 成功，走 SPM 不需 CocoaPods |
| `flutter pub get` | ✅ 成功 |
| `flutter analyze` | ✅ 1 条 info（`import_service_test.dart` 引用 `path_provider_platform_interface` 未声明依赖，**历史遗留**，非本次改动引入） |
| `flutter test` | ✅ **48/48 全过** |
| 判题引擎真机跑题库 | ✅ 题 301/501/701/901 判题 OK（含 `-X utf8`，中文正常） |
| `tools/setup_macos_platform.sh` | ✅ 生成 `macos/`，沙盒已关并回读校验 |
| `tools/build_macos.sh` 全流程 | ✅ 编译→捆绑两份 Python→裁减→签 14 个 Mach-O→`valid on disk`→出 zip |
| 打包产物真机启动 | ✅ 启动成功，日志确认解析到 `Contents/Resources/python-x86_64/bin/python3` |
| 磁盘 | ✅ 剩余 150 GB |
| 网络 | ✅ pub.dev / github / storage.googleapis.com / cdn.cocoapods.org 均通；`maven.google.com` 不通（**仅 Android 受影响，可无视**） |

### 沙盒前后对比（真实运行 `.app` 实测）

同一个应用、同一份代码，只改 `app-sandbox` 这一个开关：

| | 沙盒 ON（模板默认） | 沙盒 OFF（本手册方案） |
|---|---|---|
| 容器目录 | 生成 `~/Library/Containers/<bundle-id>/Data/` | 不生成 |
| `getApplicationDocumentsDirectory()` | 被重定向进容器 | `~/Documents` ✅ |
| `getDownloadsDirectory()` | 被重定向进容器 | `~/Downloads` ✅ |
| 写容器外文件 | ❌ 被拦截 | ✅ 成功 |
| `SharedPreferences` | 可用 | 可用 |

→ 这就是**必须关沙盒**的直接证据：不关的话，「进度导出」写进用户根本找不到的容器目录，
「进度导入」扫描的也是容器里那个空 Downloads。

### 打包产物真机启动日志（最终验收证据）

```
[2026-09-10 20:31:30] [system] [info] 应用启动 (V1.2)
macOS (Version 26.0 (Build 25A354)) / Dart 3.13.3 ... on "macos_x64"
  / Python .../python_practice.app/Contents/Resources/python-x86_64/bin/python3
[2026-09-10 20:31:30] [system] [info] 日志文件目录：
  /Users/sakiriwaizumi/Library/Application Support/com.sakiri.python-practice/logs
```

一行日志同时证明了三件事：捆绑解释器被正确解析、架构探测正确
（`macos_x64` → `python-x86_64`）、沙盒确实关了（日志落在真实
`~/Library/Application Support/` 而非容器）。

### ⚠️ Intel Mac 的长期风险

`flutter doctor` 已开始警告：

> Flutter is deprecating support for Intel-based Macs. A future version of Flutter will
> require an Apple Silicon Mac to build applications.

相关上游议题：[#174140 考虑降低 x64 Mac 支持](https://github.com/flutter/flutter/issues/174140)（open）、
[#173760 Xcode 26 在 Intel Mac 上的报错改进](https://github.com/flutter/flutter/issues/173760)（closed）。

实测澄清一点：**#173760 说的「Xcode 26 不能在 Intel Mac 上跑」只针对 iOS 模拟器运行时**
（报 `iOS 26.0 Platform Not Installed`），**macOS 桌面构建不受影响**——本机已实测通过。

实务建议：
- **不要盲目 `flutter upgrade`**。先把 3.47.3 当作已验证的可用版本钉住。
- 若要升级，先确认新版是否仍发布 `flutter_macos_<ver>-stable.zip`（x64 包）。
- 长期看这台 Intel 机器迟早要换，或把构建迁移到 Apple Silicon 机器上。

---

*本手册由检查结论整理，2026-09-10。*
