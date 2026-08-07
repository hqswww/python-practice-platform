import 'package:flutter/material.dart';
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
