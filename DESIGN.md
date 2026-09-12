# 编程练习册 — 项目设计文档

> 目标：面向计算机入门后辈的**编程**练习/检测综合平台（Python / C，可继续扩语言）
> 形态：Flutter 本地桌面应用（Windows / Linux / macOS）
> 状态：**v1.2**（多语言地基 + Python / C 两门题库就位）
>
> ⚠️ 本文档记录的是 v1.0 时期的设计决策，其中「捆绑 Python runtime」等表述
> 只适用于 Python；C 走系统编译器路线。多语言部分见 `docs/MACOS_MIGRATION.md`
> 与 `tools/C_BANK_SPEC.md`。

## 一、核心闭环
学生选题 → 写代码 → 运行（Python 解释执行 / C 先编译）→ 比对输出 → 对/错反馈 + 进度记录

## 二、技术决策（已拍板）
| 项 | 决策 |
|----|------|
| 框架 | Flutter（Dart），开发者已有 Flutter Android 经验 |
| 开发机 | Linux（当前 Fedora 44），最终迁移 Windows 出 .exe |
| 判题 | 捆绑 Python runtime，标准输入输出比对 |
| 编辑器 | MVP 用基础文本框（TextField），增强留二期 |
| 判题交互 | 即时运行 + 自动标对错 |
| 进度存储 | shared_preferences（本地持久化） |
| 防作弊 | 不做（自习自测场景） |
| 结果显示 | 可切换：简洁模式(对/错) / 详细模式(实际vs期望 + traceback) |

## 三、题库结构（对齐 runoob 学习进度）
```
assets/problems/
├── 01_syntax.json      # 基础语法（缩进/注释/print/变量）
├── 02_datatype.json    # 数据类型与转换
├── 03_operators.json   # 运算符
├── 04_conditionals.json  # 条件判断 if/elif/else
├── 05_loops.json       # 循环 for/while
├── 06_strings.json     # 字符串处理
├── 07_lists.json       # 列表
├── 08_tuples_sets.json # 元组+集合
├── 09_dicts.json       # 字典
├── 10_functions.json   # 函数
├── 11_advanced.json    # 进阶（迭代器/生成器/异常/文件）
└── 12_challenges.json  # 综合挑战
```
难度：easy / medium / hard（3 级）
- 入门同学接受能力偏弱 → 保留细分分类，循序渐进
- 高难度题描述可更详细

## 四、题目 JSON 格式 (v1)
```json
{
  "id": 101,
  "title": "Hello, World!",
  "difficulty": "easy",
  "description": "...",
  "input_format": "...",
  "output_format": "...",
  "sample_input": "...",
  "sample_output": "...",
  "test_cases": [
    {"input": "...", "output": "..."}
  ],
  "hints": ["提示1", "提示2"]   // 多级提示，逐步揭示
}
```

## 五、判题反馈机制（友好错误提示层）⭐ 用户体验灵魂
判题失败时，在简单显示"错误"前，先做智能检测：
| 常见错误 | 检测 | 提示 |
|---------|------|------|
| 空格/换行问题 | 去空白后一致但原样不同 | 内容对但多了/少了空格或换行，注意格式 |
| 多余输出 | 实际输出含预期输出 | 结果包含在输出中，可能多了额外内容 |
| 中文标点/全角 | 输出含全角字符 | 检查是否用了中文标点（应为英文半角） |
| 没读入输入 | 输出固定与输入无关 | 可能需要用 input() 读入输入 |

核心：**先做"空白规范化比对"**，判定后给针对性提示，而非干巴巴"答案错误"。

