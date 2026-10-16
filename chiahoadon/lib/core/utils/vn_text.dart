/// Xử lý văn bản tiếng Việt: bỏ dấu để tìm kiếm và so trùng tên.
///
/// Dùng cho hai việc:
/// - Cột `members.name_norm`, để gõ "an" tìm được "Ân" và "Àn".
/// - Cảnh báo trùng tên thành viên (SPEC FR-1, quy tắc nghiệp vụ).
class VnText {
  const VnText._();

  static const Map<String, String> _diacritics = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };

  static final Map<int, String> _lookup = _buildLookup();

  /// Bỏ dấu, chuyển về chữ thường, gộp khoảng trắng liên tiếp thành một.
  ///
  /// `"  Nguyễn  Văn Đức "` → `"nguyen van duc"`.
  static String normalize(String input) {
    final lower = input.toLowerCase();
    final buffer = StringBuffer();

    for (final codeUnit in lower.runes) {
      buffer.write(_lookup[codeUnit] ?? String.fromCharCode(codeUnit));
    }

    return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Hai tên có bị coi là trùng nhau hay không (sau khi bỏ dấu và trim).
  static bool isSameName(String a, String b) => normalize(a) == normalize(b);

  /// `haystack` có chứa `needle` hay không, bỏ qua dấu và hoa thường.
  ///
  /// Dùng cho ô tìm kiếm thành viên (FR-1.7) và hóa đơn (FR-3.12).
  static bool contains(String haystack, String needle) {
    final n = normalize(needle);
    if (n.isEmpty) return true;
    return normalize(haystack).contains(n);
  }

  /// Chữ cái đầu dùng làm avatar: `"Nguyễn Văn Đức"` → `"Đ"`.
  ///
  /// Lấy chữ đầu của từ **cuối** vì người Việt gọi nhau bằng tên, không bằng họ.
  /// Giữ nguyên dấu để avatar hiển thị đúng chữ.
  static String initial(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    return words.last.substring(0, 1).toUpperCase();
  }

  static Map<int, String> _buildLookup() {
    final map = <int, String>{};
    for (final entry in _diacritics.entries) {
      for (final char in entry.value.runes) {
        map[char] = entry.key;
      }
    }
    return map;
  }
}
