import 'dart:typed_data';

import '../excel_controller.dart';
import '../xlsx/xlsx_model.dart';
import 'csv_codec.dart';
import 'csv_document.dart';

/// Trình sửa CSV: dùng lại toàn bộ thao tác của [ExcelController], nhưng
/// giữ nguyên chuỗi người dùng gõ (không chuẩn hóa số, không có công thức)
/// và ghi ra CSV theo định dạng của file gốc.
class CsvController extends ExcelController {
  CsvController(
    CsvDocument csv, {
    required Uint8List bytes,
    required this.sheetName,
  }) : format = csv.format,
       hadMalformedBytes = csv.hadMalformedBytes,
       _savedBytes = bytes,
       super(csv.workbook);

  final String sheetName;
  CsvFormat format;
  final bool hadMalformedBytes;

  /// Nội dung file như lần đọc / lưu gần nhất. Lưu khi chưa sửa gì sẽ trả
  /// lại đúng các byte này (file không bị đổi dù chỉ một ký tự).
  Uint8List _savedBytes;
  Uint8List? _pending;

  @override
  String get saveMime =>
      format.delimiter == '\t' ? 'text/tab-separated-values' : 'text/csv';

  @override
  Future<Uint8List> encode() async {
    if (!isDirty) return _savedBytes;
    return _pending = CsvDocument.encodeSheet(sheet, format);
  }

  @override
  void markSaved() {
    if (_pending != null) {
      _savedBytes = _pending!;
      _pending = null;
    }
    super.markSaved();
  }

  @override
  void applyInput(XlsxCell cell, String input) {
    cell.sharedIndex = null;
    cell.formula = null;
    if (input.isEmpty) {
      cell.type = CellType.empty;
      cell.raw = null;
    } else {
      cell.type = CellType.text;
      cell.raw = input;
    }
  }

  @override
  bool alignRight(XlsxCell cell) => CsvCodec.looksNumeric(cell.raw ?? '');

  @override
  void insertColumn(int at) {
    super.insertColumn(at);
    _shiftFieldCounts(at, 1);
  }

  @override
  void deleteColumn(int at) {
    super.deleteColumn(at);
    _shiftFieldCounts(at, -1);
  }

  /// Dòng có số trường gốc vượt qua cột [at] thì tăng/giảm theo.
  void _shiftFieldCounts(int at, int delta) {
    for (final attrs in sheet.rowAttrs.values) {
      final n = int.tryParse(attrs[kCsvFieldsAttr] ?? '');
      if (n != null && n > at) attrs[kCsvFieldsAttr] = '${n + delta}';
    }
  }

  /// Đọc lại file (bản đã lưu gần nhất) với dấu phân cách [delimiter].
  /// Chỉ gọi khi không có thay đổi chưa lưu.
  void changeDelimiter(String delimiter) {
    assert(!isDirty);
    final fresh = CsvDocument.read(
      _savedBytes,
      sheetName: sheetName,
      delimiter: delimiter,
    );
    sheet.restore(fresh.sheet);
    format = fresh.format;
    resetHistory();
  }
}
