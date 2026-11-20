import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/drive/drive_link.dart';
import '../../domain/drive/drive_models.dart';
import '../../domain/models/book.dart';
import '../../services/drive_sync_service.dart';
import '../library/library_provider.dart';
import 'drive_provider.dart';

/// Giao diện nhập/đồng bộ từ Google Drive.
class DriveUi {
  const DriveUi._();

  /// Hỏi liên kết thư mục rồi nhập (có hộp thoại tiến độ, hủy được).
  static Future<void> importFromLink(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final input = await showDialog<String>(
      context: context,
      builder: (_) => const _LinkDialog(),
    );
    if (input == null || !context.mounted) return;
    final folderId = DriveLink.parseFolderId(input);
    if (folderId == null) {
      _snack(context, 'Liên kết hoặc ID thư mục Drive không hợp lệ.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<(int, int)>((0, 0));
    final cancel = CancelToken();
    final dialog = _showProgress(context, progress, cancel);
    try {
      final report = await ref
          .read(driveSyncServiceProvider)
          .importFolder(
            folderId,
            cancel: cancel,
            onProgress: (d, t) => progress.value = (d, t),
          );
      ref.read(driveUpdatesProvider.notifier).markImported(report.bookId);
      await ref.read(libraryProvider.notifier).refresh();
      _show(messenger, _importMessage(report));
    } on DriveCancelledException {
      _show(messenger, 'Đã hủy nhập từ Drive.');
    } on DriveException catch (e) {
      _show(messenger, e.message);
    } catch (e) {
      _show(messenger, 'Nhập từ Drive thất bại: $e');
    } finally {
      await dialog();
      progress.dispose();
    }
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

  static String _importMessage(DriveSyncReport r) {
    if (!r.isNewBook) return syncMessage(r);
    final failed = r.failed > 0
        ? ' (${r.failed} chương tải lỗi, bấm "Cập nhật từ Drive" để thử lại)'
        : '';
    return 'Đã nhập truyện từ Drive: ${r.added} chương$failed.';
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

  static void _snack(BuildContext context, String text) =>
      _show(ScaffoldMessenger.of(context), text);

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

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nhập từ Google Drive'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'Dán liên kết hoặc ID thư mục',
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          const SizedBox(height: 12),
          Text(
            'Thư mục cần chia sẻ "Bất kỳ ai có đường liên kết". Mỗi tệp .md/.txt '
            'hoặc Google Docs là một chương (tên dạng "Chương 1: ...").',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _c.text),
          child: const Text('Tải về'),
        ),
      ],
    );
  }
}
