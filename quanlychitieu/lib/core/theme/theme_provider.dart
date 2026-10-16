import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';

class ThemePreference {
  final String colorName;
  final ThemeMode mode;
  const ThemePreference({this.colorName = 'blue', this.mode = ThemeMode.light});

  ThemePreference copyWith({String? colorName, ThemeMode? mode}) =>
      ThemePreference(
        colorName: colorName ?? this.colorName,
        mode: mode ?? this.mode,
      );
}

class ThemeNotifier extends StateNotifier<ThemePreference> {
  ThemeNotifier() : super(const ThemePreference()) {
    _load();
  }

  final _repo = SettingsRepository();

  Future<void> _load() async {
    final color = await _repo.get('theme_color') ?? 'blue';
    final modeStr = await _repo.get('theme_mode') ?? 'light';
    state = ThemePreference(colorName: color, mode: _parseMode(modeStr));
  }

  Future<void> setColor(String color) async {
    await _repo.set('theme_color', color);
    state = state.copyWith(colorName: color);
  }

  Future<void> setMode(ThemeMode mode) async {
    await _repo.set('theme_mode', _modeToString(mode));
    state = state.copyWith(mode: mode);
  }

  static ThemeMode _parseMode(String s) {
    switch (s) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static String _modeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      default:
        return 'light';
    }
  }

  static String labelForMode(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:
        return 'Tối';
      case ThemeMode.system:
        return 'Theo hệ thống';
      default:
        return 'Sáng';
    }
  }
}

final themePreferenceProvider =
    StateNotifierProvider<ThemeNotifier, ThemePreference>(
  (ref) => ThemeNotifier(),
);
