import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Wraps the Hive 'settings' box with typed getters/setters.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _boxName = 'settings';
  static const _keyTheme = 'theme';
  static const _keyLocale = 'locale';
  static const _keySound = 'sound';
  static const _keyHaptic = 'haptic';
  static const _keyPlayerName = 'player_name';

  late Box _box;

  Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    } else {
      _box = await Hive.openBox(_boxName);
    }
  }

  ThemeMode get themeMode {
    final v = _box.get(_keyTheme, defaultValue: 'system') as String;
    return switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  set themeMode(ThemeMode mode) {
    final v = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    _box.put(_keyTheme, v);
  }

  Locale? get locale {
    final v = _box.get(_keyLocale) as String?;
    if (v == null) return null;
    return Locale(v);
  }

  set locale(Locale? l) => _box.put(_keyLocale, l?.languageCode);

  bool get soundEnabled => _box.get(_keySound, defaultValue: true) as bool;
  set soundEnabled(bool v) => _box.put(_keySound, v);

  bool get hapticEnabled => _box.get(_keyHaptic, defaultValue: true) as bool;
  set hapticEnabled(bool v) => _box.put(_keyHaptic, v);

  String get playerName =>
      _box.get(_keyPlayerName, defaultValue: 'Player') as String;
  set playerName(String v) => _box.put(_keyPlayerName, v);
}
