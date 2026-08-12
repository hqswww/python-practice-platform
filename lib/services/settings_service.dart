import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _pythonPathKey = 'settings_python_path';

  ThemeMode _themeMode = ThemeMode.system;
  int _timeoutMs = 2000;
  String _accentId = 'green';

  // 编辑器外观：字体大小（12–22）与缩进宽度（空格数），默认 14 / 4
  int _editorFontSize = 14;
  int _editorIndentWidth = 4;
  // 自定义 Python 解释器路径（空 = 自动解析：Linux python3 / Windows 捆绑 python.exe）
  String _pythonPath = '';

  ThemeMode get themeMode => _themeMode;
  int get timeoutMs => _timeoutMs;

  /// 编辑器字体大小（px），默认 14
  int get editorFontSize => _editorFontSize;

  /// 编辑缩进宽度（空格数），默认 4
  int get editorIndentWidth => _editorIndentWidth;

  /// 自定义 Python 解释器路径；空字符串表示自动
  String get pythonPath => _pythonPath;

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
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final modeIndex = _prefs!.getInt(_themeModeKey) ?? 0;
    _themeMode = ThemeMode.values[modeIndex % ThemeMode.values.length];
    _timeoutMs = _prefs!.getInt(_timeoutKey) ?? 2000;
    _accentId = _prefs!.getString(_accentKey) ?? 'green';
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

  /// 设置自定义 Python 解释器路径（空 = 自动解析）并持久化
  Future<void> setPythonPath(String path) async {
    _pythonPath = path.trim();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_pythonPathKey, _pythonPath);
    notifyListeners();
  }
}
