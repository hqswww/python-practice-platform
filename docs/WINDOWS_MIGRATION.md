# 🪟 Windows 迁移手册

> 目标：把「Python 练习平台」在 Windows 上打出可分发、免装 Python 的 `.exe`。
> 本手册 = 阶段 A（Linux 侧已备好代码/脚本）+ 阶段 B（Windows 虚拟机实操）。

---

## 一、架构结论（为什么这样设计）

| 项 | 决策 | 原因 |
|----|------|------|
| 构建机 | **必须在 Windows** | Flutter Windows 桌面 = C++/MSVC 工具链，无法 Linux 交叉编译 |
| Python | **嵌入式 Python**（`python-3.13-embed-amd64.zip`） | 免装、体积小(~10MB)、够判题用 |
| Python 位置 | 放在 `exe同目录/python/` | 判题引擎按**相对 exe 路径**找，不依赖系统 PATH |
| 编码 | 进程加 `-X utf8` + `PYTHONIOENCODING=utf-8` | Windows Python 默认可能 GBK，中文输出会比对错 |
| 分发 | 整目录拷贝（绿色版） | 无需安装，双击即用 |

---

## 二、Windows 机器前置环境（一次性安装）

1. **Flutter SDK**（Windows）
   - 下载：https://docs.flutter.dev/get-started/install/windows
   - 解压到 `C:\flutter`，把 `C:\flutter\bin` 加入 PATH
   - `flutter doctor` 确认无红叉

2. **Visual Studio**（C++ 桌面开发套件）
   - 装 **Visual Studio 2022 Community**
   - 勾选「**使用 C++ 的桌面开发**」工作负载（含 MSVC 编译器和 Windows SDK）
   - 这是 Flutter Windows 编译的硬依赖，缺失会报 `Unable to find suitable Visual Studio toolchain`

3. 确认：
   ```powershell
   flutter doctor
   flutter --version   # 应显示 windows 平台可用
   ```

---

## 三、在 Windows 上一键打包

把整个项目文件夹（含 `windows/`、`lib/`、`assets/`、`tools/`）拷到 Windows 机器。

在**项目根目录**打开 PowerShell，运行：

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
```

脚本自动完成 4 步：
1. `flutter build windows --release` 编译 exe
2. 下载嵌入式 Python
3. 配置 `.pth`（可选开启 site-packages）
4. 组装到 `dist\Python练习平台\`（exe + data + python/）

---

## 四、验证与分发

### 验证（关键！）
1. 双击 `dist\Python练习平台\Python练习平台.exe` 能启动
2. **重点测判题**：随便挑一题写对代码提交，应显示「通过」而非乱码/报错
   - 中文输出的题尤其要测（验证编码加固是否生效）
3. 测试交互终端、成就、主题色是否正常

### 分发
把整个 `Python练习平台` 文件夹打包成 zip 发给用户。
用户双击 exe，**无需安装 Python**。

---

## 五、常见坑 & 排查

| 症状 | 原因 / 解法 |
|------|------------|
| `flutter build windows` 报找不到 VS | 没装 Visual Studio C++ 工作负载 |
| 判题输出乱码（中文变 `鍜嬪挓`） | 编码未生效 → 检查 `PythonRuntime.withUtf8Env`（已内置） |
| 用户机器说「找不到 python」 | 打包时 `python/` 没拷全 → 重跑 build 脚本 |
| 判题 `ModuleNotFoundError` | 嵌入式 Python 缺第三方库 → 需手动把包放进 `python/Lib/site-packages/` |

---

## 六、代码侧已完成的迁移准备（阶段 A，Linux 上已做）

- ✅ `flutter create --platforms=windows .` 生成 Windows 脚手架
- ✅ 新增 `lib/services/python_runtime.dart`：
  - `resolvePythonCommand()` — Windows 优先找捆绑 python，其他回退 `python3`
  - `withUtf8Env()` — 强制 UTF-8 环境
  - `utf8Args` — `['-X','utf8']` 启动参数
- ✅ `judge_engine.dart` / `interactive_runner.dart` 接上 `PythonRuntime`
- ✅ 新增 `test/python_runtime_test.dart`
- ✅ `tools/build_windows.ps1` 一键打包脚本
