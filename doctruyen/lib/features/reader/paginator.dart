import 'package:flutter/material.dart';

import '../../domain/text/paragraph.dart';
import 'reader_text.dart';

/// Một đoạn (hoặc một phần đoạn) nằm trên một trang.
class PageSlice {
  const PageSlice(this.paragraph, this.start, this.end);

  final int paragraph;
  final int start;
  final int end;
}

class ReaderPage {
  ReaderPage(this.slices);

  final List<PageSlice> slices;

  int get firstParagraph => slices.isEmpty ? 0 : slices.first.paragraph;
}

/// Chia các đoạn thành trang theo kích thước vùng chữ, đo bằng TextPainter.
/// Đoạn dài được cắt theo dòng để lấp đầy trang.
class Paginator {
  const Paginator._();

  static List<ReaderPage> paginate(
    List<StoryParagraph> paragraphs,
    ReaderStyles styles, {
    required double width,
    required double height,
    required double paragraphSpacing,
  }) {
    final pages = <ReaderPage>[];
    var current = <PageSlice>[];
    var avail = height;

    void newPage() {
      if (current.isNotEmpty) pages.add(ReaderPage(current));
      current = <PageSlice>[];
      avail = height;
    }

    for (var i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      if (p.kind == ParagraphKind.separator) {
        const h = 40.0;
        if (avail < h) newPage();
        current.add(PageSlice(i, 0, 0));
        avail -= h;
        continue;
      }
      final tp = TextPainter(
        text: buildParagraphSpan(p, styles),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        locale: kReaderLocale,
        textAlign: p.kind == ParagraphKind.heading
            ? TextAlign.center
            : TextAlign.start,
      )..layout(maxWidth: width);
      final lines = tp.computeLineMetrics();
      if (lines.isEmpty) {
        tp.dispose();
        continue;
      }
      var li = 0;
      while (li < lines.length) {
        var fit = 0;
        var used = 0.0;
        while (li + fit < lines.length &&
            used + lines[li + fit].height <= avail) {
          used += lines[li + fit].height;
          fit++;
        }
        if (fit == 0) {
          if (current.isEmpty) {
            fit = 1; // dòng cao hơn cả trang: vẫn phải đặt vào.
            used = lines[li].height;
          } else {
            newPage();
            continue;
          }
        }
        final startOffset = li == 0 ? 0 : _offsetAtLine(tp, lines, li);
        var endLine = li + fit;
        var endOffset = endLine >= lines.length
            ? p.text.length
            : _offsetAtLine(tp, lines, endLine);
        // Đo lại đúng như lúc vẽ (lát được dựng thành Text riêng): tổng chiều
        // cao từng dòng có thể lệch vài px so với thực tế (chữ nghiêng, font
        // dự phòng), cộng dồn lại làm dòng cuối bị tràn xuống dưới thanh điều khiển.
        used = _sliceHeight(p, styles, startOffset, endOffset, width);
        while (used > avail && endLine - li > 1) {
          endLine--;
          endOffset = _offsetAtLine(tp, lines, endLine);
          used = _sliceHeight(p, styles, startOffset, endOffset, width);
        }
        if (used > avail && current.isNotEmpty) {
          newPage();
          continue;
        }
        current.add(PageSlice(i, startOffset, endOffset));
        avail -= used;
        li = endLine;
        if (li < lines.length) {
          newPage();
        } else {
          avail -= paragraphSpacing;
          if (avail <= 0) newPage();
        }
      }
      tp.dispose();
    }
    if (current.isNotEmpty) pages.add(ReaderPage(current));
    if (pages.isEmpty) pages.add(ReaderPage(const []));
    return pages;
  }

  /// Chiều cao thật của một lát văn bản, đo như khi vẽ.
  static double _sliceHeight(
    StoryParagraph p,
    ReaderStyles styles,
    int from,
    int to,
    double width,
  ) {
    final tp = TextPainter(
      text: buildParagraphSpan(p, styles, from: from, to: to),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: kReaderLocale,
      textAlign: p.kind == ParagraphKind.heading
          ? TextAlign.center
          : TextAlign.start,
    )..layout(maxWidth: width);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  static int _offsetAtLine(TextPainter tp, List<LineMetrics> lines, int line) {
    final l = lines[line];
    // Tâm hộp dòng theo vị trí thật (đường cơ sở), không cộng dồn chiều cao.
    final y = l.baseline + (l.descent - l.ascent) / 2;
    return tp.getPositionForOffset(Offset(1, y)).offset;
  }

  /// Các trang mà câu [start, end) của đoạn [paragraph] trải qua (theo thứ tự).
  /// Một câu nằm vắt qua ranh giới trang sẽ có nhiều hơn một trang.
  static List<int> pagesOfRange(
    List<ReaderPage> pages,
    int paragraph,
    int start,
    int end,
  ) {
    final out = <int>[];
    for (var i = 0; i < pages.length; i++) {
      for (final s in pages[i].slices) {
        if (s.paragraph != paragraph) continue;
        final overlaps = s.start < end && start < s.end;
        // Đoạn rỗng/lát rỗng: coi như trùng nếu cùng điểm bắt đầu.
        final emptyHit = s.start == s.end && s.start == start;
        if (overlaps || emptyHit) {
          out.add(i);
          break;
        }
      }
    }
    return out;
  }

  /// Trang chứa chỗ BẮT ĐẦU của câu; nếu không tìm được thì trang của đoạn.
  static int pageOfSentence(
    List<ReaderPage> pages,
    int paragraph,
    int start,
    int end,
  ) {
    final hit = pagesOfRange(pages, paragraph, start, end);
    return hit.isNotEmpty ? hit.first : pageOfParagraph(pages, paragraph);
  }

  /// Trang chứa đoạn [paragraph].
  static int pageOfParagraph(List<ReaderPage> pages, int paragraph) {
    for (var i = 0; i < pages.length; i++) {
      final s = pages[i].slices;
      if (s.isNotEmpty && s.last.paragraph >= paragraph) return i;
    }
    return pages.length - 1;
  }
}
