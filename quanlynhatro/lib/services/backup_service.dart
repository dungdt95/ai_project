import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';

/// Backup/restore toàn bộ dữ liệu app vào một file .zip gồm:
///  - quanlynhatro.db (SQLite database: địa điểm, phòng, khách, hóa đơn...)
///  - qr/<tên ảnh> (ảnh QR thanh toán của từng địa điểm)
class BackupService {
  static const String dbEntryName = 'quanlynhatro.db';
  static const String qrFolder = 'qr';

  /// Tạo file zip backup, trả về đường dẫn file zip đã ghi.
  static Future<String> createBackup() async {
    final dbPath = await DatabaseHelper.instance.getDbPath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('Không tìm thấy file database');
    }

    final archive = Archive();

    // 1. File database
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(ArchiveFile(dbEntryName, dbBytes.length, dbBytes));

    // 2. Ảnh QR của các địa điểm (lưu theo basename, tránh trùng)
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'locations',
      columns: ['qr_image_path'],
      where: 'qr_image_path IS NOT NULL',
    );
    final seen = <String>{};
    for (final r in rows) {
      final path = r['qr_image_path'] as String?;
      if (path == null) continue;
      final f = File(path);
      if (!await f.exists()) continue;
      final base = p.basename(path);
      if (!seen.add(base)) continue;
      final bytes = await f.readAsBytes();
      archive.addFile(ArchiveFile('$qrFolder/$base', bytes.length, bytes));
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('Không tạo được file backup');
    }

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final zipPath = p.join(dir.path, 'backup_$ts.zip');
    await File(zipPath).writeAsBytes(zipBytes, flush: true);
    return zipPath;
  }

  /// Khôi phục dữ liệu từ file zip backup. Ghi đè toàn bộ DB hiện tại.
  static Future<void> restoreBackup(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? dbEntry;
    final qrEntries = <ArchiveFile>[];
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name.startsWith('$qrFolder/')) {
        qrEntries.add(entry);
      } else if (p.basename(name) == dbEntryName) {
        dbEntry = entry;
      }
    }
    if (dbEntry == null) {
      throw Exception('File backup không hợp lệ (thiếu database)');
    }

    final docsDir = await getApplicationDocumentsDirectory();

    // 1. Đóng DB hiện tại để ghi đè file
    await DatabaseHelper.instance.closeDb();

    // 2. Ghi đè file database
    final dbPath = await DatabaseHelper.instance.getDbPath();
    await File(dbPath)
        .writeAsBytes(dbEntry.content as List<int>, flush: true);

    // 3. Giải nén ảnh QR vào thư mục documents
    final restoredQr = <String>{};
    for (final entry in qrEntries) {
      final base = p.basename(entry.name);
      if (base.isEmpty) continue;
      await File(p.join(docsDir.path, base))
          .writeAsBytes(entry.content as List<int>, flush: true);
      restoredQr.add(base);
    }

    // 4. Mở lại DB và cập nhật qr_image_path theo đường dẫn máy hiện tại
    final db = await DatabaseHelper.instance.db;
    final locs = await db.query(
      'locations',
      columns: ['id', 'qr_image_path'],
      where: 'qr_image_path IS NOT NULL',
    );
    for (final loc in locs) {
      final oldPath = loc['qr_image_path'] as String?;
      if (oldPath == null) continue;
      final base = p.basename(oldPath);
      if (restoredQr.contains(base)) {
        // Trỏ lại đúng file vừa giải nén trên máy này
        await db.update(
          'locations',
          {'qr_image_path': p.join(docsDir.path, base)},
          where: 'id = ?',
          whereArgs: [loc['id']],
        );
      } else {
        // Ảnh không có trong backup → null để fallback QR mặc định
        await db.update(
          'locations',
          {'qr_image_path': null},
          where: 'id = ?',
          whereArgs: [loc['id']],
        );
      }
    }
  }
}
