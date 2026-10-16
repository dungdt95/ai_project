import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/constants.dart';
import '../../database/database_helper.dart';
import '../../models/location.dart';
import '../../providers/app_state.dart';
import '../../services/backup_service.dart';
import '../locations/location_form_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Địa điểm'),
          const SizedBox(height: 8),
          ...app.locations.map((loc) => _locationTile(context, loc, app)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openForm(context, null, app),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Thêm địa điểm'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          _sectionHeader('Sao lưu & Khôi phục'),
          const SizedBox(height: 4),
          const Text(
            'File backup (.zip) bao gồm toàn bộ địa điểm, phòng, khách, hóa đơn và ảnh QR.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _backupDb(context),
            icon: const Icon(Icons.cloud_download),
            label: const Text('Xuất file backup (.zip)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _restoreDb(context),
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Khôi phục từ file backup'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _resetDb(context),
            icon: const Icon(Icons.restart_alt, color: Colors.red),
            label: const Text('Reset dữ liệu',
                style: TextStyle(color: Colors.red)),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
                '${AppConstants.appName} • v${AppConstants.appVersion}',
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(title,
      style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: AppColors.textPrimary));

  Widget _locationTile(
      BuildContext context, Location loc, AppState app) {
    final isActive = loc.id == app.currentLocationId;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isActive
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isActive ? AppColors.primary : Colors.grey.shade200,
          child: Icon(Icons.location_on,
              color: isActive ? Colors.white : AppColors.textSecondary,
              size: 20),
        ),
        title: Text(loc.name,
            style: TextStyle(
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal)),
        subtitle: loc.address != null ? Text(loc.address!) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              const Chip(
                label: Text('Đang dùng',
                    style: TextStyle(fontSize: 11, color: AppColors.primary)),
                backgroundColor: Color(0xFFE3F2FD),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _openForm(context, loc, app),
            ),
          ],
        ),
        onTap: () async {
          await app.switchLocation(loc.id!);
        },
      ),
    );
  }

  Future<void> _openForm(
      BuildContext context, Location? loc, AppState app) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LocationFormScreen(location: loc),
    ));
    // reloadLocations đã được gọi trong LocationFormScreen._save/_delete
  }

  Future<void> _backupDb(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final zipPath = await BackupService.createBackup();
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(zipPath)],
          text: 'Backup quản lý nhà trọ');
    } catch (e) {
      if (context.mounted) _showSnack(context, 'Lỗi backup: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreDb(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Khôi phục dữ liệu'),
        content: const Text(
            'Toàn bộ dữ liệu hiện tại sẽ bị GHI ĐÈ bằng dữ liệu trong file backup. '
            'Hành động này không thể hoàn tác. Tiếp tục?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Khôi phục',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    setState(() => _busy = true);
    try {
      await BackupService.restoreBackup(path);
      if (!context.mounted) return;
      await context.read<AppState>().loadAll();
      if (context.mounted) {
        _showSnack(context, 'Đã khôi phục dữ liệu thành công.');
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, 'Lỗi khôi phục: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetDb(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa toàn bộ dữ liệu'),
        content: const Text(
            'Hành động này sẽ xóa tất cả địa điểm, phòng, khách thuê, hóa đơn. Không thể khôi phục.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Xóa hết', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await DatabaseHelper.instance.resetDatabase();
    if (!context.mounted) return;
    _showSnack(context,
        'Đã reset. Vui lòng khởi động lại app để load lại dữ liệu mẫu.');
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
