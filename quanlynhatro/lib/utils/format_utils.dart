import 'package:intl/intl.dart';

class FormatUtils {
  static final NumberFormat _vndFormat = NumberFormat.decimalPattern('vi_VN');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _monthFormat = DateFormat('MM/yyyy');

  static String money(num? value) {
    if (value == null) return '0';
    return _vndFormat.format(value);
  }

  static String moneyVnd(num? value) => '${money(value)}đ';

  static String date(DateTime? d) => d == null ? '' : _dateFormat.format(d);

  static String monthYear(int month, int year) =>
      '${month.toString().padLeft(2, '0')}/$year';

  static DateTime? parseDate(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    try {
      return _dateFormat.parseStrict(input.trim());
    } catch (_) {
      return null;
    }
  }

  static int parseInt(String? input) {
    if (input == null) return 0;
    final cleaned = input.replaceAll(RegExp(r'[^0-9-]'), '');
    if (cleaned.isEmpty) return 0;
    return int.tryParse(cleaned) ?? 0;
  }

  static String monthName(int month, int year) {
    return 'Tháng ${month.toString().padLeft(2, '0')} năm $year';
  }
}
