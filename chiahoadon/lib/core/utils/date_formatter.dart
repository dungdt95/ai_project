/// Định dạng ngày tháng theo tiếng Việt.
///
/// Dùng mẫu số thuần (`dd/MM/yyyy`) và tên tháng/thứ viết sẵn trong code,
/// thay vì nạp dữ liệu locale của `intl` lúc chạy. Lý do: app phải cho ra
/// kết quả giống nhau trên mọi máy và không phụ thuộc bước khởi tạo async.
class DateFormatter {
  const DateFormatter._();

  static const List<String> _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  /// `02/10/2026`.
  static String short(DateTime date) =>
      '${_p2(date.day)}/${_p2(date.month)}/${date.year}';

  /// `02/10` — dùng khi đã biết năm từ ngữ cảnh.
  static String dayMonth(DateTime date) => '${_p2(date.day)}/${_p2(date.month)}';

  /// `02/10/2026 19:30`.
  static String withTime(DateTime date) =>
      '${short(date)} ${_p2(date.hour)}:${_p2(date.minute)}';

  /// `Thứ Sáu, 02/10/2026`.
  static String withWeekday(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${short(date)}';

  /// `Tháng 10/2026`.
  static String monthYear(DateTime date) => 'Tháng ${date.month}/${date.year}';

  /// `T10` — nhãn ngắn cho trục biểu đồ.
  static String monthLabel(DateTime date) => 'T${date.month}';

  /// `2026-10` — khóa nhóm theo tháng, khớp `strftime('%Y-%m')` của SQLite.
  static String monthKey(DateTime date) => '${date.year}-${_p2(date.month)}';

  /// Hiện `Hôm nay` / `Hôm qua` / `Mai` khi gần, còn lại là `02/10/2026`.
  ///
  /// Dùng cho danh sách hóa đơn, nơi phần lớn bản ghi là vài ngày gần đây.
  static String relative(DateTime date, {DateTime? now}) {
    final today = startOfDay(now ?? DateTime.now());
    final target = startOfDay(date);
    final diffDays = target.difference(today).inDays;

    return switch (diffDays) {
      0 => 'Hôm nay',
      -1 => 'Hôm qua',
      1 => 'Mai',
      _ => short(date),
    };
  }

  // ─── Tiện ích mốc thời gian ───

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// 23:59:59.999 cùng ngày — dùng làm biên trên trong truy vấn `BETWEEN`.
  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  /// Thứ Hai của tuần chứa [date], lúc 00:00.
  ///
  /// Tuần bắt đầu từ thứ Hai theo cách tính ở Việt Nam. `DateTime.weekday` trả
  /// 1 cho thứ Hai nên lùi lại `weekday - 1` ngày là ra đầu tuần.
  static DateTime startOfWeek(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  /// Chủ nhật của tuần chứa [date], lúc 23:59:59.999.
  static DateTime endOfWeek(DateTime date) =>
      endOfDay(startOfWeek(date).add(const Duration(days: 6)));

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month);

  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1).subtract(const Duration(milliseconds: 1));

  static DateTime startOfYear(DateTime date) => DateTime(date.year);

  /// Khoảng ngày đọc được: `29/09 – 05/10/2026`.
  ///
  /// Bỏ bớt năm ở đầu khi hai mốc cùng năm — người đọc đã thấy năm ở cuối, lặp
  /// lại chỉ làm dòng dài thêm trên màn hình hẹp.
  static String span(DateTime from, DateTime to) {
    final end = short(to);
    final start = from.year == to.year
        ? '${_p2(from.day)}/${_p2(from.month)}'
        : short(from);

    return '$start – $end';
  }

  static String _p2(int value) => value.toString().padLeft(2, '0');
}

/// Khoảng thời gian dùng cho bộ lọc thống kê (SPEC FR-7.3).
class DateRange {
  const DateRange({
    required this.from,
    required this.to,
    required this.label,
    String? detail,
  }) : _detail = detail; // ignore: prefer_initializing_formals

