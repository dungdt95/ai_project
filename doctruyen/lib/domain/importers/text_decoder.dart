import 'dart:convert';
import 'dart:typed_data';

/// Nhận diện bảng mã và giải mã tệp văn bản.
///
/// Thứ tự: BOM UTF-8 / UTF-16 LE / BE → UTF-16 không BOM (nhiều byte 0) →
/// UTF-8 hợp lệ → Windows-1258 (tiếng Việt kiểu cũ) / latin-1.
class TextDecoder {
  const TextDecoder._();

  static String decode(List<int> input) {
    final b = input is Uint8List ? input : Uint8List.fromList(input);
    if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
      return utf8.decode(b.sublist(3), allowMalformed: true);
    }
    if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) {
      return _utf16(b, 2, littleEndian: true);
    }
    if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
      return _utf16(b, 2, littleEndian: false);
    }
    final guess = _guessUtf16WithoutBom(b);
    if (guess != null) return _utf16(b, 0, littleEndian: guess);
    try {
      return utf8.decode(b);
    } on FormatException {
      return decodeWindows1258(b);
    }
  }

  /// `true` = LE, `false` = BE, `null` = không phải UTF-16.
  static bool? _guessUtf16WithoutBom(Uint8List b) {
    if (b.length < 4) return null;
    final n = b.length < 2000 ? b.length : 2000;
    var evenZero = 0;
    var oddZero = 0;
    for (var i = 0; i < n; i++) {
      if (b[i] == 0) {
        if (i.isEven) {
          evenZero++;
        } else {
          oddZero++;
        }
      }
    }
    final half = n / 2;
    if (oddZero > half * 0.3 && evenZero < half * 0.05) return true;
    if (evenZero > half * 0.3 && oddZero < half * 0.05) return false;
    return null;
  }

  static String _utf16(Uint8List b, int offset, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = offset; i + 1 < b.length; i += 2) {
      units.add(littleEndian ? b[i] | (b[i + 1] << 8) : (b[i] << 8) | b[i + 1]);
    }
    return String.fromCharCodes(units);
  }

  static const Map<int, int> _cp1258Low = {
    0x80: 0x20AC,
    0x82: 0x201A,
    0x83: 0x0192,
    0x84: 0x201E,
    0x85: 0x2026,
    0x86: 0x2020,
    0x87: 0x2021,
    0x88: 0x02C6,
    0x89: 0x2030,
    0x8B: 0x2039,
    0x8C: 0x0152,
    0x91: 0x2018,
    0x92: 0x2019,
    0x93: 0x201C,
    0x94: 0x201D,
    0x95: 0x2022,
    0x96: 0x2013,
    0x97: 0x2014,
    0x98: 0x02DC,
    0x99: 0x2122,
    0x9B: 0x203A,
    0x9C: 0x0153,
    0x9F: 0x0178,
  };

  static const Map<int, int> _cp1258High = {
    0xC3: 0x0102,
    0xCC: 0x0300,
    0xD0: 0x0110,
    0xD2: 0x0309,
    0xD5: 0x01A0,
    0xDD: 0x01AF,
    0xDE: 0x0303,
    0xE3: 0x0103,
    0xEC: 0x0301,
    0xF0: 0x0111,
    0xF2: 0x0323,
    0xF5: 0x01A1,
    0xFD: 0x01B0,
    0xFE: 0x20AB,
  };

  /// Giải mã Windows-1258 rồi ghép dấu rời thành chữ dựng sẵn (NFC).
  static String decodeWindows1258(List<int> bytes) {
    final codes = <int>[];
    for (final v in bytes) {
      if (v < 0x80) {
        codes.add(v);
      } else if (v < 0xA0) {
        codes.add(_cp1258Low[v] ?? 0xFFFD);
      } else {
        codes.add(_cp1258High[v] ?? v);
      }
    }
    return _compose(String.fromCharCodes(codes));
  }

  // Thứ tự dấu: huyền, hỏi, ngã, sắc, nặng.
  static const List<int> _marks = [0x0300, 0x0309, 0x0303, 0x0301, 0x0323];
  static const Map<String, String> _composedLower = {
    'a': 'àảãáạ',
    'ă': 'ằẳẵắặ',
    'â': 'ầẩẫấậ',
    'e': 'èẻẽéẹ',
    'ê': 'ềểễếệ',
    'i': 'ìỉĩíị',
    'o': 'òỏõóọ',
    'ô': 'ồổỗốộ',
    'ơ': 'ờởỡớợ',
    'u': 'ùủũúụ',
    'ư': 'ừửữứự',
    'y': 'ỳỷỹýỵ',
  };

  static final Map<String, String> _composeMap = () {
    final m = <String, String>{};
    _composedLower.forEach((base, composed) {
      final chars = composed.runes.map(String.fromCharCode).toList();
      for (var i = 0; i < _marks.length; i++) {
        final mark = String.fromCharCode(_marks[i]);
        m['$base$mark'] = chars[i];
        m['${base.toUpperCase()}$mark'] = chars[i].toUpperCase();
      }
    });
    return m;
  }();

  static String _compose(String s) {
    if (!s.contains(RegExp('[̣̀́̃̉]'))) return s;
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i + 1 < s.length) {
        final composed = _composeMap[s.substring(i, i + 2)];
        if (composed != null) {
          out.write(composed);
          i++;
          continue;
        }
      }
      out.write(s[i]);
    }
    return out.toString();
  }
}
