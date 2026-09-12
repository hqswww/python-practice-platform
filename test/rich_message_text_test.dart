import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/pages/widgets/rich_message_text.dart';

/// 判题提示里的轻量标记渲染。
///
/// 这些提示是写给学生的，里面一直写着 `**加粗**` 和 `` `代码` `` ——
/// 但结果面板原先用普通 Text，学生看到的是**字面的星号和反引号**，
/// 既像 bug，也把重点冲淡了。
String flatten(List<InlineSpan> spans) =>
    spans.map((s) => (s as TextSpan).text ?? '').join();

List<TextSpan> textSpans(List<InlineSpan> spans) =>
    spans.cast<TextSpan>().toList();

void main() {
  const base = TextStyle(fontSize: 13);

  test('**加粗** 变成加粗片段，且不残留星号', () {
    final spans = RichMessageText.parse('内容是对的，只是**格式不对**。', base);
    expect(flatten(spans), '内容是对的，只是格式不对。');
    expect(flatten(spans), isNot(contains('*')));

    final bold = textSpans(spans)
        .where((s) => s.style?.fontWeight == FontWeight.w700)
        .toList();
    expect(bold.length, 1, reason: '应恰好有一段加粗');
    expect(bold.first.text, '格式不对');
  });

  test('`代码` 变成等宽片段，且不残留反引号', () {
    final spans =
        RichMessageText.parse('确认 `as.exe` 在不在 `gcc.exe` 旁边', base);
    expect(flatten(spans), '确认 as.exe 在不在 gcc.exe 旁边');
    expect(flatten(spans), isNot(contains('`')));

    final mono = textSpans(spans)
        .where((s) => s.style?.fontFamily == 'monospace')
        .toList();
    expect(mono.map((s) => s.text), ['as.exe', 'gcc.exe']);
  });

  test('两种标记可以混在同一行', () {
    final spans = RichMessageText.parse(
        '编译器**没装完整** —— `as.exe` 不在 `gcc.exe` 旁边', base);
    expect(flatten(spans), '编译器没装完整 —— as.exe 不在 gcc.exe 旁边');
    expect(flatten(spans).contains('*'), isFalse);
    expect(flatten(spans).contains('`'), isFalse);
  });

  test('多行文本里的标记也认得', () {
    final spans = RichMessageText.parse('第一行 **重点**\n第二行 `file.c`', base);
    expect(flatten(spans), '第一行 重点\n第二行 file.c');
  });

  test('没配对的标记原样保留 —— 宁可显示成普通文字，也不能把内容吃掉', () {
    for (final raw in ['只有单个 ** 星号', '一个反引号 ` 而已', '**', '`']) {
      final spans = RichMessageText.parse(raw, base);
      expect(flatten(spans), raw, reason: '「$raw」不该被改动');
    }
  });

  test('没有标记时原样一段，不额外切分', () {
    final spans = RichMessageText.parse('就是一句普通的话', base);
    expect(spans.length, 1);
    expect(flatten(spans), '就是一句普通的话');
  });

  test('空字符串不崩', () {
    expect(flatten(RichMessageText.parse('', base)), '');
  });

  group('渲染成组件', () {
    testWidgets('界面里不再出现字面的 ** 和反引号', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: RichMessageText('这**不是**你代码的问题：看 `as.exe` 在不在'),
        ),
      ));

      final widget = tester.widget<Text>(find.byType(Text));
      final span = widget.textSpan! as TextSpan;
      final plain = flatten(span.children!);
      expect(plain, '这不是你代码的问题：看 as.exe 在不在');
      expect(plain, isNot(contains('*')));
      expect(plain, isNot(contains('`')));
    });
  });
}
