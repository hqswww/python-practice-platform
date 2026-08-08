import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/data/problem_repository.dart';
import 'package:python_practice/pages/learn_page.dart';

void main() {
  testWidgets('学习页渲染分类树、详细教程卡片和 body 高度', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cats = await ProblemRepository().loadCategories();
    final p0 = cats.first.problems.first;
    await tester.pumpWidget(MaterialApp(home: LearnPage(categories: cats)));
    // 用有限 pump 代替 pumpAndSettle，避免无限动画死锁
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 侧边栏渲染分类
    expect(find.text('基础语法'), findsWidgets);
    // 详细教程（第一题已有 tutorial）首屏可见
    expect(find.text('详细教程'), findsWidgets);
    expect(find.text('认识 print() 函数'), findsWidgets);
    expect(find.text('#${p0.id}'), findsWidgets);
    // body 高度不为 0
    final size = tester.getSize(find.byKey(const ValueKey('bodyRow')));
    expect(size.height, greaterThan(0), reason: 'body 高度不应为 0');

    // 滚动内容区到底部，确认示例/提示/参考代码仍渲染
    final scrollable = find
        .descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('参考代码'), 200, scrollable: scrollable);
    expect(find.text('参考代码'), findsOneWidget);
  });
}
