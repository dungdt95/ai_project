enum ParagraphKind { heading, text, separator }

/// Đoạn định dạng inline [start, end) trong [StoryParagraph.text].
class InlineStyle {
  const InlineStyle(
    this.start,
    this.end, {
    this.bold = false,
    this.italic = false,
  });

  final int start;
  final int end;
  final bool bold;
  final bool italic;
}

/// Một đoạn của chương sau khi phân tích Markdown-lite. [text] đã bỏ ký hiệu
/// `*`/`**`, nên chỉ số trong [styles] và trong câu TTS cùng một hệ quy chiếu.
class StoryParagraph {
  const StoryParagraph({
    required this.kind,
    required this.text,
    this.styles = const [],
  });

  final ParagraphKind kind;
  final String text;
  final List<InlineStyle> styles;

  bool get isDialogue =>
      kind == ParagraphKind.text && RegExp(r'^[—–-]\s*\S').hasMatch(text);

  /// Có chữ hoặc số để đọc (đường phân cách và "* * *" thì không).
  bool get isReadable =>
      kind != ParagraphKind.separator &&
      RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text);
}
