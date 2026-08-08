import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;

/// 简易 Python 语法高亮 + 行号代码输入框。
///
/// 方案：外层一个 [SingleChildScrollView]，内含一个 Stack——
/// 下层是只读的行号 + 高亮 RichText，上层是文字透明的 TextField。
/// 两者在同一条滚动里自然同步（TextField 在无界高度下自动撑满内容高度）。
///
/// 全部自实现、零第三方依赖，方便离线打包（Windows 迁移无 pub 风险）。
///
/// 缩进增强（P3）：
/// - Tab 缩进：插入/移动到下一个 4 空格停止位
/// - Shift+Tab 反缩进：减少本级开头空格的 4 的倍数
/// - Enter 自动缩进：新行携带上一行前导缩进；上一行尾是 `:` 时自动多缩进一级
/// - 快捷键写在_内部 Focus 节点的 onKeyEvent 里，不劫持原生 TextField 光标/键盘
class PythonCodeField extends StatefulWidget {
  final TextEditingController controller;
  final int minLines;
  final int? maxLines;
  final TextStyle? style;
  final String? hintText;

  // 调用方只传 minLines 时（maxLines 为 null），默认上限给到很大以强制软换行，
  // 与高亮 RichText 的折行行为一致——否则 TextField 在 maxLines=null 下是
  // “单行无限宽”可横向滚动、RichText 却自动折行，导致长行文字越来越向左错位。
  static const int _wrapMaxLines = 20000;

  const PythonCodeField({
    super.key,
    required this.controller,
    this.minLines = 6,
    this.maxLines,
    this.style,
    this.hintText,
  });

  @override
  State<PythonCodeField> createState() => _PythonCodeFieldState();
}

class _PythonCodeFieldState extends State<PythonCodeField> {
  final GlobalKey _textKey = GlobalKey();
  final GlobalKey _highKey = GlobalKey();
  // 内部 Focus 节点：拦截 Tab/Enter 做缩进，不交给系统焦点移动
  final FocusNode _focusNode = FocusNode();
  // 高亮层需额外平移的量（测量 TextField 首字 global 坐标 与 高亮层 global 坐标之差）
  Offset _alignDelta = Offset.zero;
  bool _aligned = false;

