import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/importers/parsed_book.dart';
import '../../domain/models/book.dart';
import '../../domain/stats/stats_aggregator.dart';
import '../database/app_database.dart';

/// Kết quả nhập/cập nhật một truyện.
class ImportResult {
  const ImportResult({
    required this.bookId,
    required this.isUpdate,
    required this.added,
    required this.updated,
    required this.unchanged,
  });

  final int bookId;
  final bool isUpdate;
  final int added;
  final int updated;
  final int unchanged;
}

class BookDao {
  BookDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static const String _bookSelect = '''
SELECT b.*,
  (SELECT COUNT(*) FROM chapters c WHERE c.book_id = b.id) AS chapter_count,
  CASE WHEN b.last_chapter_id IS NULL THEN 0 ELSE
    ((SELECT COUNT(*) FROM chapters c WHERE c.book_id = b.id AND c.number <
        (SELECT number FROM chapters WHERE id = b.last_chapter_id))
      + b.last_fraction) * 1.0
    / MAX(1, (SELECT COUNT(*) FROM chapters c WHERE c.book_id = b.id))
  END AS progress
FROM books b''';

  Future<List<Book>> listBooks() async {
    final rows = await _db.rawQuery(_bookSelect);
    return rows.map(Book.fromMap).toList();
  }

  Future<Book?> getBook(int id) async {
    final rows = await _db.rawQuery('$_bookSelect WHERE b.id = ?', [id]);
    return rows.isEmpty ? null : Book.fromMap(rows.first);
  }

  Future<void> deleteBook(int id) =>
      _db.delete(Tables.books, where: 'id = ?', whereArgs: [id]);

  Future<List<Arc>> listArcs(int bookId) async {
    final rows = await _db.query(
      Tables.arcs,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'from_number',
    );
    return rows
        .map(
          (r) => Arc(
            name: r['name']! as String,
            from: r['from_number']! as int,
            to: r['to_number']! as int,
          ),
        )
        .toList();
  }

  static const _infoColumns = [
    'id',
    'book_id',
    'number',
    'title',
    'finished',
    'word_count',
  ];

  Future<List<ChapterInfo>> listChapters(int bookId) async {
    final rows = await _db.query(
      Tables.chapters,
      columns: _infoColumns,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'number',
    );
    return rows.map(ChapterInfo.fromMap).toList();
  }

