import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/models/test_record.dart';
import 'package:python_practice/pages/about_page.dart';
import 'package:python_practice/pages/mine_page.dart';
import 'package:python_practice/pages/settings_page.dart';
import 'package:python_practice/services/language_service.dart';
import 'package:python_practice/services/progress_service.dart';

/// 「我的」页。
///
/// ⚠️ 整个文件只有**一条** testWidgets：它会读三门语言的题库（rootBundle），
/// 而 rootBundle 在同一个测试文件里只能成功加载一次。其余都是纯源码/纯函数检查。
void main() {
  group('导航结构（源码级，不读资产）', () {
    final main = File('lib/main.dart').readAsStringSync();

    test('底栏第 4 个是「我的」，不再是「设置」', () {
      expect(main, contains("label: '我的'"));
      expect(main, isNot(contains("label: '设置'")),
          reason: '「设置」已降为「我的」下的子页面，不该再占一个底栏位置');
    });

    test('底栏指向 MinePage', () {
      expect(main, contains('MinePage('));
      expect(main, isNot(contains('SettingsPage(')),
          reason: '底栏应当指向「我的」，设置是从「我的」push 进去的子页面');
    });

    test('「我的」在切回来时会重算（IndexedStack 的页面不会自己重建）', () {
      expect(main, contains('isActive:'),
          reason: '不做的话，做完题切回「我的」看到的还是旧数据');
    });
  });

  group('用户可见文案里的入口指路（源码级）', () {
    // 底栏改名之后，提示里说「去设置找」就会让人找不到。注释不算，只看代码里的字符串。
    test('指路文案都写成「我的 → 设置 → …」', () {
      for (final path in [
        'lib/pages/settings_page.dart',
        'lib/pages/widgets/judge_result_panel.dart',
        'lib/services/judge_engine.dart',
      ]) {
        final src = File(path).readAsStringSync();
        final strings = RegExp(r"'[^']*设置 →[^']*'").allMatches(src);
        for (final m in strings) {
          expect(m.group(0), contains('我的 → 设置 →'),
              reason: '$path 里还写着老的指路文案：${m.group(0)}');
        }
      }
    });
  });

  group('页面渲染与两个入口（读 rootBundle，整个文件只此一条）', () {
    testWidgets('数据、结论、设置与关于入口都在，且点得进去', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await languageService.load();
      await languageService.select(ProgrammingLanguage.python);

      // 造一点真实进度，让结论不是「完全没有数据」那条
      final progress = ProgressService();
      for (final id in [101, 102, 103, 104, 105, 106]) {
        await progress.markSolved(ProgrammingLanguage.python, id);
      }
      await progress.recordWrong(ProgrammingLanguage.python, 201);
      // 一条测试记录，让「测试正确率」那条结论有话可说
      await progress.addTestRecord(TestRecord(
        timestamp: DateTime.now(),
        correctCount: 3,
        totalCount: 5,
        items: const [],
      ));

      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: MinePage(onResetProgress: () async {}),
      ));
      await tester.pumpAndSettle();

      String allText() => tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
          .join('\n');

      final text = allText();

      // 总览：三门语言合起来算
      expect(text, contains('总进度'));
      expect(text, contains('6 / 216'), reason: '做题数应当跨三门语言合计');
      expect(text, contains('当前称号'));

      // 结论卡：不是只列数字，要有话
      expect(text, contains('小结'));
      expect(text, contains('已完成 6 / 216 题'));

      // 三门语言逐门列出
      expect(text, contains('三门语言'));
      for (final l in const ['Python', 'C', 'C++']) {
        expect(text, contains(l));
      }

      // 分类完成度（跟着当前语言）
      expect(text, contains('分类完成度'));
      expect(text, contains('基础语法'));
      expect(text, contains('（Python）'));

      // 两个入口都在页面上
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);

      expect(tester.takeException(), isNull);

      // ── 点「设置」能进去
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('外观'), findsWidgets, reason: '设置页的分类列表应当出来了');

      // 返回
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MinePage), findsOneWidget);

      // ── 点「关于」能进去
      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();
      expect(find.byType(AboutPage), findsOneWidget);
      expect(find.text('更新日志'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
