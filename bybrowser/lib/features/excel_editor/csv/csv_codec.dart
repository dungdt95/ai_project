/// Đọc / ghi CSV theo RFC 4180 ở mức trường (field): ô trong `"…"`, `""`
/// bên trong ô, xuống dòng nằm trong ô. Văn bản đầu vào đã được chuẩn hóa
/// xuống dòng về `\n` (xem `TextCodec`).
library;

/// Các dấu phân cách được tự nhận diện, theo thứ tự ưu tiên khi hòa điểm.
const kCsvDelimiters = [',', ';', '\t', '|'];

String delimiterLabel(String d) => switch (d) {
  ',' => 'Dấu phẩy ( , )',
  ';' => 'Chấm phẩy ( ; )',
  '\t' => 'Tab',
  '|' => 'Gạch đứng ( | )',
  _ => d,
};

/// Kiểu đặt ngoặc kép khi ghi, đoán từ file gốc để lưu ra giống nhất có thể.
enum CsvQuoteStyle {
  /// Chỉ đặt ngoặc khi bắt buộc (chứa dấu phân cách, `"`, xuống dòng).
  minimal,

  /// Mọi ô có nội dung đều trong ngoặc.
  all,

  /// Ô chữ trong ngoặc, ô số để trần.
  nonNumeric,
}

class CsvField {
  const CsvField(this.value, this.quoted);
  final String value;

  /// Ô gốc được đặt trong ngoặc kép.
  final bool quoted;
}

class CsvCodec {
  CsvCodec._();

  static final _numRe = RegExp(
    r'^[+-]?(\d+([.,]\d+)*|[.,]\d+)([eE][+-]?\d+)?%?$',
  );

  /// Chuỗi trông như số (kể cả `1,5` / `1.234.567` / `12%`) — dùng để căn
  /// phải khi hiển thị và cho kiểu ngoặc [CsvQuoteStyle.nonNumeric].
  static bool looksNumeric(String s) => _numRe.hasMatch(s.trim());

  /// Tách [text] thành các bản ghi. Dòng trống cho ra bản ghi `[""]`.
  /// Không ném lỗi với dữ liệu sai chuẩn (ngoặc không đóng → tới hết file).
  static List<List<CsvField>> parse(
    String text,
    String delimiter, {
    int? maxRecords,
  }) {
    final rows = <List<CsvField>>[];
    final d = delimiter.codeUnitAt(0);
    final n = text.length;
    var row = <CsvField>[];
    final sb = StringBuffer();
    var quoted = false;
    var inQuotes = false;
    var fieldStart = true;

    void endField() {
      row.add(CsvField(sb.toString(), quoted));
      sb.clear();
      quoted = false;
      fieldStart = true;
    }

    var i = 0;
    while (i < n) {
      final c = text.codeUnitAt(i);
      if (inQuotes) {
        if (c == 0x22) {
          if (i + 1 < n && text.codeUnitAt(i + 1) == 0x22) {
            sb.writeCharCode(0x22);
            i += 2;
          } else {
            inQuotes = false;
            i++;
          }
          continue;
        }
        // Chép nguyên đoạn tới dấu " kế tiếp.
        var j = text.indexOf('"', i);
        if (j < 0) j = n;
        sb.write(text.substring(i, j));
        i = j;
        continue;
      }
      if (c == 0x22 && fieldStart) {
        inQuotes = true;
        quoted = true;
        fieldStart = false;
        i++;
      } else if (c == d) {
        endField();
        i++;
      } else if (c == 0x0A) {
        endField();
        rows.add(row);
        row = <CsvField>[];
        i++;
        if (maxRecords != null && rows.length >= maxRecords) return rows;
      } else {
        // Chép nguyên đoạn không có ký tự đặc biệt.
        var j = i + 1;
        while (j < n) {
          final cj = text.codeUnitAt(j);
          if (cj == d || cj == 0x0A) break;
          j++;
        }
        sb.write(text.substring(i, j));
        fieldStart = false;
        i = j;
      }
    }
    // Bản ghi cuối không kết thúc bằng xuống dòng.
    if (!fieldStart || row.isNotEmpty) {
      endField();
      rows.add(row);
    }
    return rows;
  }

  /// Đoán dấu phân cách: chọn dấu cho nhiều dòng có cùng số cột (≥ 2) nhất;
  /// hòa thì lấy dấu cho nhiều cột hơn, rồi theo thứ tự ưu tiên.
  static String detectDelimiter(String text, {String preferred = ','}) {
    final candidates = [
      preferred,
      ...kCsvDelimiters.where((d) => d != preferred),
    ];
    var best = preferred;
    var bestRows = 0;
    var bestCols = 0;
    for (final d in candidates) {
      final rows = parse(
        text,
        d,
        maxRecords: 30,
      ).where((r) => !(r.length == 1 && r[0].value.isEmpty)).toList();
      if (rows.isEmpty) continue;
      final counts = <int, int>{};
      for (final r in rows) {
        counts[r.length] = (counts[r.length] ?? 0) + 1;
      }
      var modeCols = 0;
      var modeRows = 0;
      for (final e in counts.entries) {
        if (e.value > modeRows || (e.value == modeRows && e.key > modeCols)) {
          modeCols = e.key;
          modeRows = e.value;
        }
      }
      if (modeCols < 2) continue;
      if (modeRows > bestRows ||
          (modeRows == bestRows && modeCols > bestCols)) {
        best = d;
        bestRows = modeRows;
        bestCols = modeCols;
      }
    }
    return best;
  }

  /// Mã hóa một ô để ghi ra file.
  static String encodeField(String v, String delimiter, CsvQuoteStyle style) {
    if (v.isEmpty) return '';
    final needs =
        v.contains(delimiter) ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r') ||
        style == CsvQuoteStyle.all ||
        (style == CsvQuoteStyle.nonNumeric && !looksNumeric(v));
    return needs ? '"${v.replaceAll('"', '""')}"' : v;
  }
}
