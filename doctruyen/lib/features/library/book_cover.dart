import 'package:flutter/material.dart';

import '../../core/utils/vn_text.dart';

/// Ảnh bìa giả: màu theo tiêu đề + chữ cái đầu.
class BookCover extends StatelessWidget {
  const BookCover({required this.title, this.width = 56, super.key});

  final String title;
  final double width;

  static const List<Color> _colors = [
    Color(0xFF0D9488),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF2563EB),
    Color(0xFF65A30D),
    Color(0xFFB45309),
    Color(0xFF475569),
  ];

  static Color colorFor(String title) {
    var h = 0;
    for (final r in title.runes) {
      h = (h * 31 + r) & 0x7fffffff;
    }
    return _colors[h % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final base = colorFor(title);
    return Container(
      width: width,
      height: width * 1.4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, Color.lerp(base, Colors.black, 0.35)!],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        VnText.initials(title),
        style: TextStyle(
          color: Colors.white,
          fontSize: width * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
