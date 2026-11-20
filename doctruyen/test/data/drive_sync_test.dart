import 'dart:convert';

import 'package:doctruyen/data/dao/book_dao.dart';
import 'package:doctruyen/data/dao/bookmark_dao.dart';
import 'package:doctruyen/data/database/app_database.dart';
import 'package:doctruyen/data/database/migrations.dart';
import 'package:doctruyen/domain/drive/drive_models.dart';
import 'package:doctruyen/services/drive_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeDrive implements DriveSource {
  FakeDrive(this.name);

  final String name;
  final Map<String, DriveEntry> entries = {};
  final Map<String, String> bodies = {};
  final Map<String, String> fileNames = {};
  int fetches = 0;
  bool signIn = false;
  Set<String> failIds = {};

  void put(
    String id,
    String title,
    String body, {
    String modified = '11:24 am',
    bool doc = false,
    String? fileName,
  }) {
    entries[id] = DriveEntry(
      id: id,
      title: title,
      isDoc: doc,
      modified: modified,
    );
    bodies[id] = body;
    fileNames[id] = fileName ?? (doc ? '' : '$title.markdown');
  }

  @override
  Future<DriveListing> listFolder(String folderId) async {
    if (signIn) throw const DriveSignInRequiredException();
    return DriveListing(folderName: name, entries: entries.values.toList());
  }

  @override
  Future<DriveFile> fetchChapter(DriveEntry entry) async {
    fetches++;
    if (failIds.contains(entry.id)) throw const DriveException('lỗi mạng');
    return DriveFile(
      bytes: utf8.encode(bodies[entry.id]!),
      fileName: fileNames[entry.id]!,
    );
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late BookDao dao;
  late FakeDrive drive;
  late DriveSyncService svc;
  final now = DateTime(2026, 3, 15, 9);

  setUp(() async {
    db = await AppDatabase.openInMemory();
    dao = BookDao(db);
    drive = FakeDrive('Truyện thử');
    for (var i = 1; i <= 5; i++) {
      drive.put(
        'f$i',
        'Chương $i: Tên $i',
        '# Chương $i: Tên $i\n\nNội dung $i.',
        doc: i > 3,
      );
    }
    svc = DriveSyncService(drive, dao, clock: () => now);
  });

  tearDown(() => db.close());

  test('nhập lần đầu: đủ chương, đúng thứ tự, lưu dấu vết Drive', () async {
    final progress = <(int, int)>[];
    final r = await svc.importFolder(
      'FOLDER',
      onProgress: (d, t) => progress.add((d, t)),
    );
    expect(r.isNewBook, isTrue);
    expect(r.added, 5);
    expect(progress.last, (5, 5));
    final book = (await dao.getBook(r.bookId))!;
    expect(book.title, 'Truyện thử');
    expect(book.isDrive, isTrue);
    expect(book.driveFolderId, 'FOLDER');
    final chapters = await dao.listChapters(r.bookId);
    expect(chapters.map((c) => c.number), [1, 2, 3, 4, 5]);
    expect(chapters.first.title, 'Chương 1: Tên 1');
    final stored = await dao.driveChapters(r.bookId);
    expect(stored, hasLength(5));
    expect(stored.every((s) => s.hash.isNotEmpty), isTrue);
    expect(stored.first.modified, '11:24 am');
  });

  test('đồng bộ không đổi gì: không tải lại chương', () async {
    final r = await svc.importFolder('FOLDER');
    drive.fetches = 0;
    final book = (await dao.getBook(r.bookId))!;
    final check = await svc.check(book);
    expect(check.hasUpdates, isFalse);
    final s = await svc.syncBook(book);
    expect(s.nothingChanged, isTrue);
    expect(drive.fetches, 0);
  });

  test('chương mới + chương sửa: giữ tiến độ và dấu trang', () async {
    final r = await svc.importFolder('FOLDER');
    final chapters = await dao.listChapters(r.bookId);
    await dao.saveProgress(
      bookId: r.bookId,
      chapterId: chapters[2].id,
      paragraph: 3,
      fraction: 0.5,
      now: now,
    );
    await BookmarkDao(db).add(
      bookId: r.bookId,
      chapterId: chapters[2].id,
      paragraph: 1,
      snippet: 's',
      now: now,
    );
    await dao.markFinished(chapters[0].id, now);

    drive.put('f6', 'Chương 6: Mới', '# Chương 6: Mới\n\nMới.', doc: true);
    drive.put(
      'f2',
      'Chương 2: Tên 2',
      '# Chương 2: Tên 2\n\nĐã sửa.',
      modified: '12:30 pm',
    );
    final book = (await dao.getBook(r.bookId))!;
    final check = await svc.check(book);
    expect(check.newChapters, 1);
    expect(check.changedChapters, 1);

    drive.fetches = 0;
    final s = await svc.syncBook(book);
    expect(s.added, 1);
    expect(s.updated, 1);
    expect(drive.fetches, 2);

    final after = await dao.listChapters(r.bookId);
    expect(after.map((c) => c.number), [1, 2, 3, 4, 5, 6]);
    // Id chương giữ nguyên nên tiến độ/dấu trang/đã đọc còn.
    expect(after[2].id, chapters[2].id);
    expect(after[0].finished, isTrue);
    final b2 = (await dao.getBook(r.bookId))!;
    expect(b2.lastChapterId, chapters[2].id);
    expect(b2.lastParagraph, 3);
    expect(await BookmarkDao(db).list(r.bookId), hasLength(1));
    expect((await dao.getChapter(after[1].id))!.content, contains('Đã sửa'));

    // Lần sau không còn gì để cập nhật.
    expect((await svc.check(b2)).hasUpdates, isFalse);
  });

  test(
    'nhãn mơ hồ (qua ngày): tải để so băm, nội dung giống thì không sửa',
    () async {
      final r = await svc.importFolder('FOLDER');
      for (final id in drive.entries.keys.toList()) {
        final old = drive.entries[id]!;
        drive.entries[id] = DriveEntry(
          id: id,
          title: old.title,
          isDoc: old.isDoc,
          modified: 'Nov 21',
        );
      }
      final book = (await dao.getBook(r.bookId))!;
      expect((await svc.check(book)).hasUpdates, isFalse);
      final s = await svc.syncBook(book);
      expect(s.nothingChanged, isTrue);
      expect(s.unchanged, 5);
      // Nhãn đã được làm mới nên lần sau không phải tải nữa.
      drive.fetches = 0;
      await svc.syncBook(book);
      expect(drive.fetches, 0);
    },
  );

  test('chương bị xóa trên Drive vẫn được giữ', () async {
    final r = await svc.importFolder('FOLDER');
    drive.entries.remove('f5');
    final book = (await dao.getBook(r.bookId))!;
    final s = await svc.syncBook(book);
    expect(s.nothingChanged, isTrue);
    expect(await dao.listChapters(r.bookId), hasLength(5));
  });

  test('chương tải lỗi: bỏ qua và thử lại lần sau', () async {
    drive.failIds = {'f3'};
    final r = await svc.importFolder('FOLDER');
    expect(r.added, 4);
    expect(r.failed, 1);
    drive.failIds = {};
    final book = (await dao.getBook(r.bookId))!;
    final s = await svc.syncBook(book);
    expect(s.added, 1);
    expect((await dao.listChapters(r.bookId)).map((c) => c.number), [
      1,
      2,
      3,
      4,
      5,
    ]);
  });

  test('bỏ qua tệp không phải văn bản', () async {
    drive.put('img', 'Chương 9: ảnh', 'x', fileName: 'anh.png');
    final r = await svc.importFolder('FOLDER');
    expect(r.skipped, 1);
    expect(r.added, 5);
  });

  test('Docs xuất .txt (BOM, CRLF, không #) vẫn ra chương đúng', () async {
    drive.entries.clear();
    drive.put(
      'd1',
      'Chương 1: A',
      '﻿Chương 1: A\r\nĐoạn.\r\n\r\n\r\nĐoạn 2.',
      doc: true,
    );
    final r = await svc.importFolder('FOLDER');
    final c = (await dao.getChapter(
      (await dao.listChapters(r.bookId)).first.id,
    ))!;
    expect(c.content, '# Chương 1: A\n\nĐoạn.\n\nĐoạn 2.');
  });

  test('thư mục riêng tư -> lỗi đăng nhập; hủy giữa chừng không lưu', () async {
    drive.signIn = true;
    await expectLater(
      svc.importFolder('FOLDER'),
      throwsA(isA<DriveSignInRequiredException>()),
    );
    drive.signIn = false;
    final cancel = CancelToken();
    await expectLater(
      svc.importFolder(
        'FOLDER',
        cancel: cancel,
        onProgress: (d, t) {
          if (d >= 1) cancel.cancel();
        },
      ),
      throwsA(isA<DriveCancelledException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await dao.listBooks(), isEmpty);
  });

  test('thư mục rỗng -> lỗi dễ hiểu', () async {
    drive.entries.clear();
    await expectLater(
      svc.importFolder('FOLDER'),
      throwsA(isA<DriveException>()),
    );
  });

  test('di trú v1 -> v2 thêm cột Drive', () async {
    final file = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (d, _) async {
          await d.execute(
            'CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, source_type TEXT, created_at INTEGER)',
          );
          await d.execute(
            'CREATE TABLE chapters (id INTEGER PRIMARY KEY, book_id INTEGER, number INTEGER, title TEXT, content TEXT)',
          );
          await d.insert('books', {
            'title': 'Cũ',
            'source_type': 'zip',
            'created_at': 1,
          });
        },
      ),
    );
    await Migrations.run(file, 1, 2);
    final rows = await file.query('books');
    expect(rows.single['drive_folder_id'], '');
    expect(rows.single['drive_synced_at'], isNull);
    await file.insert('chapters', {
      'book_id': 1,
      'number': 1,
      'title': 't',
      'content': 'c',
      'drive_file_id': 'x',
    });
    final c = await file.query('chapters');
    expect(c.single['content_hash'], '');
    await file.close();
  });
}
