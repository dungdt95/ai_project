/// Mô hình dữ liệu tối giản cho file .xlsx, đủ để hiển thị và sửa nội dung ô
/// mà vẫn giữ nguyên các phần còn lại của file khi ghi (xem `xlsx_writer.dart`).
library;

enum CellType { empty, text, number, bool, error }

class XlsxCell {
  XlsxCell({
    this.type = CellType.empty,
    this.raw,
    this.formula,
    this.styleIndex,
    this.sharedIndex,
  });

  /// Kiểu của giá trị (với ô công thức: kiểu của giá trị cache).
  CellType type;

  /// Giá trị thô: text, hoặc chuỗi số / "1"|"0" (bool) / mã lỗi (#DIV/0!).
  String? raw;

  /// Công thức (không có dấu `=`). Không được tính lại trong app.
  String? formula;

  /// Chỉ số style `s="…"` trong styles.xml/cellXfs. Giữ nguyên khi sửa.
  int? styleIndex;

  /// Chỉ số trong sharedStrings nếu ô gốc là `t="s"` và chưa bị sửa;
  /// khi ghi sẽ tham chiếu lại chỉ số này để giữ rich text.
  int? sharedIndex;

  bool get isEmpty => type == CellType.empty && formula == null;

  double? get number => type == CellType.number ? double.tryParse(raw ?? '') : null;

  XlsxCell copy() => XlsxCell(
        type: type,
        raw: raw,
        formula: formula,
        styleIndex: styleIndex,
        sharedIndex: sharedIndex,
      );
}

/// Vùng ô [r1,c1]..[r2,c2] (0-based, bao gồm cả hai đầu).
class CellRange {
  const CellRange(this.r1, this.c1, this.r2, this.c2);

  final int r1, c1, r2, c2;

  int get rowSpan => r2 - r1 + 1;
  int get colSpan => c2 - c1 + 1;

  bool contains(int r, int c) => r >= r1 && r <= r2 && c >= c1 && c <= c2;

  String toRef() => '${cellRef(r1, c1)}:${cellRef(r2, c2)}';

  static CellRange? parse(String ref) {
    final parts = ref.split(':');
    final a = parseCellRef(parts[0]);
    if (a == null) return null;
    final b = parts.length > 1 ? parseCellRef(parts[1]) : a;
    if (b == null) return null;
    return CellRange(a.$1, a.$2, b.$1, b.$2);
  }

  @override
  bool operator ==(Object other) =>
      other is CellRange &&
      other.r1 == r1 &&
      other.c1 == c1 &&
      other.r2 == r2 &&
      other.c2 == c2;

  @override
  int get hashCode => Object.hash(r1, c1, r2, c2);
}

/// Một mục `<col min max width …/>` trong `<cols>`.
class ColSpec {
  ColSpec({required this.min, required this.max, required this.attrs});

  /// 0-based, bao gồm cả hai đầu.
  int min, max;

  /// Các thuộc tính khác ngoài min/max (width, style, hidden, customWidth…).
  final Map<String, String> attrs;

  double? get width => double.tryParse(attrs['width'] ?? '');
  bool get hidden => attrs['hidden'] == '1' || attrs['hidden'] == 'true';

  ColSpec copy() => ColSpec(min: min, max: max, attrs: Map.of(attrs));
}

class Worksheet {
  Worksheet({
    required this.name,
    required this.path,
    required this.originalXml,
  });

  final String name;

  /// Đường dẫn trong zip, ví dụ `xl/worksheets/sheet1.xml`.
  final String path;
  final String originalXml;

  /// row0 → col0 → ô. Chỉ chứa ô có dữ liệu hoặc style.
  Map<int, Map<int, XlsxCell>> cells = {};

  /// Thuộc tính của `<row>` ngoài `r` và `spans` (ht, customHeight, s, hidden…).
  Map<int, Map<String, String>> rowAttrs = {};

  List<ColSpec> cols = [];
  List<CellRange> merges = [];

  int maxRow = -1;
  int maxCol = -1;

  /// Nội dung ô có thay đổi → cần ghi lại `<sheetData>`.
  bool dirty = false;

  /// Cấu trúc (cols, merges) thay đổi → cần ghi lại các block tương ứng.
  bool structureChanged = false;

