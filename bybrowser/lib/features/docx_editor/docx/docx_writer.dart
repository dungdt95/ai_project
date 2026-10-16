import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_quill/quill_delta.dart';

import 'docx_model.dart';

/// Ghi Delta ngược lại thành .docx theo cách "vá tại chỗ": dựng lại nội dung
/// `<w:body>` trong document.xml gốc (giữ nguyên root, namespace, sectPr),
/// mọi part khác của zip giữ nguyên trừ khi cần bổ sung (style heading,
/// định nghĩa numbering, relationship cho hyperlink).
class DocxWriter {
  DocxWriter._();

  static Uint8List write(DocxDocument doc, Delta delta) {
    final parts = Map<String, List<int>>.of(doc.parts);
    final w = _Writer(doc, parts);
    final body = w.buildBody(delta);
    parts['word/document.xml'] = utf8.encode(_replaceBody(doc.documentXml, body));
    w.finish();

    final archive = Archive();
    for (final e in parts.entries) {
      archive.add(ArchiveFile.bytes(e.key, e.value));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static String _replaceBody(String xml, String newInner) {
    final open = RegExp(r'<w:body\b[^>]*>').firstMatch(xml);
    final close = xml.lastIndexOf('</w:body>');
    if (open == null || close < 0) throw StateError('document.xml không có <w:body>');
    final oldInner = xml.substring(open.end, close);
    // Giữ nguyên sectPr cuối body (khổ giấy, lề, header/footer).
    final sect = RegExp(r'<w:sectPr\b(?:[^>]*/>|[^>]*>[\s\S]*?</w:sectPr>)(?![\s\S]*<w:sectPr\b)').firstMatch(oldInner);
    final sectXml = sect?.group(0) ?? '';
    return xml.substring(0, open.end) + newInner + sectXml + xml.substring(close);
  }
}

class _Writer {
  _Writer(this.doc, this.parts);

  final DocxDocument doc;
  final Map<String, List<int>> parts;

  final Map<String, String> _hyperlinkRels = {}; // url → rId
  final Set<int> _headingsNeeded = {};
  bool _needBullet = false;
  bool _needOrdered = false;
  int? _bulletNumId;
  int? _orderedNumId;

  // ------------------------------------------------------------------ body

  String buildBody(Delta delta) {
    final sb = StringBuffer();
    var lastWasRawBlock = false;
    for (final line in _lines(delta)) {
      final segments = line.$1;
      final attrs = line.$2;
      // Tách quanh các embed cấp block (bảng…).
      var current = <_Seg>[];
      for (final s in segments) {
        if (s.blockId != null) {
          if (_hasContent(current)) sb.write(_paragraph(current, attrs));
          sb.write(doc.blockRaws[s.blockId]?.xml ?? '');
          lastWasRawBlock = true;
          current = [];
        } else {
          current.add(s);
        }
      }
      if (current.isNotEmpty || !segments.any((s) => s.blockId != null)) {
        sb.write(_paragraph(current, attrs));
        lastWasRawBlock = false;
      }
    }
    // Word yêu cầu body kết thúc bằng đoạn văn (không phải bảng).
    if (lastWasRawBlock) sb.write('<w:p/>');
    return sb.toString();
  }

  bool _hasContent(List<_Seg> segs) =>
      segs.any((s) => s.inlineId != null || (s.text?.isNotEmpty ?? false));

  /// Chia Delta thành các dòng: (segments, thuộc tính của "\n").
  Iterable<(List<_Seg>, Map<String, dynamic>)> _lines(Delta delta) sync* {
    var segs = <_Seg>[];
    for (final op in delta.toList()) {
      final data = op.data;
      final attrs = op.attributes ?? const <String, dynamic>{};
      if (data is Map) {
        if (data.containsKey(kEmbedImage)) {
          segs.add(_Seg(inlineId: data[kEmbedImage] as String, attrs: attrs));
        } else if (data.containsKey(kEmbedBlock)) {
          segs.add(_Seg(blockId: data[kEmbedBlock] as String, attrs: attrs));
        } else if (data.containsKey('image')) {
          segs.add(_Seg(text: '[Ảnh]', attrs: attrs));
        }
        continue;
      }
      final text = data as String;
      var start = 0;
      while (true) {
        final nl = text.indexOf('\n', start);
        if (nl < 0) {
          if (start < text.length) segs.add(_Seg(text: text.substring(start), attrs: attrs));
          break;
        }
        if (nl > start) segs.add(_Seg(text: text.substring(start, nl), attrs: attrs));
        yield (segs, attrs);
        segs = [];
        start = nl + 1;
      }
    }
    if (segs.isNotEmpty) yield (segs, const {});
  }

  String _paragraph(List<_Seg> segs, Map<String, dynamic> attrs) {
    final sb = StringBuffer('<w:p>');
    sb.write(_pPr(attrs));
    String? openLink;
    for (final s in segs) {
      final link = s.attrs['link'] as String?;
      if (link != openLink) {
        if (openLink != null) sb.write('</w:hyperlink>');
        if (link != null) sb.write('<w:hyperlink r:id="${_hyperlinkId(link)}">');
        openLink = link;
      }
      if (s.inlineId != null) {
        sb.write(doc.inlineRaws[s.inlineId]?.xml ?? '');
      } else if (s.text != null && s.text!.isNotEmpty) {
        sb.write(_run(s.text!, s.attrs, inLink: link != null));
      }
    }
    if (openLink != null) sb.write('</w:hyperlink>');
    sb.write('</w:p>');
    return sb.toString();
  }

  String _run(String text, Map<String, dynamic> attrs, {required bool inLink}) {
    final sb = StringBuffer('<w:r>');
    sb.write(_rPr(attrs, inLink: inLink));
    final pieces = text.split('\t');
    for (var i = 0; i < pieces.length; i++) {
      if (i > 0) sb.write('<w:tab/>');
      if (pieces[i].isNotEmpty) {
        sb.write('<w:t xml:space="preserve">${_esc(pieces[i])}</w:t>');
      }
    }
    sb.write('</w:r>');
    return sb.toString();
  }

  // ------------------------------------------------------------------ pPr

  static const _pPrOrder = [
    'pStyle', 'keepNext', 'keepLines', 'pageBreakBefore', 'framePr', 'widowControl',
    'numPr', 'suppressLineNumbers', 'pBdr', 'shd', 'tabs', 'suppressAutoHyphens',
    'kinsoku', 'wordWrap', 'overflowPunct', 'topLinePunct', 'autoSpaceDE', 'autoSpaceDN',
    'bidi', 'adjustRightInd', 'snapToGrid', 'spacing', 'ind', 'contextualSpacing',
    'mirrorIndents', 'suppressOverlap', 'jc', 'textDirection', 'textAlignment',
    'textboxTightWrap', 'outlineLvl', 'divId', 'cnfStyle', 'rPr', 'sectPr', 'pPrChange',
  ];

  String _pPr(Map<String, dynamic> attrs) {
    final children = <String, String>{};
    final residualId = attrs[kAttrPPr] as String?;
    for (final rc in doc.pprs[residualId] ?? const <RawChild>[]) {
      children[rc.name] = rc.xml;
    }
    final header = attrs['header'];
    if (header is int && header >= 1 && header <= 6) {
      children['pStyle'] = '<w:pStyle w:val="${_headingStyleId(header)}"/>';
    }
    final list = attrs['list'];
    final indent = (attrs['indent'] is int) ? attrs['indent'] as int : 0;
    if (list == 'bullet' || list == 'ordered' || list == 'checked' || list == 'unchecked') {
      final bullet = list != 'ordered';
      final numId = _numIdFor(bullet, attrs[kAttrNumId]);
      children['numPr'] = '<w:numPr><w:ilvl w:val="${indent.clamp(0, 8)}"/><w:numId w:val="$numId"/></w:numPr>';
    } else if (indent > 0) {
      children['ind'] = '<w:ind w:left="${720 * indent}"/>';
    }
    final align = attrs['align'];
    final jc = switch (align) {
      'center' => 'center',
      'right' => 'right',
      'justify' => 'both',
      _ => null,
    };
    if (jc != null) children['jc'] = '<w:jc w:val="$jc"/>';
    if (children.isEmpty) return '';
    return '<w:pPr>${_ordered(children, _pPrOrder)}</w:pPr>';
  }

  // ------------------------------------------------------------------ rPr

  static const _rPrOrder = [
    'rStyle', 'rFonts', 'b', 'bCs', 'i', 'iCs', 'caps', 'smallCaps', 'strike', 'dstrike',
    'outline', 'shadow', 'emboss', 'imprint', 'noProof', 'snapToGrid', 'vanish', 'webHidden',
    'color', 'spacing', 'w', 'kern', 'position', 'sz', 'szCs', 'highlight', 'u', 'effect',
    'bdr', 'shd', 'fitText', 'vertAlign', 'rtl', 'cs', 'em', 'lang', 'eastAsianLayout',
    'specVanish', 'oMath',
  ];

  String _rPr(Map<String, dynamic> attrs, {required bool inLink}) {
    final children = <String, String>{};
    final residualId = attrs[kAttrRPr] as String?;
    for (final rc in doc.rprs[residualId] ?? const <RawChild>[]) {
      children[rc.name] = rc.xml;
    }
    if (inLink && doc.hasHyperlinkStyle && !children.containsKey('rStyle')) {
      children['rStyle'] = '<w:rStyle w:val="Hyperlink"/>';
    }
    final font = attrs['font'];
    if (font is String && font.isNotEmpty) {
      final f = _esc(font);
      children['rFonts'] = '<w:rFonts w:ascii="$f" w:hAnsi="$f" w:cs="$f"/>';
    }
    if (attrs['bold'] == true) {
      children['b'] = '<w:b/>';
      children['bCs'] = '<w:bCs/>';
    }
    if (attrs['italic'] == true) {
      children['i'] = '<w:i/>';
      children['iCs'] = '<w:iCs/>';
    }
    if (attrs['strike'] == true) children['strike'] = '<w:strike/>';
    if (attrs['underline'] == true) children['u'] = '<w:u w:val="single"/>';
    final color = _hex(attrs['color']);
    if (color != null) children['color'] = '<w:color w:val="$color"/>';
    final bg = _hex(attrs['background']);
    if (bg != null) children['shd'] = '<w:shd w:val="clear" w:color="auto" w:fill="$bg"/>';
    final half = _halfPoints(attrs['size']);
    if (half != null) {
      children['sz'] = '<w:sz w:val="$half"/>';
      children['szCs'] = '<w:szCs w:val="$half"/>';
    }
    final script = attrs['script'];
    if (script == 'super') children['vertAlign'] = '<w:vertAlign w:val="superscript"/>';
    if (script == 'sub') children['vertAlign'] = '<w:vertAlign w:val="subscript"/>';
    if (children.isEmpty) return '';
    return '<w:rPr>${_ordered(children, _rPrOrder)}</w:rPr>';
  }

  static String? _hex(dynamic v) {
    if (v is! String) return null;
    var s = v.startsWith('#') ? v.substring(1) : v;
    if (s.length == 8) s = s.substring(2); // AARRGGBB → RRGGBB
    if (s.length != 6 || !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(s)) return null;
    return s.toUpperCase();
  }

  static int? _halfPoints(dynamic size) {
    if (size == null) return null;
    if (size is num) return (size * 2).round();
    final s = size.toString();
    switch (s) {
      case 'small':
        return 16;
      case 'large':
        return 28;
      case 'huge':
        return 40;
    }
    final v = double.tryParse(s);
    return v == null ? null : (v * 2).round();
  }

  static String _ordered(Map<String, String> children, List<String> order) {
    final keys = children.keys.toList()
      ..sort((a, b) {
        final ia = order.indexOf(a);
        final ib = order.indexOf(b);
        return (ia < 0 ? order.length : ia).compareTo(ib < 0 ? order.length : ib);
      });
    return keys.map((k) => children[k]!).join();
  }

  // ------------------------------------------------------- styles/numbering

  String _headingStyleId(int level) {
    final existing = doc.headingStyleIds[level];
    if (existing != null) return existing;
    _headingsNeeded.add(level);
    return 'Heading$level';
  }

  int _numIdFor(bool bullet, dynamic originalNumId) {
    if (originalNumId is int && doc.numIdIsBullet[originalNumId] == bullet) {
      return originalNumId;
    }
    if (bullet) {
      _bulletNumId ??= doc.numIdIsBullet.entries.where((e) => e.value).map((e) => e.key).firstOrNull;
      if (_bulletNumId == null) _needBullet = true;
      return _bulletNumId ?? -1;
    }
    _orderedNumId ??= doc.numIdIsBullet.entries.where((e) => !e.value).map((e) => e.key).firstOrNull;
    if (_orderedNumId == null) _needOrdered = true;
    return _orderedNumId ?? -2;
  }

  String _hyperlinkId(String url) => _hyperlinkRels.putIfAbsent(url, () => 'rIdBb${_hyperlinkRels.length + 1}');

  /// Bổ sung các part phụ thuộc sau khi đã dựng body.
  void finish() {
    if (_headingsNeeded.isNotEmpty) _addHeadingStyles();
    if (_needBullet || _needOrdered) _addNumbering();
    if (_hyperlinkRels.isNotEmpty) _addHyperlinkRels();
  }

  void _addHeadingStyles() {
    _patch('word/styles.xml', (s) {
      final sb = StringBuffer();
      for (final level in _headingsNeeded) {
        final size = [32, 28, 26, 24, 24, 24][level - 1];
        sb.write('<w:style w:type="paragraph" w:styleId="Heading$level">'
            '<w:name w:val="heading $level"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/>'
            '<w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="240" w:after="60"/>'
            '<w:outlineLvl w:val="${level - 1}"/></w:pPr>'
            '<w:rPr><w:b/><w:bCs/><w:sz w:val="$size"/><w:szCs w:val="$size"/></w:rPr></w:style>');
      }
      final i = s.lastIndexOf('</w:styles>');
      return i < 0 ? s : s.substring(0, i) + sb.toString() + s.substring(i);
    });
  }

  void _addNumbering() {
    const path = 'word/numbering.xml';
    var xml = parts.containsKey(path) ? utf8.decode(parts[path]!) : null;
    var nextAbs = 0;
    var nextNum = 1;
    if (xml != null) {
      for (final m in RegExp(r'w:abstractNumId="(\d+)"').allMatches(xml)) {
        nextAbs = (int.parse(m.group(1)!) + 1).clamp(nextAbs, 1 << 30);
      }
      for (final m in RegExp(r'<w:num\b[^>]*w:numId="(\d+)"').allMatches(xml)) {
        nextNum = (int.parse(m.group(1)!) + 1).clamp(nextNum, 1 << 30);
      }
    }
    final abstracts = StringBuffer();
    final nums = StringBuffer();
    String lvls(bool bullet) {
      final sb = StringBuffer();
      for (var i = 0; i < 9; i++) {
        final left = 720 * (i + 1);
        sb.write('<w:lvl w:ilvl="$i"><w:start w:val="1"/>'
            '<w:numFmt w:val="${bullet ? 'bullet' : 'decimal'}"/>'
            '<w:lvlText w:val="${bullet ? '•' : '%${i + 1}.'}"/><w:lvlJc w:val="left"/>'
            '<w:pPr><w:ind w:left="$left" w:hanging="360"/></w:pPr>'
            '${bullet ? '<w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/></w:rPr>' : ''}'
            '</w:lvl>');
      }
      return sb.toString();
    }

    void add(bool bullet) {
      final abs = nextAbs++;
      final num = nextNum++;
      abstracts.write('<w:abstractNum w:abstractNumId="$abs"><w:multiLevelType w:val="hybridMultilevel"/>${lvls(bullet)}</w:abstractNum>');
      nums.write('<w:num w:numId="$num"><w:abstractNumId w:val="$abs"/></w:num>');
      if (bullet) {
        _bulletNumId = num;
      } else {
        _orderedNumId = num;
      }
    }

    if (_needBullet) add(true);
    if (_needOrdered) add(false);

    if (xml == null) {
      xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<w:numbering xmlns:w="$wNs" xmlns:r="$rNs">$abstracts$nums</w:numbering>';
      _patch('word/_rels/document.xml.rels', (s) => _insertBefore(s, '</Relationships>',
          '<Relationship Id="rIdBbNum" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>'));
      _patch('[Content_Types].xml', (s) => _insertBefore(s, '</Types>',
          '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'));
    } else {
      // abstractNum phải đứng trước mọi <w:num>.
      final firstNum = xml.indexOf('<w:num ');
      if (firstNum >= 0) {
        xml = xml.substring(0, firstNum) + abstracts.toString() + xml.substring(firstNum);
      } else {
        xml = _insertBefore(xml, '</w:numbering>', abstracts.toString());
      }
      xml = _insertBefore(xml, '</w:numbering>', nums.toString());
    }
    parts[path] = utf8.encode(xml);
    // Các numId tạm (-1/-2) trong body → numId thật.
    _patch('word/document.xml', (s) => s
        .replaceAll('<w:numId w:val="-1"/>', '<w:numId w:val="${_bulletNumId ?? 1}"/>')
        .replaceAll('<w:numId w:val="-2"/>', '<w:numId w:val="${_orderedNumId ?? 1}"/>'));
  }

  void _addHyperlinkRels() {
    _patch('word/_rels/document.xml.rels', (s) {
      final sb = StringBuffer();
      for (final e in _hyperlinkRels.entries) {
        sb.write('<Relationship Id="${e.value}" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" '
            'Target="${_esc(e.key)}" TargetMode="External"/>');
      }
      return _insertBefore(s, '</Relationships>', sb.toString());
    });
  }

  static String _insertBefore(String s, String anchor, String insert) {
    final i = s.lastIndexOf(anchor);
    return i < 0 ? s : s.substring(0, i) + insert + s.substring(i);
  }

  void _patch(String path, String Function(String) f) {
    final b = parts[path];
    if (b == null) return;
    parts[path] = utf8.encode(f(utf8.decode(b, allowMalformed: true)));
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class _Seg {
  _Seg({this.text, this.inlineId, this.blockId, required this.attrs});
  final String? text;
  final String? inlineId;
  final String? blockId;
  final Map<String, dynamic> attrs;
}
