import 'chapter_naming.dart';
import 'drive_models.dart';

/// Chương đã lưu cục bộ, dùng để so với danh sách Drive.
class StoredChapterRef {
  const StoredChapterRef({
    required this.fileId,
    required this.number,
    required this.modified,
    this.hash = '',
  });

  final String fileId;
  final int number;
  final String modified;
  final String hash;
}

/// Kết quả so sánh danh sách Drive với dữ liệu cục bộ.
class DrivePlan {
  const DrivePlan({
    required this.numbers,
    required this.added,
    required this.changed,
    required this.ambiguous,
    required this.unchanged,
  });

  /// id tệp -> số chương (đã gán cho mọi mục văn bản).
  final Map<String, int> numbers;

  /// Tệp mới (chưa có chương tương ứng).
  final List<DriveEntry> added;

  /// Nhãn "sửa lần cuối" đã đổi chắc chắn -> cần tải lại để so băm.
  final List<DriveEntry> changed;

  /// Nhãn đổi không đáng tin (ví dụ "11:24 am" thành "Nov 21" khi sang ngày
  /// mới, hoặc không có nhãn): chỉ tải để so băm khi người dùng chủ động đồng bộ.
  final List<DriveEntry> ambiguous;

  final List<DriveEntry> unchanged;

  int get newCount => added.length;

  /// Có gì đáng báo "có cập nhật" khi kiểm tra nền (không tải gì).
  bool get hasUpdates => added.isNotEmpty || changed.isNotEmpty;

  /// Tệp phải tải khi đồng bộ.
  List<DriveEntry> toFetch({required bool includeAmbiguous}) => [
    ...added,
    ...changed,
    if (includeAmbiguous) ...ambiguous,
  ];

  static final RegExp _timeLike = RegExp(
    r'^\d{1,2}:\d{2}(\s?[ap]m)?$',
    caseSensitive: false,
  );

  /// So nhãn cũ/mới: 0 = giống, 1 = đổi chắc chắn, 2 = không chắc.
  static int compareModified(String stored, String current) {
    if (stored.isEmpty || current.isEmpty) return 2;
    if (stored == current) return 0;
    if (_timeLike.hasMatch(stored) && !_timeLike.hasMatch(current)) return 2;
    return 1;
  }

  static DrivePlan compute(
    List<DriveEntry> listing,
    List<StoredChapterRef> stored, {
    Set<int> existingNumbers = const {},
  }) {
    final entries = listing.where((e) => e.isTextual).toList();
    final byId = {for (final s in stored) s.fileId: s};
    final fixed = {
      for (final e in entries)
        if (byId[e.id] != null) e.id: byId[e.id]!.number,
    };
    // Số chương cục bộ chỉ dùng để số tự gán (tệp không có "Chương N") không
    // đè lên; tệp có "Chương N" vẫn gộp vào chương cùng số khi lưu.
    final numbers = ChapterNaming.assign(
      entries,
      fixed: fixed,
      reserved: existingNumbers,
    );

    final added = <DriveEntry>[];
    final changed = <DriveEntry>[];
    final ambiguous = <DriveEntry>[];
    final unchanged = <DriveEntry>[];
    final ordered = [...entries]
      ..sort((a, b) => numbers[a.id]!.compareTo(numbers[b.id]!));
    for (final e in ordered) {
      final s = byId[e.id];
      if (s == null) {
        added.add(e);
        continue;
      }
      switch (compareModified(s.modified, e.modified)) {
        case 0:
          unchanged.add(e);
        case 1:
          changed.add(e);
        default:
          ambiguous.add(e);
      }
    }
    return DrivePlan(
      numbers: numbers,
      added: added,
      changed: changed,
      ambiguous: ambiguous,
      unchanged: unchanged,
    );
  }
}