  /// Tuần này, tính từ thứ Hai tới Chủ nhật.
  factory DateRange.thisWeek([DateTime? now]) {
    final base = now ?? DateTime.now();
    return DateRange(
      from: DateFormatter.startOfWeek(base),
      to: DateFormatter.endOfWeek(base),
      label: 'Tuần này',
    );
  }

  factory DateRange.lastWeek([DateTime? now]) {
    final base = now ?? DateTime.now();
    final prev = DateFormatter.startOfWeek(
      base,
    ).subtract(const Duration(days: 1));
    return DateRange(
      from: DateFormatter.startOfWeek(prev),
      to: DateFormatter.endOfWeek(prev),
      label: 'Tuần trước',
    );
  }

  factory DateRange.thisMonth([DateTime? now]) {
    final base = now ?? DateTime.now();
    return DateRange(
      from: DateFormatter.startOfMonth(base),
      to: DateFormatter.endOfMonth(base),
      label: 'Tháng này',
      detail: DateFormatter.monthYear(base),
    );
  }

  factory DateRange.lastMonth([DateTime? now]) {
    final base = now ?? DateTime.now();
    final prev = DateTime(base.year, base.month - 1);
    return DateRange(
      from: DateFormatter.startOfMonth(prev),
      to: DateFormatter.endOfMonth(prev),
      label: 'Tháng trước',
      detail: DateFormatter.monthYear(prev),
    );
  }

  factory DateRange.last3Months([DateTime? now]) {
    final base = now ?? DateTime.now();
    return DateRange(
      from: DateFormatter.startOfMonth(DateTime(base.year, base.month - 2)),
      to: DateFormatter.endOfMonth(base),
      label: '3 tháng gần nhất',
    );
  }

  factory DateRange.thisYear([DateTime? now]) {
    final base = now ?? DateTime.now();
    return DateRange(
      from: DateFormatter.startOfYear(base),
      to: DateFormatter.endOfDay(DateTime(base.year, 12, 31)),
      label: 'Năm nay',
      detail: 'Năm ${base.year}',
    );
  }

  /// Toàn bộ lịch sử — dùng cho "tổng chi phí" ở SPEC FR-7.1.
  factory DateRange.allTime() => DateRange(
    from: DateTime(2000),
    to: DateTime(2100),
    label: 'Tất cả',
    // Khoảng này là hai mốc kỹ thuật, in ra "01/01/2000 – 01/01/2100" chỉ làm
    // người đọc bối rối.
    detail: 'Toàn bộ thời gian',
  );

  factory DateRange.custom(DateTime from, DateTime to) => DateRange(
    from: DateFormatter.startOfDay(from),
    to: DateFormatter.endOfDay(to),
    label: '${DateFormatter.short(from)} - ${DateFormatter.short(to)}',
  );

  final DateTime from;
  final DateTime to;

  /// Nhãn ngắn cho chip chọn kỳ: "Tuần này", "Tháng trước".
  final String label;

  final String? _detail;

  /// Nói rõ kỳ này là từ ngày nào tới ngày nào.
  ///
  /// Nhãn ngắn không đủ: "Tuần trước" thì người đọc vẫn phải tự đếm lùi xem là
  /// những ngày nào. Mặc định in ra khoảng ngày; các kỳ có cách gọi gọn hơn
  /// (tháng, năm) thì tự đặt chuỗi riêng.
  String get detail => _detail ?? DateFormatter.span(from, to);

  int get fromMs => from.millisecondsSinceEpoch;
  int get toMs => to.millisecondsSinceEpoch;

  bool contains(DateTime date) =>
      !date.isBefore(from) && !date.isAfter(to);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.fromMs == fromMs && other.toMs == toMs;

  @override
  int get hashCode => Object.hash(fromMs, toMs);
}
