import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/dao/book_dao.dart';
import 'data/dao/bookmark_dao.dart';
import 'data/dao/stats_dao.dart';
import 'data/data_providers.dart';
import 'data/database/app_database.dart';
import 'data/repositories/library_repository.dart';
import 'data/repositories/stats_repository.dart';
import 'services/activity_tracker.dart';
import 'services/system_channel.dart';
import 'services/tts_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mở DB và prefs song song để rút ngắn thời gian trước khung hình đầu.
  final opened = await Future.wait<Object>([
    AppDatabase.open(),
    SharedPreferences.getInstance(),
  ]);
  final database = opened[0] as AppDatabase;
  final prefs = opened[1] as SharedPreferences;
  final systemChannel = SystemChannel();

  final library = LibraryRepository(BookDao(database), BookmarkDao(database));
  final tracker = ActivityTracker(StatsRepository(StatsDao(database)))..start();

  // Tạo handler ngay (nhẹ) nhưng CHƯA đăng ký với audio_service: bind dịch vụ
  // nền + MediaSession chặn luồng chính vài giây, nên để sau khung hình đầu.
  final handler = StoryAudioHandler(
    library: library,
    activity: tracker.accumulator,
    onKeepAwake: (on) => unawaited(systemChannel.setKeepAwake(on)),
  );
  handler.configure(
    speed: prefs.getDouble('ttsSpeed'),
    pitch: prefs.getDouble('ttsPitch'),
    voiceName: prefs.getString('ttsVoiceName'),
    voiceLocale: prefs.getString('ttsVoiceLocale'),
    engine: prefs.getString('ttsEngine'),
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ttsHandlerProvider.overrideWithValue(handler),
        activityTrackerProvider.overrideWithValue(tracker),
        systemChannelProvider.overrideWithValue(systemChannel),
      ],
      child: const DocTruyenApp(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(_initAudioService(handler)),
  );
}

/// Đăng ký handler với audio_service (thông báo media, màn hình khóa) sau khi
/// UI đã lên hình. Handler vẫn đọc được trước đó; trạng thái được đồng bộ khi
/// dịch vụ sẵn sàng.
Future<void> _initAudioService(StoryAudioHandler handler) async {
  try {
    await AudioService.init<StoryAudioHandler>(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.dtd.doctruyen.audio',
        androidNotificationChannelName: 'Đọc truyện (TTS)',
        androidNotificationIcon: 'drawable/ic_stat_audio',
      ),
    );
  } catch (e) {
    debugPrint('AudioService.init lỗi: $e');
  }
}
