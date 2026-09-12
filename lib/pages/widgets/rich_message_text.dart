import 'package:flutter/material.dart';

/// 把判题提示里的轻量标记渲染出来。
///
/// 提示文案里一直写着 `**加粗**` 和 `` `代码` ``，但结果面板用的是普通 `Text`，
/// 于是学生看到的是**字面的星号和反引号** —— 既像 bug，也把重点冲淡了。
///
/// 这里只认两种标记，不做完整 Markdown —— 为此引一个 Markdown 依赖
/// （以及它带来的构建体积与转义/安全考虑）不划算。
///
/// 没配对的标记原样保留：提示文本是拼出来的，宁可显示成普通文字，
/// 也不能把内容吃掉。
class RichMessageText extends StatelessWidget {
  const RichMessageText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  /// 把文本切成若干段（可单独测）
  static List<InlineSpan> parse(String text, TextStyle base) {
    final bold = base.copyWith(fontWeight: FontWeight.w700);
    // 反引号里用等宽字体：提示里大量出现 `gcc.exe`、`as.exe` 这类文件名，
    // 等宽能让它们从中文句子里跳出来
    final code = base.copyWith(fontFamily: 'monospace');

    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`', multiLine: true);
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      final b = m.group(1);
      spans.add(b != null
          ? TextSpan(text: b, style: bold)
          : TextSpan(text: m.group(2), style: code));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(TextSpan(children: parse(text, base)), style: base);
  }
}
