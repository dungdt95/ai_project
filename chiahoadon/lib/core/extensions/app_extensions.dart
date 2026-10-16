import '../utils/date_formatter.dart';
import '../utils/money_formatter.dart';

/// Tiện ích cho số tiền. Tiền luôn là `int` đơn vị đồng (SPEC NFR-6).
extension MoneyInt on int {
  /// `1234567.toVnd()` → `"1.234.567 đ"`.
  String toVnd() => MoneyFormatter.format(this);

  /// Không kèm ký hiệu tiền.
  String toVndPlain() => MoneyFormatter.formatPlain(this);

  /// Luôn kèm dấu `+` hoặc `-`.
  String toVndSigned() => MoneyFormatter.formatSigned(this);

  /// Dạng ngắn cho nhãn biểu đồ.
  String toVndCompact() => MoneyFormatter.formatCompact(this);

  /// Phần trăm basis point: `800.toPercent()` → `"8%"`.
  String toPercent() => MoneyFormatter.formatPercentBp(this);
}

extension EpochMs on int {
  /// Chuyển mốc epoch milli đọc từ DB thành [DateTime] theo giờ địa phương.
  DateTime toDateTime() => DateTime.fromMillisecondsSinceEpoch(this);
}

extension DateTimeX on DateTime {
  int get epochMs => millisecondsSinceEpoch;

  DateTime get dayStart => DateFormatter.startOfDay(this);

  DateTime get dayEnd => DateFormatter.endOfDay(this);

  /// `02/10/2026`.
  String toShortDate() => DateFormatter.short(this);

  /// `Hôm nay` / `Hôm qua` / `02/10/2026`.
  String toRelativeDate() => DateFormatter.relative(this);

  bool isSameDayAs(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

extension NullableStringX on String? {
  /// `null` và chuỗi chỉ gồm khoảng trắng đều coi là rỗng.
  bool get isBlank => this == null || this!.trim().isEmpty;

  bool get isNotBlank => !isBlank;

  /// Trả `null` nếu rỗng, ngược lại trả chuỗi đã trim.
  /// Dùng khi ghi vào cột cho phép NULL để không lưu chuỗi rỗng.
  String? get trimmedOrNull {
    final value = this?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }
}
