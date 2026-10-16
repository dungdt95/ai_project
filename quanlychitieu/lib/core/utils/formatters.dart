import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _vndFormatter = NumberFormat('#,###', 'vi_VN');
final _dateFormatter = DateFormat('dd/MM/yyyy');
final _monthFormatter = DateFormat('MM/yyyy');

String formatCurrency(double amount) {
  return '${_vndFormatter.format(amount.toInt())} đ';
}

String formatDate(DateTime date) => _dateFormatter.format(date);

String formatMonth(DateTime date) => _monthFormatter.format(date);

String formatDateFromString(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  return formatDate(DateTime.parse(iso));
}

DateTime parseDate(String iso) => DateTime.parse(iso);

String toIso(DateTime date) => date.toIso8601String().substring(0, 10);

int daysUntil(String isoDate) {
  final due = DateTime.parse(isoDate);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  return dueDay.difference(today).inDays;
}

String percentChange(double current, double previous) {
  if (previous == 0) return '';
  final pct = ((current - previous) / previous * 100).toStringAsFixed(1);
  return current >= previous ? '+$pct%' : '$pct%';
}

/// Parse chuỗi có dấu chấm nghìn về double. VD: "1.500.000" → 1500000.0
double parseAmount(String text) {
  return double.tryParse(text.replaceAll('.', '')) ?? 0;
}

/// Formatter tự động thêm dấu . phân cách hàng nghìn khi nhập.
/// VD: gõ "1500000" → hiển thị "1.500.000"
class ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    final formatted = _addDots(digits);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _addDots(String digits) {
    final buf = StringBuffer();
    final len = digits.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}
