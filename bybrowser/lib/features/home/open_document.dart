import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/document_ref.dart';
import '../../core/recent/recent_files.dart';
import '../../core/saf/saf_service.dart';
import '../../shared/dialogs.dart';
import '../editor/unsupported_page.dart';
import '../docx_editor/docx/docx_reader.dart';
import '../docx_editor/docx_editor_page.dart';
import '../excel_editor/csv/csv_controller.dart';
import '../excel_editor/csv/csv_document.dart';
import '../excel_editor/excel_controller.dart';
import '../excel_editor/excel_editor_page.dart';
import '../excel_editor/xlsx/xlsx_reader.dart';
import '../text_editor/text_editor_page.dart';

/// Quá ngưỡng này (số ô có dữ liệu) thì hỏi trước khi mở CSV dạng bảng,
/// vì mỗi ô là một object và lưới sẽ tốn nhiều bộ nhớ trên điện thoại.
const kMaxCsvGridCells = 200000;

/// Đọc file theo [ref], chọn editor phù hợp theo loại file và mở màn hình đó.
///
/// Dùng chung cho nút "Mở file", danh sách gần đây và chuyển chế độ xem.
/// [as] ép mở bằng editor của loại đó (ví dụ CSV dạng văn bản);
/// [replace] thay màn hình hiện tại thay vì mở chồng lên.
Future<void> openDocument(
  BuildContext context,
  DocumentRef ref,
  RecentFilesStore recents, {
  DocumentKind? as,
  bool replace = false,
}) async {
  // Hiện loading trong lúc đọc file (file lớn có thể mất vài giây).
  var loading = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  void closeLoading() {
    if (!loading) return;
    loading = false;
    Navigator.of(context).pop();
  }

  try {
    // Làm mới tên/kích thước (file có thể đã đổi) và xác nhận còn quyền.
    final fresh = await SafService.getInfo(ref.uri);
    final kind = as ?? fresh.kind;
    final bytes = kind == DocumentKind.unsupported
        ? null
        : await SafService.readBytes(fresh.uri);
    await recents.touch(fresh);

    if (!context.mounted) return;
    final navigator = Navigator.of(context);

    Widget textPage() =>
        TextEditorPage(document: fresh, bytes: bytes!, recents: recents);

    final Widget page;
    switch (kind) {
      case DocumentKind.csv:
        final csv = await compute(_readCsv, (bytes!, fresh));
        if (!context.mounted) return;
        closeLoading();
        var asGrid = true;
        if (bytes.length > kMaxEditableTextBytes || csv.cellCount > kMaxCsvGridCells) {
          final choice = await _askLargeCsv(context, csv.cellCount);
          if (choice == null) return;
          asGrid = choice;
        }
        page = asGrid
            ? ExcelEditorPage(
                document: fresh,
                controller: CsvController(csv, bytes: bytes, sheetName: _baseName(fresh.name)),
                recents: recents,
              )
            : textPage();
      case DocumentKind.text:
        page = textPage();
      case DocumentKind.xlsx:
        page = ExcelEditorPage(
          document: fresh,
          controller: ExcelController(XlsxReader.read(bytes!)),
          recents: recents,
        );
      case DocumentKind.docx:
        page = DocxEditorPage(
          document: fresh,
          doc: DocxReader.read(bytes!),
          recents: recents,
        );
      case DocumentKind.unsupported:
        page = UnsupportedPage(document: fresh);
    }
    closeLoading();
    final route = MaterialPageRoute<void>(builder: (_) => page);
    await (replace ? navigator.pushReplacement(route) : navigator.push(route));
  } on XlsxFormatException catch (e) {
    if (!context.mounted) return;
    closeLoading();
    await showErrorDialog(context, 'Không đọc được file Excel', e.message);
  } on DocxFormatException catch (e) {
    if (!context.mounted) return;
    closeLoading();
    await showErrorDialog(context, 'Không đọc được file Word', e.message);
  } on SafException catch (e) {
    if (!context.mounted) return;
    closeLoading();
    if (e.code == 'not_found' || e.code == 'no_permission') {
      await recents.remove(ref.uri);
      if (!context.mounted) return;
      await showErrorDialog(
        context,
        'Không mở được file',
        'File "${ref.name}" không còn truy cập được (đã bị xóa/di chuyển '
            'hoặc quyền bị thu hồi). Đã gỡ khỏi danh sách gần đây.',
      );
    } else {
      await showErrorDialog(context, 'Không mở được file', e.message);
    }
  } catch (e) {
    if (!context.mounted) return;
    closeLoading();
    await showErrorDialog(context, 'Không mở được file', '$e');
  }
}

/// Chạy trong isolate riêng (qua [compute]) để không đứng màn hình.
CsvDocument _readCsv((Uint8List, DocumentRef) args) {
  final (bytes, ref) = args;
  return CsvDocument.read(
    bytes,
    sheetName: _baseName(ref.name),
    preferred: ref.extension == 'tsv' ? '\t' : ',',
  );
}

String _baseName(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

/// true = mở dạng bảng, false = dạng văn bản, null = hủy.
Future<bool?> _askLargeCsv(BuildContext context, int cells) => showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File CSV lớn'),
        content: Text(
          'File có khoảng $cells ô dữ liệu. Mở dạng bảng có thể chậm và tốn '
          'nhiều bộ nhớ. Mở dạng văn bản sẽ nhanh hơn '
          '(chỉ đọc nếu file lớn hơn ${formatFileSize(kMaxEditableTextBytes)}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Dạng văn bản'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dạng bảng'),
          ),
        ],
      ),
    );
