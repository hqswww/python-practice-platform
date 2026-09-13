import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/programming_language.dart';
import '../../services/interactive_runner.dart';

/// 交互式运行面板。
///
/// - 解释型语言（Python）：等价于一个常驻 REPL 进程
/// - 编译型语言（C / C++）：**先编译再运行产物**，编译报错直接显示在终端里
///
/// 无论哪种，程序读到输入停下时用户都能在这儿敲一行回车喂进去 ——
/// 这是让学生看懂「多个 input / scanf 到底各读走了哪一行」的关键。
///
/// [onJudge] 用户点"提交判题"回调（由外层跑完整判题）
class InteractiveTerminal extends StatefulWidget {
  /// 本面板要跑哪门语言。**必须传对** —— 曾经这里没有这个参数，
  /// 于是 C / C++ 题目上起的是 Python 解释器。
  final ProgrammingLanguage language;

  /// 覆盖解释器 / 编译器路径（测试或设置页自定义）
  final String? commandOverride;

  /// 取当前编辑器代码（判题/运行用）
  final String Function() getCode;

  /// 题目样例输入（B 辅助：自动喂样例）
  final String sampleInput;

  /// 用户点"提交判题"时回调
  final Future<void> Function() onJudge;

  /// 是否正在判题（外层控制，用于禁用按钮）
  final bool isJudging;

  const InteractiveTerminal({
    super.key,
    required this.language,
    this.commandOverride,
    required this.getCode,
    required this.sampleInput,
    required this.onJudge,
    this.isJudging = false,
  });

  @override
  State<InteractiveTerminal> createState() => _InteractiveTerminalState();
}

class _InteractiveTerminalState extends State<InteractiveTerminal> {
  late final InteractiveRunner _runner = InteractiveRunner(
    language: widget.language,
    commandOverride: widget.commandOverride,
  );
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<_TermLine> _lines = [];
  StreamSubscription<RunnerEvent>? _sub;
  bool _running = false;
  bool _ended = false; // 本次进程已结束（自然退出或被终止）

  static const int _maxLines = 2000;

