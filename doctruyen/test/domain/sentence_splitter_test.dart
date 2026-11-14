import 'package:doctruyen/domain/text/sentence_splitter.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> split(String s) =>
    SentenceSplitter.split(s).map((e) => e.slice(s)).toList();

void main() {
  group('SentenceSplitter', () {
    test('tách theo dấu chấm, chấm than, chấm hỏi', () {
      expect(split('Trời tối. Gió nổi! Ai đó?'), [
        'Trời tối.',
        'Gió nổi!',
        'Ai đó?',
      ]);
    });

    test('dấu ba chấm giữa câu không tách khi sau là chữ thường', () {
      expect(split('Hắn đi... không ngoái lại. Trời tối!'), [
        'Hắn đi... không ngoái lại.',
        'Trời tối!',
      ]);
    });

    test('dấu ba chấm cuối câu rồi câu mới thì tách', () {
      expect(split('Hắn im lặng... Rồi bỏ đi.'), [
        'Hắn im lặng...',
        'Rồi bỏ đi.',
      ]);
      expect(split('Thật sao… Không thể nào.'), [
        'Thật sao…',
        'Không thể nào.',
      ]);
    });

    test('?! và nhiều dấu liền nhau', () {
      expect(split('Gì cơ?! Ngươi nói lại xem!!! Được.'), [
        'Gì cơ?!',
        'Ngươi nói lại xem!!!',
        'Được.',
      ]);
    });

    test('viết tắt TP., TS., chữ cái đứng một mình không bị tách', () {
      expect(split('Ông ở TP. Hồ Chí Minh. Rất đông.'), [
        'Ông ở TP. Hồ Chí Minh.',
        'Rất đông.',
      ]);
      expect(split('TS. Nguyễn Văn A đến. Mọi người đứng dậy.'), [
        'TS. Nguyễn Văn A đến.',
        'Mọi người đứng dậy.',
      ]);
      expect(split('N. V. A đến nơi.'), ['N. V. A đến nơi.']);
    });

    test('ngoặc kép: lời dẫn chữ thường đi sau thì giữ cùng câu', () {
      expect(split('"Đi đi!" hắn quát. Ai nấy im lặng.'), [
        '"Đi đi!" hắn quát.',
        'Ai nấy im lặng.',
      ]);
      expect(split('"Đi đi!" Hắn quát.'), ['"Đi đi!"', 'Hắn quát.']);
      expect(split('Hắn nói: “Được rồi.” Rồi quay đi.'), [
        'Hắn nói: “Được rồi.”',
        'Rồi quay đi.',
      ]);
    });

    test('lời thoại gạch đầu dòng', () {
      expect(split('— Ngươi là ai? — Hắn hỏi.'), [
        '— Ngươi là ai?',
        '— Hắn hỏi.',
      ]);
      expect(SentenceSplitter.speakable('— Ngươi là ai?'), 'Ngươi là ai?');
    });

    test('số thập phân không bị tách; câu cuối không dấu vẫn được giữ', () {
      expect(split('Giá 3.5 triệu. Còn lại không rõ'), [
        'Giá 3.5 triệu.',
        'Còn lại không rõ',
      ]);
    });

    test('đoạn rỗng và chỉ có dấu', () {
      expect(split(''), isEmpty);
      expect(split('...'), ['...']);
    });

    test('span khớp chỉ số trong chuỗi gốc', () {
      const s = 'Một. Hai! Ba?';
      final spans = SentenceSplitter.split(s);
      expect(spans.first.start, 0);
      expect(s.substring(spans[1].start, spans[1].end), 'Hai!');
    });
  });
}
