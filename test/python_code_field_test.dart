import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/pages/widgets/python_code_field.dart';

void main() {
  test('highlight 把 def/return/数字/注释 切成独立着色 span', () {
    final theme = ThemeData.light();
    final code = 'def foo(n):\n    return n + 2  # 注释';
    final spans = flatten(highlight(code, theme));
    expect(spans.join(''), code);
    expect(spans, contains('def'));
    expect(spans, contains('return'));
    expect(spans, contains('2'));
    expect(spans, contains('# 注释'));
    // 关键字 span 应带颜色样式
    final defSpan = uniqueKeywordSpan(highlight(code, theme));
    expect(defSpan?.style?.color, isNotNull);
  });

  test('highlight 处理三引号多行字符串不炸', () {
    final theme = ThemeData.light();
    final code = 'x = """line1\nline2"""\ny = 1  # end';
    final spans = flatten(highlight(code, theme));
    expect(spans.join(''), code);
  });

  testWidgets('PythonCodeField 渲染行号 gutter', (tester) async {
    final controller =
        TextEditingController(text: 'def foo(n):\n    return n + 2  # 注释');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PythonCodeField(controller: controller, minLines: 2),
        ),
      ),
    );
    // 两行 → 行号文本 "1\n2"
    expect(find.textContaining('2'), findsWidgets);
  });

  testWidgets('按 Tab 插入 4 空格缩进', (tester) async {
    final controller = TextEditingController(text: 'x = 1');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PythonCodeField(controller: controller, minLines: 1),
        ),
      ),
    );
    // 聚焦并让光标到行尾（offset 5）
    await tester.showKeyboard(find.byType(TextField));
    controller.selection = const TextSelection.collapsed(offset: 5);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.text, 'x = 1    ');
    expect(controller.selection.baseOffset, 9);
  });

  testWidgets('Enter 在冒号行后自动缩进一级', (tester) async {
    final controller = TextEditingController(text: 'if x > 0:');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PythonCodeField(controller: controller, minLines: 1),
        ),
      ),
    );
    await tester.showKeyboard(find.byType(TextField));
    controller.selection = const TextSelection.collapsed(offset: 9);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.text, 'if x > 0:\n    ');
    expect(controller.selection.baseOffset, 14);
  });

  testWidgets('Enter 在普通行后沿用当前缩进', (tester) async {
    final controller = TextEditingController(text: '    return n + 2');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PythonCodeField(controller: controller, minLines: 1),
        ),
      ),
    );
    await tester.showKeyboard(find.byType(TextField));
    controller.selection = const TextSelection.collapsed(offset: 16);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.text, '    return n + 2\n    ');
  });

  testWidgets('多行选中按 Tab 整体缩进 4 格', (tester) async {
    final controller = TextEditingController(text: 'a = 1\nb = 2');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PythonCodeField(controller: controller, minLines: 2),
        ),
      ),
    );
    await tester.showKeyboard(find.byType(TextField));
    controller.selection =
        const TextSelection(baseOffset: 0, extentOffset: 5);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.text, '    a = 1\nb = 2');
  });
}

List<String> flatten(List<InlineSpan> spans) {
  final out = <String>[];
  void visit(InlineSpan s) {
    if (s is TextSpan) {
      if (s.text != null) out.add(s.text!);
      for (final c in s.children ?? const <InlineSpan>[]) {
        visit(c);
      }
    }
  }

  for (final s in spans) {
    visit(s);
  }
  return out;
}

TextSpan? uniqueKeywordSpan(List<InlineSpan> spans) {
  for (final s in spans) {
    if (s is TextSpan && s.text == 'def') return s;
  }
  return null;
}
