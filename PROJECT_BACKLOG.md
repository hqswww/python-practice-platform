# 📋 项目 Backlog（待办 / 想法池）

> 维护方式：Sakiri 想到什么就丢进来，我（Sakiri-chan）记录、排期。
> 状态：`⬜ 待办` · `🔨 进行中` · `✅ 已完成` · `🔇 搁置`
> 里程碑用 tag 归档（如 v1.0-final）。

---

## 🎯 当前版本状态

- **v1.0-final**（已发布，git tag + GitHub 远程存档）
- P1/P2/P3 全部主要功能完成：判题引擎、交互终端、学习页详细教程（72 题全覆盖）、成就与称号系统、自定义主题强调色
- Windows 迁移完成：绿色版 .exe，免装 Python（捆绑嵌入式 Python 3.12.10）

---

## 🐛 已知问题 / 待修

### ⬜ 交互终端输入栏底色跟随主题未固定
- **现象**：用户切到深色主题时，终端输入栏也跟着变深（期望固定深色衬底 `#1E2430`）
- **状态**：代码里已写固定色，但重启后仍随主题 → 尚未定位
- **怀疑**：全局主题或 InputDecoration 背景被覆盖 / 终端容器被主题色替换
- **优先级**：低（用户说小问题，先搁置）

---

## 💡 开放想法（攒一批做一版）

### 归档中的历史想法（已完成或已决策）
| 想法 | 状态 |
|------|------|
| 判题首个用例差异详情 | ✅ 已实现（`_analyzeWrongAnswer` 字符级 diff） |
| 判题输入自适应（EOFError → 按空格拆分重试） | ✅ 已实现（方案X） |
| 成就与称号系统 | ✅ v1.0 |
| 自定义主题强调色 | ✅ v1.0 |
| 学习页详细教程（72 题） | ✅ v1.0 |
| Windows 迁移 .exe | ✅ v1.0 |
| macOS 迁移 .app | 🔨 准备就绪，待实机验证（见下） |

### 🖥️ 响应式界面（已实现）
- [x] `lib/pages/widgets/responsive.dart`：断点（840）+ `AdaptiveMasterDetail` 自适应分栏
- [x] **设置页**：宽屏「左分类列表 + 右详情」两栏；窄屏整页列表、点击进入详情页
- [x] **练习页**：分类网格从固定 3 列改为按最大宽度自适应列数（宽窗口不再被撑成巨型方块）
- [x] 窗口默认尺寸 800→1180，并设最小 420×520（模板默认 800 低于断点，启动只会看到单列）
- [x] 测试：`responsive_layout_test.dart`（12 项）+ `practice_grid_test.dart`（3 项）

**其他页面（本轮一并做了）**
- [x] `MaxWidthBody` + `ContentWidth`：给列表/表单类页面加最大宽度并居中
      （`list`=900 / `article`=760 / `workspace`=1160 / `log`=1100）
- [x] 已接入：题目列表、收藏、测试历史（含历史详情页）、测试模式、错题本、日志中心、
      学习页正文、成就页
- [x] **学习页**原来固定 230px 侧栏且无断点（窄窗口正文只剩 ~190px）→
      窄屏侧栏收进抽屉、正文独占整屏，选完自动收起
- [x] **成就页**网格从固定 3 列改为按最大宽度自适应
- [x] 测试：`responsive_pages_test.dart`（10 项，含三页面 × 六种宽度的溢出扫描）

**应用图标（已完成）**
- [x] 用 `~/Documents/icon.png` 的左上方形区域做图标（`--region top-left`）
- [x] 圆角复用 Flutter 模板的 alpha（Apple squircle），投影一并继承
- [x] macOS 7 张（16→1024，带 alpha）+ Windows 多尺寸 `.ico`
- [x] `tools/make_icons.py`（幂等，遮罩固化为 `tools/icon_mask_1024.png`）
- [x] `build_macos.sh` 加 iconutil 步骤重打完整 icns（Xcode 原生只到 256×256）

**还没做的**
- [ ] 窗口尺寸记忆（重启保留用户拉的大小）
- [ ] `test_page` 的做题界面（题目 + 编辑器）在宽屏下仍偏单栏，
      要做成左右分栏的话改动较大，等实际用起来觉得挤再说

### 新的候选（待 Sakiri 排优先级）
- [x] **捆绑更纱黑体 Regular+Bold**（已实现 v1.1）：Windows 下中文笔画粗细不一致 → 全局默认字体统一。Sakiri 选 A：接受 46MB（大部分人不缺存储）。sarasaGothicSC pubspec 字重700 + main.dart fontFamily
- [x] **想法1·错题本/测试同步**：错题本 TextField→PythonCodeField；测试模式补交互终端（待做）
- [x] **想法2·进度导入功能**（已实现 v1.1）：JSON 合并导入（取并集），设置页新增导入卡片。7 导入单测，45 测试全过
- [ ] 可考虑：错题回顾/复习模式再增强
- [ ] 可考虑：学习进度导出格式扩展（如 JSON/CSV）
- [ ] 可考虑：字体/字号设置、代码主题（浅色/深色编辑器）
- [ ] 可考虑：设置项备份 / 云同步

