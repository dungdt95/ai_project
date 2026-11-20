import 'package:doctruyen/domain/text/markdown_lite.dart';
import 'package:doctruyen/domain/text/paragraph.dart';
import 'package:doctruyen/features/reader/paginator.dart';
import 'package:doctruyen/features/reader/reader_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  paginationCoverageTests();
  sentenceMappingTests();

  const body = TextStyle(fontSize: 18, height: 1.6, color: Colors.black);
  final styles = ReaderStyles(
    body: body,
    heading: body.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
    textColor: Colors.black,
    sentenceHighlight: Colors.yellow,
  );

  test('chia trang: không mất/trùng ký tự, đoạn dài được cắt qua trang', () {
    final text = List.generate(
      40,
      (i) => 'Câu số $i của một đoạn rất dài để buộc phải cắt qua nhiều trang.',
    ).join(' ');
    final paras = MarkdownLite.parseChapter('Chương 1', '$text\n\nĐoạn hai.');
    final pages = Paginator.paginate(
      paras,
      styles,
      width: 300,
      height: 400,
      paragraphSpacing: 10,
    );
    expect(pages.length, greaterThan(1));

    // Ghép lại các lát của đoạn dài phải khớp văn bản gốc, liền mạch.
    const longIndex = 1;
    var expectedStart = 0;
    for (final page in pages) {
      for (final s in page.slices.where((s) => s.paragraph == longIndex)) {
        expect(s.start, expectedStart);
        expectedStart = s.end;
      }
    }
    expect(expectedStart, paras[longIndex].text.length);

    // Mọi đoạn đều xuất hiện, theo thứ tự.
    final seen = pages.expand((p) => p.slices.map((s) => s.paragraph)).toList();
    expect(seen.first, 0);
    expect(seen.last, paras.length - 1);
    expect(Paginator.pageOfParagraph(pages, 0), 0);
    expect(
      Paginator.pageOfParagraph(pages, paras.length - 1),
      pages.length - 1,
    );
  });
}

/// Chiều cao một trang đúng như lúc vẽ: từng lát đo bằng TextPainter cùng
/// bề rộng, cộng khoảng cách đoạn sau lát cuối của mỗi đoạn.
double _measurePage(
  ReaderPage page,
  List<StoryParagraph> paras,
  ReaderStyles styles,
  double width,
  double spacing,
) {
  var h = 0.0;
  for (final s in page.slices) {
    final p = paras[s.paragraph];
    if (p.kind == ParagraphKind.separator) {
      h += 40;
      continue;
    }
    final tp = TextPainter(
      text: buildParagraphSpan(p, styles, from: s.start, to: s.end),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      textAlign: p.kind == ParagraphKind.heading
          ? TextAlign.center
          : TextAlign.start,
    )..layout(maxWidth: width);
    h += tp.height;
    tp.dispose();
    if (s.end >= p.text.length) h += spacing;
  }
  return h;
}

void paginationCoverageTests() {
  const body = TextStyle(fontSize: 19, height: 1.7, color: Colors.black);
  final styles = ReaderStyles(
    body: body,
    heading: body.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
    textColor: Colors.black,
    sentenceHighlight: Colors.yellow,
  );

  test('ghép mọi trang lại thành đúng toàn bộ chương, trang không quá cao', () {
    final chapter = StringBuffer();
    for (var i = 0; i < 30; i++) {
      chapter.writeln(
        List.generate(
          3 + i % 7,
          (k) =>
              'Đoạn $i câu $k: Một thiếu niên béo ú, con trai ông thợ rèn '
              'bước lên bục, sắc mặt tái mét như sắp bị hành hình.',
        ).join(' '),
      );
      chapter.writeln();
    }
    final paras = MarkdownLite.parseChapter(
      'Chương 1: Mệnh Giám Không Sáng',
      chapter.toString(),
    );
    for (final size in const [(340.0, 520.0), (300.0, 333.0), (360.0, 700.0)]) {
      final (width, height) = size;
      const spacing = 19 * 0.6;
      final pages = Paginator.paginate(
        paras,
        styles,
        width: width,
        height: height,
        paragraphSpacing: spacing,
      );
      // Mỗi đoạn: các lát liền mạch, không thiếu/trùng ký tự.
      final next = <int, int>{};
      for (final page in pages) {
        for (final s in page.slices) {
          final p = paras[s.paragraph];
          if (p.kind == ParagraphKind.separator) continue;
          expect(
            s.start,
            next[s.paragraph] ?? 0,
            reason: 'đoạn ${s.paragraph}',
          );
          next[s.paragraph] = s.end;
        }
      }
      for (var i = 0; i < paras.length; i++) {
        if (paras[i].kind == ParagraphKind.separator || paras[i].text.isEmpty) {
          continue;
        }
        expect(next[i], paras[i].text.length, reason: 'đoạn $i thiếu chữ');
      }
      // Văn bản ghép từ các lát == văn bản gốc.
      final rebuilt = StringBuffer();
      for (final page in pages) {
        for (final s in page.slices) {
          final p = paras[s.paragraph];
          if (p.kind != ParagraphKind.separator) {
            rebuilt.write(p.text.substring(s.start, s.end));
          }
        }
      }
      final original = paras
          .where((p) => p.kind != ParagraphKind.separator)
          .map((p) => p.text)
          .join();
      expect(rebuilt.toString(), original);
      // Không trang nào cao hơn vùng chữ (trừ dòng đơn cao hơn cả trang).
      for (final page in pages) {
        expect(
          _measurePage(page, paras, styles, width, spacing),
          lessThanOrEqualTo(height + 0.01),
        );
      }
    }
  });
}

void sentenceMappingTests() {
  List<ReaderPage> pages3() => [
    ReaderPage(const [PageSlice(0, 0, 20), PageSlice(1, 0, 50)]),
    ReaderPage(const [PageSlice(1, 50, 120)]),
    ReaderPage(const [PageSlice(1, 120, 180), PageSlice(2, 0, 30)]),
  ];

  test('câu nằm gọn trong một trang', () {
    final pages = pages3();
    expect(Paginator.pagesOfRange(pages, 1, 10, 40), [0]);
    expect(Paginator.pageOfSentence(pages, 1, 60, 100), 1);
    expect(Paginator.pagesOfRange(pages, 2, 0, 30), [2]);
  });

  test('câu vắt qua ranh giới trang: có cả hai trang, bắt đầu ở trang đầu', () {
    final pages = pages3();
    expect(Paginator.pagesOfRange(pages, 1, 40, 70), [0, 1]);
    expect(Paginator.pageOfSentence(pages, 1, 40, 70), 0);
  });

  test('đoạn bị chia qua 3 trang: câu dài trải cả 3 trang', () {
    final pages = pages3();
    expect(Paginator.pagesOfRange(pages, 1, 30, 150), [0, 1, 2]);
    expect(Paginator.pageOfSentence(pages, 1, 100, 130), 1);
    expect(Paginator.pageOfSentence(pages, 1, 125, 170), 2);
  });

  test('câu ở ngay mép trang không lẫn sang trang kia', () {
    final pages = pages3();
    expect(Paginator.pagesOfRange(pages, 1, 0, 50), [0]);
    expect(Paginator.pagesOfRange(pages, 1, 50, 80), [1]);
  });

  test('không tìm thấy thì lùi về trang của đoạn', () {
    final pages = pages3();
    expect(Paginator.pageOfSentence(pages, 9, 0, 5), 2);
  });
}
