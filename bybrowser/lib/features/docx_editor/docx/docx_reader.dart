import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:xml/xml.dart';

import 'docx_model.dart';

class DocxFormatException implements Exception {
  const DocxFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Đọc .docx → Quill Delta.
///
/// Ánh xạ: đoạn văn, heading 1-6, danh sách bullet/số (kèm cấp), căn lề,
/// đậm/nghiêng/gạch chân/gạch ngang/màu/nền/cỡ/font, hyperlink, tab.
/// Ảnh, bảng và mọi thứ không hiểu được giữ nguyên XML để ghi lại nguyên vẹn.
class DocxReader {
  DocxReader._();

  static DocxDocument read(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const DocxFormatException('File không phải định dạng .docx hợp lệ (không giải nén được).');
    }
    final parts = <String, List<int>>{};
    for (final f in archive) {
      if (f.isFile) parts[f.name] = f.content;
    }
    final docXml = _text(parts, 'word/document.xml');
    if (docXml == null) {
      throw const DocxFormatException('Không tìm thấy word/document.xml — file .docx bị hỏng hoặc không đúng định dạng.');
    }
    final rels = _readRels(_text(parts, 'word/_rels/document.xml.rels') ?? '');
    final styles = _readStyles(_text(parts, 'word/styles.xml'));
    final numbering = _readNumbering(_text(parts, 'word/numbering.xml'));

    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(docXml);
    } catch (e) {
      throw DocxFormatException('document.xml không phải XML hợp lệ: $e');
    }
    final body = doc.rootElement.findElements('body', namespaceUri: wNs).firstOrNull;
    if (body == null) throw const DocxFormatException('document.xml không có <w:body>.');

    final r = _Reader(parts, rels, styles, numbering);
    r.readBody(body);
    return DocxDocument(
      delta: r.delta,
      parts: parts,
      documentXml: docXml,
      pprs: r.pprs,
      rprs: r.rprs,
      inlineRaws: r.inlineRaws,
      blockRaws: r.blockRaws,
      headingStyleIds: styles.headingStyleIds,
      numIdIsBullet: numbering,
      hasHyperlinkStyle: styles.hasHyperlink,
      warnings: r.warnings.toList(),
    );
  }

  static String? _text(Map<String, List<int>> parts, String path) {
    final b = parts[path];
    return b == null ? null : utf8.decode(b, allowMalformed: true);
  }

  /// rId → (target, external?)
  static Map<String, (String, bool)> _readRels(String xml) {
    final out = <String, (String, bool)>{};
    if (xml.isEmpty) return out;
    for (final el in XmlDocument.parse(xml).findAllElements('Relationship')) {
      final id = el.getAttribute('Id');
      final target = el.getAttribute('Target');
      if (id != null && target != null) {
        out[id] = (target, el.getAttribute('TargetMode') == 'External');
      }
    }
    return out;
  }

  static _Styles _readStyles(String? xml) {
    final s = _Styles();
    if (xml == null) return s;
    final doc = XmlDocument.parse(xml);
    for (final st in doc.findAllElements('style', namespaceUri: wNs)) {
      final id = st.getAttribute('styleId', namespaceUri: wNs);
      final name = st.findElements('name', namespaceUri: wNs).firstOrNull?.getAttribute('val', namespaceUri: wNs);
      if (id == null || name == null) continue;
      final m = RegExp(r'^heading (\d)$', caseSensitive: false).firstMatch(name);
      if (m != null) {
        final level = int.parse(m.group(1)!);
        if (level >= 1 && level <= 6) s.headingStyleIds[level] = id;
      }
      if (name.toLowerCase() == 'hyperlink') s.hasHyperlink = true;
    }
    return s;
  }

  /// numId → bullet?
  static Map<int, bool> _readNumbering(String? xml) {
    final out = <int, bool>{};
    if (xml == null) return out;
    final doc = XmlDocument.parse(xml);
    final abstractBullet = <int, bool>{};
    for (final an in doc.findAllElements('abstractNum', namespaceUri: wNs)) {
      final id = int.tryParse(an.getAttribute('abstractNumId', namespaceUri: wNs) ?? '');
      if (id == null) continue;
      final lvl0 = an.findElements('lvl', namespaceUri: wNs).firstOrNull;
      final fmt = lvl0?.findElements('numFmt', namespaceUri: wNs).firstOrNull?.getAttribute('val', namespaceUri: wNs);
      abstractBullet[id] = fmt == 'bullet';
    }
    for (final n in doc.findAllElements('num', namespaceUri: wNs)) {
      final id = int.tryParse(n.getAttribute('numId', namespaceUri: wNs) ?? '');
      final abs = int.tryParse(
          n.findElements('abstractNumId', namespaceUri: wNs).firstOrNull?.getAttribute('val', namespaceUri: wNs) ?? '');
      if (id != null && abs != null) out[id] = abstractBullet[abs] ?? false;
    }
    return out;
  }
}

