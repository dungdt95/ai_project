import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/dao/book_dao.dart';
import '../data/repositories/library_repository.dart';
import '../domain/importers/book_importer.dart';
import '../domain/importers/local_chapters_importer.dart';
import '../domain/importers/parsed_book.dart';

ParsedBook _parseTask((Uint8List, String) args) =>
    BookImporter.parse(args.$1, args.$2);

/// Đọc tệp, phân tích (trên isolate nền) rồi ghi vào thư viện.
class ImportService {
  ImportService(this._library);

  final LibraryRepository _library;

  Future<ImportResult> importFile(String path, String name) async {
    final bytes = await File(path).readAsBytes();
    final ParsedBook parsed;
    try {
      parsed = await compute(_parseTask, (bytes, name));
    } on ImportException {
      rethrow;
    } catch (e) {
      throw ImportException('Không nhập được "$name": $e');
    }
    return _library.importParsed(parsed);
  }

  /// Tên truyện gợi ý từ chapters.json (nếu có) hoặc thư mục chứa tệp.
  Future<String> suggestTitle(List<({String path, String name})> files) async {
    for (final f in files) {
      if (f.name.toLowerCase() == 'chapters.json') {
        final t = LocalChaptersImporter.suggestedTitle({
          f.name: await File(f.path).readAsBytes(),
        });
        if (t.isNotEmpty) return t;
      }
    }
    final dir = File(files.first.path).parent.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .lastOrNull;
    const generic = {
      'cache',
      'file_picker',
      'download',
      'downloads',
      'files',
      'tmp',
      'temp',
    };
    if (dir == null || generic.contains(dir.toLowerCase())) return '';
    return Uri.decodeComponent(dir);
  }

  /// Nhập nhiều tệp chương rời (.md/.markdown/.txt + chapters.json tùy chọn)
  /// thành một truyện tên [title]; trùng tên thì thêm/cập nhật chương.
  Future<ImportResult> importChapterFiles(
    List<({String path, String name})> files,
    String title,
  ) async {
    final map = <String, Uint8List>{};
    for (final f in files) {
      map[f.name] = await File(f.path).readAsBytes();
    }
    final ParsedBook parsed;
    try {
      parsed = LocalChaptersImporter.build(map, title);
    } on ImportException {
      rethrow;
    } catch (e) {
      throw ImportException('Không nhập được các tệp chương: $e');
    }
    return _library.importParsed(parsed);
  }
}
