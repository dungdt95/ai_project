import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../importers/text_decoder.dart';

/// Chương đã chuẩn hóa: nội dung dạng markdown-lite (dòng đầu `# Tiêu đề`).
class NormalizedChapter {
  const NormalizedChapter({
    required this.title,
    required this.content,
    required this.hash,
  });

  final String title;
  final String content;

  /// Băm nội dung đã chuẩn hóa, dùng nhận biết chương có đổi hay không.
  final String hash;
}

class ChapterNormalizer {
  const ChapterNormalizer._();

  static final RegExp _chapterLine = RegExp(
    r'^(chương|chuong|chapter|hồi|hoi)\s*\d+',
    caseSensitive: false,
    unicode: true,
  );

  static NormalizedChapter fromBytes(List<int> bytes, String fallbackTitle) =>
      normalize(TextDecoder.decode(bytes), fallbackTitle);

  /// Bỏ BOM, đổi CRLF thành LF. Tiêu đề lấy từ dòng `# ...` đầu tiên; nếu dòng
  /// đầu là "Chương N..." không có `#` (xuất .txt) thì thêm `# `; còn lại dùng
  /// [fallbackTitle] (tên tệp bỏ phần mở rộng) và chèn thành dòng `# `.
  static NormalizedChapter normalize(String raw, String fallbackTitle) {
    var text = raw.replaceAll('﻿', '');
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = text.split('\n');
    var first = 0;
    while (first < lines.length && lines[first].trim().isEmpty) {
      first++;
    }
    String title;
    var body = lines.skip(first).toList();
    if (body.isNotEmpty && body.first.trimLeft().startsWith('#')) {
      title = body.first.replaceFirst(RegExp(r'^\s*#+\s*'), '').trim();
      body[0] = '# $title';
    } else if (body.isNotEmpty && _chapterLine.hasMatch(body.first.trim())) {
      title = body.first.trim();
      body[0] = '# $title';
    } else {
      title = fallbackTitle.trim();
      body = ['# $title', '', ...body];
    }
    if (title.isEmpty) title = fallbackTitle.trim();
    // Luôn có một dòng trống sau tiêu đề (bản xuất .txt không có).
    if (body.length > 1 && body[1].trim().isNotEmpty) body.insert(1, '');
    // Gộp 2+ dòng trống liên tiếp và bỏ khoảng trắng cuối dòng.
    final out = <String>[];
    var blank = 0;
    for (final l in body) {
      final t = l.trimRight();
      if (t.isEmpty) {
        blank++;
        if (blank > 1) continue;
      } else {
        blank = 0;
      }
      out.add(t);
    }
    final content = out.join('\n').trim();
    return NormalizedChapter(
      title: title,
      content: content,
      hash: sha1.convert(utf8.encode(content)).toString(),
    );
  }

  /// Tên tệp bỏ phần mở rộng.
  static String stripExtension(String name) {
    final base = name.split(RegExp(r'[\\/]')).last;
    final dot = base.lastIndexOf('.');
    return (dot > 0 && base.length - dot <= 10 ? base.substring(0, dot) : base)
        .trim();
  }
}
