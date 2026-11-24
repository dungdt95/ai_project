import 'dart:convert';

import 'package:doctruyen/data/dao/book_dao.dart';
import 'package:doctruyen/data/database/app_database.dart';
import 'package:doctruyen/domain/drive/drive_models.dart';
import 'package:doctruyen/services/drive_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _folderMime = 'application/vnd.google-apps.folder';

/// Drive giả có nhiều thư mục: thư mục chung `ROOT` chứa thư mục truyện.
class FakeLibraryDrive implements DriveSource {
  final Map<String, String> names = {'ROOT': 'Truyện chữ'};
  final Map<String, List<DriveEntry>> folders = {'ROOT': []};
  final Map<String, String> bodies = {};
  final Set<String> failFolders = {};
  int fetches = 0;

  void addBook(String id, String name, {int chapters = 0}) {
    names[id] = name;
    folders[id] = [];
    folders['ROOT']!.add(
      DriveEntry(id: id, title: name, isDoc: false, mime: _folderMime),
    );
    for (var i = 1; i <= chapters; i++) {
      addChapter(id, i);
    }
  }

  void addChapter(String bookId, int n, {String modified = 'Nov 20'}) {
    final id = '$bookId-c$n';
    folders[bookId]!.add(
      DriveEntry(
        id: id,
        title: 'Chuong_${n.toString().padLeft(2, '0')}.md',
        isDoc: false,
        modified: modified,
      ),
    );
    bodies[id] = '# Chương $n: Tên $n\n\nNội dung $n.';
  }

  @override
  Future<DriveListing> listFolder(String folderId) async {
    if (failFolders.contains(folderId)) throw const DriveException('lỗi mạng');
    final entries = folders[folderId];
    if (entries == null) throw const DriveException('không có thư mục');
    return DriveListing(folderName: names[folderId]!, entries: [...entries]);
  }

  @override
  Future<DriveFile> fetchChapter(DriveEntry entry) async {
    fetches++;
    return DriveFile(
      bytes: utf8.encode(bodies[entry.id]!),
      fileName: entry.title,
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
  late FakeLibraryDrive drive;
  late DriveSyncService svc;
  final now = DateTime(2026, 11, 24, 9);

  setUp(() async {
    db = await AppDatabase.openInMemory();
    dao = BookDao(db);
    drive = FakeLibraryDrive()
      ..addBook('A', 'Từ sơn trại đến bất hủ tiên triều', chapters: 3)
      ..addBook('B', 'Truyện B', chapters: 2);
    svc = DriveSyncService(drive, dao, clock: () => now);
  });

  tearDown(() => db.close());

  test('lần đầu: mỗi thư mục con thành một truyện', () async {
    final r = await svc.syncLibrary('ROOT');
    expect(r.newBooks, ['Từ sơn trại đến bất hủ tiên triều', 'Truyện B']);
    expect(r.syncedBookIds, hasLength(2));
    final books = await dao.listDriveBooks();
    expect(books.map((b) => b.driveFolderId).toSet(), {'A', 'B'});
    final a = books.firstWhere((b) => b.driveFolderId == 'A');
    expect(a.title, 'Từ sơn trại đến bất hủ tiên triều');
    expect((await dao.listChapters(a.id)).map((c) => c.number), [1, 2, 3]);
  });

  test(
    'lần sau: thêm chương mới và truyện mới, không tải lại chương cũ',
    () async {
      await svc.syncLibrary('ROOT');
      drive.fetches = 0;
      drive
        ..addChapter('A', 4)
        ..addBook('C', 'Truyện C', chapters: 1);

      final r = await svc.syncLibrary('ROOT', thorough: false);
      expect(r.newBooks, ['Truyện C']);
      expect(r.addedChapters, 1);
      expect(drive.fetches, 2);
      expect(await dao.listDriveBooks(), hasLength(3));

      final again = await svc.syncLibrary('ROOT');
      expect(again.nothingChanged, isTrue);
    },
  );

  test(
    'bỏ qua thư mục đã ẩn, tệp lẻ ở thư mục chung và thư mục rỗng',
    () async {
      drive
        ..addBook('EMPTY', 'Chưa có chương')
        ..folders['ROOT']!.add(
          const DriveEntry(id: 'loose', title: 'ghi chu.txt', isDoc: false),
        );
      final r = await svc.syncLibrary('ROOT', ignoredFolderIds: {'B'});
      expect(r.newBooks, ['Từ sơn trại đến bất hủ tiên triều']);
      expect(r.failedBooks, isEmpty);
      final ids = (await dao.listDriveBooks()).map((b) => b.driveFolderId);
      expect(ids, ['A']);
    },
  );

  test('một truyện lỗi không chặn truyện khác', () async {
    drive.failFolders.add('A');
    final r = await svc.syncLibrary('ROOT');
    expect(r.newBooks, ['Truyện B']);
    expect(r.failedBooks.keys, ['Từ sơn trại đến bất hủ tiên triều']);
  });

  test('thư mục chung lỗi -> báo lỗi', () async {
    drive.failFolders.add('ROOT');
    await expectLater(svc.syncLibrary('ROOT'), throwsA(isA<DriveException>()));
  });

  test(
    'truyện đã nhập bằng liên kết trước đây được nhận lại, không trùng',
    () async {
      await svc.importFolder('A');
      final r = await svc.syncLibrary('ROOT');
      expect(r.newBooks, ['Truyện B']);
      expect(await dao.listDriveBooks(), hasLength(2));
    },
  );

  test(
    'tự động bỏ qua chương nhãn thời gian không chắc; bấm tay thì tải',
    () async {
      drive.folders['A']!.clear();
      drive.addChapter('A', 1, modified: '11:24 am');
      await svc.syncLibrary('ROOT');
      drive.folders['A']!.clear();
      drive.addChapter('A', 1, modified: 'Nov 24');
      drive.fetches = 0;
      await svc.syncLibrary('ROOT', thorough: false);
      expect(drive.fetches, 0);
      await svc.syncLibrary('ROOT');
      expect(drive.fetches, 1);
    },
  );

  test('hủy giữa chừng', () async {
    final cancel = CancelToken()..cancel();
    await expectLater(
      svc.syncLibrary('ROOT', cancel: cancel),
      throwsA(isA<DriveCancelledException>()),
    );
  });
}
