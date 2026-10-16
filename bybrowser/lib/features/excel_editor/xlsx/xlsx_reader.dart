import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import 'xlsx_model.dart';

class XlsxFormatException implements Exception {
  const XlsxFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Đọc .xlsx: giải nén, lấy danh sách sheet, sharedStrings, styles và nội
/// dung từng sheet. Các part khác được giữ nguyên bytes để ghi lại sau.
class XlsxReader {
  XlsxReader._();

  static Workbook read(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw const XlsxFormatException('File không phải định dạng .xlsx hợp lệ (không giải nén được).');
    }
    final parts = <String, List<int>>{};
    for (final f in archive) {
      if (f.isFile) parts[f.name] = f.content;
    }
    final workbookXml = _text(parts, 'xl/workbook.xml');
    if (workbookXml == null) {
      throw const XlsxFormatException('Không tìm thấy xl/workbook.xml — file .xlsx bị hỏng hoặc không đúng định dạng.');
    }

    final rels = _readRels(_text(parts, 'xl/_rels/workbook.xml.rels') ?? '');
    final sharedStrings = _readSharedStrings(_text(parts, 'xl/sharedStrings.xml'));
    final styles = _readStyles(_text(parts, 'xl/styles.xml'));

    final sheets = <Worksheet>[];
    final doc = XmlDocument.parse(workbookXml);
    for (final el in doc.findAllElements('sheet')) {
      final name = el.getAttribute('name') ?? 'Sheet';
      final rid = el.getAttribute('r:id') ??
          el.attributes
              .where((a) => a.name.local == 'id')
              .map((a) => a.value)
              .firstOrNull;
      final target = rid == null ? null : rels[rid];
      if (target == null) continue;
      final path = _resolve('xl/', target);
      final xml = _text(parts, path);
      if (xml == null) continue;
      final ws = Worksheet(name: name, path: path, originalXml: xml);
      _readSheet(ws, sharedStrings);
      sheets.add(ws);
    }
    if (sheets.isEmpty) {
      throw const XlsxFormatException('File không có sheet nào đọc được.');
    }
    return Workbook(sheets: sheets, sharedStrings: sharedStrings, styles: styles, parts: parts);
  }

  static String? _text(Map<String, List<int>> parts, String path) {
    final b = parts[path];
    return b == null ? null : utf8.decode(b, allowMalformed: true);
  }

  /// "xl/" + "worksheets/sheet1.xml" → "xl/worksheets/sheet1.xml";
  /// target tuyệt đối "/xl/…" → bỏ dấu "/".
  static String _resolve(String base, String target) {
    if (target.startsWith('/')) return target.substring(1);
    return '$base$target';
  }

  static Map<String, String> _readRels(String xml) {
    final out = <String, String>{};
    if (xml.isEmpty) return out;
    for (final el in XmlDocument.parse(xml).findAllElements('Relationship')) {
      final id = el.getAttribute('Id');
      final target = el.getAttribute('Target');
      if (id != null && target != null) out[id] = target;
    }
    return out;
  }

  static List<String> _readSharedStrings(String? xml) {
    final out = <String>[];
    if (xml == null) return out;
    StringBuffer? current;
    var inPhonetic = 0;
    var inT = false;
    for (final e in parseEvents(xml)) {
      if (e is XmlStartElementEvent) {
        switch (e.localName) {
          case 'si':
            current = StringBuffer();
          case 'rPh':
            inPhonetic++;
          case 't':
            inT = inPhonetic == 0 && !e.isSelfClosing;
        }
      } else if (e is XmlEndElementEvent) {
        switch (e.localName) {
          case 'si':
            out.add(current?.toString() ?? '');
            current = null;
          case 'rPh':
            inPhonetic--;
          case 't':
            inT = false;
        }
      } else if (inT && current != null) {
        if (e is XmlTextEvent) current.write(e.value);
        if (e is XmlCDATAEvent) current.write(e.value);
      }
    }
    return out;
  }

  static XlsxStyles _readStyles(String? xml) {
    final styles = XlsxStyles();
    if (xml == null) return styles;
    final doc = XmlDocument.parse(xml);
    for (final nf in doc.findAllElements('numFmt')) {
      final id = int.tryParse(nf.getAttribute('numFmtId') ?? '');
      final code = nf.getAttribute('formatCode');
      if (id != null && code != null) styles.customFormats[id] = code;
    }
    final fontsBold = <bool>[];
    final fonts = doc.findAllElements('fonts').firstOrNull;
    if (fonts != null) {
      for (final f in fonts.findElements('font')) {
        final b = f.findElements('b').firstOrNull;
        fontsBold.add(b != null && (b.getAttribute('val') ?? '1') != '0');
      }
    }
    final cellXfs = doc.findAllElements('cellXfs').firstOrNull;
    if (cellXfs != null) {
      for (final xf in cellXfs.findElements('xf')) {
        styles.xfNumFmt.add(int.tryParse(xf.getAttribute('numFmtId') ?? '') ?? 0);
        final fontId = int.tryParse(xf.getAttribute('fontId') ?? '') ?? -1;
        styles.xfBold.add(fontId >= 0 && fontId < fontsBold.length && fontsBold[fontId]);
        styles.xfAlign.add(
            xf.findElements('alignment').firstOrNull?.getAttribute('horizontal'));
      }
    }
    return styles;
  }

