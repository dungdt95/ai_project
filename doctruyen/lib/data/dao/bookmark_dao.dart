import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/book.dart';
import '../database/app_database.dart';

class BookmarkDao {
  BookmarkDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<List<Bookmark>> list(int bookId) async {
    final rows = await _db.rawQuery(
      'SELECT m.*, c.title AS chapter_title FROM bookmarks m '
      'JOIN chapters c ON c.id = m.chapter_id WHERE m.book_id = ? '
      'ORDER BY c.number, m.paragraph',
      [bookId],
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<int?> find(int chapterId, int paragraph) async {
    final rows = await _db.query(
      Tables.bookmarks,
      columns: ['id'],
      where: 'chapter_id = ? AND paragraph = ?',
      whereArgs: [chapterId, paragraph],
    );
    return rows.isEmpty ? null : rows.first['id']! as int;
  }

  Future<int> add({
    required int bookId,
    required int chapterId,
    required int paragraph,
    required String snippet,
    required DateTime now,
  }) => _db.insert(Tables.bookmarks, {
    'book_id': bookId,
    'chapter_id': chapterId,
    'paragraph': paragraph,
    'snippet': snippet,
    'created_at': now.millisecondsSinceEpoch,
  });

  Future<void> delete(int id) =>
      _db.delete(Tables.bookmarks, where: 'id = ?', whereArgs: [id]);
}
