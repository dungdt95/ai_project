import 'xlsx_model.dart';

/// Dịch tham chiếu ô trong công thức khi chèn / xóa dòng, cột — giống Excel
/// ở mức cơ bản: A1, $A$1, A1:B5, A:A, 1:1, có hoặc không có tiền tố sheet.
///
/// Không xử lý: tham chiếu kiểu R1C1, tên vùng (named range), tham chiếu
/// cấu trúc bảng (Table[Col]), INDIRECT.
class FormulaShift {
  FormulaShift._();

  /// Chuỗi trong ngoặc kép, tiền tố sheet tùy chọn, rồi một tham chiếu.
  /// Nhóm: 1 = chuỗi, 2 = tiền tố sheet (kể cả `!`), 3 = tham chiếu.
  static final _token = RegExp(
    r'"(?:[^"]|"")*"'
    r"|((?:'(?:[^']|'')*'|[A-Za-z0-9_.À-ỹ]+)!)?"
    r'(\$?[A-Z]{1,3}\$?\d+(?::\$?[A-Z]{1,3}\$?\d+)?'
    r'|\$?[A-Z]{1,3}:\$?[A-Z]{1,3}'
    r'|\$?\d+:\$?\d+)'
    r'(?![A-Za-z0-9_(])',
    caseSensitive: false,
  );

  /// Dịch mọi tham chiếu trong [formula] trỏ tới sheet [targetSheet].
  ///
  /// [ownSheet]: sheet chứa công thức (tham chiếu không có tiền tố trỏ tới nó).
  /// [insert] = true: chèn tại [at]; false: xóa tại [at]. [rows] = true: thao
  /// tác trên dòng, ngược lại trên cột. [at] là 0-based.
  static String shift(
    String formula, {
    required String ownSheet,
    required String targetSheet,
    required bool rows,
    required bool insert,
    required int at,
  }) {
    return formula.replaceAllMapped(_token, (m) {
      final whole = m.group(0)!;
      if (whole.startsWith('"')) return whole; // chuỗi literal
      final prefix = m.group(1);
      final ref = m.group(2)!;
      final sheetName = prefix == null ? ownSheet : _unquote(prefix.substring(0, prefix.length - 1));
      if (sheetName.toLowerCase() != targetSheet.toLowerCase()) return whole;
      final shifted = _shiftRef(ref, rows: rows, insert: insert, at: at);
      return (prefix ?? '') + shifted;
    });
  }

  static String _unquote(String s) =>
      s.startsWith("'") ? s.substring(1, s.length - 1).replaceAll("''", "'") : s;

  static String _shiftRef(String ref, {required bool rows, required bool insert, required int at}) {
    final parts = ref.split(':');
    final a = _Ref.parse(parts[0]);
    if (a == null) return ref;
    if (parts.length == 1) {
      final r = a.shifted(rows: rows, insert: insert, at: at);
      return r == null ? '#REF!' : r.toString();
    }
    final b = _Ref.parse(parts[1]);
    if (b == null) return ref;
    final sa = a.shifted(rows: rows, insert: insert, at: at, rangeStart: true);
    final sb = b.shifted(rows: rows, insert: insert, at: at, rangeEnd: true);
    if (sa == null || sb == null) return '#REF!';
    // Xóa đúng toàn bộ vùng → #REF!
    if (!insert) {
      final lo = rows ? a.row : a.col;
      final hi = rows ? b.row : b.col;
      if (lo != null && hi != null && lo == at && hi == at) return '#REF!';
    }
    return '${sa.toString()}:${sb.toString()}';
  }
}

class _Ref {
  _Ref({this.col, this.colAbs = false, this.row, this.rowAbs = false});

  /// 0-based; null nếu tham chiếu không có phần đó (A:A không có dòng).
  int? col;
  bool colAbs;
  int? row;
  bool rowAbs;

  static final _re = RegExp(r'^(\$?)([A-Z]{0,3})(\$?)(\d*)$', caseSensitive: false);

  static _Ref? parse(String s) {
    final m = _re.firstMatch(s);
    if (m == null) return null;
    final letters = m.group(2)!;
    final digits = m.group(4)!;
    if (letters.isEmpty && digits.isEmpty) return null;
    int? col;
    if (letters.isNotEmpty) {
      col = 0;
      for (final u in letters.toUpperCase().codeUnits) {
        col = col! * 26 + (u - 64);
      }
      col = col! - 1;
    }
    final row = digits.isEmpty ? null : int.parse(digits) - 1;
    return _Ref(
      col: col,
      colAbs: m.group(1)!.isNotEmpty,
      row: row,
      rowAbs: m.group(3)!.isNotEmpty,
    );
  }

  /// Trả về null nếu ô bị xóa.
  _Ref? shifted({
    required bool rows,
    required bool insert,
    required int at,
    bool rangeStart = false,
    bool rangeEnd = false,
  }) {
    final v = rows ? row : col;
    if (v == null) return this;
    int? nv;
    if (insert) {
      nv = v >= at ? v + 1 : v;
    } else if (v > at) {
      nv = v - 1;
    } else if (v == at) {
      // Đầu vùng bị xóa → giữ nguyên (vùng co lại); cuối vùng bị xóa → lùi 1.
      if (rangeStart) {
        nv = v;
      } else if (rangeEnd) {
        nv = v - 1;
      } else {
        return null;
      }
    } else {
      nv = v;
    }
    if (nv < 0) return null;
    return rows
        ? _Ref(col: col, colAbs: colAbs, row: nv, rowAbs: rowAbs)
        : _Ref(col: nv, colAbs: colAbs, row: row, rowAbs: rowAbs);
  }

  @override
  String toString() {
    final sb = StringBuffer();
    if (col != null) {
      if (colAbs) sb.write(r'$');
      sb.write(columnLetters(col!));
    }
    if (row != null) {
      if (rowAbs) sb.write(r'$');
      sb.write(row! + 1);
    }
    return sb.toString();
  }
}
