import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/backup/backup_service.dart';
import '../../data/models/bank_account.dart';
import '../../data/models/notification_app.dart';
import '../invoices/invoices_controller.dart';
import '../items/items_controller.dart';
import '../notifications/notification_logs_screen.dart';
import '../notifications/widgets/simulate_notification_dialog.dart';
import '../reports/reports_controller.dart';
import 'bank_accounts_controller.dart';
import 'notification_apps_controller.dart';
import 'widgets/bank_account_form_dialog.dart';
import 'widgets/notification_app_edit_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BankAccountsController>().load();
      context.read<NotificationAppsController>().load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh permission status after returning from the system
    // notification-access settings screen — this screen stays alive inside
    // an IndexedStack so initState only runs once and wouldn't otherwise
    // pick up the change.
    if (state == AppLifecycleState.resumed) {
      context.read<NotificationAppsController>().refreshPermissionStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankController = context.watch<BankAccountsController>();
    final notifController = context.watch<NotificationAppsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: RefreshIndicator(
        onRefresh: () async {
          await bankController.load();
          await notifController.load();
        },
        child: ListView(
          children: [
            _sectionHeader('Tài khoản ngân hàng (để tạo QR)'),
            if (bankController.isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (bankController.accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chưa có tài khoản ngân hàng nào. Bấm + để thêm.'),
              )
            else
              ...bankController.accounts.map(
                (account) => ListTile(
                  leading: Icon(
                    account.isDefault
                        ? Icons.check_circle
                        : Icons.account_balance_outlined,
                    color: account.isDefault ? Colors.teal : null,
                  ),
                  title: Text('${account.bankName} • ${account.accountNumber}'),
                  subtitle: Text(account.accountName),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        _onBankMenuSelected(value, account, bankController),
                    itemBuilder: (context) => [
                      if (!account.isDefault)
                        const PopupMenuItem(
                            value: 'default', child: Text('Đặt làm mặc định')),
                      const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                      const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                    ],
                  ),
                ),
              ),
            const Divider(height: 24),
            _sectionHeader('Tự xác nhận thanh toán qua thông báo'),
            _buildPermissionTile(notifController),
            _buildBatteryOptimizationTile(notifController),
            if (notifController.isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...notifController.apps.map(
                (app) => ListTile(
                  title: Text(app.label),
                  subtitle: Text(app.packageName),
                  leading: Switch(
                    value: app.enabled,
                    onChanged: (_) => notifController.toggleEnabled(app),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editPackageName(app, notifController),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Lịch sử thông báo'),
              subtitle:
                  const Text('Xem nhật ký để debug khi không tự xác nhận được'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const NotificationLogsScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Giả lập thông báo (debug)'),
              subtitle: const Text(
                  'Kiểm tra logic khớp hóa đơn không cần app ngân hàng thật'),
              onTap: () => showDialog(
                context: context,
                builder: (_) =>
                    SimulateNotificationDialog(apps: notifController.apps),
              ),
            ),
            const Divider(height: 24),
            _sectionHeader('Dữ liệu'),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Xuất dữ liệu (backup)'),
              subtitle: const Text(
                'App lưu dữ liệu hoàn toàn trên máy — mất máy/gỡ app là mất hết. '
                'Lưu file ra Drive/email/... để phòng ngừa.',
              ),
              onTap: _exportData,
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Khôi phục dữ liệu'),
              subtitle: const Text(
                  'Chọn file backup — sẽ thay thế toàn bộ dữ liệu hiện tại'),
              onTap: _restoreData,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addAccount(bankController),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
      ),
    );
  }

  Widget _buildPermissionTile(NotificationAppsController controller) {
    return ListTile(
      leading: Icon(
        controller.permissionGranted
            ? Icons.notifications_active
            : Icons.notifications_off,
        color: controller.permissionGranted ? Colors.green : Colors.red,
      ),
      title: Text(
        controller.permissionGranted
            ? 'Đã cấp quyền đọc thông báo'
            : 'Chưa cấp quyền đọc thông báo',
      ),
      subtitle: controller.permissionGranted
          ? null
          : const Text('Cần cấp quyền để app tự xác nhận thanh toán'),
      trailing: controller.permissionGranted
          ? null
          : FilledButton(
              onPressed: () async {
                await controller.openSettings();
              },
              child: const Text('Cấp quyền'),
            ),
    );
  }

  Widget _buildBatteryOptimizationTile(NotificationAppsController controller) {
    if (controller.batteryOptimizationIgnored) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.battery_alert, color: Colors.orange),
      title: const Text('Chưa tắt tối ưu hóa pin cho app'),
      subtitle: const Text(
        'Một số máy (Xiaomi, Oppo, Samsung...) có thể tự tắt app chạy nền, '
        'làm mất khả năng tự xác nhận thanh toán',
      ),
      trailing: FilledButton(
        onPressed: () => controller.requestIgnoreBatteryOptimizations(),
        child: const Text('Tắt'),
      ),
    );
  }

  Future<void> _editPackageName(
      NotificationApp app, NotificationAppsController controller) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => NotificationAppEditDialog(app: app),
    );
    if (result != null && result.isNotEmpty) {
      await controller.updatePackageName(app, result);
    }
  }

  Future<void> _onBankMenuSelected(
    String value,
    BankAccount account,
    BankAccountsController controller,
  ) async {
    switch (value) {
      case 'default':
        await controller.setDefault(account.id!);
        break;
      case 'edit':
        await _editAccount(account, controller);
        break;
      case 'delete':
        await _deleteAccount(account, controller);
        break;
    }
  }

  Future<void> _addAccount(BankAccountsController controller) async {
    final result = await showDialog<BankAccount>(
      context: context,
      builder: (_) => const BankAccountFormDialog(),
    );
    if (result != null) {
      await controller.addAccount(result);
    }
  }

  Future<void> _editAccount(
      BankAccount account, BankAccountsController controller) async {
    final result = await showDialog<BankAccount>(
      context: context,
      builder: (_) => BankAccountFormDialog(existing: account),
    );
    if (result != null) {
      await controller.updateAccount(result);
    }
  }

  Future<void> _deleteAccount(
      BankAccount account, BankAccountsController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tài khoản'),
        content: Text(
            'Xóa tài khoản ${account.bankName} • ${account.accountNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && account.id != null) {
      await controller.deleteAccount(account.id!);
    }
  }

  Future<void> _exportData() async {
    try {
      await BackupService.shareBackup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Xuất dữ liệu thất bại: $e')));
    }
  }

  Future<void> _restoreData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục dữ liệu'),
        content: const Text(
          'Toàn bộ dữ liệu hiện tại (mặt hàng, hóa đơn, tài khoản...) sẽ bị THAY THẾ '
          'bằng dữ liệu trong file backup đã chọn. Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final itemsController = context.read<ItemsController>();
    final invoicesController = context.read<InvoicesController>();
    final bankController = context.read<BankAccountsController>();
    final notifController = context.read<NotificationAppsController>();
    final reportsController = context.read<ReportsController>();

    try {
      final restored = await BackupService.restoreFromPickedFile();
      if (!mounted || !restored) return;

      await itemsController.load();
      await invoicesController.load();
      await bankController.load();
      await notifController.load();
      await reportsController.load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khôi phục dữ liệu thành công')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Khôi phục thất bại: $e')));
    }
  }
}
