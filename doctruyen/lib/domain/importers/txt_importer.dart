import '../../core/constants/app_constants.dart';
import '../models/book.dart';
import '../text/sentence_splitter.dart';
import 'parsed_book.dart';
import 'text_decoder.dart';

/// Nhập tệp .txt: nhận diện bảng mã, tách chương theo tiêu đề "Chương 12",
/// "CHƯƠNG XII", "Chapter 3", "Hồi 5"; không có thì cắt ~5000 ký tự/phần.
class TxtImporter {
  const TxtImporter._();

  static final RegExp _heading = RegExp(
    r'^\s*(chương|chuong|chapter|hồi|hoi)\s+(\d{1,5}|[ivxlcdm]{1,8})(?![\p{L}\p{N}])\s*(?:([:\-–—.])\s*)?(.*?)\s*$',
    caseSensitive: false,
    unicode: true,
  );

  static ParsedBook parseBytes(List<int> bytes, String fileName) =>
      parseText(TextDecoder.decode(bytes), titleFromFileName(fileName));

  static String titleFromFileName(String fileName) {
    final base = fileName.split(RegExp(r'[\\/]')).last;
    final dot = base.lastIndexOf('.');
    return (dot > 0 ? base.substring(0, dot) : base).trim();
  }

  static ParsedBook parseText(String text, String bookTitle) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');

    final heads = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_isHeading(lines[i])) heads.add(i);
    }

    final chapters = heads.length >= 2
        ? _splitByHeadings(lines, heads)
        : _splitBySize(lines);
    return ParsedBook(
      title: bookTitle.isEmpty ? 'Truyện không tên' : bookTitle,
      sourceType: SourceType.txt,
      chapters: chapters,
    );
  }

  static bool _isHeading(String line) {
    if (line.length > 120) return false;
    final m = _heading.firstMatch(line);
    if (m == null) return false;
    final sep = m.group(3);
    final rest = m.group(4) ?? '';
    final word = m.group(1)!.toLowerCase();
    final roman = RegExp(
      r'^[ivxlcdm]+$',
      caseSensitive: false,
    ).hasMatch(m.group(2)!);
    if (roman && word != 'chương' && word != 'chuong' && word != 'chapter') {
      // "Hồi i ..." quá dễ nhầm với câu văn.
      if (sep == null) return false;
    }
    if (sep != null || rest.isEmpty) return true;
    // Không có dấu phân cách: chỉ nhận khi phần còn lại giống một tiêu đề.
    return rest.length <= 60 && !rest.contains(',') && !rest.endsWith('.');
  }

  static List<ParsedChapter> _splitByHeadings(
    List<String> lines,
    List<int> heads,
  ) {
    final chapters = <ParsedChapter>[];
    var number = 1;

    final preface = lines.sublist(0, heads.first).join('\n').trim();
    if (preface.length >= 200) {
      chapters.add(
        ParsedChapter(number: number++, title: 'Mở đầu', content: preface),
      );
    }
    for (var h = 0; h < heads.length; h++) {
      final end = h + 1 < heads.length ? heads[h + 1] : lines.length;
      final title = lines[heads[h]].trim();
      final body = lines.sublist(heads[h] + 1, end).join('\n').trim();
      chapters.add(
        ParsedChapter(number: number++, title: title, content: body),
      );
    }
    return chapters;
  }

  static List<ParsedChapter> _splitBySize(List<String> lines) {
    final paragraphs = <String>[];
    for (final l in lines) {
      final t = l.trim();
      if (t.isEmpty) continue;
      if (t.length > AppConstants.txtPartSize) {
        for (final s in SentenceSplitter.split(t)) {
          paragraphs.add(s.slice(t));
        }
      } else {
        paragraphs.add(t);
      }
    }
    final chapters = <ParsedChapter>[];
    var buf = StringBuffer();
    var len = 0;
    void flush() {
      if (len == 0) return;
      final n = chapters.length + 1;
      chapters.add(
        ParsedChapter(
          number: n,
          title: 'Phần $n',
          content: buf.toString().trim(),
        ),
      );
      buf = StringBuffer();
      len = 0;
    }

    for (final p in paragraphs) {
      buf.writeln(p);
      len += p.length;
      if (len >= AppConstants.txtPartSize) flush();
    }
    flush();
    return chapters;
  }
}
