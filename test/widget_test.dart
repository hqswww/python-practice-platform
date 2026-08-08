import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/main.dart';

void main() {
  testWidgets('App 能启动并显示学习页（首页）', (WidgetTester tester) async {
    await tester.pumpWidget(const PythonPracticeApp());
    await tester.pump();
    // 首页(index 0)是学习页
    expect(find.text('学习笔记'), findsWidgets);
  });
}
