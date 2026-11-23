import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

// Đóng gói một chủ đề thành .bvpack và tạo/cập nhật index.json để đưa lên Google Drive.
//
// Cách dùng (chạy trong thư mục app/):
//   dart run tools/pack_topic.dart <topicId> [--version N] [--out thư_mục] [--assets thư_mục_assets]
//
// - Đọc assets/content/topics/<topicId>.json, gom mọi đường dẫn media (images/..., audio/...) có thật
//   dưới assets/, kèm sticker (images/stickers/<sticker>.png), ghi <out>/<topicId>.bvpack.
// - Gói có topic.json ở gốc và các thư mục images/, audio/ giống hệt assets/.
// - Ghi/gộp <out>/index.json. Không truyền --version: gói mới = 1, gói đã có trong index = version cũ + 1.
void main(List<String> args) {
  String? topicId;
  int? version;
  var out = 'build/packs';
  var assets = 'assets';
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--version':
        version = int.tryParse(args[++i]);
      case '--out':
        out = args[++i];
      case '--assets':
        assets = args[++i];
      default:
        topicId = args[i];
    }
  }
  if (topicId == null) {
    stderr.writeln('Cách dùng: dart run tools/pack_topic.dart <topicId> [--version N] [--out dir]');
    exit(64);
  }

  final topicFile = File('$assets/content/topics/$topicId.json');
  if (!topicFile.existsSync()) {
    stderr.writeln('Không tìm thấy ${topicFile.path}');
    exit(66);
  }
  final topicText = topicFile.readAsStringSync();
  final topic = jsonDecode(topicText) as Map<String, dynamic>;
  if (topic['id'] != topicId) {
    stderr.writeln('Cảnh báo: id trong file (${topic['id']}) khác tên file ($topicId).');
  }

  final media = <String>{};
  void walk(Object? v, String? key) {
    if (v is Map) {
      v.forEach((k, x) => walk(x, k as String));
    } else if (v is List) {
      for (final x in v) {
        walk(x, key);
      }
    } else if (v is String) {
      if (key == 'sticker') {
        media.add('images/stickers/$v.png');
      } else if (v.startsWith('images/') || v.startsWith('audio/')) {
        media.add(v);
      }
    }
  }

  walk(topic, null);

  final archive = Archive();
  final topicBytes = utf8.encode(topicText);
  archive.addFile(ArchiveFile('topic.json', topicBytes.length, topicBytes));
  var missing = 0;
  for (final p in media.toList()..sort()) {
    final f = File('$assets/$p');
    if (!f.existsSync()) {
      stderr.writeln('Cảnh báo: thiếu file $p');
      missing++;
      continue;
    }
    final bytes = f.readAsBytesSync();
    archive.addFile(ArchiveFile(p, bytes.length, bytes));
  }

  final outDir = Directory(out)..createSync(recursive: true);
  final packName = '$topicId.bvpack';
  final packFile = File('${outDir.path}/$packName');
  packFile.writeAsBytesSync(ZipEncoder().encode(archive));

  // index.json
  final indexFile = File('${outDir.path}/index.json');
  var packs = <Map<String, dynamic>>[];
  if (indexFile.existsSync()) {
    try {
      final j = jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
      packs = [for (final p in (j['packs'] as List)) Map<String, dynamic>.from(p as Map)];
    } catch (_) {
      stderr.writeln('Cảnh báo: index.json cũ không đọc được, sẽ tạo lại.');
    }
  }
  final idx = packs.indexWhere((p) => p['id'] == topicId);
  final oldVersion = idx >= 0 ? (packs[idx]['version'] as num?)?.toInt() ?? 0 : 0;
  final newVersion = version ?? (idx >= 0 ? oldVersion + 1 : 1);
  final entry = <String, dynamic>{
    'id': topicId,
    'version': newVersion,
    'file': packName,
    'title_en': topic['title_en'],
    'title_vi': topic['title_vi'] ?? '',
    'word_count': (topic['words'] as List).length,
  };
  if (idx >= 0) {
    packs[idx] = entry;
  } else {
    packs.add(entry);
  }
  final index = {'updated_at': DateTime.now().toUtc().toIso8601String(), 'packs': packs};
  indexFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(index));

  stdout.writeln('Đã tạo ${packFile.path} (${packFile.lengthSync()} bytes, ${archive.length} file, $missing thiếu)');
  stdout.writeln('Đã cập nhật ${indexFile.path}: $topicId version $newVersion');
  stdout.writeln('Tải cả hai file lên thư mục Google Drive (ghi đè bản cũ).');
}
