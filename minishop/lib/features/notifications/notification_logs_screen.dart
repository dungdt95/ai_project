import 'package:flutter/material.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/models/notification_log.dart';
import '../../data/repositories/notification_log_repository.dart';

/// Read-only audit trail of incoming bank notifications — lets the shop
/// owner see why a payment did or didn't auto-confirm (e.g. the bank
/// changed its notification wording, see SPEC.md risk notes).
class NotificationLogsScreen extends StatefulWidget {
  const NotificationLogsScreen({super.key});

  @override
  State<NotificationLogsScreen> createState() => _NotificationLogsScreenState();
}

class _NotificationLogsScreenState extends State<NotificationLogsScreen> {
  final _repo = NotificationLogRepository();
  late Future<List<NotificationLog>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getRecent();
  }

  void _reload() {
    setState(() {
      _future = _repo.getRecent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử thông báo'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
      ),
      body: FutureBuilder<List<NotificationLog>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(
                child: Text('Chưa có thông báo nào được ghi nhận.'));
          }
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: _statusIcon(log.matchStatus),
                title: Text(log.sourceApp),
                subtitle: Text(
                  '${log.rawText}\n'
                  'Số tiền: ${log.parsedAmount ?? '—'} · Mã: ${log.parsedCode ?? '—'}',
                ),
                isThreeLine: true,
                trailing: Text(formatDateTime(log.receivedAt)),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case NotificationLog.matchAuto:
        return const Icon(Icons.check_circle, color: Colors.green);
      case NotificationLog.matchAmbiguous:
        return const Icon(Icons.help, color: Colors.orange);
      default:
        return const Icon(Icons.remove_circle_outline, color: Colors.grey);
    }
  }
}
