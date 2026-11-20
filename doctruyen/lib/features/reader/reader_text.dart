import 'package:flutter/material.dart';

import '../../domain/text/paragraph.dart';

/// Kiểu chữ dùng chung cho hiển thị và đo phân trang.
class ReaderStyles {
  const ReaderStyles({
    required this.body,
    required this.heading,
    required this.textColor,
    required this.sentenceHighlight,
  });

  /// Kiểu chữ của màn đọc. Mọi trường ảnh hưởng bề rộng chữ được đặt TƯỜNG MINH:
  /// engine vẫn kế thừa các trường để trống (kể cả khi `inherit: false`) từ
  /// DefaultTextStyle của Material (M3 có letterSpacing 0.25). Nếu không đặt, chữ
  /// vẽ ra rộng hơn chữ mà bộ phân trang đo bằng TextPainter, vài đoạn dôi thêm
  /// một dòng và dòng cuối của trang tràn xuống dưới thanh điều khiển.
  factory ReaderStyles.forReader({
    required String fontFamily,
    required double fontSize,
    required double lineHeight,
    required Color textColor,
    required Color sentenceHighlight,
  }) {
    final body = TextStyle(
      inherit: false,
      letterSpacing: 0,
      wordSpacing: 0,
      decoration: TextDecoration.none,
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: lineHeight,
      color: textColor,
    );
    return ReaderStyles(
      body: body,
      heading: body.copyWith(
        fontSize: fontSize * 1.25,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      textColor: textColor,
      sentenceHighlight: sentenceHighlight,
    );
  }

  final TextStyle body;
  final TextStyle heading;
  final Color textColor;
  final Color sentenceHighlight;

  TextStyle styleOf(StoryParagraph p) =>
      p.kind == ParagraphKind.heading ? heading : body;
}

/// Dựng TextSpan cho đoạn [p] trong khoảng ký tự [from, to), tô nền câu
/// [hlStart, hlEnd) nếu có.
TextSpan buildParagraphSpan(
  StoryParagraph p,
  ReaderStyles styles, {
  int from = 0,
  int? to,
  int? hlStart,
  int? hlEnd,
}) {
  final end = to ?? p.text.length;
  final base = styles.styleOf(p);
  final cuts = <int>{from, end};
  for (final s in p.styles) {
    cuts
      ..add(s.start)
      ..add(s.end);
  }
  if (hlStart != null && hlEnd != null) {
    cuts
      ..add(hlStart)
      ..add(hlEnd);
  }
  final points = cuts.where((c) => c >= from && c <= end).toList()..sort();
  final children = <InlineSpan>[];
  for (var i = 0; i + 1 < points.length; i++) {
    final a = points[i];
    final b = points[i + 1];
    var bold = false;
    var italic = false;
    for (final s in p.styles) {
      if (s.start <= a && s.end >= b) {
        bold = bold || s.bold;
        italic = italic || s.italic;
      }
    }
    final highlighted =
        hlStart != null && hlEnd != null && a >= hlStart && b <= hlEnd;
    children.add(
      TextSpan(
        text: p.text.substring(a, b),
        style: TextStyle(
          fontWeight: bold ? FontWeight.w700 : null,
          fontStyle: italic ? FontStyle.italic : null,
          backgroundColor: highlighted ? styles.sentenceHighlight : null,
        ),
      ),
    );
  }
  return TextSpan(style: base, children: children);
}

/// Ngôn ngữ dùng CHUNG cho vẽ chữ và đo phân trang. Phải trùng nhau: `Text` lấy
/// locale từ ngữ cảnh còn `TextPainter` thì không, nên chọn font dự phòng cho
/// dấu tiếng Việt khác nhau, chữ rộng hơn và nhiều dòng hơn số đã đo.
const Locale kReaderLocale = Locale('vi', 'VN');
