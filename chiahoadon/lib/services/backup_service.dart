import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/db_constants.dart';
import '../core/utils/result.dart';
import '../data/database/app_database.dart';

/// Sao lưu và phục hồi toàn bộ dữ liệu (SPEC FR-8.4, FR-8.5).
///
/// App chạy hoàn toàn offline nên **không có bản sao nào trên cloud**. Mất máy
/// là mất sạch, vì vậy đây là chức năng bắt buộc chứ không phải tùy chọn
/// (PLAN §2, rủi ro R3).
///
/// Tệp sao lưu là JSON chứ không phải bản sao tệp `.db`: JSON đọc được bằng
/// mắt, không phụ thuộc phiên bản SQLite, và kiểm tra được trước khi ghi đè.
class BackupService {
  const BackupService(this._database);

  /// Định dạng tệp sao lưu. Tăng khi cấu trúc JSON đổi, độc lập với
  /// `schema_version` của cơ sở dữ liệu.
  static const int formatVersion = 1;

  /// Thứ tự khôi phục: bảng cha trước bảng con, để khóa ngoại luôn trỏ tới
  /// bản ghi đã tồn tại.
  static const List<String> _tableOrder = [
    Tables.categories,
    Tables.members,
    Tables.memberGroups,
    Tables.groupMembers,
    Tables.bills,
    Tables.billPayers,
    Tables.billParticipants,
    Tables.billItems,
    Tables.billItemParticipants,
    Tables.payments,
    Tables.billTemplates,
    // Thêm từ bản sao lưu v3. Bản sao lưu cũ không có khóa này, và vòng lặp
    // phục hồi bỏ qua bảng thiếu — nên không phải tăng `formatVersion`.
    Tables.itemPresets,
    Tables.appSettings,
  ];

  final AppDatabase _database;

  /// Xuất toàn bộ dữ liệu ra chuỗi JSON.
  Future<Result<String>> export() => Result.guard(() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _tableOrder) {
      tables[table] = await _database.db.query(table);
    }

    return const JsonEncoder.withIndent('  ').convert({
      'format_version': formatVersion,
      'schema_version': AppConstants.dbVersion,
      'app': AppConstants.appName,
      'exported_at': DateTime.now().toIso8601String(),
      'counts': {
        for (final entry in tables.entries) entry.key: entry.value.length,
      },
      'tables': tables,
    });
  });

  /// Đọc tệp sao lưu và cho biết bên trong có gì, **trước khi** ghi đè.
  ///
  /// Người dùng cần thấy "tệp này có 12 hóa đơn, 5 thành viên, sao lưu ngày
  /// 03/10" rồi mới quyết định, chứ không bấm phục hồi trong vô minh.
  static Result<BackupInfo> inspect(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, Object?>) {
        return const Err(
          AppError.validation('Tệp không đúng định dạng sao lưu.'),
        );
      }

      final version = decoded['format_version'];
      if (version is! int) {
        return const Err(
          AppError.validation('Tệp không phải bản sao lưu của app này.'),
        );
      }
      if (version > formatVersion) {
        return Err(
          AppError.validation(
            'Tệp được tạo bởi phiên bản app mới hơn (định dạng v$version). '
            'Hãy cập nhật app rồi thử lại.',
          ),
        );
      }

      final tables = decoded['tables'];
      if (tables is! Map<String, Object?>) {
        return const Err(
          AppError.validation('Tệp sao lưu thiếu phần dữ liệu.'),
        );
      }

      int count(String table) => (tables[table] as List<Object?>?)?.length ?? 0;

      return Ok(
        BackupInfo(
          formatVersion: version,
          schemaVersion: decoded['schema_version'] as int? ?? 1,
          exportedAt: DateTime.tryParse(
            decoded['exported_at'] as String? ?? '',
          ),
          memberCount: count(Tables.members),
          billCount: count(Tables.bills),
          groupCount: count(Tables.memberGroups),
          paymentCount: count(Tables.payments),
        ),
      );
    } on FormatException {
      return const Err(
        AppError.validation('Tệp không đọc được — có thể đã hỏng.'),
      );
    }
  }

  /// Phục hồi từ tệp sao lưu, **ghi đè** toàn bộ dữ liệu hiện có.
  ///
  /// Chạy trong một giao dịch: hoặc phục hồi trọn vẹn, hoặc không đổi gì. Nửa
  /// vời là trường hợp tệ nhất — người dùng mất dữ liệu cũ mà cũng không có dữ
  /// liệu mới.
  Future<Result<BackupInfo>> restore(String json) async {
    final info = inspect(json);
    if (info case Err<BackupInfo>(:final error)) return Err(error);

    return Result.guard(() async {
      final decoded = jsonDecode(json) as Map<String, Object?>;
      final tables = decoded['tables']! as Map<String, Object?>;

      await _database.transaction((txn) async {
        // Xóa con trước cha, rồi chèn lại theo thứ tự ngược lại.
        for (final table in Tables.deletionOrder) {
          await txn.delete(table);
        }
        await txn.delete(Tables.appSettings);

        for (final table in _tableOrder) {
          final rows = tables[table] as List<Object?>?;
          if (rows == null) continue;

          for (final row in rows) {
            if (row is! Map<String, Object?>) continue;
            await txn.insert(
              table,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });

      return info.valueOrNull!;
    });
  }

  /// Xóa sạch dữ liệu rồi nạp lại dữ liệu khởi tạo (SPEC FR-9.6).
  Future<Result<void>> resetAll() => Result.guard(_database.resetAll);

  /// Tên tệp gợi ý khi lưu, có kèm ngày để không ghi đè bản cũ.
  static String suggestedFileName([DateTime? now]) {
    final date = now ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'chiahoadon-${date.year}${two(date.month)}${two(date.day)}'
        '-${two(date.hour)}${two(date.minute)}.json';
  }

  /// Số ngày kể từ lần sao lưu gần nhất, `null` nếu chưa sao lưu bao giờ.
  static int? daysSince(DateTime? lastBackup, [DateTime? now]) {
    if (lastBackup == null) return null;
    return (now ?? DateTime.now()).difference(lastBackup).inDays;
  }

  /// Có nên nhắc người dùng sao lưu hay không (SPEC FR-8.6).
  static bool shouldRemind(DateTime? lastBackup, [DateTime? now]) {
    final days = daysSince(lastBackup, now);
    return days == null || days >= AppConstants.backupReminderDays;
  }
}

/// Tóm tắt nội dung một tệp sao lưu.
class BackupInfo {
  const BackupInfo({
    required this.formatVersion,
    required this.schemaVersion,
    required this.memberCount,
    required this.billCount,
    required this.groupCount,
    required this.paymentCount,
    this.exportedAt,
  });

  final int formatVersion;
  final int schemaVersion;
  final DateTime? exportedAt;
  final int memberCount;
  final int billCount;
  final int groupCount;
  final int paymentCount;

  /// Mô tả ngắn để hiện trong hộp thoại xác nhận.
  String get summary =>
      '$billCount hóa đơn · $memberCount thành viên · $groupCount nhóm';

  /// Tệp rỗng gần như luôn là chọn nhầm tệp.
  bool get isEmpty => billCount == 0 && memberCount <= 1;
}
