import 'drive_models.dart';

/// Rút số chương từ tên và sắp xếp tệp chương.
class ChapterNaming {
  const ChapterNaming._();

  static final RegExp _number = RegExp(
    r'(?:chương|chuong|chapter|chap|hồi|hoi)\s*\.?\s*(\d{1,5})(?!\d)',
    caseSensitive: false,
    unicode: true,
  );

  /// "Chương 12: ..." -> 12; không có số -> null.
  static int? numberOf(String title) {
    final m = _number.firstMatch(title);
    return m == null ? null : int.parse(m.group(1)!);
  }

  /// So sánh "tự nhiên": chuỗi số so như số.
  static int naturalCompare(String a, String b) {
    final re = RegExp(r'\d+|\D+');
    final pa = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
    final pb = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]);
      final nb = int.tryParse(pb[i]);
      final c = (na != null && nb != null)
          ? na.compareTo(nb)
          : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }

  /// Gán số chương cho các mục theo tên.
  ///
  /// Mục có "Chương N" giữ số N (trùng số: mục đến sau bị coi như không có số);
  /// mục không có số xếp cuối theo thứ tự tự nhiên, nhận số lớn nhất + 1, ...
  /// [fixed] là số đã gán trước (id -> số) và được giữ nguyên.
  static Map<String, int> assign(
    List<DriveEntry> entries, {
    Map<String, int> fixed = const {},
    Set<int> reserved = const {},
  }) {
    final result = <String, int>{};
    final used = <int>{...fixed.values};
    final sorted = [...entries]
      ..sort((a, b) => naturalCompare(a.title, b.title));
    final pending = <DriveEntry>[];
    for (final e in sorted) {
      final f = fixed[e.id];
      if (f != null) {
        result[e.id] = f;
        continue;
      }
      final n = numberOf(e.title);
      if (n != null && used.add(n)) {
        result[e.id] = n;
      } else {
        pending.add(e);
      }
    }
    final all = {...used, ...reserved};
    var next = all.isEmpty ? 1 : all.reduce((a, b) => a > b ? a : b) + 1;
    for (final e in pending) {
      result[e.id] = next++;
    }
    return result;
  }
}
