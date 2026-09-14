import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/programming_language.dart';
import '../models/test_scope.dart';

/// 全局设置服务单例（供各页面读取/修改）
final settings = SettingsService();

/// 可选主题强调色（seed 色值）
class AccentColorOption {
  final String id;
  final String name;
  final Color color;

  const AccentColorOption({
    required this.id,
    required this.name,
    required this.color,
  });
}

/// 预设强调色板
const List<AccentColorOption> kAccentColors = [
  AccentColorOption(id: 'green', name: '清新绿', color: Color(0xFF2E7D32)),
  AccentColorOption(id: 'blue', name: '科技蓝', color: Color(0xFF1565C0)),
  AccentColorOption(id: 'purple', name: '魅惑紫', color: Color(0xFF6A1B9A)),
  AccentColorOption(id: 'orange', name: '活力橙', color: Color(0xFFE65100)),
  AccentColorOption(id: 'pink', name: '少女粉', color: Color(0xFFC2185B)),
  AccentColorOption(id: 'teal', name: '青碧', color: Color(0xFF00695C)),
];

/// 应用设置服务
///
/// 持久化保存主题模式、判题超时等用户偏好。
class SettingsService extends ChangeNotifier {
  static const String _themeModeKey = 'settings_theme_mode';
  static const String _timeoutKey = 'settings_timeout_ms';
  static const String _accentKey = 'settings_accent_id';
  static const String _fontSizeKey = 'settings_editor_font_size';
  static const String _indentWidthKey = 'settings_editor_indent_width';

  /// 是否执行题库声明的源码语法要求检查（见 source_check.dart）
  static const String _strictSourceKey = 'settings_strict_source_check';

  /// 启动时自动检查更新（见 update_service.dart）
  static const String _autoUpdateKey = 'settings_auto_check_update';

  /// 用户点了「跳过这个版本」的版本号。只跳过**这一个**版本，
  /// 下一个版本照常提示 —— 不能变成「永久不再提示」。
  static const String _skippedUpdateKey = 'settings_skipped_update_version';

  /// 首次运行向导是否已完成。
  ///
  /// 用「已完成」而不是「未完成」做键：键不存在时默认 false（= 该显示向导），
  /// 这样老用户升级上来也会看到一次向导 —— 他们那台机器上编译器可能确实没配好，
  /// 顺带补上是有价值的。
  static const String _setupDoneKey = 'settings_setup_wizard_done';
  /// 旧版单一「Python 解释器路径」的键。保留只为迁移到按语言存储。
  static const String _legacyPythonPathKey = 'settings_python_path';

  /// 各语言运行时路径的键前缀（实际键为 `settings_runtime_path_<语言 id>`）
  static const String _runtimePathPrefix = 'settings_runtime_path_';

  /// 各测试模式倒计时时长的存储键前缀（实际键为 `settings_test_time_<modeId>`）
  static const String _testTimePrefix = 'settings_test_time_';

  /// 各测试模式出题范围的存储键前缀
  /// （`settings_test_scope_cats_<模式 id>` / `settings_test_scope_tier_<模式 id>`）
  static const String _testScopeCatsPrefix = 'settings_test_scope_cats_';
  static const String _testScopeTierPrefix = 'settings_test_scope_tier_';

  /// 各测试模式的默认倒计时时长（秒），0 = 不限时。
  ///
  /// 之所以逐模式配置而不是一个全局值：题量差太多（5 题 vs 72 题），
  /// 同一个时长对「快速测验」太松、对「全题库」又根本不够。
  /// 全题库默认不限时 —— 它更像完整模拟考，不是限时训练。
  static const Map<String, int> defaultTestTimeLimits = {
    'quick': 600, // 快速测验（5 题）→ 10 分钟
    'standard': 900, // 标准测验（10 题）→ 15 分钟
    'intensive': 1200, // 强化测验（15 题）→ 20 分钟
    'full': 0, // 全题库 → 不限时
  };

  ThemeMode _themeMode = ThemeMode.system;
  int _timeoutMs = 2000;
  String _accentId = 'green';

  // 编辑器外观：字体大小（12–22）与缩进宽度（空格数），默认 14 / 4
  int _editorFontSize = 14;
  int _editorIndentWidth = 4;

  /// 严格模式：题库声明了「必须用上某个语法」时，判题会到源码里核对。
  /// 默认开 —— 这正是解决「不用指针也能判过」的那个开关。
  bool _strictSourceCheck = true;

  /// 启动时自动检查更新。默认开：这是个纯离线应用，用户没有别的途径
  /// 知道有新版本，不主动提示就永远不会更新。
  bool _autoCheckUpdate = true;

