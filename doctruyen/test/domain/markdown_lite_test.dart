import 'package:doctruyen/domain/text/markdown_lite.dart';
import 'package:doctruyen/domain/text/paragraph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bỏ tiêu đề # trùng, nhận diện thoại, nghiêng/đậm và dấu phân cách', () {
    const content = '''
# Chương 1: Mở đầu

Trời *mưa* rất **to**.

— Ngươi là ai?

---

* * *
Hết.
''';
    final ps = MarkdownLite.parseChapter('Chương 1: Mở đầu', content);
    expect(ps.first.kind, ParagraphKind.heading);
    expect(ps.first.text, 'Chương 1: Mở đầu');
    expect(ps[1].text, 'Trời mưa rất to.');
    expect(
      ps[1].styles.any(
        (s) => s.italic && ps[1].text.substring(s.start, s.end) == 'mưa',
      ),
      isTrue,
    );
    expect(
      ps[1].styles.any(
        (s) => s.bold && ps[1].text.substring(s.start, s.end) == 'to',
      ),
      isTrue,
    );
    expect(ps[2].isDialogue, isTrue);
    expect(ps[3].kind, ParagraphKind.separator);
    expect(ps[4].kind, ParagraphKind.separator);
    expect(ps.last.text, 'Hết.');
    expect(ps.where((p) => p.kind == ParagraphKind.heading).length, 1);
  });
}
