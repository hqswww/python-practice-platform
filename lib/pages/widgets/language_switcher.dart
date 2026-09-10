import 'package:flutter/material.dart';

import '../../data/problem_repository.dart';
import '../../models/programming_language.dart';
import '../../services/language_service.dart';

/// 顶栏语言切换器
///
/// 行为设计：
/// - **始终显示当前语言**（不是「多于一个才显示」）。三个主板块（学习/练习/测试）
///   都是按语言划分内容的，把当前语言摆在顶栏本身就是有用的信息，
///   也让人一眼看出这是个多语言平台。
/// - **只有一个语言时不可点击**（不弹菜单、不画下拉箭头）——
///   点开只有一个选项的菜单是纯噪音。
/// - 题库接上第二门语言后自动变成真正的下拉菜单，不需要改这里。
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key, this.available, this.service});

  /// 可选语言。默认取题库里已接入的语言（目前只有 Python）。
  /// 参数化的目的是让测试能注入多语言场景来验证下拉行为。
  final List<ProgrammingLanguage>? available;

  /// 语言状态服务。默认用全局单例；测试可注入以便验证切换行为。
  final LanguageService? service;

  LanguageService get _service => service ?? languageService;

  @override
  Widget build(BuildContext context) {
    final langs = available ?? availableLanguages;
    if (langs.isEmpty) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final current = _service.value;
        final switchable = langs.length > 1;
        final scheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: PopupMenuButton<ProgrammingLanguage>(
            tooltip: switchable ? '切换编程语言' : '当前语言',
            enabled: switchable,
            initialValue: current,
            onSelected: _service.select,
            itemBuilder: (context) => [
              for (final lang in langs)
                PopupMenuItem<ProgrammingLanguage>(
                  value: lang,
                  child: Row(
                    children: [
                      Icon(
                        lang == current
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: lang == current ? scheme.primary : scheme.outline,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        lang.displayName,
                        style: TextStyle(
                          fontWeight:
                              lang == current ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.code, size: 15, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    current.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  // 只有一个语言时不给下拉暗示，免得用户去点一个没反应的控件
                  if (switchable) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: 18, color: scheme.primary),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
