import 'dart:typed_data';

import '../drive/chapter_naming.dart';
import '../drive/chapter_normalizer.dart';
import '../models/book.dart';
import 'parsed_book.dart';
import 'zip_importer.dart';

/// Nhập nhiều tệp chương rời (.md/.markdown/.txt, kèm `chapters.json` tùy chọn)
/// thành một truyện.
class LocalChaptersImporter {
  const LocalChaptersImporter._();

  static const List<String> chapterExtensions = ['md', 'markdown', 'txt'];

  static String _ext(String name) {
    final lower = name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    return dot < 0 ? '' : lower.substring(dot + 1);
  }

  /// Tiêu đề gợi ý: `book` trong chapters.json, nếu không thì rỗng.
  static String suggestedTitle(Map<String, Uint8List> files) {
    final book = ZipImporter.manifestBookTitle(files);
    return book ?? '';
  }

  /// [files]: tên tệp -> byte. [title] là tên truyện do người dùng đặt.
  static ParsedBook build(Map<String, Uint8List> files, String title) {
    final hasManifest = files.keys.any(
      (n) => n.split(RegExp(r'[\\/]')).last.toLowerCase() == 'chapters.json',
    );
    if (hasManifest) {
      final book = ZipImporter.fromFiles(files, title);
      return ParsedBook(
        title: title.trim().isEmpty ? book.title : title.trim(),
        volume: book.volume,
        author: book.author,
        sourceType: SourceType.txt,
        arcs: book.arcs,
        chapters: book.chapters,
      );
    }
    final names =
        files.keys.where((n) => chapterExtensions.contains(_ext(n))).toList()
          ..sort(ChapterNaming.naturalCompare);
    if (names.isEmpty) {
      throw const ImportException(
        'Không có tệp chương (.md, .markdown, .txt).',
      );
    }
    final parsed = <(String, NormalizedChapter)>[];
    for (final n in names) {
      parsed.add((
        n,
        ChapterNormalizer.fromBytes(
          files[n]!,
          ChapterNormalizer.stripExtension(n),
        ),
      ));
    }
    final used = <int>{};
    final numbered = <int?>[];
    for (final (name, ch) in parsed) {
      final n =
          ChapterNaming.numberOf(ch.title) ??
          ChapterNaming.numberOf(ChapterNormalizer.stripExtension(name));
      if (n != null && used.add(n)) {
        numbered.add(n);
      } else {
        numbered.add(null);
      }
    }
    var next = used.isEmpty ? 1 : used.reduce((a, b) => a > b ? a : b) + 1;
    final chapters = <ParsedChapter>[];
    for (var i = 0; i < parsed.length; i++) {
      final ch = parsed[i].$2;
      chapters.add(
        ParsedChapter(
          number: numbered[i] ?? next++,
          title: ch.title,
          content: ch.content,
          contentHash: ch.hash,
        ),
      );
    }
    chapters.sort((a, b) => a.number.compareTo(b.number));
    return ParsedBook(
      title: title.trim().isEmpty ? 'Truyện không tên' : title.trim(),
      sourceType: SourceType.txt,
      chapters: chapters,
    );
  }
}
