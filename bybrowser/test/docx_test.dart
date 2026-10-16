import 'dart:io';
import 'dart:typed_data';

import 'package:bybrowser/features/docx_editor/docx/docx_model.dart';
import 'package:bybrowser/features/docx_editor/docx/docx_reader.dart';
import 'package:bybrowser/features/docx_editor/docx/docx_writer.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _fixture() => File('test/fixtures/mau.docx').readAsBytesSync();

/// Văn bản thuần của Delta, embed thành [tên].
String plain(Delta d) => d
    .toList()
    .map((op) => op.data is String ? op.data as String : '[${(op.data as Map).keys.first}]')
    .join();

/// Các dòng (text, thuộc tính của "\n").
List<(String, Map<String, dynamic>)> lines(Delta d) {
  final out = <(String, Map<String, dynamic>)>[];
  var buf = StringBuffer();
  for (final op in d.toList()) {
    final data = op.data;
    if (data is Map) {
      buf.write('[${data.keys.first}]');
      continue;
    }
    final s = data as String;
    var start = 0;
    while (true) {
      final nl = s.indexOf('\n', start);
      if (nl < 0) {
        buf.write(s.substring(start));
        break;
      }
      buf.write(s.substring(start, nl));
      out.add((buf.toString(), op.attributes ?? const {}));
      buf = StringBuffer();
      start = nl + 1;
    }
  }
  return out;
}

