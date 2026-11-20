import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/book.dart';
import 'parsed_book.dart';
import 'text_decoder.dart';
import 'txt_importer.dart';

/// Nhập gói truyện .zip gồm `chapters.json` và `chuong/*.md`.
///
/// Thư mục `notes/` (ghi chú của tác giả) và `index.html` bị bỏ qua. Nếu không
/// có `chapters.json`, dùng mọi tệp .md/.txt (trừ `notes/`) theo thứ tự tên.
class ZipImporter {
  const ZipImporter._();

  static ParsedBook parseBytes(List<int> bytes, String fileName) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw const ImportException('Không đọc được tệp ZIP (tệp hỏng?).');
    }
    final files = <String, Uint8List>{};
    for (final f in archive.files) {
      if (!f.isFile) continue;
      files[f.name.replaceAll('\\', '/')] = f.content;
    }
    return fromFiles(files, fileName);
  }

  /// Trường `book` trong chapters.json (nếu có và đọc được).
  static String? manifestBookTitle(Map<String, Uint8List> files) {
    final path = _findManifest(files.keys);
    if (path == null) return null;
    try {
      final json = jsonDecode(TextDecoder.decode(files[path]!));
      final b = json is Map ? json['book'] : null;
      return b is String && b.trim().isNotEmpty ? b.trim() : null;
    } on FormatException {
      return null;
    }
  }

  /// Dựng sách từ các tệp đã có sẵn (tên -> byte); dùng chung cho ZIP và nhập
  /// nhiều tệp rời kèm `chapters.json`.
  static ParsedBook fromFiles(Map<String, Uint8List> files, String fileName) {
    final manifestPath = _findManifest(files.keys);
    if (manifestPath == null) return _fallback(files, fileName);

    final dir = manifestPath.contains('/')
        ? manifestPath.substring(0, manifestPath.lastIndexOf('/') + 1)
        : '';
    final Object? json;
    try {
      json = jsonDecode(TextDecoder.decode(files[manifestPath]!));
    } on FormatException {
      throw const ImportException('chapters.json không hợp lệ.');
    }
    if (json is! Map<String, dynamic>) {
      throw const ImportException('chapters.json không hợp lệ.');
    }

    final chapters = <ParsedChapter>[];
    final list = json['chapters'];
    if (list is List) {
      for (final c in list) {
        if (c is! Map) continue;
        final n = (c['n'] as num?)?.toInt();
        final file = c['file'] as String?;
        if (n == null || file == null) continue;
        final data = files[_normalize('$dir$file')];
        if (data == null) continue;
        final title = ((c['title'] as String?) ?? 'Chương $n').trim();
        chapters.add(
          ParsedChapter(
            number: n,
            title: _fullTitle(n, title),
            content: TextDecoder.decode(data),
          ),
        );
      }
    }
    chapters.sort((a, b) => a.number.compareTo(b.number));
    if (chapters.isEmpty) {
      throw const ImportException('Gói truyện không có chương nào.');
    }

    final arcs = <Arc>[];
    final arcList = json['arcs'];
    if (arcList is List) {
      for (final a in arcList) {
        if (a is! Map) continue;
        final from = (a['from'] as num?)?.toInt();
        final to = (a['to'] as num?)?.toInt();
        if (from == null || to == null) continue;
        arcs.add(
          Arc(name: ((a['name'] as String?) ?? '').trim(), from: from, to: to),
        );
      }
    }

    return ParsedBook(
      title:
          ((json['book'] as String?) ?? TxtImporter.titleFromFileName(fileName))
              .trim(),
      volume: ((json['volume'] as String?) ?? '').trim(),
      author: ((json['author'] as String?) ?? '').trim(),
      sourceType: SourceType.zip,
      arcs: arcs,
      chapters: chapters,
    );
  }

  /// "Mệnh Giám Không Sáng" -> "Chương 1: Mệnh Giám Không Sáng" (trừ khi tiêu đề
  /// đã có chữ "Chương").
  static String _fullTitle(int n, String title) {
    if (RegExp(
      r'^(chương|chapter|hồi)\s',
      caseSensitive: false,
      unicode: true,
    ).hasMatch(title)) {
      return title;
    }
    return 'Chương $n: $title';
  }

  static String? _findManifest(Iterable<String> names) {
    final candidates =
        names
            .where((n) => n.split('/').last.toLowerCase() == 'chapters.json')
            .toList()
          ..sort((a, b) => a.split('/').length.compareTo(b.split('/').length));
    return candidates.isEmpty ? null : candidates.first;
  }

  static String _normalize(String path) {
    final out = <String>[];
    for (final part in path.split('/')) {
      if (part == '..') {
        if (out.isNotEmpty) out.removeLast();
      } else if (part != '.' && part.isNotEmpty) {
        out.add(part);
      }
    }
    return out.join('/');
  }

  static ParsedBook _fallback(Map<String, Uint8List> files, String fileName) {
    final names = files.keys.where((n) {
      final lower = n.toLowerCase();
      if (lower.split('/').any((p) => p == 'notes')) return false;
      return lower.endsWith('.md') || lower.endsWith('.txt');
    }).toList()..sort(_naturalCompare);
    if (names.isEmpty) {
      throw const ImportException(
        'Không tìm thấy chapters.json hay tệp chương trong ZIP.',
      );
    }
    final chapters = <ParsedChapter>[];
    for (var i = 0; i < names.length; i++) {
      final text = TextDecoder.decode(files[names[i]]!);
      final firstLine = text
          .split('\n')
          .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      final title = firstLine.startsWith('#')
          ? firstLine.replaceFirst(RegExp(r'^#+\s*'), '').trim()
          : 'Chương ${i + 1}';
      chapters.add(ParsedChapter(number: i + 1, title: title, content: text));
    }
    return ParsedBook(
      title: TxtImporter.titleFromFileName(fileName),
      sourceType: SourceType.zip,
      chapters: chapters,
    );
  }

  static int _naturalCompare(String a, String b) {
    final re = RegExp(r'\d+|\D+');
    final pa = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
    final pb = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]);
      final nb = int.tryParse(pb[i]);
      final c = (na != null && nb != null)
          ? na.compareTo(nb)
          : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }
}
