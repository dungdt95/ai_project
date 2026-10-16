import 'dart:typed_data';

import '../editor/document_editor.dart';
import 'xlsx/formula_shift.dart';
import 'xlsx/number_format.dart';
import 'xlsx/xlsx_model.dart';
import 'xlsx/xlsx_writer.dart';

/// Vị trí ô đang chọn.
class CellPos {
  const CellPos(this.row, this.col);
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is CellPos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

class _UndoEntry {
  _UndoEntry(this.sheetIndex, this.snapshots);

  /// Sheet đang mở lúc thao tác (để quay lại đúng sheet khi undo).
  final int sheetIndex;

  /// Bản chụp của các sheet bị ảnh hưởng (chỉ số sheet → snapshot).
  final Map<int, Worksheet> snapshots;
}

/// Trạng thái sửa bảng tính: workbook, sheet đang mở, ô đang chọn, undo/redo.
class ExcelController extends DocumentEditorController {
  ExcelController(this.workbook);

  final Workbook workbook;
  int _sheetIndex = 0;
  CellPos _selected = const CellPos(0, 0);
  final List<_UndoEntry> _undo = [];
  final List<_UndoEntry> _redo = [];
  static const _maxUndo = 30;

  /// Bản đã lưu lần cuối có thay đổi cấu trúc chưa (để tính isDirty sau save).
  bool _dirtySinceSave = false;

  /// Tăng mỗi khi cấu trúc/nội dung đổi ngoài thao tác gõ ở ô đang chọn
  /// (chèn/xóa dòng cột, undo/redo, đổi sheet) để UI nạp lại thanh công thức.
  int mutation = 0;

  Worksheet get sheet => workbook.sheets[_sheetIndex];
  int get sheetIndex => _sheetIndex;
  XlsxStyles get styles => workbook.styles;
  CellPos get selected => _selected;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  @override
  bool get isDirty => _dirtySinceSave;

  @override
  String get saveMime =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  @override
  Future<Uint8List> encode() async => XlsxWriter.write(workbook);

  @override
  void markSaved() {
    _dirtySinceSave = false;
    for (final s in workbook.sheets) {
      s.unsaved = false;
    }
    notifyListeners();
  }

  void selectSheet(int i) {
    if (i == _sheetIndex || i < 0 || i >= workbook.sheets.length) return;
    _sheetIndex = i;
    _selected = const CellPos(0, 0);
    mutation++;
    notifyListeners();
  }

  void select(int row, int col) {
    // Chọn vào vùng gộp → chọn ô góc trên trái.
    final m = sheet.mergeAt(row, col);
    final pos = m == null ? CellPos(row, col) : CellPos(m.r1, m.c1);
    if (pos == _selected) return;
    _selected = pos;
    notifyListeners();
  }

  /// Chuỗi để đưa vào thanh công thức khi chọn ô.
  String inputFor(int row, int col) {
    final cell = sheet.cellAt(row, col);
    if (cell == null) return '';
    if (cell.formula != null) return '=${cell.formula}';
    return switch (cell.type) {
      CellType.empty => '',
      CellType.text => cell.raw ?? '',
      CellType.number => cell.raw ?? '',
      CellType.bool => (cell.raw == '1' || cell.raw == 'true') ? 'TRUE' : 'FALSE',
      CellType.error => cell.raw ?? '',
    };
  }

  String displayFor(int row, int col) {
    final cell = sheet.cellAt(row, col);
    return cell == null ? '' : XlsxNumberFormat.display(cell, styles);
  }

  /// Ghi giá trị người dùng nhập vào ô. Trả về false nếu không có gì đổi.
  bool setCellInput(int row, int col, String input) {
    if (inputFor(row, col) == input) return false;
    _pushUndo();
    applyInput(sheet.ensureCell(row, col), input);
    _markChanged();
    return true;
  }

  /// Chuyển chuỗi người dùng nhập thành giá trị ô (số, bool, công thức, text).
  /// Lớp con có thể override (CSV giữ nguyên chuỗi).
  void applyInput(XlsxCell cell, String input) {
    cell.sharedIndex = null;
    cell.formula = null;
    final s = input.trim();
    if (s.isEmpty) {
      cell.type = CellType.empty;
      cell.raw = null;
    } else if (s.startsWith('=') && s.length > 1) {
      // Công thức: không tính được trong app, Excel sẽ tính khi mở.
      cell.formula = s.substring(1);
      cell.type = CellType.empty;
      cell.raw = null;
    } else if (s.toUpperCase() == 'TRUE' || s.toUpperCase() == 'FALSE') {
      cell.type = CellType.bool;
      cell.raw = s.toUpperCase() == 'TRUE' ? '1' : '0';
    } else if (_looksNumeric(s)) {
      cell.type = CellType.number;
      cell.raw = _normalizeNumber(s);
    } else {
      cell.type = CellType.text;
      cell.raw = input;
    }
  }

  /// Ô được căn phải khi không có căn lề riêng (mặc định như Excel: số, bool).
  bool alignRight(XlsxCell cell) =>
      cell.type == CellType.number || cell.type == CellType.bool;