  /// Có thay đổi chưa lưu (chỉ để hiển thị dấu * trên tab; [dirty] vẫn giữ
  /// true sau khi lưu vì lần lưu sau vẫn phải dựng lại sheetData từ model).
  bool unsaved = false;

  XlsxCell? cellAt(int r, int c) => cells[r]?[c];

  XlsxCell ensureCell(int r, int c) {
    final row = cells.putIfAbsent(r, () => {});
    final cell = row.putIfAbsent(c, XlsxCell.new);
    if (r > maxRow) maxRow = r;
    if (c > maxCol) maxCol = c;
    return cell;
  }

  /// Chiều rộng cột theo đơn vị "ký tự" của Excel (mặc định 8.43).
  double columnWidth(int c) {
    for (final spec in cols) {
      if (c >= spec.min && c <= spec.max) {
        if (spec.hidden) return 0;
        return spec.width ?? 8.43;
      }
    }
    return 8.43;
  }

  /// Chiều cao dòng theo point (mặc định 15).
  double rowHeight(int r) {
    final a = rowAttrs[r];
    if (a == null) return 15;
    if (a['hidden'] == '1' || a['hidden'] == 'true') return 0;
    return double.tryParse(a['ht'] ?? '') ?? 15;
  }

  /// Vùng gộp chứa ô (r, c), nếu có.
  CellRange? mergeAt(int r, int c) {
    for (final m in merges) {
      if (m.contains(r, c)) return m;
    }
    return null;
  }

  void _recomputeBounds() {
    maxRow = -1;
    maxCol = -1;
    for (final e in cells.entries) {
      if (e.value.isEmpty) continue;
      if (e.key > maxRow) maxRow = e.key;
      for (final c in e.value.keys) {
        if (c > maxCol) maxCol = c;
      }
    }
  }

  // ----------------------------------------------------------- chèn / xóa

  /// Chèn một dòng trống tại vị trí [at] (các dòng từ [at] dịch xuống).
  /// Công thức tham chiếu tới các ô bị dịch KHÔNG được cập nhật.
  void insertRow(int at) {
    cells = _shiftKeys(cells, at, 1);
    rowAttrs = _shiftKeys(rowAttrs, at, 1);
    merges = merges
        .map((m) => CellRange(
              m.r1 >= at ? m.r1 + 1 : m.r1,
              m.c1,
              m.r2 >= at ? m.r2 + 1 : m.r2,
              m.c2,
            ))
        .toList();
    dirty = true;
    structureChanged = true;
    _recomputeBounds();
  }

  void deleteRow(int at) {
    cells.remove(at);
    rowAttrs.remove(at);
    cells = _shiftKeys(cells, at + 1, -1);
    rowAttrs = _shiftKeys(rowAttrs, at + 1, -1);
    merges = merges
        .where((m) => !(m.r1 == at && m.r2 == at))
        .map((m) => CellRange(
              m.r1 > at ? m.r1 - 1 : m.r1,
              m.c1,
              m.r2 >= at ? m.r2 - 1 : m.r2,
              m.c2,
            ))
        .toList();
    dirty = true;
    structureChanged = true;
    _recomputeBounds();
  }

  void insertColumn(int at) {
    for (final r in cells.keys.toList()) {
      cells[r] = _shiftKeys(cells[r]!, at, 1);
    }
    for (final spec in cols) {
      if (spec.min >= at) {
        spec.min++;
        spec.max++;
      } else if (spec.max >= at) {
        spec.max++;
      }
    }
    merges = merges
        .map((m) => CellRange(
              m.r1,
              m.c1 >= at ? m.c1 + 1 : m.c1,
              m.r2,
              m.c2 >= at ? m.c2 + 1 : m.c2,
            ))
        .toList();
    dirty = true;
    structureChanged = true;
    _recomputeBounds();
  }

