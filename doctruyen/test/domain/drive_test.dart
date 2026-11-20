import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:doctruyen/domain/drive/chapter_naming.dart';
import 'package:doctruyen/domain/drive/chapter_normalizer.dart';
import 'package:doctruyen/domain/drive/drive_link.dart';
import 'package:doctruyen/domain/drive/drive_listing_parser.dart';
import 'package:doctruyen/domain/drive/drive_models.dart';
import 'package:doctruyen/domain/drive/drive_plan.dart';
import 'package:doctruyen/domain/importers/local_chapters_importer.dart';
import 'package:flutter_test/flutter_test.dart';

DriveEntry e(String id, String title, {String modified = '11:24 am'}) =>
    DriveEntry(id: id, title: title, isDoc: false, modified: modified);

void main() {
  group('DriveLink.parseFolderId', () {
    const id = '1zscBkqIakWhQJiHlOc3WWCo5riJnMfgk';
    test('các dạng liên kết', () {
      expect(
        DriveLink.parseFolderId(
          'https://drive.google.com/drive/folders/$id?usp=drive_link',
        ),
        id,
      );
      expect(
        DriveLink.parseFolderId(
          'https://drive.google.com/drive/u/0/folders/$id',
        ),
        id,
      );
      expect(
        DriveLink.parseFolderId('https://drive.google.com/open?id=$id'),
        id,
      );
      expect(DriveLink.parseFolderId('  $id  '), id);
    });
    test('không hợp lệ', () {
      expect(DriveLink.parseFolderId(''), isNull);
      expect(DriveLink.parseFolderId('hello world'), isNull);
      expect(DriveLink.parseFolderId('https://example.com/abc'), isNull);
    });
  });

  group('DriveListingParser', () {
    final html = File('test/fixtures/drive_list.html').readAsStringSync();
    test('đọc thư mục thật: tên, 30 mục, Docs và tệp tải lên', () {
      final l = DriveListingParser.parse(html);
      expect(l.folderName, 'Biên Hoang Lười Biếng: Sau Rèm Thao Túng Thiên Hạ');
      expect(l.entries, hasLength(30));
      final c10 = l.entries.firstWhere((x) => x.title.startsWith('Chương 10:'));
      expect(c10.isDoc, isFalse);
      expect(c10.id, '13E-RkYbLmswHazwC45LAEm7FKSIeHHTN');
      expect(c10.mime, 'text/markdown');
      expect(c10.modified, '11:24 am');
      final c11 = l.entries.firstWhere((x) => x.title.startsWith('Chương 11:'));
      expect(c11.isDoc, isTrue);
      expect(c11.isTextual, isTrue);
      // &quot; được giải mã.
      expect(
        l.entries.any((x) => x.title.contains('"Ve Sầu Thoát Xác"')),
        isTrue,
      );
    });
    test('trang đăng nhập', () {
      const signIn =
          '<html><head><title>Sign in - Google Accounts</title></head>'
          '<body><a href="https://accounts.google.com/ServiceLogin">x</a></body></html>';
      expect(DriveListingParser.isSignInPage(signIn), isTrue);
      expect(DriveListingParser.isSignInPage(html), isFalse);
      expect(
        () => DriveListingParser.parse(signIn),
        throwsA(isA<DriveSignInRequiredException>()),
      );
    });
    test('trang lạ -> lỗi, thư mục rỗng -> danh sách rỗng', () {
      expect(
        () => DriveListingParser.parse('<html>404</html>'),
        throwsA(isA<DriveException>()),
      );
      final empty = DriveListingParser.parse(
        '<html><head><title>X</title></head><body><div id="flip-contents">'
        '<div class="flip-entries"></div></div></body></html>',
      );
      expect(empty.entries, isEmpty);
    });
    test('bỏ qua ảnh/thư mục khi chọn chương', () {
      const img = DriveEntry(
        id: 'a',
        title: 'cover',
        isDoc: false,
        mime: 'image/png',
      );
      const dir = DriveEntry(
        id: 'b',
        title: 'sub',
        isDoc: false,
        mime: 'application/vnd.google-apps.folder',
      );
      expect(img.isTextual, isFalse);
      expect(dir.isTextual, isFalse);
    });
  });

  group('ChapterNaming', () {
    test('rút số chương', () {
      expect(ChapterNaming.numberOf('Chương 12: abc'), 12);
      expect(ChapterNaming.numberOf('chuong 3'), 3);
      expect(ChapterNaming.numberOf('Chapter 7 - x'), 7);
      expect(ChapterNaming.numberOf('Hồi 5'), 5);
      expect(ChapterNaming.numberOf('Lời mở đầu'), isNull);
    });
    test('thứ tự: số trước, không số xếp cuối theo tên tự nhiên', () {
      final entries = [
        e('a', 'Chương 10: x'),
        e('b', 'Phụ lục 2'),
        e('c', 'Chương 2: y'),
        e('d', 'Phụ lục 10'),
        e('f', 'Chương 1: z'),
      ];
      final n = ChapterNaming.assign(entries);
      expect(n['f'], 1);
      expect(n['c'], 2);
      expect(n['a'], 10);
      expect(n['b'], 11);
      expect(n['d'], 12);
    });
    test('số trùng: mục đến sau bị coi như không có số', () {
      final n = ChapterNaming.assign([
        e('a', 'Chương 1: A'),
        e('b', 'Chương 1: B'),
      ]);
      expect({n['a'], n['b']}, {1, 2});
    });
  });

  group('ChapterNormalizer', () {
    test('markdown tải lên: giữ tiêu đề, bỏ BOM/CRLF', () {
      final n = ChapterNormalizer.normalize(
        '﻿# Chương 1: Mở đầu\r\n\r\nĐoạn một.\r\n\r\nĐoạn hai.\r\n',
        'tên tệp',
      );
      expect(n.title, 'Chương 1: Mở đầu');
      expect(n.content, '# Chương 1: Mở đầu\n\nĐoạn một.\n\nĐoạn hai.');
    });
    test('xuất .txt: tiêu đề không có #, 2 dòng trống giữa đoạn', () {
      final n = ChapterNormalizer.normalize(
        '﻿Chương 11: Bố Cục\r\nĐoạn một.\r\n\r\n\r\nĐoạn hai.',
        'x',
      );
      expect(n.title, 'Chương 11: Bố Cục');
      expect(n.content.startsWith('# Chương 11: Bố Cục\n'), isTrue);
      expect(n.content.contains('\n\n\n'), isFalse);
    });
    test('không có tiêu đề: dùng tên tệp bỏ phần mở rộng', () {
      final n = ChapterNormalizer.normalize('Chỉ có văn.\n', 'Tập 1.markdown');
      expect(ChapterNormalizer.stripExtension('Tập 1.markdown'), 'Tập 1');
      expect(n.title, 'Tập 1.markdown');
      final m = ChapterNormalizer.normalize(
        'Chỉ có văn.',
        ChapterNormalizer.stripExtension('Tập 1.markdown'),
      );
      expect(m.title, 'Tập 1');
      expect(m.content, '# Tập 1\n\nChỉ có văn.');
    });
    test('băm ổn định, đổi khi nội dung đổi, md và txt cùng nội dung khớp', () {
      final a = ChapterNormalizer.normalize('# T\n\nX', 'f');
      final b = ChapterNormalizer.normalize('# T\r\n\r\nX', 'f');
      final c = ChapterNormalizer.normalize('# T\n\nY', 'f');
      expect(a.hash, b.hash);
      expect(a.hash, isNot(c.hash));
    });
    test('mẫu thật: .markdown, Docs md và Docs txt cho cùng dạng', () {
      final up = ChapterNormalizer.fromBytes(
        File('test/fixtures/drive_ch01.markdown').readAsBytesSync(),
        'f',
      );
      expect(up.title.startsWith('Chương 1:'), isTrue);
      final md = ChapterNormalizer.fromBytes(
        File('test/fixtures/drive_ch11.md').readAsBytesSync(),
        'f',
      );
      final txt = ChapterNormalizer.fromBytes(
        File('test/fixtures/drive_ch11.txt').readAsBytesSync(),
        'f',
      );
      expect(md.title, txt.title);
      expect(md.content.startsWith('# '), isTrue);
      expect(txt.content.startsWith('# '), isTrue);
      expect(md.content, contains('Nắng xuân phủ'));
      expect(txt.content, contains('Nắng xuân phủ'));
      expect(txt.content.contains('\n\n\n'), isFalse);
    });
  });

  group('DrivePlan', () {
    StoredChapterRef s(String id, int n, String mod) =>
        StoredChapterRef(fileId: id, number: n, modified: mod);

    test('lần đầu: tất cả là mới, đúng thứ tự', () {
      final p = DrivePlan.compute([
        e('b', 'Chương 2: b'),
        e('a', 'Chương 1: a'),
      ], const []);
      expect(p.added.map((x) => x.id), ['a', 'b']);
      expect(p.hasUpdates, isTrue);
    });
    test('mới / đổi / không đổi / mơ hồ', () {
      final p = DrivePlan.compute(
        [
          e('a', 'Chương 1: a'),
          e('b', 'Chương 2: b', modified: '12:00 pm'),
          e('c', 'Chương 3: c', modified: 'Nov 21'),
          e('d', 'Chương 4: d'),
        ],
        [s('a', 1, '11:24 am'), s('b', 2, '11:24 am'), s('c', 3, '11:24 am')],
        existingNumbers: {1, 2, 3},
      );
      expect(p.unchanged.map((x) => x.id), ['a']);
      expect(p.changed.map((x) => x.id), ['b']);
      expect(p.ambiguous.map((x) => x.id), ['c']);
      expect(p.added.map((x) => x.id), ['d']);
      expect(p.numbers['d'], 4);
      expect(p.hasUpdates, isTrue);
      expect(p.toFetch(includeAmbiguous: false).map((x) => x.id), ['d', 'b']);
    });
    test('không có gì mới', () {
      final p = DrivePlan.compute(
        [e('a', 'Chương 1: a')],
        [s('a', 1, '11:24 am')],
        existingNumbers: {1},
      );
      expect(p.hasUpdates, isFalse);
    });
    test('tệp không số không đè lên số chương cũ đã bị xóa khỏi Drive', () {
      final p = DrivePlan.compute(
        [e('x', 'Phụ lục')],
        [s('gone', 9, '11:24 am')],
        existingNumbers: {9},
      );
      expect(p.numbers['x'], 10);
    });
    test('tệp thay thế cùng "Chương N" nhận lại số N', () {
      final p = DrivePlan.compute(
        [e('new', 'Chương 5: lại')],
        [s('old', 5, '11:24 am')],
        existingNumbers: {5},
      );
      expect(p.numbers['new'], 5);
    });
    test('compareModified', () {
      expect(DrivePlan.compareModified('11:24 am', '11:24 am'), 0);
      expect(DrivePlan.compareModified('11:24 am', '11:30 am'), 1);
      expect(DrivePlan.compareModified('11:24 am', 'Nov 21'), 2);
      expect(DrivePlan.compareModified('Nov 20', 'Nov 21'), 1);
      expect(DrivePlan.compareModified('', '11:24 am'), 2);
    });
  });

  group('LocalChaptersImporter', () {
    Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));
    test('nhiều tệp .md theo số chương', () {
      final book = LocalChaptersImporter.build({
        'Chương 10.md': b('# Chương 10: Z\n\nz'),
        'Chương 2.markdown': b('# Chương 2: B\n\nb'),
        'Chương 1.txt': b('Chương 1: A\n\na'),
      }, 'Truyện thử');
      expect(book.title, 'Truyện thử');
      expect(book.chapters.map((c) => c.number), [1, 2, 10]);
      expect(book.chapters.first.title, 'Chương 1: A');
    });
    test('có chapters.json', () {
      final book = LocalChaptersImporter.build({
        'chapters.json': b(
          '{"book":"Sách","chapters":[{"n":1,"file":"a.md","title":"Một"}]}',
        ),
        'a.md': b('# Chương 1: Một\n\nx'),
      }, 'Tên khác');
      expect(book.title, 'Tên khác');
      expect(book.chapters.single.number, 1);
    });
  });
}
