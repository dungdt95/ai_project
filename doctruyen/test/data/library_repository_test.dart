import 'dart:io';

import 'package:doctruyen/data/dao/book_dao.dart';
import 'package:doctruyen/data/dao/bookmark_dao.dart';
import 'package:doctruyen/data/dao/stats_dao.dart';
import 'package:doctruyen/data/database/app_database.dart';
import 'package:doctruyen/data/repositories/library_repository.dart';
import 'package:doctruyen/domain/importers/parsed_book.dart';
import 'package:doctruyen/domain/importers/zip_importer.dart';
import 'package:doctruyen/domain/stats/activity_accumulator.dart';
import 'package:doctruyen/domain/stats/stats_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late LibraryRepository repo;
  late StatsDao statsDao;
  late ParsedBook full;
  final now = DateTime(2026, 3, 15, 9);

  setUp(() async {
    db = await AppDatabase.openInMemory();
    repo = LibraryRepository(BookDao(db), BookmarkDao(db), clock: () => now);
    statsDao = StatsDao(db);
    full = ZipImporter.parseBytes(
      File('test/fixtures/sample_story.zip').readAsBytesSync(),
      'sample.zip',
    );
  });

  tearDown(() => db.close());

  /// Bản "cũ" của truyện: thiếu chương 14 và chương 3 có nội dung khác.
  ParsedBook olderVersion() => ParsedBook(
    title: full.title,
    volume: full.volume,
    sourceType: full.sourceType,
    arcs: full.arcs,
    chapters: [
      for (final c in full.chapters.take(13))
        ParsedChapter(
          number: c.number,
          title: c.title,
          content: c.number == 3 ? 'Bản nháp cũ của chương 3.' : c.content,
        ),
    ],
  );

  test('nhập truyện mới: sách, hồi, chương và mục lục theo thứ tự', () async {
    final r = await repo.importParsed(full);
    expect(r.isUpdate, isFalse);
    expect(r.added, 14);
    final book = (await repo.getBook(r.bookId))!;
    expect(book.chapterCount, 14);
    expect(book.progress, 0);
    expect((await repo.listArcs(r.bookId)).length, 4);
    final chapters = await repo.listChapters(r.bookId);
    expect(chapters.map((c) => c.number), List.generate(14, (i) => i + 1));
    final ch = (await repo.getChapter(chapters.first.id))!;
    expect(ch.content, contains('Trấn Thanh Thạch'));
  });

  test('nhập lại bản mới hơn: thêm chương, sửa chương đổi, giữ tiến độ/dấu trang/thống kê', () async {
    final first = await repo.importParsed(olderVersion());
    expect(first.added, 13);
    final chapters = await repo.listChapters(first.bookId);
    final ch5 = chapters.firstWhere((c) => c.number == 5);
    final ch3 = chapters.firstWhere((c) => c.number == 3);

    // Người dùng đọc tới giữa chương 5, đặt dấu trang ở chương 3, xong chương 3.
    await repo.saveProgress(
      bookId: first.bookId,
      chapterId: ch5.id,
      paragraph: 7,
      fraction: 0.5,
    );
    await repo.toggleBookmark(
      bookId: first.bookId,
      chapterId: ch3.id,
      paragraph: 2,
      snippet: 'dấu trang',
    );
    await repo.markChapterFinished(ch3.id);
    final acc = ActivityAccumulator()
      ..setListening(first.bookId)
      ..tick(now);
    for (var i = 1; i <= 30; i++) {
      acc.tick(now.add(Duration(seconds: i)));
    }
    await statsDao.addSeconds(acc.drain());

    final before = (await repo.getBook(first.bookId))!;
    expect(before.progress, closeTo((4 + 0.5) / 13, 1e-9));

    final second = await repo.importParsed(full);
    expect(second.isUpdate, isTrue);
    expect(second.bookId, first.bookId);
    expect(second.added, 1);
    expect(second.updated, 1); // chương 3 được khôi phục nội dung mới
    expect(second.unchanged, 12);

    final after = (await repo.getBook(first.bookId))!;
    expect(after.chapterCount, 14);
    expect(after.lastChapterId, ch5.id);
    expect(after.lastParagraph, 7);
    expect(after.progress, closeTo((4 + 0.5) / 14, 1e-9));

    final updated3 = (await repo.getChapter(ch3.id))!;
    expect(updated3.content, isNot(contains('Bản nháp cũ')));
    expect(updated3.info.finished, isTrue);
    expect((await repo.bookmarks(first.bookId)).single.paragraph, 2);

    final rows = await statsDao.since('2026-03-01');
    expect(rows.single.listenSeconds, 30);
    expect(rows.single.chaptersFinished, 1);
    expect((await repo.listBooks()).length, 1);
  });

  test(
    'bookmark bật/tắt, tìm trong truyện không phân biệt dấu, xóa sách xóa hết',
    () async {
      final r = await repo.importParsed(full);
      final ch = (await repo.listChapters(r.bookId)).first;
      expect(
        await repo.toggleBookmark(
          bookId: r.bookId,
          chapterId: ch.id,
          paragraph: 1,
          snippet: 's',
        ),
        isTrue,
      );
      expect(
        await repo.toggleBookmark(
          bookId: r.bookId,
          chapterId: ch.id,
          paragraph: 1,
          snippet: 's',
        ),
        isFalse,
      );

      final hits = await repo.searchInBook(r.bookId, 'tran thanh thach');
      expect(hits, isNotEmpty);
      expect(hits.first.snippet.toLowerCase(), contains('thanh thạch'));

      await repo.markChapterFinished(ch.id);
      await repo.deleteBook(r.bookId);
      expect(await repo.listBooks(), isEmpty);
      expect(await statsDao.since('2000-01-01'), isEmpty);
    },
  );

  test(
    'markChapterFinished chỉ đếm một lần; tổng hợp thống kê từ DB',
    () async {
      final r = await repo.importParsed(full);
      final ch = (await repo.listChapters(r.bookId)).first;
      expect(await repo.markChapterFinished(ch.id), isTrue);
      expect(await repo.markChapterFinished(ch.id), isFalse);
      final rows = await statsDao.since('2026-03-01');
      final s = StatsAggregator.summarize(rows, now);
      expect(s.today.chaptersFinished, 1);
      expect(s.streak, 1);
    },
  );
}
