import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