class _Styles {
  final Map<int, String> headingStyleIds = {};
  bool hasHyperlink = false;
}

class _Reader {
  _Reader(this.parts, this.rels, this.styles, this.numbering);

  final Map<String, List<int>> parts;
  final Map<String, (String, bool)> rels;
  final _Styles styles;
  final Map<int, bool> numbering;

  final delta = Delta();
  final pprs = <String, List<RawChild>>{};
  final rprs = <String, List<RawChild>>{};
  final inlineRaws = <String, InlineRaw>{};
  final blockRaws = <String, BlockRaw>{};
  final warnings = <String>{};
  var _seq = 0;

  String _id() => 'x${_seq++}';

  /// Ngược của heading map: styleId → level.
  late final Map<String, int> _headingByStyleId = {
    for (final e in styles.headingStyleIds.entries) e.value: e.key,
  };

  void readBody(XmlElement body) {
    for (final node in body.children) {
      if (node is! XmlElement) continue;
      _readBlock(node);
    }
    // Quill yêu cầu tài liệu kết thúc bằng "\n".
    if (delta.isEmpty || !(delta.last.data is String && (delta.last.data as String).endsWith('\n'))) {
      delta.insert('\n');
    }
  }

  void _readBlock(XmlElement el) {
    if (el.name.namespaceUri != wNs) {
      _rawBlock(el, 'other');
      return;
    }
    switch (el.name.local) {
      case 'p':
        _readParagraph(el);
      case 'tbl':
        _rawBlock(el, 'table');
      case 'sectPr':
        break; // giữ lại khi ghi (writer lấy từ XML gốc)
      case 'sdt':
        final content = el.findElements('sdtContent', namespaceUri: wNs).firstOrNull;
        if (content != null) {
          for (final c in content.children) {
            if (c is XmlElement) _readBlock(c);
          }
        }
      case 'bookmarkStart':
      case 'bookmarkEnd':
      case 'proofErr':
      case 'permStart':
      case 'permEnd':
      case 'commentRangeStart':
      case 'commentRangeEnd':
        break;
      case 'customXml':
        for (final c in el.children) {
          if (c is XmlElement) _readBlock(c);
        }
      default:
        _rawBlock(el, 'other');
    }
  }

  void _rawBlock(XmlElement el, String kind) {
    final id = _id();
    List<List<String>>? rows;
    if (kind == 'table') {
      rows = [];
      for (final tr in el.findElements('tr', namespaceUri: wNs)) {
        final cells = <String>[];
        for (final tc in tr.findElements('tc', namespaceUri: wNs)) {
          cells.add(_plainText(tc));
        }
        rows.add(cells);
      }
    }
    blockRaws[id] = BlockRaw(xml: el.toXmlString(), kind: kind, tableRows: rows);
    delta
      ..insert({kEmbedBlock: id})
      ..insert('\n');
  }

  String _plainText(XmlElement el) {
    final sb = StringBuffer();
    var first = true;
    for (final p in el.findAllElements('p', namespaceUri: wNs)) {
      if (!first) sb.write('\n');
      first = false;
      for (final t in p.findAllElements('t', namespaceUri: wNs)) {
        sb.write(t.innerText);
      }
    }
    return sb.toString();
  }

  // ------------------------------------------------------------ paragraph

  void _readParagraph(XmlElement p) {
    final lineAttrs = <String, dynamic>{};
    final pPr = p.findElements('pPr', namespaceUri: wNs).firstOrNull;
    if (pPr != null) _readPPr(pPr, lineAttrs);

    final ctx = _RunContext();
    _readInlineChildren(p, ctx, null);

    delta.insert('\n', lineAttrs.isEmpty ? null : lineAttrs);
  }

