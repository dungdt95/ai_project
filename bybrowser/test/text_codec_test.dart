import 'dart:convert';
import 'dart:typed_data';

import 'package:bybrowser/core/encoding/text_codec.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _b(List<int> l) => Uint8List.fromList(l);

void main() {
  group('TextCodec.decode', () {
    test('UTF-8 không BOM, LF', () {
      final d = TextCodec.decode(_b(utf8.encode('xin chào\nđường\n')));
      expect(d.encoding, TextEncoding.utf8);
      expect(d.lineEnding, LineEnding.lf);
      expect(d.text, 'xin chào\nđường\n');
      expect(d.hadMalformedBytes, isFalse);
    });

    test('UTF-8 BOM, CRLF → chuẩn hóa về LF', () {
      final d = TextCodec.decode(_b([0xEF, 0xBB, 0xBF, ...utf8.encode('a\r\nb\r\n')]));
      expect(d.encoding, TextEncoding.utf8Bom);
      expect(d.lineEnding, LineEnding.crlf);
      expect(d.text, 'a\nb\n');
    });

    test('UTF-16 LE BOM', () {
      final d = TextCodec.decode(_b([0xFF, 0xFE, 0x41, 0x00, 0x0A, 0x00, 0xEA, 0x01]));
      expect(d.encoding, TextEncoding.utf16Le);
      expect(d.text, 'A\nǪ'); // 0x01EA = U+01EA
    });

    test('UTF-16 BE BOM', () {
      final d = TextCodec.decode(_b([0xFE, 0xFF, 0x00, 0x41, 0x00, 0x42]));
      expect(d.encoding, TextEncoding.utf16Be);
      expect(d.text, 'AB');
    });

    test('bytes không phải UTF-8 → Latin-1, đánh dấu malformed', () {
      final d = TextCodec.decode(_b([0x48, 0xE9, 0x0A])); // "Hé\n" trong Latin-1
      expect(d.encoding, TextEncoding.latin1);
      expect(d.text, 'Hé\n');
      expect(d.hadMalformedBytes, isTrue);
    });

    test('kiểu xuống dòng hỗn hợp: đa số thắng', () {
      final d = TextCodec.decode(_b(utf8.encode('a\r\nb\r\nc\nd')));
      expect(d.lineEnding, LineEnding.crlf);
      expect(d.text, 'a\nb\nc\nd');
    });

    test('CR đơn (Mac cổ điển)', () {
      final d = TextCodec.decode(_b(utf8.encode('a\rb\r')));
      expect(d.lineEnding, LineEnding.cr);
      expect(d.text, 'a\nb\n');
    });

    test('file rỗng', () {
      final d = TextCodec.decode(Uint8List(0));
      expect(d.text, '');
      expect(d.encoding, TextEncoding.utf8);
      expect(d.lineEnding, LineEnding.lf);
    });
  });

  group('TextCodec.encode', () {
    test('round-trip UTF-8 BOM + CRLF giữ nguyên bytes', () {
      final original = _b([0xEF, 0xBB, 0xBF, ...utf8.encode('một\r\nhai\r\n')]);
      final d = TextCodec.decode(original);
      expect(TextCodec.encode(d.text, d.encoding, d.lineEnding), original);
    });

    test('round-trip UTF-16 LE giữ nguyên bytes', () {
      final original = _b([0xFF, 0xFE, 0x41, 0x00, 0x0D, 0x00, 0x0A, 0x00, 0x42, 0x00]);
      final d = TextCodec.decode(original);
      expect(d.lineEnding, LineEnding.crlf);
      expect(TextCodec.encode(d.text, d.encoding, d.lineEnding), original);
    });

    test('Latin-1: ký tự ngoài bảng mã thay bằng ?', () {
      final out = TextCodec.encode('aư', TextEncoding.latin1, LineEnding.lf);
      expect(out, [0x61, 0x3F]);
    });
  });
}
