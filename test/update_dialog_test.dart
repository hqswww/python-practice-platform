import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/app_version.dart';
import 'package:python_practice/pages/widgets/update_dialog.dart';
import 'package:python_practice/services/update_service.dart';

/// 更新弹窗。
///
/// ⚠️ 这个文件里**不要点「去下载」并让它真的打开浏览器** ——
/// 那会在测试机上弹出真实的浏览器窗口。下面只测两种安全的路径：
/// 按钮存在、以及链接不合法时走「手动复制网址」的兜底。
void main() {
  const full = UpdateInfo(
    version: '1.5.0',
    tagName: 'v1.5.0',
    notes: '## 新增\n- 启动时自动检查更新\n\n## 修复\n- 深色模式下判题结果是黑字',
    releaseUrl: 'https://github.com/hqswww/python-practice-platform/releases/tag/v1.5.0',
    downloadUrl:
        'https://github.com/hqswww/python-practice-platform/releases/download/v1.5.0/%E7%BC%96%E7%A8%8B%E7%BB%83%E4%B9%A0%E5%86%8C-macOS-universal.dmg',
    assetName: '编程练习册-macOS-universal.dmg',
  );

  /// 弹窗返回值放进 notifier：`showUpdateDialog` 是在按钮回调里 await 的，
  /// 直接用一个局部变量会在弹窗关闭前就被读走（拿到的永远是 null）。
  Future<ValueNotifier<UpdateDialogAction?>> pumpDialog(
    WidgetTester tester,
    UpdateInfo info, {
    bool allowSkip = true,
  }) async {
    final result = ValueNotifier<UpdateDialogAction?>(null);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result.value = await showUpdateDialog(context, info,
                    allowSkip: allowSkip);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  String allText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
      .join('\n');

  group('更新弹窗', () {
    testWidgets('把「从哪个版本到哪个版本」写清楚', (tester) async {
      await pumpDialog(tester, full);
      final text = allText(tester);
      expect(text, contains('发现新版本'));
      // 用户要先确认自己是不是真的旧了
      expect(text, contains('v$appVersion'));
      expect(text, contains('v1.5.0'));
    });

    testWidgets('显示更新内容', (tester) async {
      await pumpDialog(tester, full);
      final text = allText(tester);
      expect(text, contains('更新内容'));
      expect(text, contains('启动时自动检查更新'));
      expect(text, contains('深色模式下判题结果是黑字'));
      // 标题标记和列表符号在弹窗里要processed过，不能原样露出来
      expect(text, isNot(contains('##')), reason: 'Markdown 标题标记漏到界面上了');
      expect(text, isNot(contains('```')), reason: '代码围栏漏到界面上了');
    });

    testWidgets('没有更新内容时不能空着', (tester) async {
      await pumpDialog(
        tester,
        const UpdateInfo(
          version: '1.5.0',
          tagName: 'v1.5.0',
          notes: '',
          releaseUrl: 'https://github.com/x/y/releases',
        ),
      );
      expect(allText(tester), contains('没有写更新说明'),
          reason: '空白的「更新内容」框看起来像界面坏了');
    });

    testWidgets('说清「覆盖安装不丢进度」—— 用户最先担心这个', (tester) async {
      await pumpDialog(tester, full);
      expect(allText(tester), contains('不会丢失'));
      expect(allText(tester), contains('编程练习册-macOS-universal.dmg'),
          reason: '要告诉用户该下哪个包');
    });

    testWidgets('挑不到平台安装包时改口径为「去下载页自己选」', (tester) async {
      await pumpDialog(
        tester,
        const UpdateInfo(
          version: '1.5.0',
          tagName: 'v1.5.0',
          notes: 'x',
          releaseUrl: 'https://github.com/x/y/releases',
        ),
      );
      final text = allText(tester);
      expect(text, contains('下载页'));
      expect(text, isNot(contains('.dmg')));
    });

    testWidgets('「以后再说」返回 later（下次启动还会提示）', (tester) async {
      final r = await pumpDialog(tester, full);
      await tester.tap(find.text('以后再说'));
      await tester.pumpAndSettle();
      expect(find.text('发现新版本'), findsNothing);
      expect(r.value, UpdateDialogAction.later,
          reason: '「以后再说」不能顺手记成「跳过这个版本」');
    });

    testWidgets('「跳过这个版本」返回 skipVersion（外层靠它记版本号）', (tester) async {
      final r = await pumpDialog(tester, full);
      await tester.tap(find.text('跳过这个版本'));
      await tester.pumpAndSettle();
      expect(r.value, UpdateDialogAction.skipVersion);
    });

    testWidgets('「跳过这个版本」只在自动提示时出现', (tester) async {
      await pumpDialog(tester, full, allowSkip: false);
      expect(find.text('跳过这个版本'), findsNothing,
          reason: '用户主动来检查时，不该给他一个「以后别告诉我」的按钮');
      expect(find.text('关闭'), findsOneWidget);
    });

    testWidgets('设置页手动检查的弹窗也有「去下载」', (tester) async {
      await pumpDialog(tester, full, allowSkip: false);
      expect(find.text('去下载'), findsOneWidget);
    });
  });

  group('打不开浏览器时的兜底', () {
    testWidgets('链接不合法 → 弹出手动复制的对话框，而不是卡住', (tester) async {
      // 用一个过不了安全检查的链接（http 而非 https）。
      // 这样 openExternalUrl 会**立即返回 false**，不会真的去起浏览器进程 ——
      // 顺便把兜底路径也测了。
      const unsafe = UpdateInfo(
        version: '1.5.0',
        tagName: 'v1.5.0',
        notes: 'x',
        releaseUrl: 'https://github.com/x/y/releases',
        downloadUrl: 'http://insecure.example.com/setup.exe',
        assetName: 'setup.exe',
      );
      await pumpDialog(tester, unsafe);
      await tester.tap(find.text('去下载'));
      await tester.pumpAndSettle();

      expect(find.text('没能自动打开浏览器'), findsOneWidget);
      final sel = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((t) => t.data ?? '')
          .join('\n');
      expect(sel, contains('http://insecure.example.com/setup.exe'),
          reason: '至少要能把网址给用户复制出来');
    });
  });
}