  TextStyle get _base {
    return widget.style ??
        const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.5,
          // 锁定字体字重，避免 TextField 与 RichText 字体回退不一致
          fontFamilyFallback: ['JetBrainsMono Nerd Font Mono'],
          // 显式归零字间距——主题默认继承 letterSpacing 0.5，
          // 导致 TextField caret 每字符多算 ~0.5px 而 RichText 不，匀速累积成“光标跑更快”。
          letterSpacing: 0,
          wordSpacing: 0,
        );
  }

  int get _lineCount =>
      (widget.controller.text.isEmpty
          ? 1
          : '\n'.allMatches(widget.controller.text).length + 1);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant PythonCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _focusNode.dispose();
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  // ---- 缩进处理 ----

  // 当前选中块的首行行首 index
  int _selectionStartAtLineStart(String text, int start) {
    final idx = text.lastIndexOf('\n', start - 1);
    return idx + 1;
  }

  void _insertIndentAt(TextEditingValue v) {
    // 固定插入 1 个缩进级（4 空格），更符合用户预期（按一次 Tab 缩进一档）
    final pos = v.selection.start;
    final insert = ' ' * _indentWidth;
    widget.controller.value = TextEditingValue(
      text: v.text.substring(0, pos) + insert + v.text.substring(pos),
      selection: TextSelection.collapsed(offset: pos + _indentWidth),
    );
  }

  void _outdentAt(int pos) {
    final v = widget.controller.value;
    final text = v.text;
    // 当前行首
    final lineStart = _selectionStartAtLineStart(text, pos);
    // 计算行首连续空格（最多 4）
    var removed = 0;
    while (removed < _indentWidth &&
        lineStart + removed < text.length &&
        text[lineStart + removed] == ' ') {
      removed++;
    }
    if (removed == 0) return; // 行首没有空格，不删
    final newText =
        text.substring(0, lineStart) + text.substring(lineStart + removed);
    final newSel =
        pos <= lineStart + removed ? lineStart : pos - removed;
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newSel),
    );
  }

  // 多行选区整体 +4；返回新的选区（右移 4）
  void _indentSelectionBlock() {
    final v = widget.controller.value;
    final text = v.text;
    final sel = v.selection;

    // 选区起止“行”的范围：[startLine .. endLine]，按行号处理
    // 行号从 0 开始；startLine = 选区起点所在行
    final startLine = text.substring(0, sel.start).split('\n').length - 1;
    // endLine = 选区终点所在行（若终点恰在某行末尾，仍算该行）
    final endLine = text.substring(0, sel.end).split('\n').length - 1;

    // 第一行行首 index
    var lineStart = 0;
    // 逐行整体前插 4 空格
    final sb = StringBuffer();
    sb.write(text.substring(0, lineStart));
    // 从 startLine 起到 endLine 止，遍历这些行
    String line;
    for (var ln = 0; ln <= endLine; ln++) {
      // 取第 ln 行的内容（不含换行）
      var eol = text.indexOf('\n', lineStart);
      if (eol == -1) eol = text.length;
      line = text.substring(lineStart, eol);
      if (ln >= startLine) {
        sb.write(' ' * _indentWidth);
      }
      sb.write(line);
      if (eol < text.length) sb.write('\n');
      lineStart = eol + 1;
    }
    // 剩余行（endLine 之后）原样保留
    sb.write(text.substring(lineStart));

    final newText = sb.toString();
    // 选区整体右移：起点右移 4；终点还需算上选区内每一行都加了 4
    final selText = text.substring(sel.start, sel.end);
    final lineCountInSel = 1 + '\n'.allMatches(selText).length;
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: sel.start + _indentWidth,
        extentOffset: sel.end + _indentWidth * lineCountInSel,
      ),
    );
  }

  void _insertNewlineIndent() {
    final v = widget.controller.value;
    final text = v.text;
    final pos = v.selection.start;
    if (pos < 0 || pos > text.length) return;

    final lineStart = _selectionStartAtLineStart(text, pos);
    final prefix = text.substring(lineStart, pos);
    final m = RegExp(r'^ *').firstMatch(prefix);
    final curIndent = m?.group(0) ?? '';

    // 行尾（忽略尾随空格）是 ':' 则下一行额外 +4
    final lineNoTrail = prefix.trimRight();
    var extra = '';
    if (lineNoTrail.isNotEmpty &&
        lineNoTrail[lineNoTrail.length - 1] == ':') {
      extra = ' ' * _indentWidth;
    }

    final newIndent = curIndent + extra;
    final newText = '${text.substring(0, pos)}\n$newIndent${text.substring(pos)}';
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + 1 + newIndent.length),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    // Tab（含 Shift+Tab）：不交给系统焦点移动，做缩进
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final v = widget.controller.value;
      final sel = v.selection;
      if (isShift) {
        _outdentAt(sel.start);
      } else if (sel.start != sel.end) {
        _indentSelectionBlock();
      } else {
        _insertIndentAt(v);
      }
      return KeyEventResult.handled;
    }
    // Enter：自动缩进下一行（沿用上一行，行尾冒号则 +4）
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _insertNewlineIndent();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // Python 缩进宽度：1 个 Tab = 4 空格
  static const int _indentWidth = 4;

  // 从 render 树里递归找第一个 RenderEditable（TextField 的 key 拿到的是 RenderMouseRegion）
  RenderEditable? _findEditable(RenderObject? ro) {
    if (ro is RenderEditable) return ro;
    RenderEditable? found;
    ro?.visitChildren((c) {
      found ??= _findEditable(c);
    });
    return found;
  }

  // 用 render 几何精确测量 TextField 与高亮层文字起点之差，动态对齐（自动，不靠魔法数）
  void _measureAlignment() {
    if (_aligned) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Offset? tf;
      try {
        final ro = _textKey.currentContext?.findRenderObject();
        final re = _findEditable(ro);
        if (re != null) {
          // caret(offset 0) 本地矩形转全局 = 文本首字位置；单参签名(Flutter 3.4x)
          final caret = re.getLocalRectForCaret(const TextPosition(offset: 0));
          tf = re.localToGlobal(caret.topLeft);
        }
      } catch (_) {
        tf = null;
      }
      Offset? hi;
      final hr = _highKey.currentContext?.findRenderObject() as RenderBox?;
      if (hr != null) hi = hr.localToGlobal(Offset.zero);
      if (tf != null && hi != null) {
        _alignDelta = tf - hi;
        _aligned = true;
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _measureAlignment();
    final theme = Theme.of(context);
    final base = _base.copyWith(color: theme.colorScheme.onSurface);
    // maxLines 未显式给（null）时用大上限强制软换行，跟高亮层折行对齐
    final maxLines = widget.maxLines ?? PythonCodeField._wrapMaxLines;
    final gutterWidth = 14.0 + _lineCount.toString().length * 9.0 + 10.0;
    // 文本框是全幅的（没有行号列），用含 gutter 的 codePad，文字起点=gutter+8
    final codePad = EdgeInsets.only(
        left: gutterWidth + 8, right: 12, top: 12, bottom: 12);
    // 高亮层里行号列已单独占 gutterWidth，RichText 只需从行号右侧 8px 开始。
    // 精确对齐：textPad.left = codePad.left - gutterWidth = 8，无需手调。
    final textPad = codePad.copyWith(left: codePad.left - gutterWidth);
    // 统一行高(strut)，TextField 与 RichText 每行都 14*1.5=21px，两行框一致
    final _strut = const StrutStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      height: 1.5,
      forceStrutHeight: true,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Stack(
          // 顺序反过来：TextField 放下层，高亮层放最上层(IgnorePointer 只读展示)
          // 这样即使 GTK 真机渲染时 TextField 画出不透明衬底，也会被高亮层盖住，
          // 用户始终能看到高亮文字。高亮层不画背景(纯文字像素)，光标可透过间隙显示。
          children: [
            // ---- 下层：透明字输入框（保留光标/选中/编辑/滚动） ----
            // 用内部 Focus 节点 + onKeyEvent 拦截 Tab/Enter 做缩进，
            // 否则 Tab 会被系统拿去移动焦点（无法缩进）
            Focus(
              focusNode: _focusNode,
              onKeyEvent: _onKey,
              child: TextField(
                key: _textKey,
                controller: widget.controller,
                minLines: widget.minLines,
                maxLines: maxLines,
                style: base.copyWith(
                  color: Colors.transparent,
                  decoration: TextDecoration.none,
                  height: base.height,
                ),
                // 强制行高与高亮层一致，消除 TextField/EditableText 的基线偏移
                strutStyle: _strut,
                cursorColor: theme.colorScheme.primary,
                cursorWidth: 2,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: base.copyWith(
                    color: Colors.grey,
                  ),
                  border: InputBorder.none,
                  // 不用 isCollapsed（会破坏 TextField 正常布局、光标偏左上）；
                  // 留正常 contentPadding，让 _measureAlignment 量到真实 caret 再来平移对齐。
                  contentPadding: codePad,
                ),
              ),
            ),
            // ---- 最上层：行号 + 高亮代码（只读，IgnorePointer 不挡输入） ----
            IgnorePointer(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: gutterWidth,
                    padding:
                        const EdgeInsets.only(top: 12, bottom: 12, right: 8),
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    child: Text(
                      _lineNumbers(),
                      textAlign: TextAlign.right,
                      style: base.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: textPad,
                      // 用测量到的 _alignDelta 平移高亮层，与 TextField 文字精确重合（自动）
                      child: Transform.translate(
                        offset: _alignDelta,
                        child: RichText(
                          key: _highKey,
                          strutStyle: _strut,
                          text: TextSpan(
                            style: base,
                            children:
                                highlight(widget.controller.text, theme),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _lineNumbers() {
    final b = StringBuffer();
    for (var i = 1; i <= _lineCount; i++) {
      if (i > 1) b.write('\n');
      b.write(i);
    }
    return b.toString();
  }
}

/// 把代码按 Python 词法切分成带颜色的 span（顶层函数，便于单测）。
List<InlineSpan> highlight(String code, ThemeData theme) {
  final dark = theme.brightness == Brightness.dark;
  final Color kw = dark ? const Color(0xFFC678DD) : const Color(0xFF7C3AED);
  final Color bi = dark ? const Color(0xFF61AFEF) : const Color(0xFF0060AC);
  final Color st = dark ? const Color(0xFF98C379) : const Color(0xFF228722);
  final Color cm = dark ? const Color(0xFF7F848E) : const Color(0xFF9E9E9E);
  final Color nu = dark ? const Color(0xFFE5C07B) : const Color(0xFFB4521D);
  final Color dc = dark ? const Color(0xFF839987) : const Color(0xFF6A8F6A);

  final spans = <InlineSpan>[];
  // raw 三引号拼接正则；字面引号用 \x22(双) / \x27(单) 十六进制转义。
  // 此文件由 heredoc 生成，\\n 在源码里是字面反斜杠+n（正则换行），不能是真实换行。
  final re = RegExp(
    r'''(#[^\n]*)|''' 
        r'''(\x22\x22\x22[\s\S]*?\x22\x22\x22|\x27\x27\x27[\s\S]*?\x27\x27\x27|\x22(?:[^\x22\\\n]|\\.)*\x22|\x27(?:[^\x27\\\n]|\\.)*\x27)|''' 
        r'''(@\w+)|''' 
        r'''(\b\d[\w.]*\b)|''' 
        r'''(\b(?:def|return|if|elif|else|for|while|import|from|as|class|try|''' 
        r'''except|finally|raise|with|pass|break|continue|lambda|yield|global|''' 
        r'''nonlocal|and|or|not|in|is|None|True|False|del|assert|async|await)\b)|''' 
        r'''(\b(?:print|len|range|int|str|float|bool|list|dict|tuple|set|input|''' 
        r'''abs|sum|min|max|sorted|reversed|enumerate|zip|map|filter|type|isinstance|''' 
        r'''open|super|self|round|any|all|repr|format)\b)''',
    multiLine: true,
  );

  var last = 0;
  for (final m in re.allMatches(code)) {
    if (m.start > last) {
      spans.add(TextSpan(text: code.substring(last, m.start)));
    }
    final kind = m.group(1) != null
        ? 'comment'
        : m.group(2) != null
            ? 'string'
            : m.group(3) != null
                ? 'decorator'
                : m.group(4) != null
                    ? 'number'
                    : m.group(5) != null
                        ? 'keyword'
                        : 'builtin';
    final color = switch (kind) {
      'comment' => cm,
      'string' => st,
      'decorator' => dc,
      'number' => nu,
      'keyword' => kw,
      _ => bi,
    };
    spans.add(TextSpan(text: m.group(0), style: TextStyle(color: color)));
    last = m.end;
  }
  if (last < code.length) {
    spans.add(TextSpan(text: code.substring(last)));
  }
  return spans;
}
