import '../models/book.dart';

class ParsedChapter {
  const ParsedChapter({
    required this.number,
    required this.title,
    required this.content,
    this.driveFileId = '',
    this.contentHash = '',
    this.driveModified = '',
  });

  final int number;
  final String title;
  final String content;

  /// Chỉ dùng cho truyện từ Drive.
  final String driveFileId;
  final String contentHash;
  final String driveModified;

  int get wordCount =>
      content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

/// Kết quả phân tích một tệp truyện, chưa gắn với DB.
class ParsedBook {
  const ParsedBook({
    required this.title,
    required this.sourceType,
    required this.chapters,
    this.volume = '',
    this.author = '',
    this.arcs = const [],
    this.driveFolderId = '',
  });

  /// Id thư mục Drive (rỗng nếu không phải nguồn Drive).
  final String driveFolderId;

  final String title;
  final String volume;
  final String author;
  final SourceType sourceType;
  final List<Arc> arcs;
  final List<ParsedChapter> chapters;
}

class ImportException implements Exception {
  const ImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
