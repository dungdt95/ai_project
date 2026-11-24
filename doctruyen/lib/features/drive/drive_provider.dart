import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/data_providers.dart';
import '../../domain/drive/drive_models.dart';
import '../../domain/models/book.dart';
import '../../services/drive_sync_service.dart';
import '../../services/http_drive_source.dart';
import '../library/library_provider.dart';

final driveSourceProvider = Provider<DriveSource>((ref) {
  final source = HttpDriveSource();
  ref.onDispose(source.close);
  return source;
});

final driveSyncServiceProvider = Provider<DriveSyncService>(
  (ref) => DriveSyncService(
    ref.watch(driveSourceProvider),
    ref.watch(bookDaoProvider),
  ),
);

/// Khoảng tối thiểu giữa hai lần kiểm tra nền của cùng một truyện.
const Duration kDriveCheckInterval = Duration(minutes: 10);

/// Truyện Drive đang có cập nhật chưa áp dụng (bookId -> kết quả kiểm tra).
class DriveUpdatesNotifier extends Notifier<Map<int, DriveCheck>> {
  final Map<int, DateTime> _lastCheck = {};
  final Set<int> _running = {};

  @override
  Map<int, DriveCheck> build() => const {};

  /// Kiểm tra nền một truyện; lỗi mạng bị bỏ qua (không chặn việc đọc).
  Future<DriveCheck?> check(Book book, {bool force = false}) async {
    if (!book.isDrive || _running.contains(book.id)) return state[book.id];
    final last = _lastCheck[book.id];
    final now = DateTime.now();
    if (!force && last != null && now.difference(last) < kDriveCheckInterval) {
      return state[book.id];
    }
    _running.add(book.id);
    _lastCheck[book.id] = now;
    try {
      final c = await ref.read(driveSyncServiceProvider).check(book);
      final next = {...state};
      if (c.hasUpdates) {
        next[book.id] = c;
      } else {
        next.remove(book.id);
      }
      state = next;
      return c;
    } catch (_) {
      // Mất mạng, bị giới hạn...: giữ nguyên, thử lại sau.
      _lastCheck.remove(book.id);
      return null;
    } finally {
      _running.remove(book.id);
    }
  }

  Future<void> checkAll({bool force = false}) async {
    final books = await ref.read(bookDaoProvider).listDriveBooks();
    await Future.wait(books.map((b) => check(b, force: force)));
  }

  /// Đồng bộ ngay; xóa dấu "có cập nhật" và làm mới thư viện.
  Future<DriveSyncReport> sync(
    Book book, {
    DriveProgress? onProgress,
    CancelToken? cancel,
  }) async {
    final report = await ref
        .read(driveSyncServiceProvider)
        .syncBook(book, onProgress: onProgress, cancel: cancel);
    _lastCheck[book.id] = DateTime.now();
    state = {...state}..remove(book.id);
    await ref.read(libraryProvider.notifier).refresh();
    return report;
  }

  void markImported(int bookId) {
    _lastCheck[bookId] = DateTime.now();
    state = {...state}..remove(bookId);
  }
}

final driveUpdatesProvider =
    NotifierProvider<DriveUpdatesNotifier, Map<int, DriveCheck>>(
      DriveUpdatesNotifier.new,
    );

/// Trạng thái đồng bộ thư mục truyện chung.
class LibrarySyncState {
  const LibrarySyncState({
    this.running = false,
    this.title = '',
    this.index = 0,
    this.total = 0,
    this.done = 0,
    this.chapters = 0,
  });

  final bool running;

  /// Truyện đang xử lý.
  final String title;
  final int index;
  final int total;
  final int done;
  final int chapters;

  /// Tiến độ 0..1, `null` khi chưa biết (đang đọc danh sách).
  double? get fraction {
    if (total == 0) return null;
    final inBook = chapters == 0 ? 0.0 : done / chapters;
    return ((index + inBook) / total).clamp(0.0, 1.0);
  }
}

/// Đồng bộ thư viện với thư mục Drive chung: khi mở app (tự động) hoặc khi
/// bấm "Cập nhật". Truyện người dùng đã xóa được nhớ lại để không tải lại.
class LibrarySyncNotifier extends Notifier<LibrarySyncState> {
  static const String _ignoredKey = 'driveIgnoredFolders';

  DateTime? _lastSuccess;

  @override
  LibrarySyncState build() => const LibrarySyncState();

  Set<String> get ignoredFolders => {
    ...?ref.read(sharedPreferencesProvider).getStringList(_ignoredKey),
  };

  /// Không tự tải lại thư mục truyện này nữa (người dùng đã xóa truyện).
  Future<void> ignore(String folderId) async {
    if (folderId.isEmpty) return;
    await ref.read(sharedPreferencesProvider).setStringList(_ignoredKey, [
      ...{...ignoredFolders, folderId},
    ]);
  }

  /// Bỏ danh sách truyện đã ẩn để lần đồng bộ sau tải lại.
  Future<void> restoreIgnored() =>
      ref.read(sharedPreferencesProvider).remove(_ignoredKey);

  /// Đồng bộ. [manual] = người dùng bấm (kiểm tra kỹ mọi chương, luôn chạy);
  /// tự động thì bỏ qua nếu vừa đồng bộ xong trong [AppConstants.librarySyncInterval].
  ///
  /// Trả `null` nếu không chạy (đang chạy dở hoặc chưa đến lúc).
  Future<LibrarySyncReport?> sync({
    required bool manual,
    CancelToken? cancel,
  }) async {
    if (state.running) return null;
    final last = _lastSuccess;
    if (!manual &&
        last != null &&
        DateTime.now().difference(last) < AppConstants.librarySyncInterval) {
      return null;
    }
    state = const LibrarySyncState(running: true);
    var lastIndex = -1;
    try {
      final report = await ref
          .read(driveSyncServiceProvider)
          .syncLibrary(
            AppConstants.driveLibraryFolderId,
            ignoredFolderIds: ignoredFolders,
            thorough: manual,
            cancel: cancel,
            onProgress: (title, i, total, done, chapters) {
              // Sang truyện mới: hiện ngay truyện vừa tải xong trong thư viện.
              if (i != lastIndex && lastIndex >= 0) {
                unawaited(ref.read(libraryProvider.notifier).refresh());
              }
              lastIndex = i;
              state = LibrarySyncState(
                running: true,
                title: title,
                index: i,
                total: total,
                done: done,
                chapters: chapters,
              );
            },
          );
      _lastSuccess = DateTime.now();
      final updates = ref.read(driveUpdatesProvider.notifier);
      report.syncedBookIds.forEach(updates.markImported);
      return report;
    } finally {
      state = const LibrarySyncState();
      await ref.read(libraryProvider.notifier).refresh();
    }
  }
}

final librarySyncProvider =
    NotifierProvider<LibrarySyncNotifier, LibrarySyncState>(
      LibrarySyncNotifier.new,
    );