  @override
  void initState() {
    super.initState();
    final lang = widget.language;
    _append(_TermLine.hint(lang.compiled
        ? '>> 按「开始运行」先编译再执行 ${lang.displayName} 程序；'
            '程序读到输入时在此敲一行回车喂给它。\n'
        : '>> 按「开始运行」启动 ${lang.displayName}；'
            '程序跑到 input() 时在此输入并按回车。\n'));
    _sub = _runner.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _runner.dispose();
    _inputController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onEvent(RunnerEvent e) {
    if (!mounted) return;
    switch (e.kind) {
      case RunnerEventKind.output:
        _append(_TermLine.text(e.text));
        break;
      case RunnerEventKind.error:
        // stderr 用红色高亮（错误/traceback）
        _append(_TermLine.error(e.text));
        break;
      case RunnerEventKind.exit:
        setState(() {
          _running = false;
          _ended = true;
        });
        _append(_TermLine.hint(
            e.exitCode == 0
                ? '\n[进程已正常结束，退出码 0]'
                : '\n[进程已结束，退出码 ${e.exitCode}]'));
        break;
      case RunnerEventKind.hint:
        // 命令行回显、「正在编译」、「编译失败」这类面板自己产生的话
        _append(_TermLine.hint(e.text));
        break;
    }
  }

  void _append(_TermLine line) {
    setState(() {
      _lines.add(line);
      if (_lines.length > _maxLines) {
        _lines.removeRange(0, _lines.length - _maxLines);
      }
    });
    // 自动滚到底
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _start() async {
    final code = widget.getCode();
    if (code.trim().isEmpty) {
      _append(_TermLine.hint('⚠️ 代码为空，请先写点代码'));
      return;
    }
    setState(() {
      _lines.clear();
      _running = true;
      _ended = false;
    });
    // 注意：命令行回显不在这里做 —— 编不编译、跑的是哪个产物，只有
    // InteractiveRunner 知道，由它通过 hint 事件推回来（曾经这里硬编码
    // 「$ python3 runner.py」，在任何语言下都显示那一行）。
    try {
      final started = await _runner.start(code);
      if (!started && mounted) setState(() => _running = false);
    } catch (e) {
      _append(_TermLine.error('启动失败: $e'));
      if (mounted) setState(() => _running = false);
    }
  }

  /// B 辅助：自动把样例输入按行喂给程序（模拟多 input 依次读到）
  void _autoFeedSample() {
    if (!_running || _ended) {
      _append(_TermLine.hint('请先「开始运行」，再自动喂样例'));
      return;
    }
    final lines = widget.sampleInput
        .split('\n')
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      _append(_TermLine.hint('本题没有样例输入，直接运行即可'));
      return;
    }
    // 逐个喂入（间隔极小，模拟连续 input）
    for (final l in lines) {
      _runner.sendLine(l, onEcho: _echo);
    }
  }

  void _echo(String line) => _append(_TermLine.input(line));

  void _submitLine() {
    final text = _inputController.text;
    if (text.isEmpty) return;
    if (!_running || _ended) {
      _append(_TermLine.hint('程序未在运行，输入未发送 (可先「开始运行」)'));
      _inputController.clear();
      return;
    }
    _runner.sendLine(text, onEcho: _echo);
    _inputController.clear();
  }

  Future<void> _stop() async {
    await _runner.stop();
    setState(() {
      _running = false;
      _ended = true;
    });
    _append(_TermLine.hint('\n[已手动停止]'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: const Color(0xFF0B0E14), // 深色终端底
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 终端标题栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF161A23),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 16, color: Colors.tealAccent),
                const SizedBox(width: 6),
                const Text(
                  '交互式终端',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _running && !_ended
                        ? Colors.greenAccent
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _running && !_ended ? '运行中' : '空闲',
                  style: TextStyle(
                    color: (_running && !_ended)
                        ? Colors.greenAccent
                        : Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // 终端输出区（滚动）
          Container(
            height: 180,
            padding: const EdgeInsets.all(10),
            child: Scrollbar(
              controller: _scroll,
              child: ListView.builder(
                controller: _scroll,
                itemCount: _lines.length,
                itemBuilder: (context, i) {
                  final l = _lines[i];
                  return Text(
                    l.text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.35,
                      color: switch (l.kind) {
                        _LineKind.error => const Color(0xFFFF7B72),
                        _LineKind.input =>
                          const Color(0xFF79C0FF), // 用户输入蓝色
                        _LineKind.hint => const Color(0xFF8B949E), // 提示灰
                        _ => const Color(0xFFE6EDF3), // 程序输出
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          // 输入行
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Row(
              children: [
                Text(_running && !_ended ? '>>> ' : '··· ',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.tealAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Expanded(
                  child: Container(
                    // 深色衬底：让输入栏和浅色文字在深色终端上有清晰对比
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2430),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF3A4254)),
                    ),
                    child: TextField(
                      controller: _inputController,
                      enabled: _running && !_ended,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFF0F6FC),
                          fontSize: 13),
                      cursorColor: Colors.tealAccent,
                      // ⚠️ `filled: false` 不能省。全局 InputDecorationTheme 是
                      //    `filled: true` + 浅灰/深灰 fillColor：浅色模式下它会在这层
                      //    深色衬底上再刷一层**浅灰**，而这里的文字是写死的浅色 ——
                      //    结果就是「浅色主题下终端输入框里的字看不见了」。
                      //    输入框自己画了底色，就必须显式声明不要再填一层。
                      decoration: const InputDecoration(
                        filled: false,
                        isDense: true,
                        hintText: '输入数据后按回车…',
                        hintStyle:
                            TextStyle(color: Color(0xFF6E7681), fontSize: 12),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _submitLine(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '发送这行',
                  onPressed: _running && !_ended ? _submitLine : null,
                  icon: const Icon(Icons.send,
                      size: 18, color: Colors.tealAccent),
                ),
              ],
            ),
          ),
          // 操作按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _actionButton(
                  icon: Icons.play_arrow,
                  label: '开始运行',
                  color: Colors.greenAccent,
                  onTap: _running ? null : _start,
                ),
                _actionButton(
                  icon: Icons.fast_forward,
                  label: '自动喂样例',
                  color: Colors.amberAccent,
                  onTap: (_running && !_ended) ? _autoFeedSample : null,
                ),
                _actionButton(
                  icon: Icons.check_circle_outline,
                  label: '提交判题',
                  color: Colors.lightBlueAccent,
                  // 判题中禁用；其他时候随时可提交（即使没亲自在终端喂数）
                  onTap: widget.isJudging ? null : _judge,
                ),
                _actionButton(
                  icon: Icons.stop,
                  label: '停止',
                  color: Colors.redAccent,
                  onTap: _running ? _stop : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _judge() async {
    if (_running && !_ended) {
      // 若进程还在跑，先停止再判题（确保是当前代码的最终状态）
      await _runner.stop();
    }
    await widget.onJudge();
  }
}

enum _LineKind { text, error, input, hint }

class _TermLine {
  final String text;
  final _LineKind kind;
  const _TermLine(this.text, this.kind);
  const _TermLine.text(this.text) : kind = _LineKind.text;
  const _TermLine.error(this.text) : kind = _LineKind.error;
  const _TermLine.input(this.text) : kind = _LineKind.input;
  const _TermLine.hint(this.text) : kind = _LineKind.hint;
}
