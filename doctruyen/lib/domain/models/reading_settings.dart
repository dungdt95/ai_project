enum ReaderThemeId { light, dark, sepia, black }

enum ReaderFont {
  beVietnam('BeVietnamPro', 'Be Vietnam Pro'),
  serif('serif', 'Có chân (Noto Serif)'),
  sans('sans-serif', 'Không chân (Roboto)');

  const ReaderFont(this.family, this.label);

  final String family;
  final String label;
}

/// Cài đặt đọc + TTS, lưu trong SharedPreferences.
class ReadingSettings {
  const ReadingSettings({
    this.fontSize = 19,
    this.font = ReaderFont.beVietnam,
    this.lineHeight = 1.7,
    this.margin = 20,
    this.theme = ReaderThemeId.light,
    this.keepScreenOn = true,
    this.pageMode = false,
    this.ttsSpeed = 1.0,
    this.ttsPitch = 1.0,
    this.ttsVoiceName,
    this.ttsVoiceLocale,
    this.ttsEngine,
  });

  static const double minFont = 14;
  static const double maxFont = 34;

  final double fontSize;
  final ReaderFont font;
  final double lineHeight;
  final double margin;
  final ReaderThemeId theme;
  final bool keepScreenOn;

  /// `true` = lật trang, `false` = cuộn dọc.
  final bool pageMode;
  final double ttsSpeed;
  final double ttsPitch;
  final String? ttsVoiceName;
  final String? ttsVoiceLocale;
  final String? ttsEngine;

  ReadingSettings copyWith({
    double? fontSize,
    ReaderFont? font,
    double? lineHeight,
    double? margin,
    ReaderThemeId? theme,
    bool? keepScreenOn,
    bool? pageMode,
    double? ttsSpeed,
    double? ttsPitch,
    String? ttsVoiceName,
    String? ttsVoiceLocale,
    String? ttsEngine,
  }) => ReadingSettings(
    fontSize: fontSize ?? this.fontSize,
    font: font ?? this.font,
    lineHeight: lineHeight ?? this.lineHeight,
    margin: margin ?? this.margin,
    theme: theme ?? this.theme,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    pageMode: pageMode ?? this.pageMode,
    ttsSpeed: ttsSpeed ?? this.ttsSpeed,
    ttsPitch: ttsPitch ?? this.ttsPitch,
    ttsVoiceName: ttsVoiceName ?? this.ttsVoiceName,
    ttsVoiceLocale: ttsVoiceLocale ?? this.ttsVoiceLocale,
    ttsEngine: ttsEngine ?? this.ttsEngine,
  );
}
