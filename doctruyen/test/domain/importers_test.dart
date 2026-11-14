import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:doctruyen/domain/importers/book_importer.dart';
import 'package:doctruyen/domain/importers/epub_importer.dart';
import 'package:doctruyen/domain/importers/parsed_book.dart';
import 'package:doctruyen/domain/importers/text_decoder.dart';
import 'package:doctruyen/domain/importers/txt_importer.dart';
import 'package:doctruyen/domain/importers/zip_importer.dart';
import 'package:doctruyen/domain/models/book.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List utf16(String s, {required bool le, bool bom = true}) {
  final out = <int>[];
  if (bom) out.addAll(le ? [0xFF, 0xFE] : [0xFE, 0xFF]);
  for (final u in s.codeUnits) {
    if (le) {
      out
        ..add(u & 0xFF)
        ..add(u >> 8);
    } else {
      out
        ..add(u >> 8)
        ..add(u & 0xFF);
    }
  }
  return Uint8List.fromList(out);
}

Uint8List zipOf(Map<String, String> files) {
  final a = Archive();
  files.forEach((name, text) {
    final bytes = utf8.encode(text);
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encodeBytes(a));
}

void main() {
  group('ZipImporter (gói mẫu)', () {
    late ParsedBook book;

    setUpAll(() {
      final bytes = File('test/fixtures/sample_story.zip').readAsBytesSync();
      book = ZipImporter.parseBytes(bytes, 'Thiên Thư Vô Danh.zip');
    });

    test('đọc tên sách, quyển, hồi và chương', () {
      expect(book.title, 'Thiên Thư Vô Danh');
      expect(book.volume, 'Quyển 1 · Trang Giấy Trắng');
      expect(book.sourceType, SourceType.zip);
      expect(book.arcs.length, 4);
      expect(book.arcs.first.name, 'Hồi 1 · Kẻ Không Tên');
      expect(book.arcs.first.from, 1);
      expect(book.arcs.first.to, 6);
      expect(book.chapters.length, 14);
      expect(book.chapters.first.number, 1);
      expect(book.chapters.first.title, 'Chương 1: Mệnh Giám Không Sáng');
      expect(book.chapters.last.number, 14);
    });

    test('nội dung chương có chữ, và không lẫn ghi chú tác giả', () {
      for (final c in book.chapters) {
        expect(c.content.trim(), isNotEmpty, reason: c.title);
        expect(c.wordCount, greaterThan(100), reason: c.title);
      }
      expect(book.chapters.first.content, contains('Trấn Thanh Thạch'));
    });
  });

  group('ZipImporter (tổng hợp)', () {
    test('bỏ qua notes/ và index.html; thiếu tệp chương thì bỏ chương đó', () {
      final bytes = zipOf({
        'chapters.json': jsonEncode({
          'book': 'Sách',
          'volume': 'Q1',
          'arcs': [
            {'name': 'Hồi 1', 'from': 1, 'to': 2},
          ],
          'chapters': [
            {'n': 2, 'title': 'Hai', 'file': 'chuong/b.md'},
            {'n': 1, 'title': 'Một', 'file': 'chuong/a.md'},
            {'n': 3, 'title': 'Ba', 'file': 'chuong/missing.md'},
          ],
        }),
        'chuong/a.md': '# Chương 1: Một\n\nNội dung A',
        'chuong/b.md': '# Chương 2: Hai\n\nNội dung B',
        'notes/ghi_chu.md': 'KHÔNG ĐƯỢC NHẬP',
        'index.html': '<html></html>',
      });
      final b = ZipImporter.parseBytes(bytes, 'x.zip');
      expect(b.chapters.map((c) => c.number), [1, 2]);
      expect(b.chapters.any((c) => c.content.contains('KHÔNG')), isFalse);
    });

    test('ZIP hỏng hoặc không có chương thì báo lỗi rõ ràng', () {
      expect(
        () => ZipImporter.parseBytes([1, 2, 3], 'x.zip'),
        throwsA(isA<ImportException>()),
      );
      expect(
        () => ZipImporter.parseBytes(zipOf({'readme.bin': 'x'}), 'x.zip'),
        throwsA(isA<ImportException>()),
      );
    });

    test('không có chapters.json: dùng các tệp .md theo thứ tự tự nhiên', () {
      final bytes = zipOf({
        'c10.md': '# Mười\nx',
        'c2.md': '# Hai\ny',
        'notes/n.md': 'bỏ',
      });
      final b = ZipImporter.parseBytes(bytes, 'Truyện X.zip');
      expect(b.title, 'Truyện X');
      expect(b.chapters.map((c) => c.title), ['Hai', 'Mười']);
    });
  });

  group('TextDecoder', () {
    test('UTF-8 có và không BOM', () {
      expect(TextDecoder.decode(utf8.encode('Chương 1 ệ')), 'Chương 1 ệ');
      expect(
        TextDecoder.decode([0xEF, 0xBB, 0xBF, ...utf8.encode('Chương')]),
        'Chương',
      );
    });

    test('UTF-16 LE/BE có BOM và LE không BOM', () {
      expect(
        TextDecoder.decode(utf16('Chương 12: Đầu', le: true)),
        'Chương 12: Đầu',
      );
      expect(
        TextDecoder.decode(utf16('Chương 12: Đầu', le: false)),
        'Chương 12: Đầu',
      );
      expect(
        TextDecoder.decode(
          utf16('Hello world, chào bạn', le: true, bom: false),
        ),
        'Hello world, chào bạn',
      );
    });

    test('UTF-8 hỏng thì rơi về Windows-1258', () {
      // "Chương" và "Việt" (ê + dấu nặng rời) theo cp1258.
      expect(
        TextDecoder.decode([0x43, 0x68, 0xFD, 0xF5, 0x6E, 0x67]),
        'Chương',
      );
      expect(TextDecoder.decode([0x56, 0x69, 0xEA, 0xF2, 0x74]), 'Việt');
    });
  });

  group('TxtImporter', () {
    test('tách chương theo Chương/CHƯƠNG số La Mã/Chapter/Hồi', () {
      const text = '''
Lời tựa rất ngắn.

Chương 1: Khởi đầu
Đoạn một.
Đoạn hai.

CHƯƠNG XII - Giữa chừng
Nội dung mười hai.

Chapter 3
Nội dung ba.

Hồi 5: Kết
Nội dung năm.
''';
      final b = TxtImporter.parseText(text, 'Truyện');
      expect(b.chapters.length, 4);
      expect(b.chapters[0].title, 'Chương 1: Khởi đầu');
      expect(b.chapters[0].content, contains('Đoạn hai.'));
      expect(b.chapters[1].title, 'CHƯƠNG XII - Giữa chừng');
      expect(b.chapters[2].title, 'Chapter 3');
      expect(b.chapters[3].title, 'Hồi 5: Kết');
      expect(b.chapters.map((c) => c.number), [1, 2, 3, 4]);
      // Lời tựa < 200 ký tự bị bỏ.
      expect(b.chapters.any((c) => c.content.contains('Lời tựa')), isFalse);
    });

    test(
      'câu văn bắt đầu bằng "Hồi 5 năm trước," không bị nhận là tiêu đề',
      () {
        const text =
            'Chương 1\nHồi 5 năm trước, anh ta còn nghèo.\nChương 2\nHết.';
        final b = TxtImporter.parseText(text, 'T');
        expect(b.chapters.length, 2);
        expect(b.chapters[0].content, contains('Hồi 5 năm trước'));
      },
    );

    test('lời mở đầu dài được giữ thành chương "Mở đầu"', () {
      final preface = 'Lời nói đầu. ' * 30;
      final b = TxtImporter.parseText(
        '$preface\nChương 1\nA\nChương 2\nB',
        'T',
      );
      expect(b.chapters.first.title, 'Mở đầu');
      expect(b.chapters.length, 3);
    });

    test('không có tiêu đề chương: cắt ~5000 ký tự mỗi phần', () {
      final para = 'Một câu văn dài vừa phải để thử cắt phần. ' * 5;
      final text = List.filled(60, para).join('\n');
      final b = TxtImporter.parseText(text, 'Dài');
      expect(b.chapters.length, greaterThan(1));
      expect(b.chapters.first.title, 'Phần 1');
      for (final c in b.chapters.take(b.chapters.length - 1)) {
        expect(c.content.length, inInclusiveRange(5000, 5600));
      }
    });

    test('tên sách lấy từ tên tệp; nhận diện bảng mã qua parseBytes', () {
      final b = TxtImporter.parseBytes(
        utf16('Chương 1\nA\nChương 2\nB', le: true),
        'C:/x/Đại Đạo.txt',
      );
      expect(b.title, 'Đại Đạo');
      expect(b.chapters.length, 2);
      expect(
        BookImporter.parse(
          utf8.encode('Chương 1\nA\nChương 2\nB'),
          'a.txt',
        ).chapters.length,
        2,
      );
    });
  });

  group('EpubImporter', () {
    Uint8List buildEpub() {
      final a = Archive();
      void add(String name, String text) {
        final bytes = utf8.encode(text);
        a.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      add('mimetype', 'application/epub+zip');
      add(
        'META-INF/container.xml',
        '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
            '<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
      );
      add(
        'OEBPS/content.opf',
        '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0">'
            '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Truyện Thử</dc:title><dc:creator>Tác Giả</dc:creator></metadata>'
            '<manifest>'
            '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'
            '<item id="c1" href="text/c1.xhtml" media-type="application/xhtml+xml"/>'
            '<item id="c2" href="text/c2.xhtml" media-type="application/xhtml+xml"/>'
            '<item id="empty" href="text/empty.xhtml" media-type="application/xhtml+xml"/>'
            '</manifest><spine toc="ncx"><itemref idref="c2"/><itemref idref="empty"/><itemref idref="c1"/></spine></package>',
      );
      add(
        'OEBPS/toc.ncx',
        '<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"><navMap>'
            '<navPoint id="n1"><navLabel><text>Mở Đầu</text></navLabel><content src="text/c1.xhtml"/></navPoint>'
            '<navPoint id="n2"><navLabel><text>Cuộc Gặp</text></navLabel><content src="text/c2.xhtml#top"/></navPoint>'
            '</navMap></ncx>',
      );
      add(
        'OEBPS/text/c1.xhtml',
        '<html><head><title>x</title><style>p{color:red}</style></head><body><h1>Mở Đầu</h1>'
            '<p>Trời <em>mưa</em> &amp; gió&nbsp;lớn.</p><p>— Ai đó?<br/>— Ta &#273;ây.</p></body></html>',
      );
      add(
        'OEBPS/text/c2.xhtml',
        '<html><body><h2>Tiêu đề trong thân</h2><p>Hai &ldquo;người&rdquo; gặp nhau.</p><hr/><p><strong>Hết</strong></p></body></html>',
      );
      add('OEBPS/text/empty.xhtml', '<html><body></body></html>');
      return Uint8List.fromList(ZipEncoder().encodeBytes(a));
    }

    test('đọc metadata, thứ tự spine, tiêu đề từ NCX, bỏ trang rỗng', () {
      final b = EpubImporter.parseBytes(buildEpub(), 'x.epub');
      expect(b.title, 'Truyện Thử');
      expect(b.author, 'Tác Giả');
      expect(b.sourceType, SourceType.epub);
      expect(b.chapters.length, 2);
      // spine: c2 trước c1
      expect(b.chapters[0].title, 'Cuộc Gặp');
      expect(b.chapters[1].title, 'Mở Đầu');
      expect(b.chapters.map((c) => c.number), [1, 2]);
    });

    test('HTML được đưa về đoạn văn, giữ nghiêng/đậm, giải mã thực thể', () {
      final b = EpubImporter.parseBytes(buildEpub(), 'x.epub');
      final c1 = b.chapters[1].content.split('\n');
      expect(c1, contains('Trời *mưa* & gió lớn.'));
      expect(c1, contains('— Ai đó?'));
      expect(c1, contains('— Ta đây.'));
      expect(b.chapters[0].content, contains('Hai “người” gặp nhau.'));
      expect(b.chapters[0].content, contains('---'));
      expect(b.chapters[0].content, contains('**Hết**'));
      expect(b.chapters[1].content, isNot(contains('color:red')));
    });

    test('tệp không phải EPUB thì báo lỗi', () {
      expect(
        () => EpubImporter.parseBytes(zipOf({'a.txt': 'x'}), 'x.epub'),
        throwsA(isA<ImportException>()),
      );
    });
  });
}
