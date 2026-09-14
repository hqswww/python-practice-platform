import 'package:flutter/material.dart';

import '../../models/problem.dart';
import '../../models/problem_category.dart';
import '../../models/test_scope.dart';
import '../../services/test_scope_resolver.dart';
import 'difficulty_style.dart';

/// 出题范围设置弹窗。返回新范围；用户取消时返回 null。
///
/// 为什么用弹窗而不是塞进测试页：范围是「这个模式偶尔调一次」的东西，
/// 12 个大类 + 3 个难度档铺在列表里会把四种模式的入口淹掉。
Future<TestScope?> showTestScopeDialog({
  required BuildContext context,
  required String modeLabel,
  required List<ProblemCategory> categories,
  required TestScope scope,
}) {
  return showDialog<TestScope>(
    context: context,
    builder: (_) => _TestScopeDialog(
      modeLabel: modeLabel,
      categories: categories,
      initial: scope,
    ),
  );
}

class _TestScopeDialog extends StatefulWidget {
  const _TestScopeDialog({
    required this.modeLabel,
    required this.categories,
    required this.initial,
  });

  final String modeLabel;
  final List<ProblemCategory> categories;
  final TestScope initial;

  @override
  State<_TestScopeDialog> createState() => _TestScopeDialogState();
}

class _TestScopeDialogState extends State<_TestScopeDialog> {
  late Set<int> _ordinals = {...widget.initial.ordinals};
  late DifficultyTier _tier = widget.initial.tier;

  /// 按序号索引当前语言的分类（key 里的序号 → 分类）
  late final Map<int, ProblemCategory> _byOrdinal = {
    for (final c in widget.categories) ?categoryOrdinal(c.key): c,
  };

  @override
  void initState() {
    super.initState();
    // 存下来的档位可能对当前范围已经没意义（范围变小了 / 老数据），
    // 开弹窗时先夹一次，免得「选中的是难度三、实际按难度二出题」这种
    // 说了不算的状态被带进来。
    _clampTier();
  }

  TestScope get _scope => TestScope(ordinals: _ordinals, tier: _tier);

  ResolvedScope get _resolved =>
      resolveTestScope(categories: widget.categories, scope: _scope);

  void _toggleOrdinal(int ordinal) {
    setState(() {
      if (_ordinals.contains(ordinal)) {
        _ordinals.remove(ordinal);
      } else {
        _ordinals.add(ordinal);
      }
      // 范围变了，原来那一档可能已经没意义了（比如把唯一的困难题大类去掉），
      // 自动往下夹到最近一个还可用的档 —— 否则会出现「选了难度三，
      // 实际和难度二一样」这种说了不算的状态。
      _clampTier();
    });
  }

  void _clampTier() {
    final enabled = _resolved.enabledTiers;
    if (enabled.isEmpty || enabled.contains(_tier)) return;
    for (final t in DifficultyTier.values.reversed) {
      if (t.level <= _tier.level && enabled.contains(t)) {
        _tier = t;
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resolved = _resolved;
    final ordinals = _byOrdinal.keys.toList()..sort();

    return AlertDialog(
      title: Text('${widget.modeLabel} · 出题范围'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---------------------------------------------------- 大类
              Row(
                children: [
                  Text('从哪些大类出题',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _ordinals = {...ordinals};
                      _clampTier();
                    }),
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _ordinals = <int>{};
                      _clampTier();
                    }),
                    child: const Text('全不选'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in ordinals)
                    FilterChip(
                      label: Text(_byOrdinal[o]!.name),
                      selected: _ordinals.contains(o),
                      onSelected: (_) => _toggleOrdinal(o),
                    ),
                ],
              ),
              if (_ordinals.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '至少要选一个大类',
                    style: TextStyle(fontSize: 12, color: scheme.error),
                  ),
                ),

              const SizedBox(height: 20),

              // ---------------------------------------------------- 难度
              Text('难度范围',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (final t in DifficultyTier.values)
                _tierOption(t, resolved.enabledTiers.contains(t)),

              const SizedBox(height: 12),

              // ---------------------------------------------------- 预览
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _previewText(resolved),
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(TestScope.defaults),
          child: const Text('恢复默认'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _ordinals.isEmpty || resolved.isEmpty
              ? null
              : () => Navigator.of(context).pop(_scope),
          child: const Text('保存'),
        ),
      ],
    );
  }

  /// 一档难度：点一下选中。范围内没有那一级题目时**禁用** ——
  /// 选了也不会有任何变化，摆在那里只会让人以为「选了会变难」。
  Widget _tierOption(DifficultyTier t, bool enabled) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _tier == t;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? () => setState(() => _tier = t) : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 10),
              DifficultyDots(maxLevel: t.level),
              const SizedBox(width: 10),
              Text(t.label,
                  style: TextStyle(
                      color: color,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  enabled ? t.detail : '范围内没有${t.introduces.label}题',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewText(ResolvedScope r) {
    if (_ordinals.isEmpty) return '一个大类都没选，先选至少一个。';
    if (r.isEmpty) return '这个范围里一道题都没有。';

    final parts = <String>[];
    for (final d in Difficulty.values) {
      final n = r.countOf(d);
      if (n > 0) parts.add('${d.label} $n');
    }
    return '这个范围一共 ${r.total} 题：${parts.join(' · ')}';
  }
}
