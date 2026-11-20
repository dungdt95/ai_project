import '../../domain/importers/parsed_book.dart';
import '../../domain/models/book.dart';
import '../../domain/text/book_search.dart';
import '../dao/book_dao.dart';
import '../dao/bookmark_dao.dart';

/// Truy cập thư viện truyện: sách, chương, tiến độ, dấu trang.
class LibraryRepository {
  LibraryRepository(this._books, this._bookmarks, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final BookDao _books;
  final BookmarkDao _bookmarks;
  final DateTime Function() _clock;

  Future<ImportResult> importParsed(ParsedBook parsed) =>
      _books.upsertParsed(parsed, _clock());

  Future<List<Book>> listBooks() => _books.listBooks();
  Future<Book?> getBook(int id) => _books.getBook(id);
  Future<void> deleteBook(int id) => _books.deleteBook(id);
  Future<List<Arc>> listArcs(int bookId) => _books.listArcs(bookId);
  Future<List<ChapterInfo>> listChapters(int bookId) =>
      _books.listChapters(bookId);
  Future<Chapter?> getChapter(int id) => _books.getChapter(id);
  Future<ChapterInfo?> firstChapter(int bookId) => _books.firstChapter(bookId);
  Future<ChapterInfo?> nextChapter(int chapterId) =>
      _books.neighbour(chapterId, forward: true);
  Future<ChapterInfo?> previousChapter(int chapterId) =>
      _books.neighbour(chapterId, forward: false);

  Future<void> saveProgress({
    required int bookId,
    required int chapterId,
    required int paragraph,
    required double fraction,
  }) => _books.saveProgress(
    bookId: bookId,
    chapterId: chapterId,
    paragraph: paragraph,
    fraction: fraction,
    now: _clock(),
  );

  Future<bool> markChapterFinished(int chapterId) =>
      _books.markFinished(chapterId, _clock());

  // ── Dấu trang ──
  Future<List<Bookmark>> bookmarks(int bookId) => _bookmarks.list(bookId);

  /// Bật/tắt dấu trang tại đoạn; trả `true` nếu vừa thêm.
  Future<bool> toggleBookmark({
    required int bookId,
    required int chapterId,
    required int paragraph,
    required String snippet,
  }) async {
    final existing = await _bookmarks.find(chapterId, paragraph);
    if (existing != null) {
      await _bookmarks.delete(existing);
      return false;
    }
    await _bookmarks.add(
      bookId: bookId,
      chapterId: chapterId,
      paragraph: paragraph,
      snippet: snippet,
      now: _clock(),
    );
    return true;
  }

  Future<void> deleteBookmark(int id) => _bookmarks.delete(id);

  // ── Tìm kiếm trong truyện ──
  Future<List<SearchHit>> searchInBook(
    int bookId,
    String query, {
    int limit = 100,
  }) async {
    final hits = <SearchHit>[];
    var offset = 0;
    while (hits.length < limit) {
      final batch = await _books.chaptersWithContent(bookId, offset: offset);
      if (batch.isEmpty) break;
      for (final c in batch) {
        hits.addAll(
          BookSearch.searchChapter(c, query, limit: limit - hits.length),
        );
        if (hits.length >= limit) break;
      }
      offset += batch.length;
    }
    return hits;
  }
}