  void _readPPr(XmlElement pPr, Map<String, dynamic> attrs) {
    final residual = <RawChild>[];
    for (final c in pPr.children) {
      if (c is! XmlElement) continue;
      final name = c.name.local;
      switch (name) {
        case 'pStyle':
          final id = c.getAttribute('val', namespaceUri: wNs) ?? '';
          final level = _headingByStyleId[id];
          if (level != null) {
            attrs['header'] = level;
          } else {
            residual.add(RawChild(name, c.toXmlString()));
          }
        case 'numPr':
          final ilvl = int.tryParse(
              c.findElements('ilvl', namespaceUri: wNs).firstOrNull?.getAttribute('val', namespaceUri: wNs) ?? '0') ?? 0;
          final numId = int.tryParse(
              c.findElements('numId', namespaceUri: wNs).firstOrNull?.getAttribute('val', namespaceUri: wNs) ?? '');
          if (numId != null && numId > 0) {
            attrs['list'] = (numbering[numId] ?? false) ? 'bullet' : 'ordered';
            if (ilvl > 0) attrs['indent'] = ilvl;
            attrs[kAttrNumId] = numId;
          }
        case 'jc':
          final v = c.getAttribute('val', namespaceUri: wNs);
          final align = switch (v) {
            'center' => 'center',
            'right' || 'end' => 'right',
            'both' || 'distribute' => 'justify',
            _ => null,
          };
          if (align != null) attrs['align'] = align;
        case 'rPr':
          break; // rPr của dấu đoạn — bỏ (Word tự tạo lại)
        default:
          residual.add(RawChild(name, c.toXmlString()));
      }
    }
    if (residual.isNotEmpty) {
      final id = _id();
      pprs[id] = residual;
      attrs[kAttrPPr] = id;
    }
  }

  /// Duyệt các phần tử inline của đoạn (run, hyperlink, ins, sdt…).
  void _readInlineChildren(XmlElement parent, _RunContext ctx, String? link) {
    for (final node in parent.children) {
      if (node is! XmlElement) continue;
      final name = node.name.local;
      if (node.name.namespaceUri != wNs) {
        if (name == 'oMath' || name == 'oMathPara') {
          _rawInline(node, 'Công thức toán');
        }
        continue;
      }
      switch (name) {
        case 'r':
          _readRun(node, ctx, link);
        case 'hyperlink':
          final rid = node.getAttribute('id', namespaceUri: rNs);
          final target = rid == null ? null : rels[rid];
          final url = target != null && target.$2 ? target.$1 : null;
          _readInlineChildren(node, ctx, url ?? link);
        case 'ins':
        case 'smartTag':
        case 'customXml':
        case 'fldSimple':
        case 'dir':
        case 'bdo':
          _readInlineChildren(node, ctx, link);
        case 'sdt':
          final content = node.findElements('sdtContent', namespaceUri: wNs).firstOrNull;
          if (content != null) _readInlineChildren(content, ctx, link);
        case 'del':
          warnings.add('Nội dung bị xóa trong chế độ Track Changes (đã chấp nhận xóa)');
        case 'pPr':
        case 'proofErr':
        case 'bookmarkStart':
        case 'bookmarkEnd':
        case 'commentRangeStart':
        case 'commentRangeEnd':
          break;
        default:
          break;
      }
    }
  }

  void _readRun(XmlElement r, _RunContext ctx, String? link) {
    // Run chứa đối tượng không phải văn bản → giữ nguyên XML.
    if (_isObjectRun(r)) {
      _rawInline(r, _objectLabel(r));
      return;
    }
    final attrs = <String, dynamic>{};
    final rPr = r.findElements('rPr', namespaceUri: wNs).firstOrNull;
    if (rPr != null) _readRPr(rPr, attrs);
    if (link != null) attrs['link'] = link;

    final sb = StringBuffer();
    void flush() {
      if (sb.isEmpty) return;
      delta.insert(sb.toString(), attrs.isEmpty ? null : Map.of(attrs));
      sb.clear();
    }

    for (final c in r.children) {
      if (c is! XmlElement) continue;
      switch (c.name.local) {
        case 't':
          if (!ctx.inFieldCode) sb.write(c.innerText);
        case 'tab':
          if (!ctx.inFieldCode) sb.write('\t');
        case 'br':
        case 'cr':
          if (!ctx.inFieldCode) {
            // Quill không có ngắt dòng mềm → thành đoạn mới.
            sb.write('\n');
          }
        case 'sym':
          final hex = c.getAttribute('char', namespaceUri: wNs);
          final code = hex == null ? null : int.tryParse(hex, radix: 16);
          if (code != null && !ctx.inFieldCode) sb.writeCharCode(code & 0xFFFF);
        case 'noBreakHyphen':
          sb.write('‑');
        case 'softHyphen':
          sb.write('­');
        case 'fldChar':
          final type = c.getAttribute('fldCharType', namespaceUri: wNs);
          if (type == 'begin') {
            ctx.inFieldCode = true;
            warnings.add('Trường (field) như số trang, mục lục sẽ thành văn bản tĩnh');
          } else if (type == 'separate' || type == 'end') {
            ctx.inFieldCode = false;
          }
        case 'footnoteReference':
        case 'endnoteReference':
          warnings.add('Chú thích cuối trang / cuối tài liệu sẽ bị mất');
        case 'commentReference':
          warnings.add('Bình luận (comment) sẽ bị mất');
        default:
          break; // rPr, lastRenderedPageBreak, instrText, delText…
      }
    }
    flush();
  }