  void deleteColumn(int at) {
    for (final r in cells.keys.toList()) {
      cells[r]!.remove(at);
      cells[r] = _shiftKeys(cells[r]!, at + 1, -1);
    }
    final next = <ColSpec>[];
    for (final spec in cols) {
      if (spec.min == at && spec.max == at) continue;
      if (spec.min > at) {
        spec.min--;
        spec.max--;
      } else if (spec.max >= at) {
        spec.max--;
      }
      next.add(spec);
    }
    cols = next;
    merges = merges
        .where((m) => !(m.c1 == at && m.c2 == at))
        .map((m) => CellRange(
              m.r1,
              m.c1 > at ? m.c1 - 1 : m.c1,
              m.r2,
              m.c2 >= at ? m.c2 - 1 : m.c2,
            ))
        .toList();
    dirty = true;
    structureChanged = true;
    _recomputeBounds();
  }

  static Map<int, T> _shiftKeys<T>(Map<int, T> map, int from, int delta) {
    final out = <int, T>{};
    for (final e in map.entries) {
      out[e.key >= from ? e.key + delta : e.key] = e.value;
    }
    return out;
  }

  /// Bản sao sâu để phục vụ undo.
  Worksheet snapshot() {
    final s = Worksheet(name: name, path: path, originalXml: originalXml)
      ..maxRow = maxRow
      ..maxCol = maxCol
      ..dirty = dirty
      ..structureChanged = structureChanged
      ..merges = List.of(merges)
      ..cols = cols.map((c) => c.copy()).toList()
      ..rowAttrs = {for (final e in rowAttrs.entries) e.key: Map.of(e.value)};
    s.cells = {
      for (final r in cells.entries)
        r.key: {for (final c in r.value.entries) c.key: c.value.copy()},
    };
    return s;
  }

  void restore(Worksheet s) {
    maxRow = s.maxRow;
    maxCol = s.maxCol;
    dirty = s.dirty;
    structureChanged = s.structureChanged;
    merges = s.merges;
    cols = s.cols;
    rowAttrs = s.rowAttrs;
    cells = s.cells;
  }
}

/// Thông tin style cần cho hiển thị, lấy từ styles.xml.
class XlsxStyles {
  /// numFmtId theo chỉ số cellXfs.
  final List<int> xfNumFmt = [];
  final List<bool> xfBold = [];

  /// 'left' | 'center' | 'right' | null theo chỉ số cellXfs.
  final List<String?> xfAlign = [];

  /// numFmtId → formatCode cho định dạng tùy chỉnh (id ≥ 164).
  final Map<int, String> customFormats = {};

  int numFmtId(int? xf) =>
      xf == null || xf < 0 || xf >= xfNumFmt.length ? 0 : xfNumFmt[xf];
  bool bold(int? xf) => xf != null && xf >= 0 && xf < xfBold.length && xfBold[xf];
  String? align(int? xf) =>
      xf == null || xf < 0 || xf >= xfAlign.length ? null : xfAlign[xf];
}

class Workbook {
  Workbook({
    required this.sheets,
    required this.sharedStrings,
    required this.styles,
    required this.parts,
  });

  final List<Worksheet> sheets;
  final List<String> sharedStrings;
  final XlsxStyles styles;

  /// Toàn bộ file trong zip (đường dẫn → bytes) để ghi lại nguyên vẹn.
  final Map<String, List<int>> parts;

  bool get isDirty => sheets.any((s) => s.dirty);
}

// --------------------------------------------------------------- tham chiếu

/// 0 → "A", 25 → "Z", 26 → "AA".
String columnLetters(int c) {
  var n = c + 1;
  final sb = StringBuffer();
  while (n > 0) {
    final rem = (n - 1) % 26;
    sb.write(String.fromCharCode(65 + rem));
    n = (n - 1) ~/ 26;
  }
  return String.fromCharCodes(sb.toString().codeUnits.reversed);
}

String cellRef(int r, int c) => '${columnLetters(c)}${r + 1}';

/// "B12" → (11, 1). Trả về null nếu không hợp lệ. Bỏ qua dấu `$`.
(int, int)? parseCellRef(String ref) {
  var col = 0;
  var i = 0;
  final s = ref.replaceAll(r'$', '').toUpperCase();
  while (i < s.length && s.codeUnitAt(i) >= 65 && s.codeUnitAt(i) <= 90) {
    col = col * 26 + (s.codeUnitAt(i) - 64);
    i++;
  }
  if (i == 0 || i >= s.length) return null;
  final row = int.tryParse(s.substring(i));
  if (row == null || row < 1) return null;
  return (row - 1, col - 1);
}
