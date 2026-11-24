import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/drive/drive_models.dart';
import '../../domain/models/book.dart';
import '../../services/drive_sync_service.dart';
import 'drive_provider.dart';

/// Giao diện đồng bộ từ Google Drive.
class DriveUi {
  const DriveUi._();

  /// Đồng bộ thư viện với thư mục Drive chung (không chặn màn hình; tiến độ
  /// hiện ở thanh trên thư viện).
  ///
  /// [manual] = người dùng bấm "Cập nhật": luôn báo kết quả, kể cả lỗi.
  /// Tự động (mở app): chỉ báo khi có truyện/chương mới, lỗi mạng thì im lặng.
  static Future<void> syncLibrary(
    ScaffoldMessengerState messenger,
    WidgetRef ref, {
    required bool manual,
  }) async {
    try {
      final report = await ref
          .read(librarySyncProvider.notifier)
          .sync(manual: manual);
      if (report == null) {
        if (manual) _show(messenger, 'Đang cập nhật thư viện...');
        return;
      }
      if (manual || !report.nothingChanged) {
        _show(messenger, libraryMessage(report));
      }
    } on DriveCancelledException {
      if (manual) _show(messenger, 'Đã hủy cập nhật.');
    } on DriveException catch (e) {
      if (manual) _show(messenger, e.message);
    } catch (e) {
      if (manual) _show(messenger, 'Cập nhật thất bại: $e');
    }
  }

  static String libraryMessage(LibrarySyncReport r) {
    final parts = <String>[
      if (r.newBooks.length == 1) 'Thêm truyện mới "${r.newBooks.first}"',
      if (r.newBooks.length > 1) 'Thêm ${r.newBooks.length} truyện mới',
      if (r.addedChapters > 0) '${r.addedChapters} chương mới',
      if (r.updatedChapters > 0) 'cập nhật ${r.updatedChapters} chương',
    ];
    final problems = <String>[
      if (r.failedChapters > 0) '${r.failedChapters} chương tải lỗi',
      if (r.failedBooks.isNotEmpty)
        '${r.failedBooks.length} truyện lỗi (${r.failedBooks.keys.join(', ')})',
    ];
    final head = parts.isEmpty
        ? 'Thư viện đã là bản mới nhất'
        : parts.join(', ');
    return problems.isEmpty
        ? '$head.'
        : '$head. ${problems.join(', ')}, sẽ thử lại lần sau.';
  }

  /// "Cập nhật từ Drive": đồng bộ ngay và báo kết quả.
  static Future<DriveSyncReport?> syncNow(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<(int, int)>((0, 0));
    final cancel = CancelToken();
    final dialog = _showProgress(context, progress, cancel);
    try {
      final report = await ref
          .read(driveUpdatesProvider.notifier)
          .sync(
            book,
            cancel: cancel,
            onProgress: (d, t) => progress.value = (d, t),
          );
      _show(messenger, syncMessage(report));
      return report;
    } on DriveCancelledException {
      _show(messenger, 'Đã hủy cập nhật.');
    } on DriveException catch (e) {
      _show(messenger, e.message);
    } catch (e) {
      _show(messenger, 'Cập nhật thất bại: $e');
    } finally {
      await dialog();
      progress.dispose();
    }
    return null;
  }

  static String syncMessage(DriveSyncReport r) {
    if (r.nothingChanged) {
      return r.failed > 0
          ? 'Không có chương mới (${r.failed} chương tải lỗi, sẽ thử lại).'
          : 'Không có chương mới, truyện đã là bản mới nhất.';
    }
    final failed = r.failed > 0 ? ' (${r.failed} chương tải lỗi)' : '';
    return 'Đã thêm ${r.added} chương mới, cập nhật ${r.updated} chương$failed.';
  }

  /// Thông báo "Có N chương mới" không chặn, kèm nút Cập nhật.
  static void showUpdateAvailable(
    ScaffoldMessengerState messenger,
    DriveCheck check, {
    required VoidCallback onUpdate,
  }) {
    final parts = <String>[
      if (check.newChapters > 0) 'Có ${check.newChapters} chương mới',
      if (check.changedChapters > 0)
        '${check.changedChapters} chương đã chỉnh sửa',
    ];
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(parts.join(', ')),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(label: 'Cập nhật', onPressed: onUpdate),
        ),
      );
  }

  static void _show(ScaffoldMessengerState m, String text) => m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Mở hộp thoại tiến độ; trả hàm đóng nó.
  static Future<void> Function() _showProgress(
    BuildContext context,
    ValueNotifier<(int, int)> progress,
    CancelToken cancel,
  ) {
    final navigator = Navigator.of(context, rootNavigator: true);
    var open = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Google Drive'),
            content: ValueListenableBuilder<(int, int)>(
              valueListenable: progress,
              builder: (_, p, _) {
                final (done, total) = p;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total == 0
                          ? 'Đang đọc danh sách thư mục...'
                          : 'Đang tải $done/$total...',
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: total == 0 ? null : done / total,
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(onPressed: cancel.cancel, child: const Text('Hủy')),
            ],
          ),
        ),
      ).whenComplete(() => open = false),
    );
    return () async {
      if (open) navigator.pop();
    };
  }
}