## 六、里程碑
- [x] 需求/设计讨论定稿
- [x] 题目格式 + 题库结构 + 判题反馈机制设计
- [x] 安装 Flutter SDK（~/flutter 3.44.9，PATH 已写入 fish）
- [x] 创建项目骨架（flutter create --platforms=linux）
- [x] 实现题目数据模型 + 题库加载
- [x] 实现判题引擎核心（judge_engine.dart，5 项测试通过）
- [x] 实现题目列表页 + 编辑器判题页（左右分栏）
- [x] 实现判题结果展示（简洁/详细模式）
- [x] MD3 主题 + 深色模式 + “下一题”按钮
- [x] 题库 12 分类全部填充完成（72 道题）
- [x] 底部 NavigationBar 三板块（练习/测试/设置）
- [x] 进度存储（shared_preferences，做对自动标记 + 练习页进度圆环/勾选）
- [x] 测试板块（随机抽题组卷、**自由选题跳题**、逐题判题、交卷汇总得分）
- [x] 设置板块（主题模式切换、判题超时滑块、真实难度统计详情、清除进度）
- [x] UI 动画体系（设置卡片 hover、判题结果交错入场、切题滑动、结果庆祝、练习网格入场、导航切换过渡）
- [x] 迁移 Windows 构建 .exe

## 七、后端引擎已验证的技术点
- `Process.start(python3, [solution.py])` + stdin/stdout 管道判题可行
- 判题通过判定用 `_normalizeLines`（去每行尾空白+统一换行），保留行内空格避免把"多打空格"误判为通过
- 格式错误走 `_analyzeWrongAnswer` 友好提示（去空白一致→提示格式；首个不同字符定位）
- 测试：`flutter test`（判题 4 项 + 启动 1 项，全过）

## 八、题库档案（72 道）
各分类均匀分布 easy/medium/hard 三级：
- 01 语法 / 02 数据类型 / 03 运算符 / 04 条件 / 05 循环 / 06 字符串
- 07 列表 / 08 元组集合 / 09 字典 / 10 函数 / 11 进阶 / 12 综合挑战

## 九、UI 动画体系 ⭐（Material 3 动效）
全部基于 Flutter 内置动画组件，无第三方包：

| 位置 | 动画 | 实现 |
|------|------|------|
| 设置卡片 | hover 上浮 + 阴影加深 | `AnimatedScale` + `MouseRegion`（onEnter/onExit） |
| 设置进度详情 | 平滑展开/收起 | `AnimatedSize` + 箭头 `AnimatedRotation` |
| 判题结果面板 | 交错滑入 | `TweenAnimationBuilder(0→1)` + 每元素按 index 延迟（`_stagger`） |
| 判题结果切换 | 整体淡入缩放 | `AnimatedSwitcher` + key 绑自增 `_judgeRun`，Fade+Scale 组合 |
| 全部通过 | 头部卡片弹跳庆祝 | `TweenAnimationBuilder` + `Curves.elasticOut` |
| 测试切题 | 滑动+淡入 | `AnimatedSwitcher` + key 绑题目 id，Slide+Fade |
| 测试进度条 | 平滑填充 | `AnimatedFractionallySizedBox`（widthFactor 随进度） |
| 测试结果页 | 上移淡入 + 奖杯弹跳 | `TweenAnimationBuilder` + easeOutBack；得分≥80% 用 elasticOut |
| 练习分类网格 | 交错入场 | 整体 `TweenAnimationBuilder`，每卡片 Index×0.08 延迟的 `_stagger` |
| 分类卡片 | hover 缩放 | `AnimatedScale` + `MouseRegion`，StatefulWidget |
| 导航切换 | 轻微缩放+淡入 | `TweenAnimationBuilder` + key 绑 `_navTransition` |

### 交错入场通用手法（`_stagger`）
```dart
// 每元素延迟：start = index*间隔，end = start+窗口宽度
final start = (index * 0.08).clamp(0.0, 0.7);
final end = (start + 0.35).clamp(0.0, 1.0);
// 在单个 TweenAnimationBuilder(0→1) 里，把整体进度 t 映射到每个元素局部进度
// 再配 Curves.easeOutCubic 得到滑入感
```

