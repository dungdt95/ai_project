import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/data_providers.dart';
import '../../domain/models/reading_settings.dart';

class SettingsNotifier extends Notifier<ReadingSettings> {
  late SharedPreferences _prefs;

  @override
  ReadingSettings build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    const d = ReadingSettings();
    return ReadingSettings(
      fontSize: _prefs.getDouble('fontSize') ?? d.fontSize,
      font: ReaderFont.values.firstWhere(
        (f) => f.name == _prefs.getString('font'),
        orElse: () => d.font,
      ),
      lineHeight: _prefs.getDouble('lineHeight') ?? d.lineHeight,
      margin: _prefs.getDouble('margin') ?? d.margin,
      theme: ReaderThemeId.values.firstWhere(
        (t) => t.name == _prefs.getString('theme'),
        orElse: () => d.theme,
      ),
      keepScreenOn: _prefs.getBool('keepScreenOn') ?? d.keepScreenOn,
      pageMode: _prefs.getBool('pageMode') ?? d.pageMode,
      ttsSpeed: _prefs.getDouble('ttsSpeed') ?? d.ttsSpeed,
      ttsPitch: _prefs.getDouble('ttsPitch') ?? d.ttsPitch,
      ttsVoiceName: _prefs.getString('ttsVoiceName'),
      ttsVoiceLocale: _prefs.getString('ttsVoiceLocale'),
      ttsEngine: _prefs.getString('ttsEngine'),
    );
  }

  void update(ReadingSettings s) {
    state = s;
    _prefs.setDouble('fontSize', s.fontSize);
    _prefs.setString('font', s.font.name);
    _prefs.setDouble('lineHeight', s.lineHeight);
    _prefs.setDouble('margin', s.margin);
    _prefs.setString('theme', s.theme.name);
    _prefs.setBool('keepScreenOn', s.keepScreenOn);
    _prefs.setBool('pageMode', s.pageMode);
    _prefs.setDouble('ttsSpeed', s.ttsSpeed);
    _prefs.setDouble('ttsPitch', s.ttsPitch);
    final vn = s.ttsVoiceName;
    if (vn != null) _prefs.setString('ttsVoiceName', vn);
    final vl = s.ttsVoiceLocale;
    if (vl != null) _prefs.setString('ttsVoiceLocale', vl);
    final en = s.ttsEngine;
    if (en != null) _prefs.setString('ttsEngine', en);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, ReadingSettings>(
  SettingsNotifier.new,
);