---

## 🍎 macOS 迁移（打包链路已跑通 ✅）

**已完成（代码 + 脚本 + 文档）**
- [x] `lib/services/python_runtime.dart` 加 macOS 分支：架构专属捆绑 → 通用捆绑 →
      Homebrew/MacPorts/Xcode 绝对路径 → PATH 兜底
- [x] `Abi.current()` 架构探测（universal 包要在两份 Python 之间挑）
- [x] `lib/services/error_log_service.dart` 平台行补 macOS + 实际解析的 Python 路径
- [x] `test/python_runtime_test.dart` 同步更新（原「非 Windows 即 python3」断言已失效）
- [x] `tools/setup_macos_platform.sh`、`tools/build_macos.sh`
- [x] `docs/MACOS_MIGRATION.md`（11 节，全部结论附实测证据）
- [x] `.metadata` 补回被 `flutter create` 挤掉的 `windows` 平台记录

**环境已就绪并实测通过（2026-09-10）**
- [x] Flutter **3.47.3 x64** 装在 `~/Develop/flutter`（PATH 写在 `~/.zprofile`）
- [x] **CocoaPods 不需要**：Flutter 3.47 走 Swift Package Manager，实测两个插件都正常
      （`path_provider_foundation 2.6` 已迁移为纯 Dart FFI，无需原生包管理器）
- [x] `flutter build macos --release` 在 Intel + Xcode 26.3 上实测成功
- [x] `flutter analyze` 通过（1 条历史遗留 info）
- [x] `flutter test` **48/48 全过**
- [x] 判题引擎真机跑题库通过（题 301/501/701/901）
- [x] 沙盒前后对比实验：证明关沙盒才能拿到真实 `~/Documents` / `~/Downloads`
- [x] `setup_macos_platform.sh` 跑通，生成 `macos/` 且沙盒回读校验通过
- [x] `build_macos.sh` 全流程跑通：universal 双 Python → 裁减 → 签 14 个 Mach-O →
      `valid on disk` → 出 `dist/Python练习平台-macOS-universal.zip`（82MB）
- [x] 打包产物真机启动成功，日志确认运行时解析到
      `Contents/Resources/python-x86_64/bin/python3`

**踩过的坑（都已修，细节见 MACOS_MIGRATION.md）**
- [x] Flutter macOS 模板默认开 App Sandbox → 必须关（否则导出/导入失灵）
- [x] `plutil` 把 `.` 当键路径分隔符 → 改 entitlements 必须转义点
- [x] `$VAR` 紧跟全角字符会被 bash 吃进变量名 → 必须写 `${VAR}`
- [x] codesign 把 `Frameworks/` 下任何目录当嵌套代码 → Python 必须放 `Resources/`
- [x] `flutter build macos` 产物是 universal 且无架构开关 → 两种架构的 Python 都得带

**下一步（只剩人工验收）**
- [ ] `flutter run -d macos` 或直接开打包好的 .app，手点一遍：
      判题（含中文 input 提示的题）、交互终端、进度导出 → 到 `~/文稿/PythonPractice导出/`、
      进度导入 → 能列出下载目录的 JSON
- [ ] 换一台 Apple Silicon 机器实测 arm64 那一份 Python 是否被正确选中

**已知待决策**
- [ ] 是否购买 Apple Developer 账号做公证（否则用户首次打开需右键「打开」）
- [ ] 体积 198MB（App）/ 82MB（zip）。想省 54MB 只能做单架构产物，
      代价是另一架构的用户要装 Rosetta 2
- [ ] 是否在 macOS 上改用系统中文字体，省掉 46MB 的 Sarasa
- [ ] **Intel Mac 长期风险**：Flutter 已警告未来版本不再支持 Intel 构建。
      建议钉住 3.47.3，升级前先确认新版仍发布 x64 包；长期需迁移到 Apple Silicon
- [ ] Homebrew 已放弃 Intel macOS 支持，会影响后续 brew 装包（备选 MacPorts）
- [ ] 缺 `docs/` 里的截图 / 用户侧安装说明

---

## 🚀 发布流程（改完一轮怎么发新版）

1. 攒一批改动，我改完测完（`flutter test` 全过 + build 成功）
2. 打 tag（如 `v1.1`）
3. 推 GitHub（`git push --tags`）
4. 你在 Windows 重新跑 `tools\build_windows.ps1` 出一版新 .exe
5. 分发 `dist\Python练习平台\` 文件夹

---

## 🔧 维护备忘

- **改代码**：小步 commit + 可回滚（GitHub 远程是保险箱）
- **远程仓库**：`git@github.com:hqswww/python-practice-platform.git`
- **Windows 重新拉最新版**：`git clone` 或 `git pull`（只拉源码，不带缓存）
- **判题**：Linux = 系统 `python3`；Windows = 捆绑 `python/python.exe`；
  macOS = 捆绑 `Contents/Resources/python-<arch>/bin/python3`（按 `Abi.current()` 挑架构）
- **编码**：判题进程已强制 UTF-8（`-X utf8` + `PYTHONIOENCODING`）