### 关键设计原则
- **保留 IndexedStack 状态**：导航切换用 `TweenAnimationBuilder`（key 触发）而非 `AnimatedSwitcher`，避免重建导致测试会话/页面状态丢失。
- **判题结果每次触发**：用自增计数器 `_judgeRun` 做 key，即使结果相同也重新过渡。
- **交错用单控制器**：一个 `TweenAnimationBuilder(0→1)` 驱动所有元素，靠 index 计算延迟，避免多 controller 浪费。
- **切题 key 绑题目 id**：`ValueKey(problem.id)` 由 AnimatedSwitcher 识别切换。

### 值得注意的坑
- 交错 `_stagger` 计算要 clamp 到 [0,1]，避免 t 越界导致闪现。
- `AnimatedSwitcher` 换 key 会重建子树：不适合保状态场景，导航切换用 `TweenAnimationBuilder` 更合适。

## 十、v1.0 小结（第一版收官）✅
第一版基本功能已全部落地，本地可运行：

| 维度 | 内容 |
|------|------|
| 题库 | 12 分类 72 题（01 语法 → 12 综合挑战），对齐 runoob 学习进度，easy/medium/hard 三级 |
| 练习 | 分类网格 → 题目列表 → 代码编辑器；多级提示；实时判题 + 友好错误提示；做对自动存进度（shared_preferences） |
| 测试 | 随机抽题组卷（5/10/15/全部）；**自由选题跳题**（题号导航栏 + 每题独立草稿 + 判题反馈条 + 交卷汇总）；做对题数计分，≥80% 奖杯 |
| 设置 | 主题切换（系统/浅/深）、判题超时滑块、进度统计（按难度）、清除进度 |
| 动画 | 全套 MD3 动效（详见第九章） |
| 判题 | 捆绑 Python runtime，Process.start 喂输入比对输出；`_normalizeLines` 判定；友好错误检测层 |
| 验证 | `flutter analyze` 零问题、5 项测试全过、`flutter build linux --release` 成功、应用稳定运行 |

**技术栈**：Flutter 3.44.9 / Dart 3.12.2 / 无第三方动画包 / shared_preferences 持久化

## 十一、优化清单（分阶段，待用户挑选）
### P1 体验增强（已完成 ✅）
- [x] 测试默认定位到**下一道未做的题**
- [x] 测试结束时提示**还有 N 题未做**（交卷前确认弹窗）
- [x] 判题结果面板显示**耗时 / 用例通过数**

### P2 功能扩展（已完成 ✅）
- [x] **错题本**：做错的题单独收集 + “未作答”标记区分 + 专项重练
- [x] **计时器**：测试板块倒计时压力模式（时间到自动交卷）
- [x] 题目收藏/标记“待复习” + 收藏复习页
- [x] 进度导出：JSON / CSV 写入文档目录
- 另有：参考代码（题解）、测试历史 + 统计概览卡、逐题回看

### P3 深度体验
- [x] 代码编辑器增强之**语法高亮 + 行号**（自研 `PythonCodeField`，零第三方依赖）
- [x] 自动缩进 / 更多高亮细节
- [x] 更丰富的判题反馈（显示首个用例差异详情）
- [x] 成就/称号系统（连胜、全对勋章）
- [x] 深色/浅色主题自定义强调色

### P4 工程化
- [x] **迁移 Windows**：Windows 分区装 Flutter SDK → `flutter build windows` 出 .exe → 捆绑 Python runtime（方案 A）
- [ ] 打包安装器（Windows 用 Inno Setup / MSIX）
- [ ] 数据库替换 shared_preferences（题目量大/需要复杂查询时，可评估 sqlite / drift 或 hive，先查开源）

## 十二、待验证/进行中
- [ ] 进度存储实机验证（做对一题 → 列表打勾 → 重启保留）
- [ ] 测试板块自由选题实机体验反馈
