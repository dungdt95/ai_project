import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/app_database.dart';

/// The app is local-only (see SPEC.md) — losing the device or reinstalling
/// means losing all data unless the user explicitly backs up. This wraps
/// that single most important piece of disaster recovery: copy the SQLite
/// file out via the OS share sheet, and copy a chosen file back in.
class BackupService {
  static Future<void> shareBackup() async {
    final db = AppDatabase.instance;
    await db.close();

    final dbFile = File(await db.path);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final tempDir = await getTemporaryDirectory();
    final backupFile =
        await dbFile.copy('${tempDir.path}/minishop_backup_$timestamp.db');

    await Share.shareXFiles(
      [XFile(backupFile.path)],
      text: 'Sao lưu dữ liệu Mini Shop ($timestamp)',
    );
  }

  /// Returns true if the user picked a file and restore succeeded.
  static Future<bool> restoreFromPickedFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    final pickedPath = result?.files.single.path;
    if (pickedPath == null) return false;

    final db = AppDatabase.instance;
    await db.close();
    await File(pickedPath).copy(await db.path);
    return true;
  }
}
