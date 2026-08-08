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

  ThemeMode _themeMode = ThemeMode.system;
  int _timeoutMs = 2000;
  String _accentId = 'green';

  ThemeMode get themeMode => _themeMode;
  int get timeoutMs => _timeoutMs;

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
}
