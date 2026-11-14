/// Lược đồ cơ sở dữ liệu, phiên bản 1.
///
/// DDL thuần SQL như bên chiahoadon: dễ đối chiếu, không cần build_runner.
class Schema {
  const Schema._();

  static const List<String> createStatements = [
    _books,
    _arcs,
    _chapters,
    _bookmarks,
    _readingStats,
  ];

  static const List<String> createIndexes = [
    'CREATE INDEX idx_chapters_book ON chapters(book_id, number)',
    'CREATE INDEX idx_arcs_book ON arcs(book_id)',
    'CREATE INDEX idx_bookmarks_book ON bookmarks(book_id, created_at DESC)',
    'CREATE INDEX idx_stats_day ON reading_stats(day)',
  ];

  static const String _books = '''
CREATE TABLE books (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  volume TEXT NOT NULL DEFAULT '',
  author TEXT NOT NULL DEFAULT '',
  source_type TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_read_at INTEGER,
  last_chapter_id INTEGER,
  last_paragraph INTEGER NOT NULL DEFAULT 0,
  last_fraction REAL NOT NULL DEFAULT 0,
  UNIQUE (title, volume)
)''';

  static const String _arcs = '''
CREATE TABLE arcs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  from_number INTEGER NOT NULL,
  to_number INTEGER NOT NULL
)''';

  static const String _chapters = '''
CREATE TABLE chapters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  number INTEGER NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  word_count INTEGER NOT NULL DEFAULT 0,
  finished INTEGER NOT NULL DEFAULT 0,
  UNIQUE (book_id, number)
)''';

  static const String _bookmarks = '''
CREATE TABLE bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  chapter_id INTEGER NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
  paragraph INTEGER NOT NULL,
  snippet TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
)''';

  static const String _readingStats = '''
CREATE TABLE reading_stats (
  day TEXT NOT NULL,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  read_seconds INTEGER NOT NULL DEFAULT 0,
  listen_seconds INTEGER NOT NULL DEFAULT 0,
  chapters_finished INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, book_id)
)''';
}
