import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/problem_repository.dart';
import '../models/judge_result.dart';
import '../models/problem.dart';
import '../models/problem_category.dart';
import '../models/test_record.dart';
import '../services/judge_engine.dart';
import '../services/language_service.dart';
import '../services/progress_service.dart';
import '../services/test_scope_resolver.dart';
import '../services/settings_service.dart';
import 'test_history_page.dart';
import 'widgets/difficulty_style.dart';
import 'widgets/rich_message_text.dart';
import 'widgets/test_scope_dialog.dart';
import 'widgets/interactive_terminal.dart';
import 'widgets/python_code_field.dart';
import 'widgets/responsive.dart';
import 'widgets/language_switcher.dart';

/// 测试中单题状态
enum Status { none, submitted, correct }

/// 测试模式定义
///
/// [id] 用于持久化「该模式的倒计时时长」——刻意用稳定 id 而不是题量做键：
/// 以后题量变了（比如全题库从 72 变 100），用户已保存的时长不会跟着丢。
class _TestModeDef {
  final String id;
  final String label;

  /// 题量；0 表示「全题库」（用实际题库总数）
  final int count;

  const _TestModeDef(this.id, this.label, this.count);
}

const List<_TestModeDef> _kTestModes = [
  _TestModeDef('quick', '快速测验', 5),
  _TestModeDef('standard', '标准测验', 10),
  _TestModeDef('intensive', '强化测验', 15),
  _TestModeDef('full', '全题库', 0),
];

/// 可选的倒计时时长（秒），0 = 不限时。
/// 0 / 5 / 10 / 15 / 20 / 30 / 45 / 60 / 90 / 120 分钟。
const List<int> kTestDurationChoices = [
  0, 300, 600, 900, 1200, 1800, 2700, 3600, 5400, 7200,
];

/// 单题最近一次判题的详情（供解题界面显示）
class _JudgeRecord {
  final int passedCases;
  final int totalCases;
  final int timeMs;
  final bool hasRuntimeError;

  /// 输出全对，但题库要求的语法没用上（见 SourceRequirement）。
  /// 这种情况下 [allPassed] 也是 false —— 不能算做对。
  final bool requirementUnmet;

  /// 判题过程的附加消息（如出错时的提示）
  final String? message;

  const _JudgeRecord({
    required this.passedCases,
    required this.totalCases,
    required this.timeMs,
    required this.hasRuntimeError,
    this.requirementUnmet = false,
    this.message,
  });

  bool get allPassed =>
      passedCases == totalCases && totalCases > 0 && !requirementUnmet;
}

/// 交卷后的逐题回看项（对错 + 我的代码 + 参考代码）
class _ReviewItem {
  final Problem problem;
  final bool wasCorrect;
  final String myCode;

  const _ReviewItem({
    required this.problem,
    required this.wasCorrect,
    required this.myCode,
  });
}

