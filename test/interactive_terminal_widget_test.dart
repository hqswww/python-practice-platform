import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/pages/widgets/interactive_terminal.dart';

void main() {
  testWidgets('交互终端输入栏有深色衬底（不再白底）', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InteractiveTerminal(
          language: ProgrammingLanguage.python,
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

  // 回归：面板曾经把「按「开始运行」启动 Python」写死在提示里，
  // C / C++ 题目上也是这么说的 —— 而且底下真的起的是 Python 解释器。
  testWidgets('提示语按语言给，C 题里不该出现 Python', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InteractiveTerminal(
          language: ProgrammingLanguage.c,
          getCode: () => 'int main(void){return 0;}',
          sampleInput: '',
          onJudge: () async {},
        ),
      ),
    ));
    await tester.pump();

    expect(find.textContaining('启动 Python'), findsNothing);
    expect(find.textContaining('编译'), findsWidgets,
        reason: 'C 是编译型，提示得说清是先编译再运行');
  });
}