  Future<Chapter?> getChapter(int id) async {
    final rows = await _db.query(
      Tables.chapters,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Chapter(
      info: ChapterInfo.fromMap(rows.first),
      content: rows.first['content']! as String,
    );
  }

  Future<ChapterInfo?> firstChapter(int bookId) async {
    final rows = await _db.query(
      Tables.chapters,
      columns: _infoColumns,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'number',
      limit: 1,
    );
    return rows.isEmpty ? null : ChapterInfo.fromMap(rows.first);
  }

  /// Chương liền sau/trước theo số chương ([forward] = true là sau).
  Future<ChapterInfo?> neighbour(int chapterId, {required bool forward}) async {
    final op = forward ? '>' : '<';
    final order = forward ? 'ASC' : 'DESC';
    final rows = await _db.rawQuery(
      'SELECT ${_infoColumns.join(', ')} FROM chapters '
      'WHERE book_id = (SELECT book_id FROM chapters WHERE id = ?) '
      'AND number $op (SELECT number FROM chapters WHERE id = ?) '
      'ORDER BY number $order LIMIT 1',
      [chapterId, chapterId],
    );
    return rows.isEmpty ? null : ChapterInfo.fromMap(rows.first);
  }

  /// Duyệt nội dung từng nhóm chương (dùng cho tìm kiếm trong truyện).
  Future<List<Chapter>> chaptersWithContent(
    int bookId, {
    int offset = 0,
    int limit = 20,
  }) async {
    final rows = await _db.query(
      Tables.chapters,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'number',
      limit: limit,
      offset: offset,
    );
    return rows
        .map(
          (r) => Chapter(
            info: ChapterInfo.fromMap(r),
            content: r['content']! as String,
          ),
        )
        .toList();
  }

  Future<void> saveProgress({
    required int bookId,
    required int chapterId,
    required int paragraph,
    required double fraction,
    required DateTime now,
  }) async {
    await _db.update(
      Tables.books,
      {
        'last_chapter_id': chapterId,
        'last_paragraph': paragraph,
        'last_fraction': fraction.clamp(0.0, 1.0),
        'last_read_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  /// Đánh dấu đã đọc xong; lần đầu thì cộng vào thống kê của ngày [now].
  Future<bool> markFinished(int chapterId, DateTime now) {
    return _db.transaction((txn) async {
      final n = await txn.update(
        Tables.chapters,
        {'finished': 1},
        where: 'id = ? AND finished = 0',
        whereArgs: [chapterId],
      );
      if (n == 0) return false;
      final rows = await txn.query(
        Tables.chapters,
        columns: ['book_id'],
        where: 'id = ?',
        whereArgs: [chapterId],
      );
      final bookId = rows.first['book_id']! as int;
      final day = StatsAggregator.dayKey(now);
      final u = await txn.rawUpdate(
        'UPDATE reading_stats SET chapters_finished = chapters_finished + 1 '
        'WHERE day = ? AND book_id = ?',
        [day, bookId],
      );
      if (u == 0) {
        await txn.insert(Tables.readingStats, {
          'day': day,
          'book_id': bookId,
          'chapters_finished': 1,
        });
      }
      return true;
    });
  }

  /// Thêm mới hoặc cập nhật truyện (khớp theo tiêu đề + quyển).
  ///
  /// Cập nhật: thêm chương mới, sửa chương đổi nội dung (giữ nguyên `id` chương
  /// nên tiến độ, dấu trang, thống kê vẫn còn). Chương không còn trong gói mới
  /// được giữ lại. Danh sách hồi (arc) được thay mới.
  Future<ImportResult> upsertParsed(ParsedBook parsed, DateTime now) {
    return _db.transaction((txn) async {
      final existing = await txn.query(
        Tables.books,
        columns: ['id'],
        where: 'title = ? AND volume = ?',
        whereArgs: [parsed.title, parsed.volume],
      );
      final isUpdate = existing.isNotEmpty;
      final int bookId;
      if (isUpdate) {
        bookId = existing.first['id']! as int;
        if (parsed.author.isNotEmpty) {
          await txn.update(
            Tables.books,
            {'author': parsed.author},
            where: 'id = ?',
            whereArgs: [bookId],
          );
        }
      } else {
        bookId = await txn.insert(Tables.books, {
          'title': parsed.title,
          'volume': parsed.volume,
          'author': parsed.author,
          'source_type': parsed.sourceType.name,
          'created_at': now.millisecondsSinceEpoch,
        });
      }

      final old = <int, Map<String, Object?>>{};
      for (final r in await txn.query(
        Tables.chapters,
        columns: ['id', 'number', 'title', 'content'],
        where: 'book_id = ?',
        whereArgs: [bookId],
      )) {
        old[r['number']! as int] = r;
      }

      var added = 0;
      var updated = 0;
      var unchanged = 0;
      for (final c in parsed.chapters) {
        final o = old[c.number];
        if (o == null) {
          await txn.insert(Tables.chapters, {
            'book_id': bookId,
            'number': c.number,
            'title': c.title,
            'content': c.content,
            'word_count': c.wordCount,
          });
          added++;
        } else if (o['content'] != c.content || o['title'] != c.title) {
          await txn.update(
            Tables.chapters,
            {'title': c.title, 'content': c.content, 'word_count': c.wordCount},
            where: 'id = ?',
            whereArgs: [o['id']],
          );
          updated++;
        } else {
          unchanged++;
        }
      }

      if (parsed.arcs.isNotEmpty || !isUpdate) {
        await txn.delete(
          Tables.arcs,
          where: 'book_id = ?',
          whereArgs: [bookId],
        );
        for (final a in parsed.arcs) {
          await txn.insert(Tables.arcs, {
            'book_id': bookId,
            'name': a.name,
            'from_number': a.from,
            'to_number': a.to,
          });
        }
      }
      return ImportResult(
        bookId: bookId,
        isUpdate: isUpdate,
        added: added,
        updated: updated,
        unchanged: unchanged,
      );
    });
  }
}
