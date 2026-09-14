import 'package:flutter/material.dart';

import '../../app_version.dart';
import '../../services/settings_service.dart';
import '../../services/update_service.dart';
import 'update_dialog.dart';

/// 「检查更新」的实际内容：开关 + 立即检查 + 当前版本。
///
/// 抽成独立组件是因为它有了两个宿主：「设置 → 关于」分类，和新的「关于」页。
/// 复制一份的代价不是代码量，而是**同一个开关在两处显示不一致**
/// （在一边关掉、另一边还显示开着），那种不一致看起来就像 bug。
class UpdatePanel extends StatefulWidget {
  const UpdatePanel({super.key});

  @override
  State<UpdatePanel> createState() => _UpdatePanelState();
}

class _UpdatePanelState extends State<UpdatePanel> {
  /// 「立即检查更新」是否正在进行（防连点、按钮转圈）
  bool _checking = false;

  /// 手动检查一次更新。三种结果都要有明确反馈 —— 用户是主动来问的，
  /// 不能像启动时那样静默。
  Future<void> _checkNow() async {
    // 用 State 自己的 context：下面的 mounted 检查才是「对得上号」的那个
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _checking = true);
    final result = await updateService.check();
    if (!mounted) return;
    setState(() => _checking = false);

    switch (result.status) {
      case UpdateCheckStatus.updateAvailable:
        await showUpdateDialog(context, result.update!, allowSkip: false);
      case UpdateCheckStatus.upToDate:
        messenger.showSnackBar(SnackBar(
          content: Text('已是最新版本（v$appVersion）'),
        ));
      case UpdateCheckStatus.failed:
        messenger.showSnackBar(SnackBar(
          content: Text('检查更新失败：${result.error}。'
              '可以直接去 GitHub 的 Releases 页面看看。'),
          duration: const Duration(seconds: 5),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.autoCheckUpdate,
            onChanged: (v) => settings.setAutoCheckUpdate(v),
            title: const Text('启动时自动检查更新'),
            subtitle: const Text('发现新版本时弹窗提示更新内容，可一键跳到下载页'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _checking ? null : _checkNow,
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_checking ? '检查中…' : '立即检查更新'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '更新只会跳到 GitHub 的下载页，由你决定什么时候装；'
            '覆盖安装不会丢失做题进度。',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
