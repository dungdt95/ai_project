import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/activity_tracker.dart';
import '../services/import_service.dart';
import '../services/system_channel.dart';
import '../services/tts_audio_handler.dart';
import 'dao/book_dao.dart';
import 'dao/bookmark_dao.dart';
import 'dao/stats_dao.dart';
import 'database/app_database.dart';
import 'repositories/library_repository.dart';
import 'repositories/stats_repository.dart';

/// Các provider dưới đây được ghi đè trong `main()` bằng đối tượng đã tạo sẵn.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('databaseProvider chưa được ghi đè trong main().');
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('sharedPreferencesProvider chưa được ghi đè trong main().');
});

final ttsHandlerProvider = Provider<StoryAudioHandler>((ref) {
  throw StateError('ttsHandlerProvider chưa được ghi đè trong main().');
});

final activityTrackerProvider = Provider<ActivityTracker>((ref) {
  throw StateError('activityTrackerProvider chưa được ghi đè trong main().');
});

final systemChannelProvider = Provider<SystemChannel>((ref) {
  throw StateError('systemChannelProvider chưa được ghi đè trong main().');
});

final bookDaoProvider = Provider<BookDao>(
  (ref) => BookDao(ref.watch(databaseProvider)),
);
final bookmarkDaoProvider = Provider<BookmarkDao>(
  (ref) => BookmarkDao(ref.watch(databaseProvider)),
);
final statsDaoProvider = Provider<StatsDao>(
  (ref) => StatsDao(ref.watch(databaseProvider)),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    ref.watch(bookDaoProvider),
    ref.watch(bookmarkDaoProvider),
  ),
);

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.watch(statsDaoProvider)),
);

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.watch(libraryRepositoryProvider)),
);