  /// 用户选择跳过的版本号（空 = 没跳过任何版本）
  String _skippedUpdateVersion = '';

  /// 首次运行向导是否已完成（false = 启动时进向导）
  bool _setupWizardDone = false;
  // 各语言自定义运行时路径（解释器 / 编译器），空 = 自动解析。
  // 按语言分开存：将来 C 要填的是 clang/gcc 路径，和 Python 的解释器不是一回事。
  final Map<ProgrammingLanguage, String> _runtimePaths = {};

  /// 各测试模式的倒计时时长（秒），0 = 不限时。键为模式 id。
  final Map<String, int> _testTimeLimits = Map.of(defaultTestTimeLimits);

  /// 各测试模式的**出题范围**（大类序号 + 难度档位）。键为模式 id。
  /// 没存过的模式用 [TestScope.defaults]（全部大类 + 不限难度）。
  final Map<String, TestScope> _testScopes = {};

  ThemeMode get themeMode => _themeMode;
  int get timeoutMs => _timeoutMs;

  /// 编辑器字体大小（px），默认 14
  int get editorFontSize => _editorFontSize;

  /// 编辑缩进宽度（空格数），默认 4
  int get editorIndentWidth => _editorIndentWidth;

  /// 首次运行向导是否已完成
  bool get setupWizardDone => _setupWizardDone;

  /// 是否执行题库声明的源码语法要求检查（默认开）
  bool get strictSourceCheck => _strictSourceCheck;

  /// 启动时是否自动检查更新（默认开）
  bool get autoCheckUpdate => _autoCheckUpdate;

  /// 用户点过「跳过这个版本」的版本号（空 = 没跳过）
  String get skippedUpdateVersion => _skippedUpdateVersion;

  /// 某语言的自定义运行时路径（解释器 / 编译器）；空字符串表示自动解析
  String runtimePath(ProgrammingLanguage language) =>
      _runtimePaths[language] ?? '';

  /// 某个测试模式的出题范围（没存过就是默认：全部大类 + 不限难度）
  TestScope testScope(String modeId) =>
      _testScopes[modeId] ?? TestScope.defaults;

  /// 某个测试模式的倒计时时长（秒）；0 = 不限时。
  /// 未知模式 id 返回 0（相当于不限时，安全默认）。
  int testTimeLimit(String modeId) => _testTimeLimits[modeId] ?? 0;

  /// 该模式的时长是否生效（>0 才倒计时）
  bool hasTestTimeLimit(String modeId) => testTimeLimit(modeId) > 0;

  /// 当前强调色 id（默认 green）
  String get accentId => _accentId;

  /// 当前强调色 seed（未知 id 回退绿色）
  Color get accentColor =>
      kAccentColors.firstWhere((o) => o.id == _accentId,
          orElse: () => kAccentColors.first).color;

  /// 设置当前强调色 id
  void setAccentId(String id) => _accentId = id;

  SharedPreferences? _prefs;