void main() {
  group('DocxReader với file do Word tạo', () {
    late DocxDocument doc;
    setUpAll(() => doc = DocxReader.read(_fixture()));

    test('các dòng và thuộc tính khối', () {
      final ls = lines(doc.delta);
      expect(ls[0].$1, 'Báo cáo thử nghiệm');
      expect(ls[0].$2.containsKey('header'), isFalse); // Title giữ làm pStyle dư
      expect(ls[0].$2.containsKey(kAttrPPr), isTrue);
      expect(ls[1].$1, '1. Giới thiệu');
      expect(ls[1].$2['header'], 1);
      expect(ls[3].$1, '1.1 Danh sách');
      expect(ls[3].$2['header'], 2);
      expect(ls[4].$1, 'Mục thứ nhất');
      expect(ls[4].$2['list'], 'bullet');
      expect(ls[6].$1, 'Bước một');
      expect(ls[6].$2['list'], 'ordered');
      expect(ls[8].$1, 'Đoạn căn giữa');
      expect(ls[8].$2['align'], 'center');
      expect(ls[9].$2['header'], 1);
      expect(ls[10].$1, '[docxblock]'); // bảng
      expect(ls[12].$1, 'Ảnh minh họa:');
      expect(ls[13].$1, '[docximage]');
      expect(ls[14].$1, 'Kết thúc tài liệu.');
    });

    test('định dạng inline', () {
      final ops = doc.delta.toList();
      Operation find(String text) => ops.firstWhere((o) => o.data == text);
      expect(find('chữ đậm').attributes?['bold'], isTrue);
      expect(find('chữ nghiêng').attributes?['italic'], isTrue);
      expect(find('gạch chân').attributes?['underline'], isTrue);
      expect(find('chữ đỏ').attributes?['color'], '#FF0000');
      expect(find('Đây là đoạn văn bình thường có ').attributes, isNull);
    });

    test('bảng và ảnh được giữ thô', () {
      final table = doc.blockRaws.values.firstWhere((b) => b.kind == 'table');
      expect(table.tableRows, [
        ['Tên', 'SL', 'Ghi chú'],
        ['Bút', '10', 'Xanh'],
      ]);
      expect(table.xml, startsWith('<w:tbl'));
      final img = doc.inlineRaws.values.first;
      expect(img.imageBytes, isNotNull);
      expect(img.imageBytes!.length, greaterThan(1000));
      expect(img.xml, contains('<w:drawing'));
    });

    test('heading styles, numbering', () {
      expect(doc.headingStyleIds[1], 'Heading1');
      expect(doc.headingStyleIds[2], 'Heading2');
      expect(doc.numIdIsBullet[1], isTrue);
      expect(doc.numIdIsBullet[2], isFalse);
    });
  });

  group('DocxWriter', () {
    test('round-trip không sửa → nội dung giữ nguyên', () {
      final doc = DocxReader.read(_fixture());
      final out = DocxWriter.write(doc, doc.delta);
      final again = DocxReader.read(out);
      expect(plain(again.delta), plain(doc.delta));
      expect(lines(again.delta).map((l) => l.$2['header']).toList(),
          lines(doc.delta).map((l) => l.$2['header']).toList());
      expect(again.blockRaws.length, doc.blockRaws.length);
      expect(again.inlineRaws.length, doc.inlineRaws.length);
      expect(again.parts['word/media/image1.png'], doc.parts['word/media/image1.png']);
    });

    test('sửa: đổi text, thêm heading, thêm list mới, link, cỡ chữ', () {
      final doc = DocxReader.read(_fixture());
      final d = Delta()
        ..insert('Tiêu đề mới', {'bold': true})
        ..insert('\n', {'header': 1})
        ..insert('Đoạn có ')
        ..insert('link', {'link': 'https://example.com'})
        ..insert(' và chữ to', {'size': '14', 'color': '#0000FF', 'background': '#FFFF00'})
        ..insert('\n')
        ..insert('Việc 1')
        ..insert('\n', {'list': 'ordered'})
        ..insert('Việc 1a')
        ..insert('\n', {'list': 'ordered', 'indent': 1})
        ..insert('Gạch đầu dòng')
        ..insert('\n', {'list': 'bullet'})
        ..insert('Có\ttab và <ký tự> & đặc biệt')
        ..insert('\n', {'align': 'right'})
        ..insert({kEmbedBlock: doc.blockRaws.keys.first})
        ..insert('\n')
        ..insert({kEmbedImage: doc.inlineRaws.keys.first})
        ..insert('\n');
      final out = DocxWriter.write(doc, d);
      File('test/fixtures/mau_out.docx').writeAsBytesSync(out);
      final again = DocxReader.read(out);
      final ls = lines(again.delta);
      expect(ls[0].$1, 'Tiêu đề mới');
      expect(ls[0].$2['header'], 1);
      expect(again.delta.toList().first.attributes?['bold'], isTrue);
      final linkOp = again.delta.toList().firstWhere((o) => o.data == 'link');
      expect(linkOp.attributes?['link'], 'https://example.com');
      final big = again.delta.toList().firstWhere((o) => o.data == ' và chữ to');
      expect(big.attributes?['size'], '14');
      expect(big.attributes?['color'], '#0000FF');
      expect(big.attributes?['background'], '#FFFF00');
      expect(ls[2].$2['list'], 'ordered');
      expect(ls[3].$2['list'], 'ordered');
      expect(ls[3].$2['indent'], 1);
      expect(ls[4].$2['list'], 'bullet');
      expect(ls[5].$1, 'Có\ttab và <ký tự> & đặc biệt');
      expect(ls[5].$2['align'], 'right');
      expect(ls[6].$1, '[docxblock]');
      expect(ls[7].$1, '[docximage]');
      // body kết thúc bằng đoạn văn, sectPr còn nguyên
      final xml = String.fromCharCodes(again.parts['word/document.xml']!);
      expect(xml, contains('<w:sectPr'));
      expect(xml, contains('</w:hyperlink>'));
    });

    test('tài liệu không có numbering/heading style vẫn ghi được', () {
      final doc = DocxReader.read(_fixture());
      // Giả lập file thiếu numbering.xml và style heading 3
      doc.parts.remove('word/numbering.xml');
      final stripped = DocxDocument(
        delta: doc.delta,
        parts: doc.parts,
        documentXml: doc.documentXml,
        pprs: doc.pprs,
        rprs: doc.rprs,
        inlineRaws: doc.inlineRaws,
        blockRaws: doc.blockRaws,
        headingStyleIds: const {},
        numIdIsBullet: const {},
        hasHyperlinkStyle: false,
        warnings: const [],
      );
      final d = Delta()
        ..insert('H3')
        ..insert('\n', {'header': 3})
        ..insert('a')
        ..insert('\n', {'list': 'bullet'})
        ..insert('b')
        ..insert('\n', {'list': 'ordered'});
      final out = DocxWriter.write(stripped, d);
      final again = DocxReader.read(out);
      expect(again.headingStyleIds[3], 'Heading3');
      expect(again.numIdIsBullet.values.where((b) => b).length, 1);
      expect(again.numIdIsBullet.values.where((b) => !b).length, 1);
      final ls = lines(again.delta);
      expect(ls[0].$2['header'], 3);
      expect(ls[1].$2['list'], 'bullet');
      expect(ls[2].$2['list'], 'ordered');
    });
  });
}
