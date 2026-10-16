import 'package:flutter/material.dart';

class ThemePreset {
  final String key;
  final String label;
  final Color seedColor;
  const ThemePreset({
    required this.key,
    required this.label,
    required this.seedColor,
  });
}

const List<ThemePreset> kThemePresets = [
  ThemePreset(key: 'blue', label: 'Xanh dương', seedColor: Color(0xFF1565C0)),
  ThemePreset(key: 'green', label: 'Xanh lá', seedColor: Color(0xFF2E7D32)),
  ThemePreset(key: 'purple', label: 'Tím', seedColor: Color(0xFF6A1B9A)),
  ThemePreset(key: 'orange', label: 'Cam', seedColor: Color(0xFFEF6C00)),
  ThemePreset(key: 'red', label: 'Đỏ', seedColor: Color(0xFFC62828)),
  ThemePreset(key: 'teal', label: 'Ngọc', seedColor: Color(0xFF00695C)),
  ThemePreset(key: 'pink', label: 'Hồng', seedColor: Color(0xFFC2185B)),
  ThemePreset(key: 'indigo', label: 'Chàm', seedColor: Color(0xFF283593)),
];

ThemePreset getPresetByKey(String key) =>
    kThemePresets.firstWhere((p) => p.key == key, orElse: () => kThemePresets.first);

ThemeData buildAppTheme(Color seed, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : null,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
    ),
    cardTheme: CardTheme(
      elevation: isDark ? 0 : 2,
      color: isDark ? const Color(0xFF1E1E1E) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: MaterialStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 11,
          fontWeight: states.contains(MaterialState.selected)
              ? FontWeight.w600
              : FontWeight.normal,
        );
      }),
    ),
  );
}
