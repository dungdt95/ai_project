import 'package:flutter/material.dart';

/// Kết quả hộp thoại "Lưu thay đổi?".
enum UnsavedAction { save, discard, cancel }

Future<UnsavedAction> showUnsavedDialog(BuildContext context, String fileName) async {
  final result = await showDialog<UnsavedAction>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Lưu thay đổi?'),
      content: Text('"$fileName" có thay đổi chưa được lưu.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, UnsavedAction.cancel),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, UnsavedAction.discard),
          child: const Text('Không lưu'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, UnsavedAction.save),
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  return result ?? UnsavedAction.cancel;
}

Future<void> showErrorDialog(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}
