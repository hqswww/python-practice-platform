import 'package:flutter/material.dart';

import '../../services/settings_service.dart';

/// 主题强调色选择器（色板圆点，点选即切）。
///
/// 抽成独立组件是因为**首次运行向导**和**设置页**都要用它 ——
/// 两处各写一份的话，以后加色板必然漏掉一边。
class AccentColorPicker extends StatelessWidget {
  const AccentColorPicker({super.key, this.onChanged});

  /// 选中后的回调（不传则只写进 settings）
  final void Function(String id)? onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final opt in kAccentColors)
              Tooltip(
                message: opt.name,
                child: InkWell(
                  key: ValueKey('accent_${opt.id}'),
                  onTap: () {
                    settings.setAccent(opt.id);
                    onChanged?.call(opt.id);
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: opt.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: settings.accentId == opt.id
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: opt.color.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: settings.accentId == opt.id
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