  static const _objectTags = {'drawing', 'pict', 'object', 'AlternateContent', 'ruby', 'fldData'};

  bool _isObjectRun(XmlElement r) {
    for (final c in r.children) {
      if (c is XmlElement && _objectTags.contains(c.name.local)) return true;
    }
    return false;
  }

  String _objectLabel(XmlElement r) {
    if (r.findAllElements('txbxContent', namespaceUri: wNs).isNotEmpty) return 'Hộp văn bản';
    if (r.findAllElements('blip', namespaceUri: aNs).isNotEmpty) return 'Ảnh';
    if (r.findAllElements('chart').isNotEmpty) return 'Biểu đồ';
    return 'Đối tượng';
  }

  void _rawInline(XmlElement el, String label) {
    Uint8List? bytes;
    final blip = el.findAllElements('blip', namespaceUri: aNs).firstOrNull;
    final rid = blip?.getAttribute('embed', namespaceUri: rNs);
    if (rid != null) {
      final target = rels[rid]?.$1;
      if (target != null) {
        final path = target.startsWith('/') ? target.substring(1) : 'word/$target';
        final data = parts[path];
        if (data != null) bytes = Uint8List.fromList(data);
      }
    }
    final id = _id();
    inlineRaws[id] = InlineRaw(xml: el.toXmlString(), imageBytes: bytes, label: label);
    delta.insert({kEmbedImage: id});
  }

  void _readRPr(XmlElement rPr, Map<String, dynamic> attrs) {
    final residual = <RawChild>[];
    for (final c in rPr.children) {
      if (c is! XmlElement) continue;
      final name = c.name.local;
      final val = c.getAttribute('val', namespaceUri: wNs);
      bool on() => val == null || val == '1' || val == 'true' || val == 'on';
      switch (name) {
        case 'b':
          if (on()) attrs['bold'] = true;
        case 'i':
          if (on()) attrs['italic'] = true;
        case 'strike':
        case 'dstrike':
          if (on()) attrs['strike'] = true;
        case 'u':
          if (val != null && val != 'none') attrs['underline'] = true;
        case 'color':
          if (val != null && val != 'auto' && val.length == 6) attrs['color'] = '#${val.toUpperCase()}';
        case 'highlight':
          final hex = _highlightHex[val];
          if (hex != null) attrs['background'] = hex;
        case 'shd':
          final fill = c.getAttribute('fill', namespaceUri: wNs);
          if (fill != null && fill != 'auto' && fill.length == 6 && !attrs.containsKey('background')) {
            attrs['background'] = '#${fill.toUpperCase()}';
          }
        case 'sz':
          final half = int.tryParse(val ?? '');
          if (half != null) attrs['size'] = (half / 2).toStringAsFixed(half.isOdd ? 1 : 0);
        case 'rFonts':
          final f = c.getAttribute('ascii', namespaceUri: wNs) ?? c.getAttribute('hAnsi', namespaceUri: wNs);
          if (f != null && f.isNotEmpty) attrs['font'] = f;
        case 'vertAlign':
          if (val == 'superscript') attrs['script'] = 'super';
          if (val == 'subscript') attrs['script'] = 'sub';
        case 'bCs':
        case 'iCs':
        case 'szCs':
          break; // ghi lại từ b/i/sz
        default:
          residual.add(RawChild(name, c.toXmlString()));
      }
    }
    if (residual.isNotEmpty) {
      final id = _id();
      rprs[id] = residual;
      attrs[kAttrRPr] = id;
    }
  }

  static const _highlightHex = {
    'yellow': '#FFFF00',
    'green': '#00FF00',
    'cyan': '#00FFFF',
    'magenta': '#FF00FF',
    'blue': '#0000FF',
    'red': '#FF0000',
    'darkBlue': '#000080',
    'darkCyan': '#008080',
    'darkGreen': '#008000',
    'darkMagenta': '#800080',
    'darkRed': '#800000',
    'darkYellow': '#808000',
    'darkGray': '#808080',
    'lightGray': '#C0C0C0',
    'black': '#000000',
    'white': '#FFFFFF',
  };
}

class _RunContext {
  bool inFieldCode = false;
}
