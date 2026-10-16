import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/encoding/text_codec.dart';
import '../xlsx/xlsx_model.dart';
import 'csv_codec.dart';

/// Thuộc tính dòng (trong [Worksheet.rowAttrs]) lưu số trường gốc của dòng,
/// để dòng "thiếu cột" được ghi lại đúng như cũ. Được dịch theo khi chèn/xóa dòng.
const kCsvFieldsAttr = 'csvFields';

/// Đánh dấu dòng trống trong file gốc (ghi lại thành dòng trống, không thêm dấu phân cách).
const kCsvBlankAttr = 'csvBlank';

/// Định dạng của file CSV gốc, dùng để ghi ra giống nhất có thể.
class CsvFormat {
  CsvFormat({
    required this.delimiter,
    required this.encoding,
    required this.lineEnding,
    required this.trailingNewline,
    required this.quoteStyle,
    required this.uniform,
    required this.sepLine,
  });

  final String delimiter;
  final TextEncoding encoding;
  final LineEnding lineEnding;

  /// File kết thúc bằng xuống dòng.
  final bool trailingNewline;
  final CsvQuoteStyle quoteStyle;

  /// Mọi dòng (trừ dòng trống) có cùng số trường → khi ghi, mọi dòng được
  /// đệm đủ số cột như nhau.
  final bool uniform;

  /// Dòng đầu `sep=;` (gợi ý dấu phân cách cho Excel).
  final bool sepLine;
}

/// File CSV đã đọc thành một [Workbook] một sheet, để dùng lại lưới /
/// controller của trình sửa Excel. Mọi ô là text, giữ nguyên chuỗi gốc
/// (`007` vẫn là `007`).
class CsvDocument {
  CsvDocument._(this.workbook, this.format, this.hadMalformedBytes);

  final Workbook workbook;
  final CsvFormat format;

  /// Dữ liệu không phải UTF-8 hợp lệ, đã phải đọc theo Latin-1.
  final bool hadMalformedBytes;

  Worksheet get sheet => workbook.sheets.first;

  int get cellCount =>
      sheet.cells.values.fold(0, (sum, row) => sum + row.length);

  /// Đọc CSV. [delimiter] null → tự đoán (ưu tiên [preferred]).
  static CsvDocument read(
    Uint8List bytes, {
    required String sheetName,
    String? delimiter,
    String preferred = ',',
  }) {
    final decoded = TextCodec.decode(bytes);
    var text = decoded.text;

    final sep = RegExp(r'^sep=(.)\n').firstMatch(text);
    if (sep != null) text = text.substring(sep.end);
    final d =
        delimiter ??
        sep?.group(1) ??
        CsvCodec.detectDelimiter(text, preferred: preferred);

    final rows = CsvCodec.parse(text, d);
    final ws = Worksheet(name: sheetName, path: '', originalXml: '');
    final widths = <int, int>{};
    final lengths = <int>{};
    var nonEmpty = 0, quoted = 0, quotedNumeric = 0, bareText = 0;

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (row.length == 1 && row[0].value.isEmpty && !row[0].quoted) {
        ws.rowAttrs[r] = {kCsvBlankAttr: '1'};
        continue;
      }
      ws.rowAttrs[r] = {kCsvFieldsAttr: '${row.length}'};
      lengths.add(row.length);
      for (var c = 0; c < row.length; c++) {
        final f = row[c];
        if (f.value.isEmpty) continue;
        ws.ensureCell(r, c)
          ..type = CellType.text
          ..raw = f.value;
        nonEmpty++;
        final numeric = CsvCodec.looksNumeric(f.value);
        if (f.quoted) {
          quoted++;
          if (numeric) quotedNumeric++;
        } else if (!numeric) {
          bareText++;
        }
        if (r < 200) {
          final firstLine = f.value.split('\n').first;
          widths[c] = math.max(widths[c] ?? 0, firstLine.length);
        }
      }
    }

    ws.cols = [
      for (final e in widths.entries)
        ColSpec(
          min: e.key,
          max: e.key,
          attrs: {'width': '${(e.value + 2).clamp(6, 40)}'},
        ),
    ];

    final CsvQuoteStyle style;
    if (nonEmpty > 0 && quoted == nonEmpty) {
      style = CsvQuoteStyle.all;
    } else if (quoted > 0 && quotedNumeric == 0 && bareText == 0) {
      style = CsvQuoteStyle.nonNumeric;
    } else {
      style = CsvQuoteStyle.minimal;
    }

    final format = CsvFormat(
      delimiter: d,
      encoding: decoded.encoding,
      lineEnding: decoded.lineEnding,
      trailingNewline: text.endsWith('\n'),
      quoteStyle: style,
      uniform: lengths.length <= 1,
      sepLine: sep != null,
    );
    final wb = Workbook(
      sheets: [ws],
      sharedStrings: const [],
      styles: XlsxStyles(),
      parts: const {},
    );
    return CsvDocument._(wb, format, decoded.hadMalformedBytes);
  }

  /// Ghi nội dung sheet thành bytes theo [format].
  Uint8List write() => encodeSheet(sheet, format);

  static Uint8List encodeSheet(Worksheet ws, CsvFormat f) {
    final d = f.delimiter;

    var rowCount = ws.maxRow + 1;
    for (final r in ws.rowAttrs.keys) {
      if (r + 1 > rowCount) rowCount = r + 1;
    }

    int lastCol(int r) {
      var last = -1;
      final row = ws.cells[r];
      if (row == null) return last;
      for (final e in row.entries) {
        if (!e.value.isEmpty && e.key > last) last = e.key;
      }
      return last;
    }

    int storedFields(int r) =>
        int.tryParse(ws.rowAttrs[r]?[kCsvFieldsAttr] ?? '') ?? 1;

    bool isBlank(int r) =>
        ws.rowAttrs[r]?[kCsvBlankAttr] == '1' && lastCol(r) < 0;

    var width = 1;
    if (f.uniform) {
      for (var r = 0; r < rowCount; r++) {
        if (isBlank(r)) continue;
        width = math.max(width, math.max(storedFields(r), lastCol(r) + 1));
      }
    }

    final sb = StringBuffer();
    if (f.sepLine) sb.write('sep=$d\n');
    for (var r = 0; r < rowCount; r++) {
      if (r > 0) sb.write('\n');
      if (isBlank(r)) continue;
      final n = f.uniform ? width : math.max(storedFields(r), lastCol(r) + 1);
      for (var c = 0; c < n; c++) {
        if (c > 0) sb.write(d);
        final cell = ws.cellAt(r, c);
        if (cell == null || cell.isEmpty) continue;
        sb.write(CsvCodec.encodeField(cell.raw ?? '', d, f.quoteStyle));
      }
    }
    if (f.trailingNewline && rowCount > 0) sb.write('\n');
    return TextCodec.encode(sb.toString(), f.encoding, f.lineEnding);
  }
}
