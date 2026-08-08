import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/pages/widgets/interactive_terminal.dart';

void main() {
  testWidgets('交互终端输入栏有深色衬底（不再白底）', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InteractiveTerminal(
          getCode: () => "print('hi')",
          sampleInput: '1 2',
          onJudge: () async {},
        ),
      ),
    ));
    await tester.pump();

    // 找到 TextField
    final tf = find.byType(TextField);
    expect(tf, findsOneWidget);
    expect(tester.widget<TextField>(tf).style!.color, const Color(0xFFF0F6FC));

    // 找到包住 TextField 的深色 Container
    final textFields = tester.widget<TextField>(tf);
    expect(textFields.decoration!.border, InputBorder.none);
  });
}
