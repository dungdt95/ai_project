/// Một câu: [start, end) trong đoạn gốc.
class SentenceSpan {
  const SentenceSpan(this.start, this.end);

  final int start;
  final int end;

  String slice(String text) => text.substring(start, end);

  @override
  bool operator ==(Object other) =>
      other is SentenceSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SentenceSpan($start, $end)';
}

/// Tách câu tiếng Việt cho TTS.
///
/// Kết thúc ở `. ! ? …` (và chuỗi `...`, `?!`) cùng dấu đóng ngoặc/ngoặc kép
/// đi liền sau; chỉ tách khi sau đó là khoảng trắng rồi một ký tự **không phải
/// chữ thường** (để `"Đi!" hắn nói` và `v.v. và` không bị cắt giữa chừng).
/// Không tách sau viết tắt (TP., TS., Mr....) và chữ cái đứng một mình.
class SentenceSplitter {
  const SentenceSplitter._();

  static const Set<String> abbreviations = {
    'tp',
    'ts',
    'ths',
    'gs',
    'pgs',
    'bs',
    'ks',
    'cn',
    'tx',
    'tt',
    'mr',
    'mrs',
    'ms',
    'dr',
    'st',
    'prof',
    'vs',
    'tr',
    'tel',
    'nxb',
    'q',
    'p',
    'h',
  };

  static const String _closers = '"\'”’»)]}›';

  static List<SentenceSpan> split(String text) {
    final spans = <SentenceSpan>[];
    final n = text.length;
    var start = 0;
    var i = 0;
    while (i < n) {
      final c = text[i];
      if (_isTerminator(c)) {
        var j = i + 1;
        while (j < n && _isTerminator(text[j])) {
          j++;
        }
        final terminatorEnd = j;
        while (j < n && _closers.contains(text[j])) {
          j++;
        }
        if (j >= n) break;
        if (_isSpace(text[j])) {
          var k = j;
          while (k < n && _isSpace(text[k])) {
            k++;
          }
          final lowerNext = k < n && _isLower(text[k]);
          final dotOnly = text.substring(i, terminatorEnd) == '.';
          if (!lowerNext &&
              !(dotOnly && _endsWithAbbreviation(text, start, i))) {
            spans.add(SentenceSpan(start, j));
            start = k;
            i = k;
            continue;
          }
        }
        i = terminatorEnd;
        continue;
      }
      i++;
    }
    if (start < n) {
      var e = n;
      while (e > start && _isSpace(text[e - 1])) {
        e--;
      }
      if (e > start) spans.add(SentenceSpan(start, e));
    }
    return _mergeNoise(text, spans);
  }

  static bool _isTerminator(String c) =>
      c == '.' || c == '!' || c == '?' || c == '…';

  /// Gộp "câu" không có chữ/số (ví dụ "...", "—") vào câu trước.
  static List<SentenceSpan> _mergeNoise(String text, List<SentenceSpan> spans) {
    final out = <SentenceSpan>[];
    final hasWord = RegExp(r'[\p{L}\p{N}]', unicode: true);
    for (final s in spans) {
      if (!hasWord.hasMatch(s.slice(text)) && out.isNotEmpty) {
        final last = out.removeLast();
        out.add(SentenceSpan(last.start, s.end));
      } else {
        out.add(s);
      }
    }
    return out;
  }

  static bool _endsWithAbbreviation(String text, int sentenceStart, int dot) {
    var b = dot;
    while (b > sentenceStart &&
        !_isSpace(text[b - 1]) &&
        !'"“‘(['.contains(text[b - 1])) {
      b--;
    }
    final token = text.substring(b, dot).toLowerCase();
    if (token.isEmpty) return false;
    if (abbreviations.contains(token)) return true;
    // Chữ cái đứng một mình: "N. V. A".
    if (token.runes.length == 1 &&
        RegExp(r'\p{L}', unicode: true).hasMatch(token)) {
      return true;
    }
    // Dạng "v.v", "t.p".
    return RegExp(r'^(\p{L}\.)+\p{L}$', unicode: true).hasMatch(token);
  }

  static bool _isSpace(String c) =>
      c == ' ' || c == '\n' || c == '\t' || c == ' ';

  static bool _isLower(String c) =>
      c != c.toUpperCase() && c == c.toLowerCase();

  /// Chuẩn hóa văn bản đưa cho engine TTS: bỏ gạch đầu dòng thoại và ký hiệu
  /// Markdown sót lại, đổi gạch ngang giữa câu thành dấu phẩy để ngắt hơi.
  static String speakable(String sentence) {
    var s = sentence.trim();
    s = s.replaceFirst(RegExp(r'^[—–-]+\s*'), '');
    s = s.replaceAll(RegExp(r'\s+[—–]\s+'), ', ');
    s = s.replaceAll(RegExp(r'[*_#]+'), '');
    return s.trim();
  }
}
