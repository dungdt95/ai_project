import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dao/book_dao.dart';
import '../../data/data_providers.dart';
import '../../domain/importers/book_importer.dart';
import '../../domain/importers/parsed_book.dart';
import '../library/library_provider.dart';

/// Chọn tệp và nhập vào thư viện, báo kết quả bằng SnackBar.
class ImportController {
  const ImportController._();

  static Future<void> pickAndImport(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: BookImporter.supportedExtensions,
    );
    if (picked.isEmpty) return;
    final f = picked.first;
    final path = f.path;
    if (path == null) return;
    if (!context.mounted) return;
    await importPath(context, ref, path, f.name);
  }

  static Future<ImportResult?> importPath(
    BuildContext context,
    WidgetRef ref,
    String path,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Đang nhập "$name"...'),
        duration: const Duration(seconds: 30),
      ),
    );
    try {
      final result = await ref
          .read(importServiceProvider)
          .importFile(path, name);
      await ref.read(libraryProvider.notifier).refresh();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_summary(result))));
      return result;
    } on ImportException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Nhập thất bại: $e')));
    }
    return null;
  }

  static String _summary(ImportResult r) {
    if (!r.isUpdate) return 'Đã nhập truyện mới: ${r.added} chương.';
    if (r.added == 0 && r.updated == 0) return 'Truyện đã là bản mới nhất.';
    return 'Đã cập nhật: thêm ${r.added} chương, sửa ${r.updated} chương.';
  }
}
