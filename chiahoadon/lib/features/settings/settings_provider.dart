import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/result.dart';
import '../../data/data_providers.dart';
import '../../domain/models/enums.dart';
import '../../services/backup_service.dart';
import '../bills/bills_provider.dart';
import '../members/members_provider.dart';

/// Toàn bộ cài đặt của app, đọc một lần từ bảng `app_settings`.
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.roundingUnit,
    required this.roundingMode,
    this.lastBackupAt,
    this.appLockEnabled = false,
  });

  static const AppSettings defaults = AppSettings(
    themeMode: ThemeMode.system,
    roundingUnit: AppConstants.defaultRoundingUnit,
    roundingMode: RoundingMode.up,
  );

  final ThemeMode themeMode;
  final int roundingUnit;
  final RoundingMode roundingMode;
  final DateTime? lastBackupAt;

  /// Đòi xác thực khi mở app (Phase 11).
  final bool appLockEnabled;

  /// Đã quá lâu chưa sao lưu hay chưa (SPEC FR-8.6).
  bool get needsBackupReminder => BackupService.shouldRemind(lastBackupAt);

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? roundingUnit,
    RoundingMode? roundingMode,
    DateTime? lastBackupAt,
    bool? appLockEnabled,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    roundingUnit: roundingUnit ?? this.roundingUnit,
    roundingMode: roundingMode ?? this.roundingMode,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    appLockEnabled: appLockEnabled ?? this.appLockEnabled,
  );
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final dao = ref.watch(settingsDaoProvider);

    return AppSettings(
      themeMode: _parseThemeMode(await dao.themeMode()),
      roundingUnit: await dao.roundingUnit(),
      roundingMode: await dao.roundingMode(),
      lastBackupAt: await dao.lastBackupAt(),
      appLockEnabled: await dao.appLockEnabled(),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(settingsDaoProvider).setThemeMode(mode.name);
    ref.invalidateSelf();
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await ref.read(settingsDaoProvider).setAppLockEnabled(enabled);
    ref.invalidateSelf();
  }

  /// Đơn vị làm tròn mặc định cho hóa đơn **mới** (SPEC FR-5.7).
  ///
  /// Hóa đơn đã lưu giữ nguyên đơn vị của nó, nên đổi cài đặt không làm thay
  /// đổi con số của bất kỳ hóa đơn cũ nào (SPEC §5.2).
  Future<void> setRoundingUnit(int unit) async {
    await ref.read(settingsDaoProvider).setRoundingUnit(unit);
    ref
      ..invalidate(defaultRoundingUnitProvider)
      ..invalidateSelf();
  }

  Future<void> setRoundingMode(RoundingMode mode) async {
    await ref.read(settingsDaoProvider).setRoundingMode(mode);
    ref.invalidateSelf();
  }

  Future<void> markBackedUp() async {
    await ref.read(settingsDaoProvider).markBackedUp();
    ref.invalidateSelf();
  }

  static ThemeMode _parseThemeMode(String value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(
      SettingsNotifier.new,
    );

/// Chế độ sáng/tối đang dùng. Tách riêng để `MaterialApp` không phải chờ cả
/// gói cài đặt nạp xong mới vẽ được.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).value?.themeMode ?? ThemeMode.system;
});

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);

/// Sao lưu và phục hồi, kèm việc nạp lại mọi thứ sau khi dữ liệu thay đổi.
class BackupNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<Result<String>> export() async {
    final result = await ref.read(backupServiceProvider).export();
    if (result.isOk) {
      await ref.read(settingsProvider.notifier).markBackedUp();
    }
    return result;
  }

  Future<Result<BackupInfo>> restore(String json) async {
    final result = await ref.read(backupServiceProvider).restore(json);
    if (result.isOk) _reloadEverything();
    return result;
  }

  Future<Result<void>> resetAll() async {
    final result = await ref.read(backupServiceProvider).resetAll();
    if (result.isOk) _reloadEverything();
    return result;
  }

  /// Phục hồi và xóa sạch đều thay toàn bộ dữ liệu, nên mọi provider đọc DB
  /// phải nạp lại — nếu không, màn hình vẫn hiện dữ liệu đã không còn tồn tại.
  void _reloadEverything() {
    ref
      ..invalidate(membersProvider)
      ..invalidate(selfMemberProvider)
      ..invalidate(categoriesProvider)
      ..invalidate(billListProvider)
      ..invalidate(settingsProvider)
      ..invalidate(defaultRoundingUnitProvider);
  }
}

final backupProvider =
    NotifierProvider<BackupNotifier, void>(BackupNotifier.new);
