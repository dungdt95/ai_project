import 'paragraph.dart';

/// Phân tích Markdown-lite của chương: tiêu đề `#`, đoạn, lời thoại (`—`),
/// `*nghiêng*`, `**đậm**`, và đường phân cách `---`.
class MarkdownLite {
  const MarkdownLite._();

  /// Mỗi dòng không rỗng là một đoạn. Đoạn đầu luôn là tiêu đề [chapterTitle];
  /// dòng `# ...` hoặc dòng trùng tiêu đề ở đầu nội dung bị bỏ để không hiển
  /// thị/đọc hai lần.
  static List<StoryParagraph> parseChapter(
    String chapterTitle,
    String content,
  ) {
    final result = <StoryParagraph>[
      StoryParagraph(kind: ParagraphKind.heading, text: chapterTitle.trim()),
    ];
    var first = true;
    final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (final raw in lines.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (first) {
        first = false;
        if (line.startsWith('#')) continue;
        if (_plain(line) == chapterTitle.trim()) continue;
      }
      final p = parseLine(line);
      if (p != null) result.add(p);
    }
    return result;
  }

  static String _plain(String s) => s.replaceAll('*', '').trim();

  static StoryParagraph? parseLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^(?:-{3,}|\*{3,}|_{3,}|(?:\*\s+){2,}\*)$').hasMatch(t)) {
      return const StoryParagraph(kind: ParagraphKind.separator, text: '');
    }
    if (t.startsWith('#')) {
      final title = t.replaceFirst(RegExp(r'^#+\s*'), '');
      return StoryParagraph(kind: ParagraphKind.heading, text: _plain(title));
    }
    return _inline(t.replaceFirst(RegExp(r'^>\s*'), ''));
  }

  static StoryParagraph _inline(String s) {
    final out = StringBuffer();
    final styles = <InlineStyle>[];
    var i = 0;
    int? boldStart;
    int? italicStart;
    while (i < s.length) {
      final c = s[i];
      if (c == r'\' &&
          i + 1 < s.length &&
          (s[i + 1] == '*' || s[i + 1] == '_')) {
        out.write(s[i + 1]);
        i += 2;
        continue;
      }
      if (c == '*') {
        if (i + 1 < s.length && s[i + 1] == '*') {
          final bs = boldStart;
          if (bs == null) {
            boldStart = out.length;
          } else {
            if (out.length > bs) {
              styles.add(InlineStyle(bs, out.length, bold: true));
            }
            boldStart = null;
          }
          i += 2;
          continue;
        }
        final is_ = italicStart;
        if (is_ == null) {
          // Dấu * đứng riêng giữa khoảng trắng thì giữ nguyên.
          final next = i + 1 < s.length ? s[i + 1] : ' ';
          if (next.trim().isEmpty) {
            out.write(c);
            i++;
            continue;
          }
          italicStart = out.length;
        } else {
          if (out.length > is_) {
            styles.add(InlineStyle(is_, out.length, italic: true));
          }
          italicStart = null;
        }
        i++;
        continue;
      }
      out.write(c);
      i++;
    }
    return StoryParagraph(
      kind: ParagraphKind.text,
      text: out.toString(),
      styles: styles,
    );
  }
}
