import 'package:flutter/material.dart';

import '../../app_version.dart';
import '../../services/update_service.dart';
import '../../services/url_opener.dart';
import 'rich_message_text.dart';

/// 用户在更新弹窗里选了什么
enum UpdateDialogAction {
  /// 「去下载」——已经把用户送到浏览器/安装包了
  download,

  /// 「以后再说」——这次不提示了，下次启动还会提示
  later,

  /// 「跳过这个版本」——这个版本不再提示，下个版本照常
  skipVersion,
}

/// 显示「发现新版本」弹窗。
///
/// [allowSkip] 为 false 时不给「跳过这个版本」（设置页手动检查的场景 ——
/// 用户是主动来问的，不该给他一个「以后别告诉我」的按钮）。
Future<UpdateDialogAction> showUpdateDialog(
  BuildContext context,
  UpdateInfo info, {
  bool allowSkip = true,
}) async {
  final action = await showDialog<UpdateDialogAction>(
    context: context,
    builder: (ctx) => _UpdateDialog(info: info, allowSkip: allowSkip),
  );
  return action ?? UpdateDialogAction.later;
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info, required this.allowSkip});

  final UpdateInfo info;
  final bool allowSkip;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _opening = false;

  Future<void> _download() async {
    final url = widget.info.preferredUrl;
    setState(() => _opening = true);
    final ok = await openExternalUrl(url);
    if (!mounted) return;
    setState(() => _opening = false);

    if (ok) {
      Navigator.of(context).pop(UpdateDialogAction.download);
      return;
    }
    // 打不开浏览器（无桌面环境的 Linux、命令缺失…）：
    // 不能让用户卡在这儿 —— 把网址给他，手动复制也能下
    if (!mounted) return;
    await _showManualUrl(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = widget.info;

    return AlertDialog(
      icon: const Icon(Icons.system_update_alt, size: 32),
      title: const Text('发现新版本'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 版本对照：把「从哪到哪」写清楚，用户才知道自己是不是真的旧
              Row(
                children: [
                  _versionChip(context, '当前', 'v$appVersion', muted: true),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 16),
                  ),
                  _versionChip(context, '最新', info.tagName, muted: false),
                ],
              ),
              const SizedBox(height: 16),
              Text('更新内容',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  // 用 RichMessageText 而不是 SelectableText：
                  // 更新说明里写着 `**加粗**` 和 `` `代码` ``，普通 Text 会把标记
                  // 原样显示出来（跟判题提示踩过的是同一个坑）。
                  child: RichMessageText(
                    info.notes.isEmpty
                        ? '这次发布没有写更新说明。'
                        : cleanReleaseNotes(info.notes),
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 覆盖安装会不会丢进度是用户最先担心的事，直接说清楚：
              // 进度存在系统的用户数据目录里，不在安装目录里
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      info.downloadUrl == null
                          ? '打开下载页，选对应平台的安装包下载即可，'
                              '覆盖安装不会丢失做题进度。'
                          : '下载 ${info.assetName ?? '安装包'} 后直接安装覆盖旧版本即可，'
                              '做题进度不会丢失。',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.allowSkip)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(UpdateDialogAction.skipVersion),
            child: const Text('跳过这个版本'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(UpdateDialogAction.later),
          child: Text(widget.allowSkip ? '以后再说' : '关闭'),
        ),
        FilledButton.icon(
          onPressed: _opening ? null : _download,
          icon: _opening
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download, size: 18),
          label: const Text('去下载'),
        ),
      ],
    );
  }

  Widget _versionChip(BuildContext context,
      String label, String version, {required bool muted}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: muted
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: muted
                      ? scheme.onSurfaceVariant
                      : scheme.onPrimaryContainer)),
          Text(
            version,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color:
                  muted ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// 打不开浏览器时的兜底：把网址显示出来让用户自己复制
Future<void> _showManualUrl(BuildContext context, String url) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('没能自动打开浏览器'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
