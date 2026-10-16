import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme Material 3 cho chế độ sáng và tối (PLAN §5.4).
class AppTheme {
  const AppTheme._();

  static const String fontFamily = 'BeVietnamPro';

  /// Thang spacing 4dp.
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;

  /// Bán kính bo góc.
  static const double radiusCard = 16;
  static const double radiusButton = 12;
  static const double radiusChip = 20;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: s16,
          vertical: s12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusChip),
        ),
        // Chip chưa chọn có viền, chip đã chọn thì không.
        //
        // Nền mặc định của chip chưa chọn gần như trùng với nền trang, nên bỏ
        // viền đi là nó trông y hệt chữ thường — người dùng không biết chạm
        // được. Chip đã chọn có nền đậm rồi nên viền chỉ làm rối.
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: s16, vertical: s4),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

/// Kiểu chữ riêng cho số tiền.
///
/// Dùng `fontFeatures: tnum` để các chữ số có cùng bề rộng — cột tiền trong
/// danh sách khi đó thẳng hàng, không nhảy khi số thay đổi.
class MoneyTextStyle {
  const MoneyTextStyle._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static const TextStyle small = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
  );

  static const TextStyle medium = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  static const TextStyle large = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );
}
