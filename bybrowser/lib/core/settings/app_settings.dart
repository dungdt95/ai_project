import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cài đặt người dùng (hiện chỉ có chế độ giao diện), lưu SharedPreferences.
class AppSettings extends ChangeNotifier {
  static const _keyTheme = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyTheme);
    _themeMode = ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, mode.name);
  }
}

String themeModeLabel(ThemeMode m) => switch (m) {
      ThemeMode.system => 'Theo hệ thống',
      ThemeMode.light => 'Sáng',
      ThemeMode.dark => 'Tối',
    };
