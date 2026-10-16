import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/result.dart';

/// Màn hình trống khi danh sách chưa có dữ liệu.
///
/// Luôn nói rõ **bước tiếp theo** chứ không chỉ thông báo "chưa có gì" — người
/// dùng mở app lần đầu phải biết ngay cần bấm vào đâu.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    super.key,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: AppTheme.s16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppTheme.s8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.s24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.s24,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Màn hình lỗi, có nút thử lại.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, super.key, this.onRetry});

  factory ErrorView.fromError(Object error, {VoidCallback? onRetry}) =>
      ErrorView(
        message: error is AppError ? error.message : 'Đã xảy ra lỗi.',
        onRetry: onRetry,
      );

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppTheme.s16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.s24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.s24,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại xác nhận.
///
/// Trả `true` khi người dùng đồng ý, `null` khi họ bấm ra ngoài.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    required this.message,
    super.key,
    this.confirmLabel = 'Đồng ý',
    this.cancelLabel = 'Hủy',
    this.isDestructive = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Đồng ý',
    String cancelLabel = 'Hủy',
    bool isDestructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return confirmed ?? false;
  }

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  /// Thao tác không hoàn tác được thì nút xác nhận hiện màu đỏ.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  minimumSize: const Size(0, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Thông báo ngắn ở đáy màn hình.
class AppSnackBar {
  const AppSnackBar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.paid, Icons.check_circle_outline);

  static void error(BuildContext context, String message) => _show(
    context,
    message,
    Theme.of(context).colorScheme.error,
    Icons.error_outline,
  );

  static void info(BuildContext context, String message) =>
      _show(context, message, null, Icons.info_outline);

  /// Thông báo kèm nút hoàn tác — dùng sau khi xóa (SPEC FR-3.14).
  static void undoable(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          action: SnackBarAction(label: 'Hoàn tác', onPressed: onUndo),
        ),
      );
  }

  static void _show(
    BuildContext context,
    String message,
    Color? accent,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: accent ?? Colors.white, size: 20),
              const SizedBox(width: AppTheme.s12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
