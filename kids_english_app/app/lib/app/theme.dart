import 'package:flutter/material.dart';

class AppColors {
  static const cream = Color(0xFFFFF8E7);
  static const sky = Color(0xFFE3F4FF);
  static const orange = Color(0xFFFF9F1C);
  static const teal = Color(0xFF2EC4B6);
  static const pink = Color(0xFFFF6B9A);
  static const yellow = Color(0xFFFFD23F);
  static const ink = Color(0xFF3D2C2E);
  static const correct = Color(0xFF4CAF50);
}

/// Kích thước vùng chạm tối thiểu cho Khu của Bé.
const double kKidTouch = 80;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.orange, surface: AppColors.cream);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: Typography.blackMountainView.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(kKidTouch, kKidTouch * 0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    ),
  );
}
