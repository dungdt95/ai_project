import 'package:flutter/material.dart';

import '../../../data/models/notification_app.dart';

class NotificationAppEditDialog extends StatefulWidget {
  final NotificationApp app;

  const NotificationAppEditDialog({super.key, required this.app});

  @override
  State<NotificationAppEditDialog> createState() =>
      _NotificationAppEditDialogState();
}

class _NotificationAppEditDialogState extends State<NotificationAppEditDialog> {
  late TextEditingController _packageCtrl;

  @override
  void initState() {
    super.initState();
    _packageCtrl = TextEditingController(text: widget.app.packageName);
  }

  @override
  void dispose() {
    _packageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mã package ${widget.app.label}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nếu app không tự xác nhận được thanh toán, mã package của ngân hàng '
            'có thể đã đổi. Vào Cài đặt > Ứng dụng trên điện thoại để tìm mã chính xác.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _packageCtrl,
            decoration: const InputDecoration(labelText: 'Package name'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_packageCtrl.text.trim()),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
