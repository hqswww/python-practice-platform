import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局设置服务单例（供各页面读取/修改）
final settings = SettingsService();

/// 应用设置服务
///
/// 持久化保存主题模式、判题超时等用户偏好。
class SettingsService extends ChangeNotifier {
  static const String _themeModeKey = 'settings_theme_mode';
  static const String _timeoutKey = 'settings_timeout_ms';

  ThemeMode _themeMode = ThemeMode.system;
  int _timeoutMs = 2000;

  ThemeMode get themeMode => _themeMode;
  int get timeoutMs => _timeoutMs;

  SharedPreferences? _prefs;

  /// 加载设置（应用启动时调用一次）
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final modeIndex = _prefs!.getInt(_themeModeKey) ?? 0;
    _themeMode = ThemeMode.values[modeIndex % ThemeMode.values.length];
    _timeoutMs = _prefs!.getInt(_timeoutKey) ?? 2000;
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