  /// 加载设置（应用启动时调用一次）
  ///
  /// ⚠️ 这里必须把**每个**持久化字段都读回来。
  /// 之前漏读了字体大小 / 缩进宽度 / Python 解释器路径三项 ——
  /// setter 老老实实写进了 SharedPreferences，但 load 从不读回，
  /// 于是重启后静默回落到默认值（14 / 4 / 空），用户会以为"设置没保存"。
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final modeIndex = _prefs!.getInt(_themeModeKey) ?? 0;
    _themeMode = ThemeMode.values[modeIndex % ThemeMode.values.length];
    _timeoutMs = _prefs!.getInt(_timeoutKey) ?? 2000;
    _accentId = _prefs!.getString(_accentKey) ?? 'green';
    _editorFontSize = _prefs!.getInt(_fontSizeKey) ?? 14;
    _editorIndentWidth = _prefs!.getInt(_indentWidthKey) ?? 4;
    _setupWizardDone = _prefs!.getBool(_setupDoneKey) ?? false;
    // 默认 true：老用户升级上来也享受到这道检查（他们那台机器上
    // 「不用指针也能过」的问题一样存在），需要关的人自己去设置页关。
    _strictSourceCheck = _prefs!.getBool(_strictSourceKey) ?? true;
    _autoCheckUpdate = _prefs!.getBool(_autoUpdateKey) ?? true;
    _skippedUpdateVersion = _prefs!.getString(_skippedUpdateKey) ?? '';
    for (final lang in ProgrammingLanguage.values) {
      _runtimePaths[lang] =
          _prefs!.getString('$_runtimePathPrefix${lang.id}') ?? '';
    }
    // 迁移：老版本只有一个「Python 解释器路径」，搬进按语言的存储里
    if ((_runtimePaths[ProgrammingLanguage.python] ?? '').isEmpty) {
      final legacy = _prefs!.getString(_legacyPythonPathKey)?.trim() ?? '';
      if (legacy.isNotEmpty) {
        _runtimePaths[ProgrammingLanguage.python] = legacy;
      }
    }
    for (final entry in defaultTestTimeLimits.entries) {
      _testTimeLimits[entry.key] =
          _prefs!.getInt('$_testTimePrefix${entry.key}') ?? entry.value;
      // 出题范围：两个键（大类序号列表 + 难度档位）一起读。
      // 缺任一个就当没存过 —— 半个范围比默认范围更难解释。
      final rawCats = _prefs!.getStringList('$_testScopeCatsPrefix${entry.key}');
      final rawTier = _prefs!.getInt('$_testScopeTierPrefix${entry.key}');
      if (rawCats != null && rawTier != null) {
        _testScopes[entry.key] = TestScope(
          ordinals: TestScope.normalizeOrdinals(
              rawCats.map(int.tryParse).whereType<int>()),
          tier: DifficultyTier.fromLevel(rawTier),
        );
      }
    }
    notifyListeners();
  }

  /// 设置主题色 id 并持久化（即时生效经 ListenableBuilder）
  Future<void> setAccent(String id) async {
    _accentId = id;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_accentKey, id);
    notifyListeners();
  }

  /// 设置主题模式并持久化
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  /// 设置判题超时（毫秒）并持久化
  Future<void> setTimeoutMs(int ms) async {
    _timeoutMs = ms;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_timeoutKey, ms);
    notifyListeners();
  }

  /// 设置编辑器字体大小（px）并持久化
  Future<void> setEditorFontSize(int px) async {
    _editorFontSize = px;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_fontSizeKey, px);
    notifyListeners();
  }

  /// 设置编辑缩进宽度（空格数）并持久化
  Future<void> setEditorIndentWidth(int width) async {
    _editorIndentWidth = width;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_indentWidthKey, width);
    notifyListeners();
  }

  /// 标记首次运行向导已完成（或重新打开：传 false）
  Future<void> setSetupWizardDone(bool done) async {
    _setupWizardDone = done;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_setupDoneKey, done);
    notifyListeners();
  }

  /// 开关「源码语法要求检查」并持久化
  Future<void> setStrictSourceCheck(bool value) async {
    _strictSourceCheck = value;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_strictSourceKey, value);
    notifyListeners();
  }

  /// 设置某个测试模式的出题范围并持久化。
  ///
  /// 两个键分开存（大类序号列表 / 难度档位），因为它们的变化互不相关 ——
  /// 合成一个 JSON 字符串也能做，但 `setStringList` 是基础类型，
  /// 出问题时在 SharedPreferences 里一眼能看懂。
  Future<void> setTestScope(String modeId, TestScope scope) async {
    final ordinals = TestScope.normalizeOrdinals(scope.ordinals);
    _testScopes[modeId] =
        TestScope(ordinals: ordinals, tier: scope.tier);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList(
        '$_testScopeCatsPrefix$modeId', (ordinals.toList()..sort()).map((o) => '$o').toList());
    await _prefs!.setInt('$_testScopeTierPrefix$modeId', scope.tier.level);
    notifyListeners();
  }

  /// 开关「启动时自动检查更新」并持久化
  Future<void> setAutoCheckUpdate(bool value) async {
    _autoCheckUpdate = value;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_autoUpdateKey, value);
    notifyListeners();
  }

  /// 记下「这个版本我不再提示了」并持久化。
  /// 传空字符串 = 清掉（手动检查时想重新看到提示就用它）。
  Future<void> setSkippedUpdateVersion(String version) async {
    _skippedUpdateVersion = version.trim();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_skippedUpdateKey, _skippedUpdateVersion);
    notifyListeners();
  }

  /// 设置某语言的自定义运行时路径（空 = 自动解析）并持久化
  Future<void> setRuntimePath(ProgrammingLanguage language, String path) async {
    final trimmed = path.trim();
    _runtimePaths[language] = trimmed;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('$_runtimePathPrefix${language.id}', trimmed);
    notifyListeners();
  }

  /// 设置某个测试模式的倒计时时长（秒，0 = 不限时）并持久化。
  /// 各模式互不影响 —— 这正是「不再一刀切」的关键。
  Future<void> setTestTimeLimit(String modeId, int seconds) async {
    _testTimeLimits[modeId] = seconds < 0 ? 0 : seconds;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt('$_testTimePrefix$modeId', _testTimeLimits[modeId]!);
    notifyListeners();
  }
}
