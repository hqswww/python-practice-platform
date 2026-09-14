import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app_version.dart';
import '../services/update_service.dart';
import '../services/url_opener.dart';
import 'widgets/responsive.dart';
import 'widgets/rich_message_text.dart';
import 'widgets/update_panel.dart';

/// 「关于」页。
///
/// 从弹窗升级成整页：弹窗里塞不下这么多东西（更新日志、许可证、项目链接），
/// 而且用户想回看「这个版本改了什么」时，弹窗一关就没了。
///
/// 两个入口都指向这里：底栏「我的 → 关于」，以及「设置 → 关于」分类里的那一项。
/// 内容只有一份 —— 两处各写一份的话迟早会出现「一个说 v1.5.1、一个说 v1.5.0」。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// 项目主页与反馈入口
  static const String repoUrl =
      'https://github.com/hqswww/python-practice-platform';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: MaxWidthBody(
        maxWidth: ContentWidth.article,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _AppHeader(),
            SizedBox(height: 16),
            _UpdateCard(),
            SizedBox(height: 12),
            _ChangelogCard(),
            SizedBox(height: 12),
            _ProjectCard(),
            SizedBox(height: 12),
            _LicenseCard(),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// 顶部：图标 + 名称 + 版本 + 一句话
class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // 用应用自己的图标，不另画一个 —— 和 Dock/Finder 里看到的保持一致。
            // 这张 png 由 tools/make_icons.py 和平台图标同源生成，
            // 不是从某个平台的目录里顺手拿的。
            Image.asset(
              'assets/app_icon.png',
              width: 56,
              height: 56,
              errorBuilder: (_, _, _) => Icon(
                Icons.menu_book,
                size: 56,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('编程练习册',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('版本 v$appVersion',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(
                    '面向初学者的本地编程练习与判题工具。'
                    'Python / C / C++ 三门语言，判题全部在本机完成。',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 检查更新（内容和「设置 → 关于」里那份是同一个组件）
class _UpdateCard extends StatelessWidget {
  const _UpdateCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.system_update_alt,
      color: Colors.teal,
      title: '检查更新',
      subtitle: '当前版本 v$appVersion',
      child: const UpdatePanel(),
    );
  }
}

/// 更新日志：读打包进来的 assets/CHANGELOG.md，按版本拆成可展开小节
class _ChangelogCard extends StatefulWidget {
  const _ChangelogCard();

  @override
  State<_ChangelogCard> createState() => _ChangelogCardState();
}

class _ChangelogCardState extends State<_ChangelogCard> {
  late final Future<List<ChangelogSection>> _future = loadChangelog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      icon: Icons.history_edu_outlined,
      color: Colors.indigo,
      title: '更新日志',
      subtitle: '每个版本改了什么',
      child: FutureBuilder<List<ChangelogSection>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final sections = snap.data ?? const <ChangelogSection>[];
          if (sections.isEmpty) {
            return Text('读不到更新日志。',
                style: TextStyle(color: scheme.onSurfaceVariant));
          }
          return Column(
            children: [
              for (var i = 0; i < sections.length; i++)
                _ChangelogTile(section: sections[i], initiallyExpanded: i == 0),
            ],
          );
        },
      ),
    );
  }
}

class _ChangelogTile extends StatelessWidget {
  const _ChangelogTile({required this.section, required this.initiallyExpanded});

