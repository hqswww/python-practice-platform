import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('默认强调色为清新绿', () async {
    final s = SettingsService();
    await s.load();
    expect(s.accentId, 'green');
    expect(s.accentColor, const Color(0xFF2E7D32));
  });

  test('切换强调色并持久化', () async {
    final s = SettingsService();
    await s.load();
    await s.setAccent('purple');
    expect(s.accentId, 'purple');
    expect(s.accentColor, const Color(0xFF6A1B9A));

    // 新实例应读到持久化的值
    final s2 = SettingsService();
    await s2.load();
    expect(s2.accentId, 'purple');
  });

  test('未知 id 回退绿色', () async {
    final s = SettingsService();
    await s.load();
    s.setAccentId('not_exist');
    expect(s.accentColor, const Color(0xFF2E7D32));
  });

  test('色板含 6 个预设', () {
    expect(kAccentColors.length, 6);
    expect(kAccentColors.first.id, 'green');
  });
}
