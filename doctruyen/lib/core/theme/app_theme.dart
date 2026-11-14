import 'package:flutter/material.dart';

import '../../domain/models/reading_settings.dart';

/// Màu nền/chữ của từng giao diện đọc.
class ReaderPalette {
  const ReaderPalette({
    required this.background,
    required this.text,
    required this.muted,
    required this.highlight,
    required this.sentenceHighlight,
    required this.brightness,
  });

  final Color background;
  final Color text;
  final Color muted;
  final Color highlight;
  final Color sentenceHighlight;
  final Brightness brightness;

  static ReaderPalette of(ReaderThemeId id) => switch (id) {
    ReaderThemeId.light => const ReaderPalette(
      background: Color(0xFFFAFAFA),
      text: Color(0xFF1F1F1F),
      muted: Color(0xFF757575),
      highlight: Color(0x1A0D9488),
      sentenceHighlight: Color(0x66FFD54F),
      brightness: Brightness.light,
    ),
    ReaderThemeId.dark => const ReaderPalette(
      background: Color(0xFF1E1E1E),
      text: Color(0xFFD6D6D6),
      muted: Color(0xFF8A8A8A),
      highlight: Color(0x2214B8A6),
      sentenceHighlight: Color(0x66B58900),
      brightness: Brightness.dark,
    ),
    ReaderThemeId.sepia => const ReaderPalette(
      background: Color(0xFFF4ECD8),
      text: Color(0xFF5B4636),
      muted: Color(0xFF8B7355),
      highlight: Color(0x22B58900),
      sentenceHighlight: Color(0x66E0A458),
      brightness: Brightness.light,
    ),
    ReaderThemeId.black => const ReaderPalette(
      background: Color(0xFF000000),
      text: Color(0xFFBDBDBD),
      muted: Color(0xFF6E6E6E),
      highlight: Color(0x2214B8A6),
      sentenceHighlight: Color(0x66806000),
      brightness: Brightness.dark,
    ),
  };
}

class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF0D9488);

  static ThemeData build(Brightness brightness) => ThemeData(
    useMaterial3: true,
    fontFamily: 'BeVietnamPro',
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
  );
}
