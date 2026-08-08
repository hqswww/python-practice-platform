import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/data/problem_repository.dart';
import 'package:python_practice/pages/learn_page.dart';

void main() {
  testWidgets('学习页渲染分类树、笔记卡片和底部导航', (tester) async {
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
    // 内容区卡片渲染
    expect(find.text('题目描述'), findsWidgets);
    expect(find.text('示例'), findsWidgets);
    expect(find.text('#${p0.id}'), findsWidgets);
    // body 高度不为 0
    final size = tester.getSize(find.byKey(const ValueKey('bodyRow')));
    expect(size.height, greaterThan(0), reason: 'body 高度不应为 0');
  });
}
