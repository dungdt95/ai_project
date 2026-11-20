import '../../core/utils/vn_text.dart';
import '../models/book.dart';
import 'markdown_lite.dart';

class SearchHit {
  const SearchHit({
    required this.chapterId,
    required this.chapterTitle,
    required this.paragraph,
    required this.snippet,
  });

  final int chapterId;
  final String chapterTitle;
  final int paragraph;
  final String snippet;
}

/// Tìm trong nội dung chương, không phân biệt hoa/thường và dấu.
class BookSearch {
  const BookSearch._();

  static List<SearchHit> searchChapter(
    Chapter chapter,
    String query, {
    int limit = 50,
  }) {
    final q = VnText.normalize(query.trim());
    if (q.isEmpty) return const [];
    final hits = <SearchHit>[];
    final paragraphs = MarkdownLite.parseChapter(
      chapter.title,
      chapter.content,
    );
    for (var i = 0; i < paragraphs.length && hits.length < limit; i++) {
      final text = paragraphs[i].text;
      final idx = VnText.normalize(text).indexOf(q);
      if (idx < 0) continue;
      final from = idx - 30 < 0 ? 0 : idx - 30;
      final to = idx + q.length + 50 > text.length
          ? text.length
          : idx + q.length + 50;
      hits.add(
        SearchHit(
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          paragraph: i,
          snippet:
              '${from > 0 ? '…' : ''}${text.substring(from, to)}${to < text.length ? '…' : ''}',
        ),
      );
    }
    return hits;
  }
}
