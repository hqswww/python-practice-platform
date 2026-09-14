import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/app_version.dart';
import 'package:python_practice/pages/about_page.dart';

/// 「关于」页。
///
/// ⚠️ 这个文件里只放**一条** testWidgets：`rootBundle` 在同一个测试文件里只能
/// 成功加载一次（读更新日志和 LICENSE 都要它），拆成多条第二条会挂住。
/// 纯函数（解析、正文清洗）放在这个文件里用普通 test 测，不碰 rootBundle。
void main() {
  group('更新日志解析（纯函数）', () {
    test('按「行首 # 」切版本，新版本在前', () {
      const raw = '''
# 更新日志

本文件由脚本生成。

# 编程练习册 v1.5.1

## 本版更新
- 甲

# 编程练习册 v1.5.0
- 乙
''';
      final s = parseChangelog(raw);
      expect(s.map((e) => e.version), ['v1.5.1', 'v1.5.0']);
      expect(s.first.body, contains('甲'));
      expect(s.last.body, contains('乙'));
    });

    test('文件头那段说明不会变成一个「版本」', () {
      // 文件头也是 # 开头，不特判的话它会以「更新日志」为标题出现在列表里
      final s = parseChangelog('# 更新日志\n\n说明文字\n\n# v1.0.0\n- 内容');
      expect(s, hasLength(1));
      expect(s.single.version, 'v1.0.0');
      expect(s.single.body, isNot(contains('说明文字')));
    });

    test('标题里没写 v 也能认，并且补上 v', () {
      expect(parseChangelog('# 1.2.3\n- x').single.version, 'v1.2.3');
    });

    test('版本正文按弹窗那套清洗：不留 Markdown 标记', () {
      const raw = r'''
# v2.0.0
## 新增
- **重要**：改了 `as.exe`
```dart
final x = 1;
```
---
尾部说明
''';
      final body = parseChangelog(raw).single.body;
      expect(body, isNot(contains('#')));
      expect(body, isNot(contains('```')));
      expect(body, isNot(contains('---')));
      expect(body, contains('· **重要**'), reason: '列表符号换成中点，加粗标记留着给富文本渲染');
      expect(body, contains('`as.exe`'));
      expect(body, contains('final x = 1;'), reason: '围栏里的内容要留着');
      expect(body, contains('尾部说明'));
    });

    test('空输入 / 没有版本小节 → 空列表，不炸', () {
      expect(parseChangelog(''), isEmpty);
      expect(parseChangelog('随便写点什么\n没有标题'), isEmpty);
    });
  });

  group('页面与资产（读 rootBundle，整个文件只此一条）', () {
    testWidgets('关于页把该有的都摆出来了', (tester) async {
      SharedPreferences.setMockInitialValues({});

      // 窗口开大一点：这个页面内容长，默认 800x600 会溢出
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: AboutPage()));
      await tester.pumpAndSettle();

      String allText() => tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
          .join('\n');

      final text = allText();

      // ① 软件名称与 ② 版本号
      expect(text, contains('编程练习册'));
      expect(text, contains('版本 v$appVersion'));

      // ③ 更新日志：最新一版默认展开，且内容是真实的（不是占位）
      expect(text, contains('更新日志'));
      expect(find.text('v$appVersion'), findsWidgets,
          reason: '最新一版的更新日志应当是展开的');
      expect(text, contains('本版更新'), reason: '展开的小节里应当有正文');

      // ④ 检查更新：开关 + 当前版本
      expect(find.text('检查更新'), findsWidgets);
      expect(find.byType(Switch), findsOneWidget);

      // ⑤⑥ 项目主页与问题反馈入口
      expect(find.text('项目主页'), findsOneWidget);
      expect(find.text('问题反馈'), findsOneWidget);
      // URL 在 onTap 里、不在界面上显示，所以断言常量本身
      expect(AboutPage.repoUrl,
          'https://github.com/hqswww/python-practice-platform');

      // ⑦⑧ 两种许可证
      expect(find.text('开源许可证（MIT）'), findsOneWidget);
      expect(find.text('第三方许可证'), findsOneWidget);

      // 正文里不该漏出 Markdown 标记
      expect(text, isNot(contains('##')));
      expect(text, isNot(contains('```')));

      expect(tester.takeException(), isNull);
    });

    test('LICENSE 就在仓库根目录，而且是完整 MIT 正文', () {
      final f = File('LICENSE');
      expect(f.existsSync(), isTrue, reason: '没有 LICENSE 文件，GitHub 上不会显示许可证');
      final text = f.readAsStringSync();
      expect(text, contains('MIT License'));
      expect(text, contains('hqswww'), reason: '署名用 GitHub 账号');
      expect(text, contains('WITHOUT WARRANTY'), reason: '缺了免责段落就不是完整 MIT');
    });

    test('更新日志资产不落后于 docs/releases/（防漂移）', () {
      // 手抄一份必然漂移，而且漂移是静默的 —— 应用里的日志少一版没人会发现。
      // 所以 assets/CHANGELOG.md 是生成物，这里盯着它跟 docs/releases/ 一致。
      // （生成器在 tools/build_changelog.py，--check 模式给发布闸门用）
      //
      // 这里直接读文件而不走 rootBundle：同一个测试文件里 rootBundle 只能
      // 成功加载一次（上面那条 testWidgets 已经用掉了），第二次会挂住。
      final releases = Directory('docs/releases')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(releases, isNotEmpty, reason: 'docs/releases/ 里一个版本文件都没有？');

      final changelog =
          parseChangelog(File('assets/CHANGELOG.md').readAsStringSync());
      for (final name in releases) {
        final v = RegExp(r'\d+\.\d+\.\d+').firstMatch(name)?.group(0);
        expect(v, isNotNull, reason: '$name 文件名里没有版本号');
        expect(changelog.any((s) => s.version == 'v$v'), isTrue,
            reason: 'docs/releases/$name 没有出现在 assets/CHANGELOG.md 里 —— '
                '跑一下 python3 tools/build_changelog.py');
      }
    });
  });
}
