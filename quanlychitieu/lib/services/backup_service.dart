import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../data/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

class BackupService {
  static Future<void> exportBackup() async {
    final db = await AppDatabase().database;
    final backup = <String, dynamic>{};
    const tables = [
      'categories', 'transactions', 'banks', 'bank_deposits',
      'borrowers', 'loans', 'loan_payments', 'settings', 'calendar_notes'
    ];
    for (final table in tables) {
      backup[table] = await db.query(table);
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final file = File('${dir.path}/backup_$timestamp.json');
    await file.writeAsString(jsonEncode(backup));
    await Share.shareXFiles([XFile(file.path)], text: 'Backup Quản lý Thu Chi');
  }

  static Future<String> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return 'Không có file được chọn';

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final backup = jsonDecode(content) as Map<String, dynamic>;

    final db = await AppDatabase().database;
    await db.transaction((txn) async {
      const ordered = [
        'calendar_notes', 'loan_payments', 'loans', 'borrowers',
        'bank_deposits', 'banks', 'transactions', 'categories', 'settings'
      ];
      for (final table in ordered) {
        await txn.delete(table);
      }
      const insertOrder = [
        'categories', 'banks', 'borrowers', 'transactions',
        'bank_deposits', 'loans', 'loan_payments', 'settings', 'calendar_notes'
      ];
      for (final table in insertOrder) {
        final rows = backup[table] as List<dynamic>? ?? [];
        for (final row in rows) {
          await txn.insert(table, Map<String, dynamic>.from(row as Map),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
    return 'Khôi phục thành công!';
  }
}
