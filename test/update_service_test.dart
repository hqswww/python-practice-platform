import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/services/update_service.dart';
import 'package:python_practice/services/url_opener.dart';

/// 自动更新检查。
///
/// 这套测试盯的是三件事：
/// 1. **版本比较不能错**（判错方向会出现「提示降级」或「永远不提示」）
/// 2. **失败必须静默且不抛异常**（没网是最常见的情况，不能影响做题）
/// 3. **挑对平台的安装包**（挑错用户会下到一个装不上的包）
void main() {
  /// 造一个 GitHub `releases/latest` 的返回体
  String releaseJson({
    required String tag,
    String body = '- 修了某某问题',
    List<(String, String)> assets = const [],
  }) =>
      jsonEncode({
        'tag_name': tag,
        'name': tag,
        'body': body,
        'html_url': 'https://github.com/hqswww/python-practice-platform/releases/tag/$tag',
        'published_at': '2025-09-01T00:00:00Z',
        'assets': [
          for (final (name, url) in assets)
            {'name': name, 'browser_download_url': url},
        ],
      });

  /// 假 fetcher：记录请求过的 URL，返回预设响应
  ({TextFetcher fetcher, List<Uri> calls}) fakeFetch(
      HttpTextResponse Function(Uri) respond) {
    final calls = <Uri>[];
    return (
      calls: calls,
      fetcher: (url) async {
        calls.add(url);
        return respond(url);
      },
    );
  }

  group('版本比较', () {
    test('基本的大小关系', () {
      expect(compareVersions('1.4.0', '1.3.0'), greaterThan(0));
      expect(compareVersions('1.3.0', '1.4.0'), lessThan(0));
      expect(compareVersions('1.4.0', '1.4.0'), 0);
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0),
          reason: '按数值比而不是按字符串比 —— 字符串比会把 1.10.0 判成比 1.9.0 小');
    });

    test('tag 上的 v 前缀不影响比较', () {
      expect(compareVersions('v1.5.0', '1.4.0'), greaterThan(0));
      expect(compareVersions('V1.5.0', 'v1.5.0'), 0);
      expect(compareVersions('1.4.0', 'v1.4.0'), 0);
    });

    test('少写一段按 0 补齐（1.5 等于 1.5.0）', () {
      expect(compareVersions('1.5', '1.5.0'), 0);
      expect(compareVersions('1.5', '1.4.9'), greaterThan(0));
    });

    test('构建号不参与比较（同一版本的重新打包）', () {
      expect(compareVersions('1.4.0+4', '1.4.0+9'), 0);
      expect(compareVersions('1.4.0+4', '1.4.1+1'), lessThan(0));
    });

    test('预发布版本小于同号正式版（SemVer）', () {
      expect(compareVersions('1.5.0-beta.1', '1.5.0'), lessThan(0));
      expect(compareVersions('1.5.0', '1.5.0-beta.1'), greaterThan(0));
      expect(compareVersions('1.5.0-beta.2', '1.5.0-beta.1'), greaterThan(0));
      expect(compareVersions('1.5.0-alpha', '1.5.0-beta'), lessThan(0));
    });

    test('畸形版本号不炸，当 0 处理', () {
      // 版本号格式千奇百怪，宁可算错也不能让检查更新崩掉
      expect(() => compareVersions('', ''), returnsNormally);
      expect(() => compareVersions('abc', '1.0'), returnsNormally);
      expect(compareVersions('abc', '1.0.0'), lessThan(0));
      expect(compareVersions('v', '0.0.0'), 0);
    });

    test('normalizeVersion 统一成 x.y.z', () {
      expect(normalizeVersion('v1.5.0'), '1.5.0');
      expect(normalizeVersion('1.5'), '1.5.0');
      expect(normalizeVersion('1.5.0+4'), '1.5.0');
      expect(normalizeVersion('1.5.0-beta.1'), '1.5.0');
    });
  });

  group('挑平台的安装包', () {
    const assets = [
      UpdateAsset(name: '编程练习册-Setup.exe', url: 'https://e/setup'),
      UpdateAsset(name: '编程练习册-macOS-universal.dmg', url: 'https://e/dmg'),
      UpdateAsset(name: '编程练习册-macOS-universal.zip', url: 'https://e/zip'),
      UpdateAsset(name: '编程练习册-linux-x86_64.tar.gz', url: 'https://e/tar'),
    ];

    test('按扩展名挑，不看中文文件名', () {
      // 中文名随时会改，按名字精确匹配的话改个名就没法更新了
      expect(pickAsset(assets, UpdatePlatform.windows)?.url, 'https://e/setup');
      expect(pickAsset(assets, UpdatePlatform.macos)?.url, 'https://e/dmg');
      expect(pickAsset(assets, UpdatePlatform.linux)?.url, 'https://e/tar');
    });

    test('macOS 优先 dmg 而不是 zip', () {
      // zip 是绿色版；dmg 才是「双击 → 拖进 Applications」那条正路
      final zipFirst = [
        const UpdateAsset(name: 'a.zip', url: 'https://e/zip'),
        const UpdateAsset(name: 'a.dmg', url: 'https://e/dmg'),
      ];
      expect(pickAsset(zipFirst, UpdatePlatform.macos)?.url, 'https://e/dmg');
    });

    test('没有对应产物时返回 null（界面上退回发布页）', () {
      expect(pickAsset(const [], UpdatePlatform.windows), isNull);
      expect(
          pickAsset(const [UpdateAsset(name: 'x.dmg', url: 'u')],
              UpdatePlatform.windows),
          isNull);
    });

    test('文件名随便起 —— 只看扩展名（用真实发布时的名字验证）', () {
      // 发布时附件名是人手起的，跟构建脚本产出的名字**可以完全不一样**：
      // 大小写不同、拼写不同、基名不同，都不该影响挑包。
      // 这里用的就是真实发布时的名字（注意 macOS 那段是大写 OS）。
      const realNames = [
        UpdateAsset(
            name: 'CodeWorkboox-macOS-universal.dmg', url: 'https://e/dmg'),
        UpdateAsset(
            name: 'CodeWorkboox-macOS-universal.zip', url: 'https://e/zip'),
        UpdateAsset(name: 'CodeWorkboox-Setup.exe', url: 'https://e/exe'),
        UpdateAsset(
            name: 'CodeWorkboox-linux-x86_64.tar.gz', url: 'https://e/tar'),
      ];
      expect(pickAsset(realNames, UpdatePlatform.macos)?.url, 'https://e/dmg',
          reason: 'macOS 要挑 dmg，不能挑到 zip');
      expect(pickAsset(realNames, UpdatePlatform.windows)?.url, 'https://e/exe');
      expect(pickAsset(realNames, UpdatePlatform.linux)?.url, 'https://e/tar');
    });

    test('大小写不敏感', () {
      expect(
          pickAsset(const [UpdateAsset(name: 'A.DMG', url: 'u')],
              UpdatePlatform.macos)?.url,
          'u');
    });
  });

  group('解析 releases/latest', () {
    test('有新版时把版本、更新内容、下载链接都取出来', () {
      final info = parseLatestRelease(
        releaseJson(
          tag: 'v1.5.0',
          body: '## 新增\n- 自动检查更新\n\n## 修复\n- 深色模式文字看不清',
          assets: const [
            ('编程练习册-Setup.exe', 'https://e/setup'),
            ('编程练习册-macOS-universal.dmg', 'https://e/dmg'),
          ],
        ),
        currentVersion: '1.4.0',
        platform: UpdatePlatform.macos,
      );
      expect(info, isNotNull);
      expect(info!.version, '1.5.0');
      expect(info.tagName, 'v1.5.0');
      expect(info.notes, contains('自动检查更新'));
      expect(info.notes, contains('深色模式文字看不清'));
      expect(info.downloadUrl, 'https://e/dmg');
      expect(info.assetName, '编程练习册-macOS-universal.dmg');
      expect(info.releaseUrl, contains('/releases/tag/v1.5.0'));
    });

    test('版本没变或更旧 → null（开发机上跑未发布版本会遇到更旧）', () {
      expect(
          parseLatestRelease(releaseJson(tag: 'v1.4.0'),
              currentVersion: '1.4.0', platform: UpdatePlatform.macos),
          isNull);
      expect(
          parseLatestRelease(releaseJson(tag: 'v1.3.0'),
              currentVersion: '1.4.0', platform: UpdatePlatform.macos),
          isNull);
    });

    test('没有对应平台的安装包时只用发布页', () {
      final info = parseLatestRelease(
        releaseJson(tag: 'v1.5.0', assets: const [('only.exe', 'https://e/setup')]),
        currentVersion: '1.4.0',
        platform: UpdatePlatform.macos,
      );
      expect(info!.downloadUrl, isNull);
      expect(info.assetName, isNull);
      expect(info.preferredUrl, info.releaseUrl,
          reason: '挑不到安装包就要退到发布页，不能让「去下载」按钮没处可去');
    });

    test('更新内容为空时给空串（界面自己兜底文案）', () {
      final info = parseLatestRelease(releaseJson(tag: 'v1.5.0', body: ''),
          currentVersion: '1.4.0', platform: UpdatePlatform.macos);
      expect(info!.notes, '');
    });

    test('缺 tag_name 视为看不懂', () {
      expect(
          () => parseLatestRelease('{"body":"x"}',
              currentVersion: '1.4.0', platform: UpdatePlatform.macos),
          throwsA(isA<FormatException>()));
    });
  });

  group('check()：网络这层', () {
    test('查到新版', () async {
      final f = fakeFetch((_) => HttpTextResponse(
          200,
          releaseJson(tag: 'v1.5.0', assets: const [
            ('编程练习册-macOS-universal.dmg', 'https://e/dmg')
          ])));
      final svc = UpdateService(currentVersion: '1.4.0', fetcher: f.fetcher);
      final r = await svc.check(platform: UpdatePlatform.macos);

      expect(r.status, UpdateCheckStatus.updateAvailable);
      expect(r.hasUpdate, isTrue);
      expect(r.update!.version, '1.5.0');
      // 请求的是标准 API 地址
      expect(f.calls.single.toString(),
          'https://api.github.com/repos/$kGitHubRepo/releases/latest');
    });

    test('已是最新', () async {
      final f = fakeFetch((_) => HttpTextResponse(200, releaseJson(tag: 'v1.4.0')));
      final r = await UpdateService(currentVersion: '1.4.0', fetcher: f.fetcher)
          .check(platform: UpdatePlatform.macos);
      expect(r.status, UpdateCheckStatus.upToDate);
      expect(r.hasUpdate, isFalse);
    });

    test('仓库还没有 Release（404）算「已是最新」，不算错误', () async {
      // 项目刚起步时 Releases 就是空的。把它报成「检查失败」会让用户
      // 以为网络有问题，其实一切正常。
      final f = fakeFetch((_) => const HttpTextResponse(404, '{"message":"Not Found"}'));
      final r = await UpdateService(currentVersion: '1.4.0', fetcher: f.fetcher)
          .check(platform: UpdatePlatform.macos);
      expect(r.status, UpdateCheckStatus.upToDate);
    });

    test('API 限流（403）算失败，并且说清是限流', () async {
      final f = fakeFetch((_) => const HttpTextResponse(403, '{"message":"rate limit"}'));
      final r = await UpdateService(currentVersion: '1.4.0', fetcher: f.fetcher)
          .check(platform: UpdatePlatform.macos);
      expect(r.status, UpdateCheckStatus.failed);
      expect(r.error, contains('限流'));
    });

    test('网络异常**不抛异常**，返回 failed', () async {
      // 断网是最常见的情况。这条如果抛出去，启动时的更新检查会变成一个
      // 未捕获异常 —— 而它跟「能不能做题」毫无关系。
      final svc = UpdateService(
        currentVersion: '1.4.0',
        fetcher: (_) async => throw const SocketException('no route to host'),
      );
      final r = await svc.check(platform: UpdatePlatform.macos);
      expect(r.status, UpdateCheckStatus.failed);
      expect(r.error, isNotNull);
    });

    test('返回体不是 JSON（被网络中间层塞了登录页）→ failed，不抛', () async {
      final svc = UpdateService(
        currentVersion: '1.4.0',
        fetcher: (_) async => const HttpTextResponse(200, '<html>登录</html>'),
      );
      final r = await svc.check(platform: UpdatePlatform.macos);
      expect(r.status, UpdateCheckStatus.failed);
    });

    test('超时 → failed，不抛', () async {
      final svc = UpdateService(
        currentVersion: '1.4.0',
        fetcher: (_) async => throw TimeoutException('慢'),
      );
      expect((await svc.check(platform: UpdatePlatform.macos)).status,
          UpdateCheckStatus.failed);
    });
  });

  group('把 Release 正文收拾成能看的文本', () {
    test('去掉标题标记与代码围栏，列表符号换成中点', () {
      const raw = '''
## 新增
- 自动检查更新
### 修复
- 深色模式文字看不清

```dart
final x = 1;
```
''';
      final out = cleanReleaseNotes(raw);
      expect(out, contains('新增'));
      expect(out, contains('· 自动检查更新'));
      expect(out, contains('修复'));
      expect(out, isNot(contains('#')), reason: '标题标记不该露出来');
      expect(out, isNot(contains('```')), reason: '代码围栏不该露出来');
      expect(out, contains('final x = 1;'), reason: '围栏里的内容要留着');
    });

    test('保留**加粗**与 `代码`（交给 RichMessageText 渲染）', () {
      final out = cleanReleaseNotes('**重要**：改了 `as.exe` 的查找方式');
      expect(out, contains('**重要**'));
      expect(out, contains('`as.exe`'));
    });

    test('多余空行压成一个', () {
      expect(cleanReleaseNotes('a\n\n\n\n\nb'), 'a\n\nb');
    });

    test('空输入不会炸', () {
      expect(cleanReleaseNotes(''), '');
      expect(cleanReleaseNotes('   \n\n  '), '');
    });

    test('真实形状：开头就是代码围栏也不会让首行是反引号', () {
      // pandoc 的 Release 正文实测就是这样开头的
      final out = cleanReleaseNotes('```\nI am pleased to announce pandoc 3.11\n```');
      expect(out.startsWith('I am pleased'), isTrue, reason: '实际：$out');
    });
  });

  group('打开外部链接前的安全检查', () {
    test('放行正常的 https 链接（含中文百分号转义）', () {
      expect(isSafeExternalUrl('https://github.com/a/b/releases'), isTrue);
      expect(
          isSafeExternalUrl(
              'https://github.com/a/b/releases/download/v1.5.0/%E7%BC%96%E7%A8%8B-Setup.exe'),
          isTrue);
    });

    test('**带中文的下载链接也要放行** —— 我们自己发的包名字就是中文的', () {
      // 这是最容易漏、后果又最明显的一种：真被拒了，用户点「去下载」
      // 永远只会看到「请手动复制网址」，功能等于废了一半。
      // GitHub 给的是原文还是转义后的形式不确定，两种都得认。
      const raw = 'https://github.com/hqswww/python-practice-platform/'
          'releases/download/v1.5.0/编程练习册-Setup.exe';
      const encoded = 'https://github.com/hqswww/python-practice-platform/'
          'releases/download/v1.5.0/%E7%BC%96%E7%A8%8B%E7%BB%83%E4%B9%A0'
          '%E5%86%8C-Setup.exe';
      expect(isSafeExternalUrl(raw), isTrue, reason: '原文形式被拒了');
      expect(isSafeExternalUrl(encoded), isTrue, reason: '转义形式被拒了');
      // 规范化之后两者应当完全一样，交给命令行的就是转义后的那串
      expect(normalizeExternalUrl(raw), normalizeExternalUrl(encoded));
      expect(normalizeExternalUrl(raw), isNot(contains('编')));
    });

    test('规范化：空格转义成 %20（转义后是安全的，不该被拒）', () {
      expect(normalizeExternalUrl('https://a.com/x y'), 'https://a.com/x%20y');
      expect(isSafeExternalUrl('https://a.com/x y'), isTrue);
    });

    test('规范化：协议大小写统一', () {
      expect(normalizeExternalUrl('HTTPS://a.com/x'), 'https://a.com/x');
      expect(isSafeExternalUrl('HTTPS://a.com/x'), isTrue);
    });

    test('畸形 URL 规范化返回 null', () {
      expect(normalizeExternalUrl(''), isNull);
      expect(normalizeExternalUrl('   '), isNull);
    });

    test('只认 https，其它协议一律拒', () {
      expect(isSafeExternalUrl('http://example.com'), isFalse);
      expect(isSafeExternalUrl('file:///etc/passwd'), isFalse);
      expect(isSafeExternalUrl('javascript:alert(1)'), isFalse);
    });

    test('命令行里有特殊含义、且**转义不掉**的字符一律拒', () {
      // 这串 URL 最终会被交给系统命令执行，要按不可信输入处理。
      // 注意 `&` `;` `(` `)` 在 URL 里是合法字符，Uri 不会转义它们 ——
      // 所以它们会原样进到命令行，必须自己挡。
      expect(isSafeExternalUrl('https://a.com/x&calc'), isFalse);
      expect(isSafeExternalUrl('https://a.com/x;rm -rf /'), isFalse);
      expect(isSafeExternalUrl(r'https://a.com/x$(id)'), isFalse);
    });

    test('Uri 转义得掉的字符转义后就安全了（不必拦）', () {
      // `|` `"` 空格在 URI 里本来就不合法，会被转义成 %7C %22 %20 ——
      // 命令行收到的是这几个百分号片段，已经没有特殊含义了。
      // 硬拦它们只会让正常链接（比如文件名里带空格的）用不了。
      expect(normalizeExternalUrl('https://a.com/a|b'), 'https://a.com/a%7Cb');
      expect(isSafeExternalUrl('https://a.com/a|b'), isTrue);
      expect(isSafeExternalUrl('https://a.com/a b'), isTrue);
    });

    test('畸形输入不会让判断崩掉', () {
      expect(() => isSafeExternalUrl(''), returnsNormally);
      expect(isSafeExternalUrl(''), isFalse);
      expect(isSafeExternalUrl('https://${'a' * 3000}'), isFalse);
    });
  });
}
