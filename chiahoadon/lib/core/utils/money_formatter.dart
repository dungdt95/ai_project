/// Định dạng và phân tích số tiền.
///
/// Toàn bộ app lưu tiền dưới dạng `int` với đơn vị **đồng** (SPEC NFR-6).
/// Việc nhóm chữ số được làm thủ công thay vì qua `NumberFormat` để kết quả
/// không phụ thuộc vào dữ liệu locale được nạp lúc chạy — app phải hoạt động
/// giống nhau trên mọi máy, kể cả khi không có mạng.
class MoneyFormatter {
  const MoneyFormatter._();

  static const String symbol = 'đ';
  static const String _groupSep = '.';

  /// `1234567` → `"1.234.567 đ"`.
  static String format(int amount) => '${formatPlain(amount)} $symbol';

  /// `1234567` → `"1.234.567"` (không có ký hiệu tiền).
  static String formatPlain(int amount) {
    final isNegative = amount < 0;
    final digits = amount.abs().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(_groupSep);
      }
      buffer.write(digits[i]);
    }

    return isNegative ? '-$buffer' : buffer.toString();
  }

  /// Luôn hiện dấu: `500000` → `"+500.000 đ"`, `-300000` → `"-300.000 đ"`.
  ///
  /// Dùng cho số dư ròng, nơi dấu mang nghĩa "được nhận" hay "phải trả".
  static String formatSigned(int amount) {
    if (amount == 0) return format(0);
    final prefix = amount > 0 ? '+' : '';
    return '$prefix${format(amount)}';
  }

  /// Dạng ngắn cho nhãn biểu đồ: `1200000` → `"1,2 tr"`, `850000` → `"850 ng"`.
  static String formatCompact(int amount) {
    final abs = amount.abs();
    final sign = amount < 0 ? '-' : '';

    if (abs >= 1000000000) {
      return '$sign${_oneDecimal(abs / 1000000000)} tỷ';
    }
    if (abs >= 1000000) {
      return '$sign${_oneDecimal(abs / 1000000)} tr';
    }
    if (abs >= 1000) {
      return '$sign${_oneDecimal(abs / 1000)} ng';
    }
    return '$sign$abs';
  }

  /// Phân tích chuỗi người dùng nhập thành số đồng.
  ///
  /// Bỏ qua mọi ký tự không phải chữ số và dấu trừ, nên chấp nhận được cả
  /// `"1.234.567"`, `"1 234 567"`, `"1,234,567"` và `"1234567 đ"`.
  /// Trả `null` nếu không có chữ số nào.
  static int? parse(String? input) {
    if (input == null) return null;

    final isNegative = input.trimLeft().startsWith('-');
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    final value = int.tryParse(digits);
    if (value == null) return null;

    return isNegative ? -value : value;
  }

  /// Phân tích, trả `0` nếu chuỗi rỗng hoặc không hợp lệ.
  static int parseOrZero(String? input) => parse(input) ?? 0;

  /// Phần trăm lưu dạng basis point: `800` → `"8%"`, `850` → `"8,5%"`.
  ///
  /// Xem SPEC §FR-5: mọi tỷ lệ phần trăm đều là `int` để tránh sai số `double`.
  static String formatPercentBp(int basisPoints) {
    if (basisPoints % 100 == 0) return '${basisPoints ~/ 100}%';

    final whole = basisPoints ~/ 100;
    final frac = (basisPoints % 100).abs();
    final fracText = frac % 10 == 0 ? '${frac ~/ 10}' : '$frac';
    return '$whole,$fracText%';
  }

  /// `"8,5"` hoặc `"8.5"` → `850` basis point. Trả `null` nếu không hợp lệ.
  static int? parsePercentToBp(String? input) {
    if (input == null) return null;

    final normalized = input.trim().replaceAll(',', '.').replaceAll('%', '');
    if (normalized.isEmpty) return null;

    final value = double.tryParse(normalized);
    if (value == null) return null;

    return (value * 100).round();
  }

  static String _oneDecimal(double value) {
    final rounded = (value * 10).round();
    final whole = rounded ~/ 10;
    final frac = rounded % 10;
    return frac == 0 ? '$whole' : '$whole,$frac';
  }
}
