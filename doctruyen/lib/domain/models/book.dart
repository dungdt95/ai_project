/// Nguồn nhập của một truyện.
enum SourceType { zip, txt, epub, drive }

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.volume,
    required this.author,
    required this.sourceType,
    required this.createdAt,
    required this.lastReadAt,
    required this.lastChapterId,
    required this.lastParagraph,
    required this.progress,
    required this.chapterCount,
    this.driveFolderId = '',
    this.driveSyncedAt,
  });

  factory Book.fromMap(Map<String, Object?> m) => Book(
    id: m['id']! as int,
    title: m['title']! as String,
    volume: (m['volume'] as String?) ?? '',
    author: (m['author'] as String?) ?? '',
    sourceType: SourceType.values.firstWhere(
      (e) => e.name == m['source_type'],
      orElse: () => SourceType.txt,
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
    lastReadAt: m['last_read_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['last_read_at']! as int),
    lastChapterId: m['last_chapter_id'] as int?,
    lastParagraph: (m['last_paragraph'] as int?) ?? 0,
    progress: ((m['progress'] as num?) ?? 0).toDouble().clamp(0.0, 1.0),
    chapterCount: (m['chapter_count'] as int?) ?? 0,
    driveFolderId: (m['drive_folder_id'] as String?) ?? '',
    driveSyncedAt: m['drive_synced_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['drive_synced_at']! as int),
  );

  final int id;
  final String title;
  final String volume;
  final String author;
  final SourceType sourceType;
  final DateTime createdAt;
  final DateTime? lastReadAt;
  final int? lastChapterId;
  final int lastParagraph;

  /// 0..1, tính từ chương đang đọc và vị trí trong chương.
  final double progress;
  final int chapterCount;

  /// Id thư mục Google Drive nếu truyện nhập từ Drive, ngược lại rỗng.
  final String driveFolderId;
  final DateTime? driveSyncedAt;

  bool get isDrive => driveFolderId.isNotEmpty;

  String get displayTitle => volume.isEmpty ? title : '$title — $volume';
}

class Arc {
  const Arc({required this.name, required this.from, required this.to});

  final String name;
  final int from;
  final int to;

  bool contains(int number) => number >= from && number <= to;
}

/// Chương không kèm nội dung (dùng cho mục lục).
class ChapterInfo {
  const ChapterInfo({
    required this.id,
    required this.bookId,
    required this.number,
    required this.title,
    required this.finished,
    required this.wordCount,
  });

  factory ChapterInfo.fromMap(Map<String, Object?> m) => ChapterInfo(
    id: m['id']! as int,
    bookId: m['book_id']! as int,
    number: m['number']! as int,
    title: m['title']! as String,
    finished: (m['finished'] as int? ?? 0) == 1,
    wordCount: (m['word_count'] as int?) ?? 0,
  );

  final int id;
  final int bookId;
  final int number;
  final String title;
  final bool finished;
  final int wordCount;
}

class Chapter {
  const Chapter({required this.info, required this.content});

  final ChapterInfo info;
  final String content;

  int get id => info.id;
  String get title => info.title;
}

class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.chapterTitle,
    required this.paragraph,
    required this.snippet,
    required this.createdAt,
  });

  factory Bookmark.fromMap(Map<String, Object?> m) => Bookmark(
    id: m['id']! as int,
    bookId: m['book_id']! as int,
    chapterId: m['chapter_id']! as int,
    chapterTitle: (m['chapter_title'] as String?) ?? '',
    paragraph: m['paragraph']! as int,
    snippet: (m['snippet'] as String?) ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
  );

  final int id;
  final int bookId;
  final int chapterId;
  final String chapterTitle;
  final int paragraph;
  final String snippet;
  final DateTime createdAt;
}
