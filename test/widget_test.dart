import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/main.dart';

void main() {
  testWidgets('App 能启动并显示标题', (WidgetTester tester) async {
    await tester.pumpWidget(const PythonPracticeApp());
    expect(find.text('Python 练习平台'), findsOneWidget);
  });
}
