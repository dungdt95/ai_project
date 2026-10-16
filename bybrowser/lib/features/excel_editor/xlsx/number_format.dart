import 'xlsx_model.dart';

/// Định dạng giá trị ô để hiển thị, bắt chước Excel ở mức cơ bản:
/// General, số thập phân/phần nghìn, phần trăm, ngày/giờ. Các định dạng
/// phức tạp hơn (điều kiện, màu, tiền tệ tùy chỉnh…) rơi về General.
class XlsxNumberFormat {
  XlsxNumberFormat._();

  static const _builtin = <int, String>{
    0: 'General',
    1: '0',
    2: '0.00',
    3: '#,##0',
    4: '#,##0.00',
    9: '0%',
    10: '0.00%',
    11: '0.00E+00',
    12: '# ?/?',
    13: '# ??/??',
    14: 'm/d/yyyy',
    15: 'd-mmm-yy',
    16: 'd-mmm',
    17: 'mmm-yy',
    18: 'h:mm AM/PM',
    19: 'h:mm:ss AM/PM',
    20: 'h:mm',
    21: 'h:mm:ss',
    22: 'm/d/yyyy h:mm',
    37: '#,##0 ;(#,##0)',
    38: '#,##0 ;[Red](#,##0)',
    39: '#,##0.00;(#,##0.00)',
    40: '#,##0.00;[Red](#,##0.00)',
    45: 'mm:ss',
    46: '[h]:mm:ss',
    47: 'mmss.0',
    48: '##0.0E+0',
    49: '@',
  };

  static String formatCode(XlsxStyles styles, int? xf) {
    final id = styles.numFmtId(xf);
    return styles.customFormats[id] ?? _builtin[id] ?? 'General';
  }

  /// Chuỗi hiển thị cho ô. Ô công thức chưa có giá trị cache → hiện công thức.
  static String display(XlsxCell cell, XlsxStyles styles) {
    switch (cell.type) {
      case CellType.empty:
        return cell.formula != null ? '=${cell.formula}' : '';
      case CellType.text:
        return cell.raw ?? '';
      case CellType.bool:
        return (cell.raw == '1' || cell.raw == 'true') ? 'TRUE' : 'FALSE';
      case CellType.error:
        return cell.raw ?? '#ERR';
      case CellType.number:
        final v = double.tryParse(cell.raw ?? '');
        if (v == null) return cell.raw ?? '';
        return formatNumber(v, formatCode(styles, cell.styleIndex));
    }
  }

  static String formatNumber(double v, String code) {
    // Chỉ dùng section đầu (số dương); bỏ màu và điều kiện.
    var section = code.split(';').first;
    section = section.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    if (section == 'General' || section.isEmpty || section == '@') {
      return general(v);
    }
    if (isDateFormat(section)) return formatDate(v, section);

    final percent = section.contains('%');
    final grouping = section.contains(',');
    final dot = section.indexOf('.');
    var decimals = 0;
    if (dot >= 0) {
      final m = RegExp(r'[0#?]+').matchAsPrefix(section, dot + 1);
      decimals = m?.group(0)!.length ?? 0;
    }
    if (section.contains('E+') || section.contains('E-')) {
      return v.toStringAsExponential(decimals);
    }
    var x = percent ? v * 100 : v;
    var s = x.toStringAsFixed(decimals);
    if (grouping) s = _group(s);
    return percent ? '$s%' : s;
  }

  /// Excel "General": tối đa ~10 chữ số có nghĩa, bỏ số 0 thừa.
  static String general(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    if (v.abs() >= 1e11 || (v.abs() < 1e-4 && v != 0)) {
      return v.toStringAsExponential(5).replaceFirst(RegExp(r'\.?0+e'), 'e');
    }
    var s = v.toStringAsPrecision(10);
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s;
  }

  static String _group(String s) {
    final neg = s.startsWith('-');
    if (neg) s = s.substring(1);
    final dot = s.indexOf('.');
    final intPart = dot < 0 ? s : s.substring(0, dot);
    final frac = dot < 0 ? '' : s.substring(dot);
    final sb = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) sb.write(',');
      sb.write(intPart[i]);
    }
    return '${neg ? '-' : ''}$sb$frac';
  }

  /// Mã định dạng là ngày/giờ nếu có d/m/y/h/s ngoài dấu nháy và không có 0/#.
  static bool isDateFormat(String section) {
    final stripped = section
        .replaceAll(RegExp(r'"[^"]*"'), '')
        .replaceAll(RegExp(r'\\.'), '')
        .replaceAll('AM/PM', '')
        .replaceAll('A/P', '');
    if (RegExp(r'[0#?]').hasMatch(stripped)) return false;
    return RegExp(r'[dmyhs]', caseSensitive: false).hasMatch(stripped);
  }

  /// Serial Excel (hệ 1900) → DateTime.
  static DateTime serialToDate(double serial) {
    final epoch = DateTime.utc(1899, 12, 30);
    final ms = (serial * 86400000).round();
    return epoch.add(Duration(milliseconds: ms));
  }

  static String formatDate(double v, String section) {
    final d = serialToDate(v);
    final lower = section.toLowerCase();
    final hasTime = RegExp(r'h|s').hasMatch(lower.replaceAll(RegExp(r'"[^"]*"'), ''));
    final hasDate = RegExp(r'y|d').hasMatch(lower) || lower.contains('mmm');
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${two(d.day)}/${two(d.month)}/${d.year}';
    final time = '${two(d.hour)}:${two(d.minute)}${lower.contains('s') ? ':${two(d.second)}' : ''}';
    if (hasDate && hasTime) return '$date $time';
    if (hasTime) return time;
    return date;
  }
}
