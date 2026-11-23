import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'content_repository.dart';
import 'models.dart';

/// Lỗi cài gói có thông điệp tiếng Việt hiển thị được cho phụ huynh.
class PackException implements Exception {
  PackException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cài / gỡ gói chủ đề (.bvpack / .zip) vào `<packsRoot>/<topicId>`. Thuần Dart, dùng chung cho
/// nạp thủ công và đồng bộ Google Drive.
class PackInstaller {
  PackInstaller(this.packsRoot, {this.maxUncompressedBytes = 600 * 1024 * 1024});

  final Directory packsRoot;
  final int maxUncompressedBytes;

  static final _safeId = RegExp(r'^[a-z0-9_]+$');

  static bool isSafeTopicId(String id) => _safeId.hasMatch(id);

  bool isInstalled(String topicId) =>
      isSafeTopicId(topicId) && File('${packsRoot.path}/$topicId/topic.json').existsSync();

  /// Chuẩn hoá đường dẫn trong zip; trả null nếu không an toàn (zip-slip).
  static String? safeEntryPath(String raw) {
    final p = raw.replaceAll(r'\', '/');
    if (p.isEmpty || p.startsWith('/') || p.contains('\u0000')) return null;
    if (RegExp(r'^[A-Za-z]:').hasMatch(p)) return null;
    final parts = p.split('/');
    for (final seg in parts) {
      if (seg == '..') return null;
    }
    final cleaned = parts.where((s) => s.isNotEmpty && s != '.').toList();
    if (cleaned.isEmpty) return null;
    return cleaned.join('/');
  }

  /// Cài gói từ [bytes]. Trả về chủ đề đã cài. Ném [PackException] nếu gói không hợp lệ.
  Future<Topic> install(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw PackException('File không phải gói .bvpack/.zip hợp lệ.');
    }

    // 1) Chuẩn hoá + kiểm tra đường dẫn từng mục.
    final entries = <String, ArchiveFile>{};
    var total = 0;
    for (final f in archive) {
      if (!f.isFile) {
        if (f.name.isNotEmpty && safeEntryPath(f.name) == null) {
          throw PackException('Gói chứa đường dẫn không an toàn: ${f.name}');
        }
        continue;
      }
      final path = safeEntryPath(f.name);
      if (path == null) throw PackException('Gói chứa đường dẫn không an toàn: ${f.name}');
      if (path.startsWith('__MACOSX/') || path.split('/').last == '.DS_Store') continue;
      total += f.size;
      if (total > maxUncompressedBytes) throw PackException('Gói quá lớn.');
      entries[path] = f;
    }

    // 2) Tìm topic.json ở gốc, hoặc trong đúng một thư mục bọc ngoài.
    var prefix = '';
    if (!entries.containsKey('topic.json')) {
      final roots = entries.keys.map((k) => k.split('/').first).toSet();
      if (roots.length == 1 && entries.containsKey('${roots.first}/topic.json')) {
        prefix = '${roots.first}/';
      } else {
        throw PackException('Gói không có file topic.json ở thư mục gốc.');
      }
    }

    // 3) Đọc + kiểm tra chủ đề.
    final Topic topic;
    try {
      final json = jsonDecode(utf8.decode(entries['${prefix}topic.json']!.content as List<int>)) as Map<String, dynamic>;
      topic = Topic.fromJson(json);
    } catch (e) {
      throw PackException('topic.json không đọc được: $e');
    }
    if (!isSafeTopicId(topic.id)) {
      throw PackException('Mã chủ đề không hợp lệ: "${topic.id}" (chỉ gồm a-z, 0-9, _).');
    }
    final errors = validateTopic(topic);
    if (errors.isNotEmpty) {
      throw PackException('Chủ đề có lỗi cấu trúc: ${errors.take(3).join('; ')}');
    }

    // 4) Giải nén vào thư mục tạm cùng volume rồi thay thế bản cũ.
    if (!await packsRoot.exists()) await packsRoot.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final tmp = Directory('${packsRoot.path}/.tmp_${topic.id}_$stamp');
    final target = Directory('${packsRoot.path}/${topic.id}');
    final backup = Directory('${packsRoot.path}/.old_${topic.id}_$stamp');
    try {
      await tmp.create(recursive: true);
      for (final e in entries.entries) {
        if (!e.key.startsWith(prefix)) continue;
        final rel = e.key.substring(prefix.length);
        final out = File('${tmp.path}/$rel');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(e.value.content as List<int>);
      }
      var hadOld = false;
      if (await target.exists()) {
        await target.rename(backup.path);
        hadOld = true;
      }
      try {
        await tmp.rename(target.path);
      } catch (_) {
        if (hadOld) await backup.rename(target.path);
        rethrow;
      }
      if (hadOld) await backup.delete(recursive: true);
    } on PackException {
      rethrow;
    } catch (e) {
      throw PackException('Không ghi được gói vào bộ nhớ: $e');
    } finally {
      if (await tmp.exists()) {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      }
    }
    return Topic.fromJson(
      jsonDecode(await File('${target.path}/topic.json').readAsString()) as Map<String, dynamic>,
      baseDir: target.path,
    );
  }

  /// Gỡ gói đã cài. Trả true nếu có thư mục bị xoá.
  Future<bool> uninstall(String topicId) async {
    if (!isSafeTopicId(topicId)) return false;
    final dir = Directory('${packsRoot.path}/$topicId');
    if (!await dir.exists()) return false;
    await dir.delete(recursive: true);
    return true;
  }
}
