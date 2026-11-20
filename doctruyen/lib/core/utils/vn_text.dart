/// Tiện ích chuỗi tiếng Việt.
class VnText {
  const VnText._();

  static const String _from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  static const String _to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

  static final Map<int, String> _map = () {
    final m = <int, String>{};
    final from = _from.runes.toList();
    for (var i = 0; i < from.length; i++) {
      m[from[i]] = _to[i];
    }
    return m;
  }();

  /// Hạ chữ thường và bỏ dấu, **giữ nguyên độ dài chuỗi** (mỗi ký tự dựng sẵn
  /// ánh xạ sang đúng một ký tự), nên chỉ số khớp dùng được trên chuỗi gốc.
  static String normalize(String input) {
    final lower = input.toLowerCase();
    final b = StringBuffer();
    for (final r in lower.runes) {
      b.write(_map[r] ?? String.fromCharCode(r));
    }
    return b.toString();
  }

  /// Chữ cái đại diện cho ảnh bìa: tối đa 2 ký tự đầu của các từ đầu.
  static String initials(String title) {
    final words = title
        .trim()
        .split(RegExp(r'\s+'))
        .where(
          (w) =>
              w.isNotEmpty &&
              RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(w[0]),
        )
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}
