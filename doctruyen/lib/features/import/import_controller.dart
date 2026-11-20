import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dao/book_dao.dart';
import '../../data/data_providers.dart';
import '../../domain/importers/book_importer.dart';
import '../../domain/importers/local_chapters_importer.dart';
import '../../domain/importers/parsed_book.dart';
import '../drive/drive_ui.dart';
import '../library/library_provider.dart';

/// Menu "Nhập truyện": từ tệp trên máy hoặc từ thư mục Google Drive.
class ImportController {
  const ImportController._();

  static Future<void> showImportMenu(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Từ tệp trên máy'),
              subtitle: const Text(
                '.zip, .txt, .epub, hoặc nhiều tệp chương .md/.txt',
              ),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Từ thư mục Google Drive'),
              subtitle: const Text('Dán liên kết thư mục đã chia sẻ'),
              onTap: () => Navigator.pop(ctx, 'drive'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'drive') {
      await DriveUi.importFromLink(context, ref);
    } else {
      await pickAndImport(context, ref);
    }
  }

  static const List<String> _pickExtensions = [
    ...BookImporter.supportedExtensions,
    'md',
    'markdown',
    'json',
  ];

  static bool _isChapterFile(String name) {
    final l = name.toLowerCase();
    return l.endsWith('.md') || l.endsWith('.markdown');
  }

  static Future<void> pickAndImport(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _pickExtensions,
    );
    if (picked.isEmpty) return;
    final files = [
      for (final f in picked)
        if (f.path != null) (path: f.path!, name: f.name),
    ];
    if (files.isEmpty || !context.mounted) return;

    final lower = files.map((f) => f.name.toLowerCase()).toList();
    final chapterFiles = [
      for (final f in files)
        if (LocalChaptersImporter.chapterExtensions.any(
              (e) => f.name.toLowerCase().endsWith('.$e'),
            ) ||
            f.name.toLowerCase() == 'chapters.json')
          f,
    ];
    final isSet =
        files.length > 1 &&
            chapterFiles.where((f) => f.name != 'chapters.json').length > 1 ||
        files.any((f) => _isChapterFile(f.name)) ||
        lower.contains('chapters.json');
    if (!isSet) {
      // Một tệp zip/txt/epub như trước (nhiều tệp: nhập lần lượt từng tệp).
      for (final f in files) {
        if (!context.mounted) return;
        await importPath(context, ref, f.path, f.name);
      }
      return;
    }
    // Các tệp zip/epub lẫn trong lựa chọn vẫn được nhập riêng.
    for (final f in files.where((f) => !chapterFiles.contains(f))) {
      if (!context.mounted) return;
      await importPath(context, ref, f.path, f.name);
    }
    if (!context.mounted) return;
    await _importChapterSet(context, ref, chapterFiles);
  }

  static Future<void> _importChapterSet(
    BuildContext context,
    WidgetRef ref,
    List<({String path, String name})> files,
  ) async {
    final service = ref.read(importServiceProvider);
    final suggested = await service.suggestTitle(files);
    if (!context.mounted) return;
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _TitleDialog(initial: suggested, count: files.length),
    );
    if (title == null || title.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Đang nhập các chương...'),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      final result = await service.importChapterFiles(files, title.trim());
      await ref.read(libraryProvider.notifier).refresh();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_summary(result))));
    } on ImportException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Nhập thất bại: $e')));
    }
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

class _TitleDialog extends StatefulWidget {
  const _TitleDialog({required this.initial, required this.count});

  final String initial;
  final int count;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tên truyện'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gộp ${widget.count} tệp thành một truyện.'),
          const SizedBox(height: 8),
          TextField(
            controller: _c,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nhập tên truyện'),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          const SizedBox(height: 8),
          Text(
            'Trùng tên với truyện đã có thì chương được thêm/cập nhật vào đó.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _c.text),
          child: const Text('Nhập'),
        ),
      ],
    );
  }
}