/// 测试板块：随机抽题组卷，自由选顺序作答，汇总得分
class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  /// 当前语言的分类（保留分类结构：出题范围要按大类选）
  List<ProblemCategory>? _categories;

  /// 当前语言的**全部**题目（分类拍平后的结果）
  List<Problem>? _allProblems;
  final ProgressService _progress = ProgressService();
  final Random _random = Random();

  // 当前测试状态
  List<Problem> _questions = [];
  int _questionIndex = 0;
  bool _testActive = false;
  bool _testDone = false;
  int _reviewedCount = 0; // 本次测试总题数快照（交卷后保留）

  // 自由选题：每题独立保存
  final Map<int, String> _drafts = {}; // 题目id -> 代码草稿
  final Map<int, Status> _status = {}; // 题目id -> 完成/正确状态
  final Map<int, _JudgeRecord> _records = {}; // 题目id -> 最近判题详情

  // 交卷后的逐题回看快照（问题 + 对错 + 我的代码 + 参考代码）
  List<_ReviewItem> _reviewItems = [];

  // 倒计时压力模式
  bool _countdownEnabled = false;
  int _remainingSeconds = 0; // 剩余秒数
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadProblems();
    languageService.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    languageService.removeListener(_onLanguageChanged);
    _stopTimer();
    super.dispose();
  }

  /// 加载**当前语言**的题库。
  ///
  /// ⚠️ 这里曾经调的是不带参数的 `loadCategories()`，而它返回的是**全部语言**
  /// 的题 —— 于是「全题库」显示的是 216 题（3 × 72），一次 Python 测验里会
  /// 混进 C 和 C++ 的题。多语言重构时 practice_page 跟着改了，这一处漏了。
  /// 出题范围要按「第几个大类」选，前提就是池子里只有一门语言，所以顺手修掉。
  Future<void> _loadProblems() async {
    final lang = languageService.value;
    final cats = await ProblemRepository().loadCategories(language: lang);
    if (!mounted) return;
    // 语言可能在 await 期间又被切了一次：只有还是同一门语言才写回，
    // 否则会用旧语言的结果覆盖新语言的加载
    if (lang != languageService.value) return;
    setState(() {
      _categories = cats;
      _allProblems = [for (final c in cats) ...c.problems];
    });
  }

  /// 切语言要重新加载题库（三个语言各有各的题）
  void _onLanguageChanged() {
    _loadProblems();
  }

  /// 某个模式当前的出题范围解析结果（UI 和抽题都用它，保证「显示几题」和
  /// 「实际出几题」是同一份计算）
  ResolvedScope _scopeOf(_TestModeDef mode) => resolveTestScope(
        categories: _categories ?? const [],
        scope: settings.testScope(mode.id),
      );

  /// 这个模式实际会出几题：模式题量与范围内题数取小。
  /// 「全题库」模式（count = 0）就是范围内的全部题。
  int _questionCountOf(_TestModeDef mode, ResolvedScope resolved) =>
      mode.count == 0 ? resolved.total : min(mode.count, resolved.total);

  /// 开始测试：按该模式的范围抽题，可选倒计时 [countdownSec]（>0 时启用压力模式）
  void _startTest(_TestModeDef mode, {int countdownSec = 0}) {
    final resolved = _scopeOf(mode);
    final count = _questionCountOf(mode, resolved);
    if (count <= 0) {
      // 范围里一道题都没有（理论上按钮会禁用，这里兜底）
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('这个出题范围里没有题目，先调一下范围'),
      ));
      return;
    }
    _stopTimer();
    // 按难度比例抽：直接洗牌取前 N 会让每次卷子的难度结构飘忽不定
    final selected = pickQuestionsByDifficulty(
      pool: resolved.pool,
      count: count,
      random: _random,
    );
    setState(() {
      _questions = selected;
      _drafts.clear();
      _status.clear();
      // 开始时定位到第一道题（此时全部未做）
      _questionIndex = 0;
      _testActive = true;
      _testDone = false;
      _countdownEnabled = countdownSec > 0;
      _remainingSeconds = countdownSec;
    });
    if (_countdownEnabled) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_testActive) return;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        _stopTimer();
        _autoFinishOnTimeout();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 倒计时结束：自动交卷（不弹确认框，直接结算）
  Future<void> _autoFinishOnTimeout() async {
    if (!mounted || !_testActive) return;
    final reviewItems = _questions.map((p) => _ReviewItem(
          problem: p,
          wasCorrect: _status[p.id] == Status.correct,
          myCode: _drafts[p.id] ?? '',
        )).toList();
    setState(() {
      _reviewedCount = _questions.length;
      _reviewItems = reviewItems;
      _questions = [];
      _testActive = false;
      _testDone = true;
    });
    for (final item in reviewItems) {
      if (!item.wasCorrect && _status[item.problem.id] == null) {
        await _progress.markUnanswered(item.problem.language, item.problem.id);
      }
    }
    _progress.addTestRecord(TestRecord(
      timestamp: DateTime.now(),
      correctCount: _correctCount,
      totalCount: _reviewedCount,
      items: reviewItems
          .map((r) => TestRecordItem.fromProblem(
                r.problem,
                wasCorrect: r.wasCorrect,
                myCode: r.myCode,
              ))
          .toList(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⏰ 时间到！已自动交卷')),
    );
  }

  /// 结束测试（交卷）：先确认未做题数
  Future<void> _finishTest() async {
    // 统计未做的题
    final notDone = _questions.where((p) => !_isDone(p)).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认交卷？'),
        content: Text(
          notDone > 0
              ? '还有 $notDone 道题未做（未判题或判错），确定要交卷吗？\n\n已做对：$_correctCount 道。'
              : '所有题都已处理，确定交卷？\n\n已做对：$_correctCount 道。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续答题'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('交卷'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _stopTimer();
    if (!mounted) return;
    // 交卷前抓取逐题回看快照（之后 _questions 会被清空）
    final reviewItems = _questions.map((p) => _ReviewItem(
          problem: p,
          wasCorrect: _status[p.id] == Status.correct,
          myCode: _drafts[p.id] ?? '',
        )).toList();
    setState(() {
      _reviewedCount = _questions.length;
      _reviewItems = reviewItems;
      _questions = [];
      _testActive = false;
      _testDone = true;
    });
    // 没做的题一并收入错题本（判对/判错的已在判题时处理，这里只补漏并标记“未作答”）
    for (final item in reviewItems) {
      if (!item.wasCorrect && _status[item.problem.id] == null) {
        await _progress.markUnanswered(item.problem.language, item.problem.id);
      }
    }
    // 持久化到测试历史（供“回顾测试”查看）
    _progress.addTestRecord(TestRecord(
      timestamp: DateTime.now(),
      correctCount: _correctCount,
      totalCount: _reviewedCount,
      items: reviewItems
          .map((r) => TestRecordItem.fromProblem(
                r.problem,
                wasCorrect: r.wasCorrect,
                myCode: r.myCode,
              ))
          .toList(),
    ));
  }

  /// 切换当前题目
  void _gotoQuestion(int index) {
    setState(() => _questionIndex = index);
  }

  /// 该题是否已完成（判过且非 none）
  bool _isDone(Problem p) {
    return _status[p.id] == Status.submitted || _status[p.id] == Status.correct;
  }

  /// 找到 [from] 之后（含）第一道未做的题；找不到返回 -1
  int _nextUnDone(int from) {
    for (var i = from; i < _questions.length; i++) {
      if (!_isDone(_questions[i])) return i;
    }
    return -1;
  }

  /// 找上一道未做的题（交卷/开始时定位用）；找不到返回 -1
  int _firstUnDone() {
    return _nextUnDone(0);
  }

  /// "下一题"：跳转到下一道未做的题；若后面无未做则回卷到第一道未做（或停当前）
  void _goToNextUnDone() {
    final next = _nextUnDone(_questionIndex + 1);
    if (next >= 0) {
      _gotoQuestion(next);
    } else {
      final first = _firstUnDone();
      if (first >= 0 && first != _questionIndex) {
        _gotoQuestion(first);
      }
    }
  }

  /// 判当前题：做对则记录，返回是否通过
  Future<_JudgeRecord> _judgeCurrent(String code) async {
    // 快照当前题目，防止 await 期间题目列表被清空（交卷）导致越界
    final problem = _questions[_questionIndex];
    final engine = JudgeEngine(
      timeoutMs: settings.timeoutMs,
      enforceSourceRequirements: settings.strictSourceCheck,
    );
    final JudgeResult result;
    try {
      result = await engine.judge(problem, code);
    } catch (e) {
      // 判题过程出错：不让它崩，给个可读反馈
      if (!mounted || !_testActive) {
        return const _JudgeRecord(
          passedCases: 0,
          totalCases: 0,
          timeMs: 0,
          hasRuntimeError: true,
        );
      }
      setState(() => _status[problem.id] = Status.submitted);
      return _JudgeRecord(
        passedCases: 0,
        totalCases: problem.testCases.length,
        timeMs: 0,
        hasRuntimeError: true,
        message: '判题出错：$e',
      );
    }
    if (!mounted || !_testActive) {
      // 交卷后判题才返回：放弃回写，避免空列表/状态错乱
      return _JudgeRecord(
        passedCases: result.passedCases,
        totalCases: result.totalCases,
        timeMs: result.caseResults.fold<int>(0, (s, r) => s + r.timeMs),
        hasRuntimeError: false,
      );
    }

    final passed = result.allPassed;
    // 记录判题详情（通过数/总用例/总耗时/是否语法错误）
    final record = _JudgeRecord(
      passedCases: result.passedCases,
      totalCases: result.totalCases,
      timeMs: result.caseResults.fold<int>(0, (sum, r) => sum + r.timeMs),
      hasRuntimeError: result.caseResults.any(
        (r) => !r.isPassed && r.stderr.isNotEmpty,
      ),
      requirementUnmet: result.hasUnmetRequirements,
    );

    setState(() {
      _drafts[problem.id] = code;
      _records[problem.id] = record;
      if (passed) {
        _status[problem.id] = Status.correct;
      } else {
        _status[problem.id] = Status.submitted;
      }
    });
    if (passed) {
      await _progress
          .markSolved(problem.language, problem.id); // 做对：标记已解决 + 清除错题
    } else {
      await _progress
          .recordWrong(problem.language, problem.id); // 做错：计入错题本
    }
    return record;
  }

  int get _correctCount =>
      _status.values.where((s) => s == Status.correct).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('测试'),
        actions: const [LanguageSwitcher()],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_allProblems == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_testActive) {
      return _buildTestFlow();
    }
    if (_testDone) {
      return _buildResult();
    }
    return _buildSetup();
  }

  /// 把秒数格式化为 mm:ss（用于倒计时显示）
  String _fmtDuration(int seconds) {
    if (seconds <= 0) return '不限时';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (s == 0) return '$m 分钟';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 一个测试模式：开始按钮 + 两行设置（出题范围 / 倒计时）
  ///
  /// 布局说明：设置项从「一个」变「两个」之后，横着排一行在窄窗口下会挤爆
  /// （应用允许拉到 420 宽）。所以开始按钮独占一行，两个设置项用 [Wrap]
  /// 排在下面 —— 窄了就自动折行，不会溢出。
  Widget _buildModeRow(_TestModeDef mode) {
    final resolved = _scopeOf(mode);
    final count = _questionCountOf(mode, resolved);
    final sec = settings.testTimeLimit(mode.id);
    final empty = count <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: empty ? null : () => _startTest(mode, countdownSec: sec),
          child: Text(empty
              ? '${mode.label}（范围内没有题目）'
              : '${mode.label}（$count 题）'),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildScopeButton(mode, resolved),
            _buildDurationPicker(mode.id, sec),
          ],
        ),
      ],
    );
  }

  /// 出题范围入口：显示当前摘要（大类数 + 难度三色点），点开设置弹窗
  Widget _buildScopeButton(_TestModeDef mode, ResolvedScope resolved) {
    final scheme = Theme.of(context).colorScheme;
    final scope = settings.testScope(mode.id);
    final isDefault = scope.isDefault;
    final fg = isDefault ? scheme.onSurfaceVariant : scheme.primary;

    // 摘要写短一点：完整范围在弹窗里看
    final label = isDefault
        ? '全部大类'
        : '${scope.ordinals.length} 个大类';

    return Tooltip(
      message: '设置「${mode.label}」的出题范围（大类与难度）',
      child: InkWell(
        onTap: () => _editScope(mode),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDefault ? scheme.outlineVariant : scheme.primary,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_outlined, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: fg,
                  fontWeight: isDefault ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              // 实际生效的档位（可能在范围变化后被下调过）
              DifficultyDots(maxLevel: resolved.tier.level, size: 9),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editScope(_TestModeDef mode) async {
    final next = await showTestScopeDialog(
      context: context,
      modeLabel: mode.label,
      categories: _categories ?? const [],
      scope: settings.testScope(mode.id),
    );
    if (next == null || !mounted) return;
    await settings.setTestScope(mode.id, next);
  }

  /// 单个模式的倒计时选择器：显示当前值，点击弹出候选时长
  Widget _buildDurationPicker(String modeId, int currentSec) {
    final scheme = Theme.of(context).colorScheme;
    final active = currentSec > 0;
    final fg = active ? scheme.primary : scheme.onSurfaceVariant;

    return PopupMenuButton<int>(
      tooltip: '设置「该模式」的倒计时时长',
      initialValue: currentSec,
      onSelected: (v) => settings.setTestTimeLimit(modeId, v),
      itemBuilder: (context) => [
        for (final sec in kTestDurationChoices)
          PopupMenuItem<int>(
            value: sec,
            child: Row(
              children: [
                Icon(
                  sec > 0 ? Icons.timer_outlined : Icons.timer_off_outlined,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(_fmtDuration(sec)),
                if (sec == currentSec) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: active ? scheme.primary : scheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.timer_outlined : Icons.timer_off_outlined,
              size: 16,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              _fmtDuration(currentSec),
              style: TextStyle(
                fontSize: 13,
                color: fg,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 设置界面：每个测试模式一行 —— 左侧按钮开始测试，右侧是该模式自己的倒计时时长。
  ///
  /// 刻意不再用「一个全局开关 + 一个全局时长」：题量差太多（5 题 vs 全题库），
  /// 同一个时长对快速测验太松、对全题库又根本不够。现在各模式互不影响，
  /// 且时长里直接含「不限时」，少一层开关概念。
  Widget _buildSetup() {
    return MaxWidthBody(
      maxWidth: ContentWidth.list,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '开始一次测试',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '随机从题库抽题，逐题编写代码并判题，结束后汇总得分。已做对过的题会正常计分。',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  // 用 RichMessageText 而不是 Text：下面写着 **各自**，普通 Text
                  // 会把星号原样显示出来（判题提示踩过同一个坑）
                  RichMessageText(
                    '每个模式都能**各自**设置两件事，互不影响：\n'
                    '· 📚 出题范围 —— 从哪些大类出题、出到哪个难度\n'
                    '· ⏱ 倒计时 —— 选「不限时」就是普通练习，设了时间则进测试即开始计时\n'
                    '抽题会按题库的难度比例来，不会一次抽出一堆难题。',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 用 ListenableBuilder 监听 settings：改完时长后选择器要立刻显示新值
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) => Column(
              children: [
                for (final mode in _kTestModes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildModeRow(mode),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 回顾测试入口
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TestHistoryPage()),
              );
            },
            icon: const Icon(Icons.history),
            label: const Text('回顾测试：查看历史记录与题解'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// 逐题作答流程（支持自由选题跳题）
  Widget _buildTestFlow() {
    final problem = _questions[_questionIndex];
    return Column(
      children: [
        // 题号导航栏（可点选任意题，上机考试式）
        _buildQuestionNav(),
        SizedBox(height: 56, child: _buildQuestionControls()),
        Divider(height: 1),
        Expanded(
          // 切题时滑动 + 淡入过渡
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              );
            },
            child: _TestQuestionView(
              key: ValueKey(problem.id),
              problem: problem,
              questionNumber: _questionIndex + 1,
              totalQuestions: _questions.length,
              initialCode: _drafts[problem.id] ?? '',
              onJudge: (code) => _judgeCurrent(code),
              onSave: (code) {
                _drafts[problem.id] = code;
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 顶部题号导航网格
  Widget _buildQuestionNav() {
    // 每个题号按钮等宽，可横向滚动（题目多时）
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _questions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final id = _questions[i].id;
          final status = _status[id];
          final isCurrent = i == _questionIndex;
          // 颜色：当前蓝色高亮，做对绿色，提交过的橙色，未做灰色
          final color = isCurrent
              ? Theme.of(context).colorScheme.primary
              : status == Status.correct
              ? Colors.green
              : status == Status.submitted
              ? Colors.orange
              : Colors.grey.shade300;
          final icon = status == Status.correct
              ? Icons.check
              : status == Status.submitted
              ? Icons.circle
              : null;
          return AnimatedScale(
            scale: isCurrent ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Material(
              color: color,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _gotoQuestion(i),
                child: Container(
                  width: 44,
                  alignment: Alignment.center,
                  child: icon != null
                      ? Icon(
                          icon,
                          size: 18,
                          color: isCurrent ? Colors.white : color,
                        )
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: isCurrent
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 上一题 / 下一题 / 交卷 控制栏
  Widget _buildQuestionControls() {
    final hasPrev = _questionIndex > 0;
    final hasNext = _questionIndex < _questions.length - 1;
    return Row(
      children: [
        // 上一题
        IconButton(
          tooltip: '上一题',
          onPressed: hasPrev ? () => _gotoQuestion(_questionIndex - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        // 进度文字
        Expanded(
          child: Center(
            child: Builder(
              builder: (context) {
                final notDone = _questions.where((p) => !_isDone(p)).length;
                final widgets = <Widget>[
                  Text(
                    '${_questionIndex + 1} / ${_questions.length}    ✔$_correctCount · 未做$notDone',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ];
                if (_countdownEnabled) {
                  final urgent = _remainingSeconds <= 60;
                  widgets.add(const SizedBox(height: 4));
                  widgets.add(
                    Icon(Icons.timer_outlined,
                        size: 14,
                        color: urgent ? Colors.red : Colors.green),
                  );
                  widgets.add(
                    Text(
                      _fmtDuration(_remainingSeconds),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: urgent ? Colors.red : Colors.green,
                      ),
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widgets,
                );
              },
            ),
          ),
        ),
        // 交卷
        TextButton.icon(
          onPressed: () => _finishTest(),
          icon: const Icon(Icons.assignment_turned_in, size: 18),
          label: const Text('交卷'),
        ),
        // 下一题（跳转到下一道未做的题）
        IconButton(
          tooltip: '下一题（跳到下一道未做的）',
          onPressed: hasNext ? _goToNextUnDone : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  /// 测试结果界面
  Widget _buildResult() {
    final total = _reviewedCount;
    final ratio = total == 0 ? 0.0 : _correctCount / total;
    final passed = ratio >= 0.8;
    final theme = Theme.of(context);
    // 入场动画 + 通过时奖杯弹跳（summary 部分）
    final summary = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutBack,
      builder: (context, rawT, _) {
        // easeOutBack 回弹会超 [0,1]，clamp 才能安全喂给 Opacity，否则断言崩
        final t = rawT.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - Curves.easeOutCubic.transform(t))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _resultIcon(passed: passed, t: t),
                const SizedBox(height: 16),
                Text(
                  '测试完成！',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '得分 $_correctCount / $total  (${(ratio * 100).round()}%)',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  passed ? '表现很棒，继续冲刺！🎉' : '再接再厉，去练习板块多练一练～',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: () => setState(() {
                        _testDone = false;
                        _testActive = false;
                      }),
                      icon: const Icon(Icons.replay),
                      label: const Text('再测一次'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _testDone = false;
                        _testActive = false;
                      }),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('返回首页'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        // 让 summary 垂直居中于可视区上方
        children: [
          // 顶部返回按钮（回到测试首页/闲置页）
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: '返回测试首页',
              onPressed: () => setState(() {
                _testDone = false;
                _testActive = false;
              }),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320),
            child: Center(child: summary),
          ),
          const SizedBox(height: 8),
          // 逐题回看 + 题解列表
          _buildReviewSection(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 交卷后的“逐题回看对错 + 参考代码”列表
  Widget _buildReviewSection(BuildContext context) {
    final theme = Theme.of(context);
    if (_reviewItems.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.fact_check_outlined,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('逐题回看',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('点击展开参考代码',
                style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        // 每道题一个可展开卡片
        ..._reviewItems.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return _buildReviewCard(context, idx + 1, item);
        }),
      ],
    );
  }

  /// 单题的“逐题回看”卡片
  Widget _buildReviewCard(BuildContext context, int number, _ReviewItem item) {
    final p = item.problem;
    // 展开状态：用本地 stateful 卡片保存，key 绑定题目id
    return _ReviewCard(
      key: ValueKey(p.id),
      number: number,
      item: item,
    );
  }

  /// 结果图标（通过时 elastic 弹跳）
  Widget _resultIcon({required bool passed, required double t}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: passed ? Curves.elasticOut : Curves.easeOutCubic,
      builder: (context, bounce, _) {
        final scale = passed ? 0.6 + 0.4 * bounce : 1.0;
        return Transform.scale(
          scale: t * scale,
          child: Icon(
            passed ? Icons.emoji_events : Icons.track_changes,
            size: 80,
            color: passed ? Colors.amber : Colors.blueGrey,
          ),
        );
      },
    );
  }
}

/// 逐题回看卡片：标题+对错，展开后展示“我的代码”与“参考代码”
class _ReviewCard extends StatefulWidget {
  final int number;
  final _ReviewItem item;

  const _ReviewCard({super.key, required this.number, required this.item});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.item.problem;
    final correct = widget.item.wasCorrect;
    // 卡片内嵌字段：对错图标 + 标题，展开时加代码对比区
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: correct
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  // 题号
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (correct
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.number}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: correct
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  // 对错状态
                  Icon(
                    correct ? Icons.check_circle : Icons.cancel,
                    size: 18,
                    color: correct
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    correct ? '做对' : '做错',
                    style: TextStyle(
                      fontSize: 12,
                      color: correct
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              // 展开区：我的代码 + 参考代码
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _codeBlock(
                      context,
                      label: '我的代码',
                      code: widget.item.myCode.isEmpty
                          ? '（本题未作答）'
                          : widget.item.myCode,
                    ),
                    const SizedBox(height: 10),
                    _codeBlock(
                      context,
                      label: '参考代码',
                      code: p.solution.trim().isEmpty
                          ? '（暂未提供）'
                          : p.solution.trim(),
                      highlight: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 一段等宽字体代码块
  Widget _codeBlock(BuildContext context,
      {required String label, required String code, bool highlight = false}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              highlight ? Icons.emoji_objects_outlined : Icons.code,
              size: 13,
              color: highlight
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: highlight
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _TestQuestionView extends StatefulWidget {
  final Problem problem;
  final int questionNumber;
  final int totalQuestions;
  final String initialCode;
  final Future<_JudgeRecord> Function(String code) onJudge;
  final void Function(String code) onSave;

  const _TestQuestionView({
    super.key,
    required this.problem,
    required this.questionNumber,
    required this.totalQuestions,
    required this.initialCode,
    required this.onJudge,
    required this.onSave,
  });

  @override
  State<_TestQuestionView> createState() => _TestQuestionViewState();
}

class _TestQuestionViewState extends State<_TestQuestionView> {
  late final TextEditingController _controller;
  bool _judging = false;
  bool _showTerminal = false;
  String? _lastFeedback; // 判题反馈（对/错提示）

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode);
    _controller.addListener(() {
      widget.onSave(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TestQuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切题后，清空上次反馈（代码框中已用 initialCode 重建为由父层保证）
    if (oldWidget.problem.id != widget.problem.id) {
      _lastFeedback = null;
    }
    // 若 initialCode 变化且不是当前正在输入的，同步到文本框
    if (oldWidget.initialCode != widget.initialCode &&
        _controller.text != widget.initialCode) {
      _controller.value = TextEditingValue(
        text: widget.initialCode,
        selection: TextSelection.collapsed(offset: widget.initialCode.length),
      );
    }
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _lastFeedback = '还没写代码呢～');
      return;
    }
    setState(() => _judging = true);
    widget.onSave(_controller.text);
    final rec = await widget.onJudge(_controller.text);
    if (!mounted) return;
    setState(() {
      _judging = false;
      if (rec.allPassed) {
        _lastFeedback =
            '✔ 这题做对了！（${rec.passedCases}/${rec.totalCases} 用例 · ${rec.timeMs}ms）';
      } else if (rec.requirementUnmet) {
        // 输出全对、只是没按要求用上语法。不能笼统说「还有用例没过」——
        // 那会把学生引向「再检查输出」，而输出一点问题都没有。
        _lastFeedback =
            '✘ 输出全对，但本题要求的语法没用上（${rec.passedCases}/${rec.totalCases} 用例）'
            ' · 回到练习页能看具体要改什么';
      } else if (rec.message != null) {
        _lastFeedback = '⚠️ ${rec.message}';
      } else {
        final parts = <String>[];
        parts.add('✘ 还有用例没过（${rec.passedCases}/${rec.totalCases}）');
        if (rec.hasRuntimeError) {
          parts.add('程序运行出错了');
        }
        parts.add('耗时 ${rec.timeMs}ms');
        parts.add('可以继续改，或先去做别的题。');
        _lastFeedback = parts.join(' · ');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.problem;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text(
                '第 ${widget.questionNumber}/${widget.totalQuestions} 题',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(p.description),
                const SizedBox(height: 8),
                if (p.sampleInput.isNotEmpty)
                  Text('示例输入: ${p.sampleInput.replaceAll('\n', ' ⏎ ')}'),
                if (p.sampleOutput.isNotEmpty)
                  Text('示例输出: ${p.sampleOutput.replaceAll('\n', ' ⏎ ')}'),
                const SizedBox(height: 12),
                PythonCodeField(
                  controller: _controller,
                  language: p.language,
                  minLines: 8,
                  hintText: '在此输入代码…',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // 交互式终端开关
                    OutlinedButton.icon(
                      onPressed: _judging
                          ? null
                          : () => setState(
                              () => _showTerminal = !_showTerminal),
                      icon: Icon(
                        _showTerminal
                            ? Icons.terminal
                            : Icons.terminal_outlined,
                        size: 16,
                      ),
                      label: Text(
                        _showTerminal ? '收起' : p.language.runPanelTitle,
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _judging ? null : _submit,
                      icon: _judging
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(_judging ? '判题中…' : '判题'),
                    ),
                  ],
                ),
                // 判题反馈条
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _lastFeedback == null
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey(_lastFeedback),
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _lastFeedback!.startsWith('✔')
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _lastFeedback!.startsWith('✔')
                                  ? Colors.green.withValues(alpha: 0.4)
                                  : Colors.orange.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _lastFeedback!.startsWith('✔')
                                    ? Icons.check_circle
                                    : Icons.info_outline,
                                color: _lastFeedback!.startsWith('✔')
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                // 判题反馈里带 **加粗** / `代码` 标记，
                                // 普通 Text 会把标记符号原样显示出来
                                child: RichMessageText(
                                  _lastFeedback!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                // 交互式终端：展开时作为页面内容的一部分排在下方（网页式下滑）
                if (_showTerminal)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: InteractiveTerminal(
                      language: widget.problem.language,
                      getCode: () => _controller.text,
                      sampleInput: widget.problem.sampleInput,
                      isJudging: _judging,
                      onJudge: _submit,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