  final ChangelogSection section;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      // 默认展开最新一版：用户点进「更新日志」多半就是想看这次改了什么
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(section.version,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: RichMessageText(
            section.body,
            style: TextStyle(
                fontSize: 13, height: 1.6, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// 项目主页 / 问题反馈
class _ProjectCard extends StatelessWidget {
  const _ProjectCard();

  Future<void> _open(BuildContext context, String url, String what) async {
    final ok = await openExternalUrl(url);
    if (!context.mounted) return;
    if (ok) return;
    // 打不开浏览器（无桌面环境的 Linux、命令缺失…）时不能就卡着 ——
    // 把网址给用户，复制到浏览器里一样能用
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('没能自动打开$what'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请手动复制下面的网址，在浏览器里打开：'),
            const SizedBox(height: 10),
            SelectableText(url, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.link,
      color: Colors.blueGrey,
      title: '项目',
      subtitle: null,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.home_outlined),
            title: const Text('项目主页'),
            subtitle: const Text('源码、发布记录、使用说明'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(context, AboutPage.repoUrl, '项目主页'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('问题反馈'),
            subtitle: const Text('遇到问题、题目有错、想要新功能都可以提'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () =>
                _open(context, '${AboutPage.repoUrl}/issues/new', '反馈页面'),
          ),
        ],
      ),
    );
  }
}

/// 许可证：第三方（Flutter 内置页面）+ 自己这份 MIT
class _LicenseCard extends StatelessWidget {
  const _LicenseCard();

  Future<void> _showOwnLicense(BuildContext context) async {
    // 直接读打包进来的 LICENSE 文件 —— 和仓库根目录那份是同一个文件，
    // 不存在「页面上写的和 LICENSE 不一致」的可能
    final text = await loadLicenseText();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('开源许可证（MIT）'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(text,
                style: const TextStyle(fontSize: 12, height: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.gavel_outlined,
      color: Colors.brown,
      title: '许可证',
      subtitle: null,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.article_outlined),
            title: const Text('开源许可证（MIT）'),
            subtitle: const Text('本项目自己的许可证'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showOwnLicense(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('第三方许可证'),
            subtitle: const Text('Flutter 及所用开源包的许可证全文'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LicensePage(
                  applicationName: '编程练习册',
                  applicationVersion: 'v$appVersion',
                  applicationLegalese: 'Copyright (c) 2026 hqswww',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 带图标标题的区块卡片（本页几个区块共用，免得各写一套间距）
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ 更新日志的解析

/// 更新日志里的一个版本小节
class ChangelogSection {
  final String version;
  final String body;

  const ChangelogSection({required this.version, required this.body});
}

/// 把 CHANGELOG.md 按「行首 # 」切成版本小节。
///
/// 只收标题里带 `vX.Y.Z` 的小节 —— 文件开头那段「本文件由脚本生成，不要手改」
/// 也是 `#` 开头，不收的话它会被当成一个版本显示出来。
List<ChangelogSection> parseChangelog(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').split('\n');
  final sections = <ChangelogSection>[];
  String? version;
  final body = <String>[];

  void flush() {
    final v = version;
    if (v == null) return;
    // 显示前用与更新弹窗同一套清洗：去掉 #、代码围栏、分隔线，
    // 列表符号换成中点，留下 **加粗** 和 `代码` 交给 RichMessageText
    sections.add(ChangelogSection(
      version: v,
      body: cleanReleaseNotes(body.join('\n')),
    ));
  }

  for (final line in lines) {
    final heading = RegExp(r'^#\s+(.*)$').firstMatch(line);
    if (heading != null) {
      final title = heading.group(1)!.trim();
      final versionToken =
          RegExp(r'v?\d+\.\d+\.\d+').firstMatch(title)?.group(0);
      if (versionToken != null) {
        flush();
        // 只留版本号本身当标题：`编程练习册 v1.5.1` → `v1.5.1`。
        // 每一行都重复一遍软件名没有信息量。
        version = versionToken.startsWith('v')
            ? versionToken
            : 'v$versionToken';
        body.clear();
        continue;
      }
      // 不是版本标题（比如文件头）：结束当前小节，并且不把它当新小节
      flush();
      version = null;
      body.clear();
      continue;
    }
    if (version != null) body.add(line);
  }
  flush();
  return sections;
}

/// 读取打包进来的更新日志
Future<List<ChangelogSection>> loadChangelog() async =>
    parseChangelog(await rootBundle.loadString('assets/CHANGELOG.md'));

/// 读取打包进来的 MIT 许可证全文
///
/// 直接读仓库根目录那份 LICENSE —— 和 GitHub 上、和打包进应用的是同一个文件，
/// 不存在「关于页写的和 LICENSE 不一致」的可能。
Future<String> loadLicenseText() async =>
    (await rootBundle.loadString('LICENSE')).trim();