  static void _readSheet(Worksheet ws, List<String> shared) {
    var row = -1;
    var col = -1;
    XlsxCell? cell;
    String? cellType;
    var section = ''; // 'f' | 'v' | 't' | ''
    var inIs = false;
    var inCols = false;
    final buf = StringBuffer();

    for (final e in parseEvents(ws.originalXml)) {
      if (e is XmlStartElementEvent) {
        final n = e.localName;
        switch (n) {
          case 'cols':
            inCols = true;
          case 'col':
            if (inCols) {
              final attrs = <String, String>{};
              int? min, max;
              for (final a in e.attributes) {
                if (a.localName == 'min') {
                  min = int.tryParse(a.value);
                } else if (a.localName == 'max') {
                  max = int.tryParse(a.value);
                } else {
                  attrs[a.localName] = a.value;
                }
              }
              if (min != null && max != null) {
                ws.cols.add(ColSpec(min: min - 1, max: max - 1, attrs: attrs));
              }
            }
          case 'row':
            col = -1;
            int? r;
            final attrs = <String, String>{};
            for (final a in e.attributes) {
              if (a.localName == 'r') {
                r = int.tryParse(a.value);
              } else if (a.localName != 'spans') {
                attrs[a.localName] = a.value;
              }
            }
            row = r != null ? r - 1 : row + 1;
            if (attrs.isNotEmpty) ws.rowAttrs[row] = attrs;
          case 'c':
            String? ref;
            int? s;
            cellType = null;
            for (final a in e.attributes) {
              switch (a.localName) {
                case 'r':
                  ref = a.value;
                case 's':
                  s = int.tryParse(a.value);
                case 't':
                  cellType = a.value;
              }
            }
            final parsed = ref == null ? null : parseCellRef(ref);
            if (parsed != null) {
              row = parsed.$1;
              col = parsed.$2;
            } else {
              col++;
            }
            cell = XlsxCell(styleIndex: s);
            ws.cells.putIfAbsent(row, () => {})[col] = cell;
            if (e.isSelfClosing) {
              _finishCell(ws, row, col, cell, cellType, shared);
              cell = null;
            }
          case 'f':
            if (cell != null) {
              section = 'f';
              buf.clear();
              if (e.isSelfClosing) section = '';
            }
          case 'v':
            if (cell != null) {
              section = 'v';
              buf.clear();
            }
          case 'is':
            inIs = true;
            buf.clear();
          case 't':
            if (inIs) section = 't';
          case 'mergeCell':
            for (final a in e.attributes) {
              if (a.localName == 'ref') {
                final r = CellRange.parse(a.value);
                if (r != null) ws.merges.add(r);
              }
            }
        }
      } else if (e is XmlEndElementEvent) {
        switch (e.localName) {
          case 'cols':
            inCols = false;
          case 'f':
            if (cell != null && section == 'f') cell.formula = buf.toString();
            section = '';
          case 'v':
            if (cell != null && section == 'v') cell.raw = buf.toString();
            section = '';
          case 't':
            if (inIs) section = '';
          case 'is':
            if (cell != null) {
              cell.raw = buf.toString();
              cell.type = CellType.text;
            }
            inIs = false;
          case 'c':
            if (cell != null) {
              _finishCell(ws, row, col, cell, cellType, shared);
              cell = null;
            }
        }
      } else if (section.isNotEmpty) {
        if (e is XmlTextEvent) buf.write(e.value);
        if (e is XmlCDATAEvent) buf.write(e.value);
      }
    }
    ws.maxRow = -1;
    ws.maxCol = -1;
    for (final r in ws.cells.entries) {
      for (final c in r.value.entries) {
        if (c.value.isEmpty) continue;
        if (r.key > ws.maxRow) ws.maxRow = r.key;
        if (c.key > ws.maxCol) ws.maxCol = c.key;
      }
    }
  }

  static void _finishCell(
      Worksheet ws, int row, int col, XlsxCell cell, String? t, List<String> shared) {
    if (cell.type == CellType.text) return; // inlineStr đã xử lý
    final v = cell.raw;
    switch (t) {
      case 's':
        final idx = int.tryParse(v ?? '');
        if (idx != null && idx >= 0 && idx < shared.length) {
          cell.raw = shared[idx];
          cell.sharedIndex = idx;
        } else {
          cell.raw = '';
        }
        cell.type = CellType.text;
      case 'str':
        cell.type = CellType.text;
        cell.raw = v ?? '';
      case 'b':
        cell.type = CellType.bool;
        cell.raw = v ?? '0';
      case 'e':
        cell.type = CellType.error;
        cell.raw = v ?? '#ERR';
      case 'd':
        cell.type = CellType.text;
        cell.raw = v ?? '';
      default:
        if (v == null || v.isEmpty) {
          cell.type = CellType.empty;
          cell.raw = null;
        } else {
          cell.type = CellType.number;
        }
    }
  }
}
