import 'package:doctruyen/domain/text/markdown_lite.dart';
import 'package:doctruyen/features/reader/paginator.dart';
import 'package:doctruyen/features/reader/reader_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Hồi quy: Text trong MaterialApp phải cao đúng bằng số đo của Paginator,
  // nếu không dòng cuối của trang sẽ tràn xuống dưới thanh điều khiển.
  testWidgets('chiều cao vẽ ra khớp với chiều cao đã phân trang', (t) async {
    final styles = ReaderStyles.forReader(
      fontFamily: 'serif',
      fontSize: 19,
      lineHeight: 1.7,
      textColor: Colors.black,
      sentenceHighlight: Colors.yellow,
    );
    final text = List.generate(
      25,
      (i) =>
          'Câu số $i: Mặt gương rung lên kêu oong một tiếng dài, mấy hoa văn.',
    ).join(' ');
    final paras = MarkdownLite.parseChapter('Chương 1', '$text\n\n$text');
    const width = 371.4;
    const spacing = 19 * 0.6;
    final pages = Paginator.paginate(
      paras,
      styles,
      width: width,
      height: 654,
      paragraphSpacing: spacing,
    );
    expect(pages.length, greaterThan(1));

    for (final page in pages) {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: width,
                child: Column(
                  key: const ValueKey('col'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in page.slices)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: s.end >= paras[s.paragraph].text.length
                              ? spacing
                              : 0,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text.rich(
                            buildParagraphSpan(
                              paras[s.paragraph],
                              styles,
                              from: s.start,
                              to: s.end,
                            ),
                            textScaler: TextScaler.noScaling,
                            locale: kReaderLocale,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final h = t.getSize(find.byKey(const ValueKey('col'))).height;
      expect(h, lessThanOrEqualTo(654 + 0.01));
    }
  });
}
