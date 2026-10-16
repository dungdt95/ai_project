import 'package:flutter/material.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = SettingsRepository();
  int _reminderDays = 3;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo.getReminderDays().then((v) => setState(() { _reminderDays = v; _loading = false; }));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
          const _SectionHeader('Giao diện'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme & màu sắc'),
            subtitle: const Text('Chọn màu chủ đạo và chế độ sáng/tối'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/theme'),
          ),
          const Divider(),
          const _SectionHeader('Tài khoản & Danh mục'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Danh mục thu chi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/categories'),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Danh sách ngân hàng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/banks'),
          ),
          ListTile(
            leading: const Icon(Icons.people_outlined),
            title: const Text('Người vay'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/borrowers'),
          ),
          const Divider(),
          const _SectionHeader('Thông báo'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Nhắc trước đáo hạn'),
            subtitle: Text('$_reminderDays ngày trước'),
            trailing: DropdownButton<int>(
              value: _reminderDays,
              underline: const SizedBox(),
              items: [1, 2, 3, 5, 7, 14].map((d) => DropdownMenuItem(value: d, child: Text('$d ngày'))).toList(),
              onChanged: (v) async {
                if (v != null) {
                  await _repo.set('due_reminder_days', v.toString());
                  setState(() => _reminderDays = v);
                }
              },
            ),
          ),
          const Divider(),
          const _SectionHeader('Dữ liệu'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Xuất dữ liệu (Backup)'),
            subtitle: const Text('Lưu file JSON và chia sẻ'),
            onTap: () async {
              try {
                await BackupService.exportBackup();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xuất dữ liệu thành công')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi: $e')));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Nhập dữ liệu (Restore)'),
            subtitle: const Text('Khôi phục từ file JSON'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Xác nhận khôi phục'),
                  content: const Text('Thao tác này sẽ xóa toàn bộ dữ liệu hiện tại và thay bằng dữ liệu từ file backup. Tiếp tục?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tiếp tục')),
                  ],
                ),
              );
              if (ok == true && mounted) {
                final msg = await BackupService.importBackup();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
          ),
          const Divider(),
          const _SectionHeader('Thông tin'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Phiên bản'),
            trailing: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
      );
}