  /// Xóa lịch sử undo/redo và đưa về ô A1 (sau khi nạp lại nội dung sheet).
  void resetHistory() {
    _undo.clear();
    _redo.clear();
    _selected = const CellPos(0, 0);
    mutation++;
    notifyListeners();
  }

  static final _numRe = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');

  static bool _looksNumeric(String s) => _numRe.hasMatch(s);

  static String _normalizeNumber(String s) {
    final v = double.parse(s);
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    return v.toString();
  }

  void insertRow(int at) {
    _pushUndo(all: true);
    sheet.insertRow(at);
    _shiftFormulas(rows: true, insert: true, at: at);
    mutation++;
    _markChanged();
  }

  void deleteRow(int at) {
    _pushUndo(all: true);
    sheet.deleteRow(at);
    _shiftFormulas(rows: true, insert: false, at: at);
    mutation++;
    if (_selected.row > 0 && _selected.row > sheet.maxRow) {
      _selected = CellPos(_selected.row - 1, _selected.col);
    }
    _markChanged();
  }

  void insertColumn(int at) {
    _pushUndo(all: true);
    sheet.insertColumn(at);
    _shiftFormulas(rows: false, insert: true, at: at);
    mutation++;
    _markChanged();
  }

  void deleteColumn(int at) {
    _pushUndo(all: true);
    sheet.deleteColumn(at);
    _shiftFormulas(rows: false, insert: false, at: at);
    mutation++;
    if (_selected.col > 0 && _selected.col > sheet.maxCol) {
      _selected = CellPos(_selected.row, _selected.col - 1);
    }
    _markChanged();
  }

  void undo() => _swap(_undo, _redo);

  void redo() => _swap(_redo, _undo);

  /// Lấy mục cuối của [from], chụp trạng thái hiện tại vào [to], rồi khôi phục.
  void _swap(List<_UndoEntry> from, List<_UndoEntry> to) {
    if (from.isEmpty) return;
    final e = from.removeLast();
    to.add(_UndoEntry(_sheetIndex, {
      for (final i in e.snapshots.keys) i: workbook.sheets[i].snapshot(),
    }));
    for (final s in e.snapshots.entries) {
      workbook.sheets[s.key]
        ..restore(s.value)
        ..unsaved = true;
    }
    _sheetIndex = e.sheetIndex;
    _dirtySinceSave = true;
    mutation++;
    notifyListeners();
  }

  /// Cập nhật tham chiếu trong công thức của MỌI sheet trỏ tới sheet hiện tại.
  void _shiftFormulas({required bool rows, required bool insert, required int at}) {
    final target = sheet.name;
    for (final ws in workbook.sheets) {
      var changed = false;
      for (final row in ws.cells.values) {
        for (final cell in row.values) {
          final f = cell.formula;
          if (f == null) continue;
          final nf = FormulaShift.shift(f,
              ownSheet: ws.name, targetSheet: target, rows: rows, insert: insert, at: at);
          if (nf != f) {
            cell.formula = nf;
            changed = true;
          }
        }
      }
      if (changed) {
        ws.dirty = true;
        ws.unsaved = true;
      }
    }
  }

  /// Tìm ô kế tiếp (theo hàng) có nội dung chứa [query], bắt đầu sau ô đang
  /// chọn; quay vòng về đầu. Trả về null nếu không có.
  CellPos? findNext(String query, {bool backward = false}) {
    final q = query.toLowerCase();
    if (q.isEmpty) return null;
    final positions = <CellPos>[];
    final rows = sheet.cells.keys.toList()..sort();
    for (final r in rows) {
      final cols = sheet.cells[r]!.keys.toList()..sort();
      for (final c in cols) {
        final cell = sheet.cells[r]![c]!;
        if (cell.isEmpty) continue;
        final hay = '${XlsxNumberFormat.display(cell, styles)}\n${cell.raw ?? ''}\n${cell.formula ?? ''}'
            .toLowerCase();
        if (hay.contains(q)) positions.add(CellPos(r, c));
      }
    }
    if (positions.isEmpty) return null;
    int cmp(CellPos a, CellPos b) =>
        a.row != b.row ? a.row.compareTo(b.row) : a.col.compareTo(b.col);
    if (!backward) {
      for (final p in positions) {
        if (cmp(p, _selected) > 0) return p;
      }
      return positions.first;
    }
    for (final p in positions.reversed) {
      if (cmp(p, _selected) < 0) return p;
    }
    return positions.last;
  }

  void _pushUndo({bool all = false}) {
    final snaps = all
        ? {for (var i = 0; i < workbook.sheets.length; i++) i: workbook.sheets[i].snapshot()}
        : {_sheetIndex: sheet.snapshot()};
    _undo.add(_UndoEntry(_sheetIndex, snaps));
    if (_undo.length > _maxUndo) _undo.removeAt(0);
    _redo.clear();
  }

  void _markChanged() {
    sheet.dirty = true;
    sheet.unsaved = true;
    _dirtySinceSave = true;
    notifyListeners();
  }
}
