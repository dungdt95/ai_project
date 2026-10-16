import 'package:flutter/material.dart';

import '../../../core/notification/notification_handler.dart';
import '../../../data/models/notification_app.dart';
import '../../../data/models/notification_log.dart';

/// Debug-only tool: runs the exact same parse → match → confirm pipeline
/// the real NotificationListenerService uses, but fed with text typed in
/// by hand. Useful for verifying the matching logic end-to-end without
/// needing a real bank app installed (which this dev environment doesn't
/// have) — the native listener itself still needs testing on a real device
/// with the real banking apps.
class SimulateNotificationDialog extends StatefulWidget {
  final List<NotificationApp> apps;

  const SimulateNotificationDialog({super.key, required this.apps});

  @override
  State<SimulateNotificationDialog> createState() =>
      _SimulateNotificationDialogState();
}

class _SimulateNotificationDialogState
    extends State<SimulateNotificationDialog> {
  late String _packageName;
  final _textCtrl = TextEditingController(
    text:
        'Số dư TK của bạn vừa +5,000VND. ND: chuyen tien HD000002. SD: 1,000,000VND',
  );
  bool _isRunning = false;
  NotificationLog? _result;

  @override
  void initState() {
    super.initState();
    _packageName = widget.apps.isNotEmpty ? widget.apps.first.packageName : '';
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _isRunning = true);
    final result = await NotificationHandler.handle(
      packageName: _packageName,
      rawText: _textCtrl.text,
    );
    setState(() {
      _isRunning = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Giả lập thông báo (debug)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _packageName.isEmpty ? null : _packageName,
              decoration: const InputDecoration(labelText: 'App nguồn'),
              items: widget.apps
                  .map((a) => DropdownMenuItem(
                      value: a.packageName, child: Text(a.label)))
                  .toList(),
              onChanged: (v) => setState(() => _packageName = v ?? ''),
            ),
            TextField(
              controller: _textCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Nội dung thông báo giả lập'),
            ),
            const SizedBox(height: 12),
            if (_result != null) _buildResult(_result!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: _isRunning ? null : _run,
          child: _isRunning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Chạy thử'),
        ),
      ],
    );
  }

  Widget _buildResult(NotificationLog result) {
    final (label, color) = switch (result.matchStatus) {
      NotificationLog.matchAuto => (
          'Đã tự xác nhận hóa đơn #${result.matchedInvoiceId}',
          Colors.green
        ),
      NotificationLog.matchAmbiguous => (
          'Khớp nhiều hóa đơn — cần xác nhận tay',
          Colors.orange
        ),
      _ => ('Không khớp hóa đơn nào', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          Text('Số tiền nhận diện: ${result.parsedAmount ?? '—'}'),
          Text('Mã hóa đơn nhận diện: ${result.parsedCode ?? '—'}'),
        ],
      ),
    );
  }
}
