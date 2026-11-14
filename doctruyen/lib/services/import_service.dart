import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/dao/book_dao.dart';
import '../data/repositories/library_repository.dart';
import '../domain/importers/book_importer.dart';
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
}
