import 'dart:convert';
import 'dart:typed_data';

/// Bảng mã của file text. Chỉ hỗ trợ các bảng mã Unicode phổ biến + Latin-1
/// làm phương án dự phòng khi dữ liệu không phải UTF-8 hợp lệ.
enum TextEncoding {
  utf8,
  utf8Bom,
  utf16Le,
  utf16Be,
  latin1;

  String get label => switch (this) {
        TextEncoding.utf8 => 'UTF-8',
        TextEncoding.utf8Bom => 'UTF-8 BOM',
        TextEncoding.utf16Le => 'UTF-16 LE',
        TextEncoding.utf16Be => 'UTF-16 BE',
        TextEncoding.latin1 => 'Latin-1',
      };
}

/// Kiểu xuống dòng trong file. Editor luôn làm việc với `\n`; khi lưu sẽ
/// chuyển lại kiểu gốc để không làm "đổi toàn bộ dòng" trong diff.
enum LineEnding {
  lf,
  crlf,
  cr;

  String get label => switch (this) {
        LineEnding.lf => 'LF',
        LineEnding.crlf => 'CRLF',
        LineEnding.cr => 'CR',
      };

  String get sequence => switch (this) {
        LineEnding.lf => '\n',
        LineEnding.crlf => '\r\n',
        LineEnding.cr => '\r',
      };
}

/// Kết quả giải mã: nội dung đã chuẩn hóa xuống dòng thành `\n` + metadata
/// để mã hóa ngược lại y như file gốc.
class DecodedText {
  const DecodedText({
    required this.text,
    required this.encoding,
    required this.lineEnding,
    this.hadMalformedBytes = false,
  });

  final String text;
  final TextEncoding encoding;
  final LineEnding lineEnding;

  /// `true` nếu dữ liệu không phải UTF-8 hợp lệ và đã phải rơi về Latin-1.
  final bool hadMalformedBytes;
}

class TextCodec {
  TextCodec._();

  static const _utf8Bom = [0xEF, 0xBB, 0xBF];

  static DecodedText decode(Uint8List bytes) {
    // 1. Nhận diện theo BOM.
    if (bytes.length >= 3 &&
        bytes[0] == _utf8Bom[0] &&
        bytes[1] == _utf8Bom[1] &&
        bytes[2] == _utf8Bom[2]) {
      final text = utf8.decode(bytes.sublist(3), allowMalformed: true);
      return _finish(text, TextEncoding.utf8Bom);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _finish(_decodeUtf16(bytes, 2, Endian.little), TextEncoding.utf16Le);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _finish(_decodeUtf16(bytes, 2, Endian.big), TextEncoding.utf16Be);
    }

    // 2. Không BOM: thử UTF-8 nghiêm ngặt, hỏng thì Latin-1 (không bao giờ ném lỗi).
    try {
      return _finish(utf8.decode(bytes), TextEncoding.utf8);
    } on FormatException {
      return _finish(latin1.decode(bytes), TextEncoding.latin1, malformed: true);
    }
  }

  static Uint8List encode(String text, TextEncoding encoding, LineEnding lineEnding) {
    final normalized = lineEnding == LineEnding.lf
        ? text
        : text.replaceAll('\n', lineEnding.sequence);
    switch (encoding) {
      case TextEncoding.utf8:
        return Uint8List.fromList(utf8.encode(normalized));
      case TextEncoding.utf8Bom:
        return Uint8List.fromList([..._utf8Bom, ...utf8.encode(normalized)]);
      case TextEncoding.utf16Le:
        return _encodeUtf16(normalized, Endian.little, bom: const [0xFF, 0xFE]);
      case TextEncoding.utf16Be:
        return _encodeUtf16(normalized, Endian.big, bom: const [0xFE, 0xFF]);
      case TextEncoding.latin1:
        // Ký tự ngoài Latin-1 (ví dụ tiếng Việt) không biểu diễn được → thay bằng '?'.
        return Uint8List.fromList(
          normalized.codeUnits.map((c) => c <= 0xFF ? c : 0x3F).toList(),
        );
    }
  }

  /// Chuẩn hóa xuống dòng về `\n` và ghi nhận kiểu gốc (đa số thắng).
  static DecodedText _finish(String raw, TextEncoding enc, {bool malformed = false}) {
    var crlf = 0, lf = 0, cr = 0;
    for (var i = 0; i < raw.length; i++) {
      final c = raw.codeUnitAt(i);
      if (c == 0x0D) {
        if (i + 1 < raw.length && raw.codeUnitAt(i + 1) == 0x0A) {
          crlf++;
          i++;
        } else {
          cr++;
        }
      } else if (c == 0x0A) {
        lf++;
      }
    }
    final LineEnding ending;
    if (crlf == 0 && cr == 0) {
      ending = LineEnding.lf;
    } else if (crlf >= lf && crlf >= cr) {
      ending = LineEnding.crlf;
    } else if (lf >= cr) {
      ending = LineEnding.lf;
    } else {
      ending = LineEnding.cr;
    }
    final text = (crlf == 0 && cr == 0)
        ? raw
        : raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return DecodedText(
      text: text,
      encoding: enc,
      lineEnding: ending,
      hadMalformedBytes: malformed,
    );
  }

  static String _decodeUtf16(Uint8List bytes, int offset, Endian endian) {
    final len = (bytes.length - offset) ~/ 2;
    final data = ByteData.sublistView(bytes, offset, offset + len * 2);
    final units = Uint16List(len);
    for (var i = 0; i < len; i++) {
      units[i] = data.getUint16(i * 2, endian);
    }
    return String.fromCharCodes(units);
  }

  static Uint8List _encodeUtf16(String text, Endian endian, {required List<int> bom}) {
    final units = text.codeUnits;
    final out = Uint8List(bom.length + units.length * 2);
    out.setRange(0, bom.length, bom);
    final data = ByteData.sublistView(out, bom.length);
    for (var i = 0; i < units.length; i++) {
      data.setUint16(i * 2, units[i], endian);
    }
    return out;
  }
}
