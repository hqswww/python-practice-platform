import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/problem_repository.dart';
import '../models/programming_language.dart';

/// 全平台「当前语言」状态
///
/// 为什么独立成一个服务，而不是塞进 `SettingsService`：
/// 1. 它需要被 `ListenableBuilder` 监听（切语言要重建整页），`ValueNotifier` 最贴合
/// 2. 它读得比写得多 —— 各页面/服务的「语言级」统计都从这儿取当前语言，
///    不必一层层往下传参数
///
/// 用法约定：
/// - **语言级**统计（错题数、收藏数、测试次数、总进度）用 [value]
/// - **单题**操作一律用对象自带的 `problem.language`
///   后者更可靠：即使某页面显示的不是当前语言的题，也不会把进度写到别处
class LanguageService extends ValueNotifier<ProgrammingLanguage> {
  LanguageService() : super(ProgrammingLanguage.python);

  static const String _key = 'settings_current_language';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// 读取上次选的语言（应用启动时调用一次）
  Future<void> load() async {
    final prefs = await _ensure();
    value = _safest(ProgrammingLanguage.fromId(prefs.getString(_key)));
  }

  /// 切换语言并持久化
  Future<void> select(ProgrammingLanguage language) async {
    final target = _safest(language);
    if (target == value) return;
    value = target;
    final prefs = await _ensure();
    await prefs.setString(_key, target.id);
  }

  /// 保证返回的语言确实有题库；否则回退到第一个可用的。
  /// （比如某语言的题库后来被移除了，存下来的选择就失效了）
  static ProgrammingLanguage _safest(ProgrammingLanguage wanted) {
    final available = availableLanguages;
    if (available.isEmpty) return wanted;
    return available.contains(wanted) ? wanted : available.first;
  }
}

/// 全局单例
final languageService = LanguageService();
