import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'xlsx_model.dart';

/// Ghi lại .xlsx theo cách "vá tại chỗ": chỉ thay `<sheetData>` (và `<cols>`,
/// `<mergeCells>`, `<dimension>` khi cần) trong XML gốc của các sheet đã sửa.
/// Mọi part khác của zip (styles, chart, drawing, định nghĩa tên…) được giữ
/// nguyên từng byte, nên định dạng không bị mất.
class XlsxWriter {
  XlsxWriter._();

  static Uint8List write(Workbook wb) {
    final parts = Map<String, List<int>>.of(wb.parts);
    var anyDirty = false;
    for (final ws in wb.sheets) {
      if (!ws.dirty) continue;
      anyDirty = true;
      parts[ws.path] = utf8.encode(rewriteSheetXml(ws));
    }
    if (anyDirty) {
      _dropCalcChain(parts);
      _forceFullCalc(parts);
    }
    final archive = Archive();
    for (final e in parts.entries) {
      archive.add(ArchiveFile.bytes(e.key, e.value));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  // ------------------------------------------------------------- sheet xml

  static String rewriteSheetXml(Worksheet ws) {
    var xml = ws.originalXml;

    // 1. sheetData
    final sheetData = _buildSheetData(ws);
    final sdSelf = RegExp(r'<sheetData\b[^>]*/>');
    final sdFull = RegExp(r'<sheetData\b[^>]*>[\s\S]*?</sheetData>');
    if (sdFull.hasMatch(xml)) {
      xml = xml.replaceFirst(sdFull, sheetData);
    } else if (sdSelf.hasMatch(xml)) {
      xml = xml.replaceFirst(sdSelf, sheetData);
    } else {
      throw StateError('Sheet "${ws.name}" không có <sheetData>');
    }

    // 2. dimension
    final dim = ws.maxRow < 0 ? 'A1' : 'A1:${cellRef(ws.maxRow, ws.maxCol)}';
    xml = xml.replaceFirst(RegExp(r'<dimension\b[^>]*/>'), '<dimension ref="$dim"/>');

    if (ws.structureChanged) {
      // 3. cols (đứng trước sheetData)
      final colsRe = RegExp(r'<cols\b[^>]*>[\s\S]*?</cols>|<cols\b[^>]*/>');
      final colsXml = _buildCols(ws);
      if (colsRe.hasMatch(xml)) {
        xml = xml.replaceFirst(colsRe, colsXml);
      } else if (colsXml.isNotEmpty) {
        final i = xml.indexOf('<sheetData');
        xml = xml.substring(0, i) + colsXml + xml.substring(i);
      }

      // 4. mergeCells (đứng sau sheetData và vài phần tử tùy chọn)
      final mergeRe = RegExp(r'<mergeCells\b[^>]*>[\s\S]*?</mergeCells>|<mergeCells\b[^>]*/>');
      final mergeXml = _buildMerges(ws);
      if (mergeRe.hasMatch(xml)) {
        xml = xml.replaceFirst(mergeRe, mergeXml);
      } else if (mergeXml.isNotEmpty) {
        final i = _mergeInsertIndex(xml);
        xml = xml.substring(0, i) + mergeXml + xml.substring(i);
      }
    }
    return xml;
  }

  /// Vị trí chèn `<mergeCells>`: sau `</sheetData>` và sau các phần tử
  /// (nếu có) mà schema quy định đứng trước mergeCells.
  static int _mergeInsertIndex(String xml) {
    var idx = _endOfElement(xml, 'sheetData', 0);
    const before = [
      'sheetCalcPr', 'sheetProtection', 'protectedRanges', 'scenarios',
      'autoFilter', 'sortState', 'dataConsolidate', 'customSheetViews',
    ];
    for (final name in before) {
      final start = xml.indexOf('<$name', idx);
      if (start >= 0) idx = _endOfElement(xml, name, start);
    }
    return idx;
  }

  /// Chỉ số ngay sau thẻ đóng của phần tử [name] bắt đầu tìm từ [from].
  static int _endOfElement(String xml, String name, int from) {
    final start = xml.indexOf('<$name', from);
    if (start < 0) return from;
    final gt = xml.indexOf('>', start);
    if (gt > 0 && xml[gt - 1] == '/') return gt + 1;
    final close = xml.indexOf('</$name>', gt);
    return close < 0 ? gt + 1 : close + name.length + 3;
  }

  static String _buildSheetData(Worksheet ws) {
    final sb = StringBuffer('<sheetData>');
    final rows = ws.cells.keys.toSet()..addAll(ws.rowAttrs.keys);
    final sortedRows = rows.toList()..sort();
    for (final r in sortedRows) {
      final cells = ws.cells[r];
      final attrs = ws.rowAttrs[r];
      final cellXml = StringBuffer();
      if (cells != null) {
        final cols = cells.keys.toList()..sort();
        for (final c in cols) {
          _writeCell(cellXml, r, c, cells[c]!);
        }
      }
      if (cellXml.isEmpty && (attrs == null || attrs.isEmpty)) continue;
      sb.write('<row r="${r + 1}"');
      attrs?.forEach((k, v) => sb.write(' $k="${_esc(v)}"'));
      if (cellXml.isEmpty) {
        sb.write('/>');
      } else {
        sb..write('>')..write(cellXml)..write('</row>');
      }
    }
    sb.write('</sheetData>');
    return sb.toString();
  }

  static void _writeCell(StringBuffer sb, int r, int c, XlsxCell cell) {
    final style = cell.styleIndex == null ? '' : ' s="${cell.styleIndex}"';
    final ref = cellRef(r, c);
    if (cell.formula != null) {
      final t = switch (cell.type) {
        CellType.text => ' t="str"',
        CellType.bool => ' t="b"',
        CellType.error => ' t="e"',
        _ => '',
      };
      sb.write('<c r="$ref"$style$t><f>${_esc(cell.formula!)}</f>');
      if (cell.type != CellType.empty && cell.raw != null) {
        sb.write('<v>${_esc(cell.raw!)}</v>');
      }
      sb.write('</c>');
      return;
    }
    switch (cell.type) {
      case CellType.empty:
        if (cell.styleIndex != null) sb.write('<c r="$ref"$style/>');
      case CellType.text:
        if (cell.sharedIndex != null) {
          sb.write('<c r="$ref"$style t="s"><v>${cell.sharedIndex}</v></c>');
        } else {
          sb.write('<c r="$ref"$style t="inlineStr"><is><t xml:space="preserve">'
              '${_esc(cell.raw ?? '')}</t></is></c>');
        }
      case CellType.number:
        sb.write('<c r="$ref"$style><v>${_esc(cell.raw ?? '0')}</v></c>');
      case CellType.bool:
        sb.write('<c r="$ref"$style t="b"><v>${cell.raw == '1' || cell.raw == 'true' ? 1 : 0}</v></c>');
      case CellType.error:
        sb.write('<c r="$ref"$style t="e"><v>${_esc(cell.raw ?? '#N/A')}</v></c>');
    }
  }

  static String _buildCols(Worksheet ws) {
    if (ws.cols.isEmpty) return '';
    final sb = StringBuffer('<cols>');
    for (final s in ws.cols) {
      if (s.max < s.min) continue;
      sb.write('<col min="${s.min + 1}" max="${s.max + 1}"');
      s.attrs.forEach((k, v) => sb.write(' $k="${_esc(v)}"'));
      sb.write('/>');
    }
    sb.write('</cols>');
    return sb.toString();
  }

  static String _buildMerges(Worksheet ws) {
    final valid = ws.merges.where((m) => m.r2 > m.r1 || m.c2 > m.c1).toList();
    if (valid.isEmpty) return '';
    final sb = StringBuffer('<mergeCells count="${valid.length}">');
    for (final m in valid) {
      sb.write('<mergeCell ref="${m.toRef()}"/>');
    }
    sb.write('</mergeCells>');
    return sb.toString();
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ------------------------------------------------------------ workbook

  /// calcChain.xml liệt kê các ô công thức; nếu lệch với sheetData Excel sẽ
  /// báo "repair". Bỏ nó đi, Excel tự tạo lại khi mở.
  static void _dropCalcChain(Map<String, List<int>> parts) {
    if (!parts.containsKey('xl/calcChain.xml')) return;
    parts.remove('xl/calcChain.xml');
    _patchText(parts, 'xl/_rels/workbook.xml.rels', (s) =>
        s.replaceAll(RegExp(r'<Relationship\b[^>]*Target="[^"]*calcChain\.xml"[^>]*/>'), ''));
    _patchText(parts, '[Content_Types].xml', (s) =>
        s.replaceAll(RegExp(r'<Override\b[^>]*PartName="/xl/calcChain\.xml"[^>]*/>'), ''));
  }

  /// Yêu cầu Excel tính lại toàn bộ công thức khi mở (vì app không tính).
  static void _forceFullCalc(Map<String, List<int>> parts) {
    _patchText(parts, 'xl/workbook.xml', (s) {
      final calcPr = RegExp(r'<calcPr\b[^>]*/>');
      final m = calcPr.firstMatch(s);
      if (m != null) {
        var tag = m.group(0)!;
        tag = tag.contains('fullCalcOnLoad=')
            ? tag.replaceFirst(RegExp(r'fullCalcOnLoad="[^"]*"'), 'fullCalcOnLoad="1"')
            : tag.replaceFirst('/>', ' fullCalcOnLoad="1"/>');
        return s.replaceRange(m.start, m.end, tag);
      }
      for (final anchor in ['</definedNames>', '</externalReferences>', '</sheets>']) {
        final i = s.indexOf(anchor);
        if (i >= 0) {
          final at = i + anchor.length;
          return '${s.substring(0, at)}<calcPr fullCalcOnLoad="1"/>${s.substring(at)}';
        }
      }
      return s;
    });
  }

  static void _patchText(
      Map<String, List<int>> parts, String path, String Function(String) f) {
    final b = parts[path];
    if (b == null) return;
    parts[path] = utf8.encode(f(utf8.decode(b, allowMalformed: true)));
  }
}
