import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/extensions/app_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_feedback.dart';
import '../../data/data_providers.dart';
import '../../domain/models/bill_filter.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/expense_category.dart';
import '../../domain/models/member.dart';
import '../../services/backup_service.dart';
import '../../services/csv_export.dart';
import '../items/item_presets_screen.dart';
import '../members/members_provider.dart';
import '../shell/app_lock_gate.dart';
import 'categories_screen.dart';
import 'settings_provider.dart';

/// S12 — Cài đặt (SPEC FR-9) và S13 — Sao lưu & phục hồi (SPEC FR-8.4, FR-8.5).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Future<void> push(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (context) => const SettingsScreen()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: switch (settings) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => ErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(settingsProvider),
        ),
        AsyncData(:final value) => _Content(settings: value),
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppTheme.s16),
      children: [
        if (settings.needsBackupReminder)
          Card(
            color: AppColors.warningBg,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.s16),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.warningFg,
                  ),
                  const SizedBox(width: AppTheme.s12),
                  Expanded(
                    child: Text(
                      settings.lastBackupAt == null
                          ? 'Bạn chưa sao lưu lần nào. Dữ liệu chỉ nằm trên '
                                'máy này — mất máy là mất sạch.'
                          : 'Lần sao lưu gần nhất đã '
                                '${BackupService.daysSince(settings.lastBackupAt)} '
                                'ngày trước.',
                      style: const TextStyle(color: AppColors.warningFg),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: AppTheme.s8),
        const _SectionTitle('GIAO DIỆN'),
        Card(
          // `RadioGroup` quản lý giá trị chung; từ Flutter 3.32 thì
          // `groupValue`/`onChanged` đặt trên từng `RadioListTile` đã lỗi thời.
          child: RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (value) => value == null
                ? null
                : ref.read(settingsProvider.notifier).setThemeMode(value),
            child: Column(
              children: [
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    value: mode,
                    title: Text(_themeLabel(mode)),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppTheme.s16),
        const _SectionTitle('LÀM TRÒN MẶC ĐỊNH'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Áp dụng cho hóa đơn tạo mới. Hóa đơn đã lưu giữ nguyên '
                  'cách làm tròn của nó.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.s12),
                Wrap(
                  spacing: AppTheme.s8,
                  children: [
                    for (final unit in AppConstants.roundingUnits)
                      ChoiceChip(
                        label: Text(unit == 1 ? 'Từng đồng' : unit.toVnd()),
                        selected: settings.roundingUnit == unit,
                        onSelected: (_) => ref
                            .read(settingsProvider.notifier)
                            .setRoundingUnit(unit),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.s12),
                Wrap(
                  spacing: AppTheme.s8,
                  children: [
                    for (final mode in RoundingMode.values)
                      ChoiceChip(
                        label: Text(mode.label),
                        selected: settings.roundingMode == mode,
                        onSelected: (_) => ref
                            .read(settingsProvider.notifier)
                            .setRoundingMode(mode),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppTheme.s16),
        const _SectionTitle('BẢO MẬT'),
        Card(
          child: SwitchListTile(
            value: settings.appLockEnabled,
            onChanged: (value) => _toggleLock(context, ref, value),
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Khóa ứng dụng'),
            subtitle: const Text(
              'Hỏi vân tay hoặc mã khóa máy khi mở lại app',
            ),
          ),
        ),

        const SizedBox(height: AppTheme.s16),
        const _SectionTitle('DANH MỤC & MÓN'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: const Text('Quản lý danh mục'),
                subtitle: const Text(
                  'Danh mục cũng là tên gợi ý khi tạo hóa đơn',
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => CategoriesScreen.push(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restaurant_menu_outlined),
                title: const Text('Món có sẵn'),
                subtitle: const Text('Đặt sẵn tên và giá để chọn nhanh'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => ItemPresetsScreen.push(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.s16),
        const _SectionTitle('SAO LƯU & PHỤC HỒI'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Sao lưu ra tệp'),
                subtitle: Text(
                  settings.lastBackupAt == null
                      ? 'Chưa sao lưu lần nào'
                      : 'Lần gần nhất: '
                            '${DateFormatter.withTime(settings.lastBackupAt!)}',
                ),
                onTap: () => _export(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Phục hồi từ tệp'),
                subtitle: const Text('Ghi đè toàn bộ dữ liệu hiện có'),
                onTap: () => _restore(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Xuất CSV'),
                subtitle: const Text(
                  'Mở bằng Excel để tự cộng trừ — không phục hồi lại được',
                ),
                onTap: () => _exportCsv(context, ref),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.s16),
        const _SectionTitle('NGUY HIỂM'),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              'Xóa toàn bộ dữ liệu',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('Không hoàn tác được'),
            onTap: () => _reset(context, ref),
          ),
        ),

        const SizedBox(height: AppTheme.s24),
        Center(
          child: Text(
            '${AppConstants.appName} · dữ liệu chỉ lưu trên máy này',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Theo hệ thống',
    ThemeMode.light => 'Sáng',
    ThemeMode.dark => 'Tối',
  };

  /// Xuất JSON ra tệp tạm rồi mở bảng chia sẻ của hệ điều hành.
  ///
  /// Không tự ghi vào thư mục Tải về: Android hiện đại giới hạn truy cập bộ
  /// nhớ ngoài, và để người dùng tự chọn nơi lưu (Drive, Zalo, tệp) thì linh
  /// hoạt hơn mà không cần xin thêm quyền nào.
  /// Xuất toàn bộ hóa đơn ra CSV rồi chia sẻ (SPEC FR-8.3).
  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    // Lấy hết hóa đơn chứ không chỉ trang đang xem: người dùng xuất ra để tổng
    // kết cả năm, một trang 50 dòng thì vô dụng.
    final bills = await ref.read(billRepositoryProvider).getPage(
      const BillFilter(includeDrafts: false),
      limit: 100000,
    );
    if (!context.mounted) return;

    await bills.when(
      ok: (list) async {
        final members = ref.read(membersProvider).value ?? const <Member>[];
        final categories =
            ref.read(categoriesProvider).value ?? const <ExpenseCategory>[];

        final csv = CsvExport.build(
          list,
          members: {for (final member in members) member.id: member},
          categories: {for (final each in categories) each.id: each},
        );

        final dir = await getTemporaryDirectory();
        final file = File(p.join(dir.path, CsvExport.fileName()));
        await file.writeAsString(csv);

        if (!context.mounted) return;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: '${AppConstants.appName} — ${list.length} hóa đơn',
          ),
        );

        if (context.mounted) {
          AppSnackBar.success(context, 'Đã tạo tệp CSV');
        }
      },
      err: (error) async => AppSnackBar.error(context, error.message),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(backupProvider.notifier).export();
    if (!context.mounted) return;

    await result.when(
      ok: (json) async {
        final dir = await getTemporaryDirectory();
        final file = File(
          p.join(dir.path, BackupService.suggestedFileName()),
        );
        await file.writeAsString(json);

        if (!context.mounted) return;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Sao lưu ${AppConstants.appName}',
          ),
        );

        if (context.mounted) {
          AppSnackBar.success(context, 'Đã tạo tệp sao lưu');
        }
      },
      err: (error) async => AppSnackBar.error(context, error.message),
    );
  }

  /// Chọn tệp, xem trước nội dung, rồi mới ghi đè.
  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    // file_picker v13:  là static và trả về danh sách, không còn
    //  hay  nullable như các bản cũ.
    // file_picker v13 đổi API: pickFiles là phương thức tĩnh và trả về một
    // danh sách, không còn FilePicker.platform hay kết quả nullable như bản cũ.
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked.isEmpty ? null : picked.single.path;
    if (path == null || !context.mounted) return;

    final json = await File(path).readAsString();
    if (!context.mounted) return;

    final info = BackupService.inspect(json);
    if (info case Err(:final error)) {
      AppSnackBar.error(context, error.message);
      return;
    }

    final backup = info.valueOrNull!;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Phục hồi từ tệp này?',
      message:
          'Tệp chứa ${backup.summary}'
          '${backup.exportedAt == null ? '' : ', sao lưu ngày '
                '${DateFormatter.short(backup.exportedAt!)}'}.\n\n'
          'Toàn bộ dữ liệu hiện có trên máy sẽ bị thay thế.',
      confirmLabel: 'Phục hồi',
      isDestructive: true,
    );
    if (!context.mounted || !confirmed) return;

    final result = await ref.read(backupProvider.notifier).restore(json);
    if (!context.mounted) return;

    result.when(
      ok: (restored) =>
          AppSnackBar.success(context, 'Đã phục hồi ${restored.summary}'),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xóa toàn bộ dữ liệu?',
      message: 'Mọi hóa đơn, thành viên và nhóm sẽ biến mất vĩnh viễn. '
          'Nếu chưa sao lưu thì không lấy lại được.',
      confirmLabel: 'Xóa hết',
      isDestructive: true,
    );
    if (!context.mounted || !confirmed) return;

    final result = await ref.read(backupProvider.notifier).resetAll();
    if (!context.mounted) return;

    result.when(
      ok: (_) => AppSnackBar.success(context, 'Đã xóa toàn bộ dữ liệu'),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }

  /// Bật/tắt khóa ứng dụng.
  ///
  /// Bật thì phải xác thực được **ngay tại đây** mới lưu: máy chưa đặt vân tay
  /// hay mã khóa màn hình mà vẫn bật thì lần mở sau người dùng sẽ đứng trước
  /// một màn khóa không có cách nào qua.
  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final notifier = ref.read(settingsProvider.notifier);

    if (!enable) {
      await notifier.setAppLockEnabled(false);
      return;
    }

    final authenticator = ref.read(authenticatorProvider);
    if (!await authenticator.isAvailable()) {
      if (!context.mounted) return;
      AppSnackBar.error(
        context,
        'Máy chưa đặt vân tay hoặc mã khóa màn hình.',
      );
      return;
    }

    if (!await authenticator.authenticate()) {
      if (!context.mounted) return;
      AppSnackBar.error(context, 'Chưa xác thực được, khóa vẫn tắt.');
      return;
    }

    // Người dùng vừa xác thực xong ngay trên dòng trên; bắt họ xác thực lại
    // lần nữa chỉ vì khóa vừa bật là vô nghĩa.
    ref.read(appUnlockedProvider.notifier).unlock();

    await notifier.setAppLockEnabled(true);
    if (!context.mounted) return;
    AppSnackBar.success(context, 'Đã bật khóa ứng dụng');
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.s4,
        bottom: AppTheme.s8,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
