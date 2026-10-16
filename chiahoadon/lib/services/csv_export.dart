import '../core/utils/date_formatter.dart';
import '../domain/models/bill.dart';
import '../domain/models/enums.dart';
import '../domain/models/expense_category.dart';
import '../domain/models/member.dart';

/// Xuất dữ liệu ra CSV để mở bằng Excel hoặc Google Sheets (SPEC FR-8.3).
///
/// Khác với sao lưu JSON: tệp này **không** dùng để phục hồi, nó để người dùng
/// tự cộng trừ theo cách của họ. Vì vậy mỗi dòng là *một người trong một hóa
/// đơn* chứ không phải một hóa đơn — dạng dài này mới xoay được pivot table,
/// còn dạng mỗi hóa đơn một dòng thì số người thay đổi nên không có bộ cột cố
/// định nào đúng.
class CsvExport {
  const CsvExport._();

  /// Dấu phân cách cột.
  ///
  /// Dùng chấm phẩy chứ không dùng dấu phẩy: Excel trên máy đặt ngôn ngữ Việt
  /// lấy dấu phẩy làm dấu thập phân, nên tệp phân cách bằng dấu phẩy mở ra bị
  /// dồn hết vào một cột. Google Sheets tự nhận ra cả hai.
  static const String separator = ';';

  /// Ký tự đánh dấu UTF-8 ở đầu tệp.
  ///
  /// Không có nó thì Excel đọc tệp theo bảng mã hệ thống và mọi chữ có dấu
  /// thành ký tự lạ — đây là lý do phổ biến nhất khiến CSV tiếng Việt "hỏng".
  static const String utf8Bom = '﻿';

  static const List<String> _columns = [
    'Ngày',
    'Hóa đơn',
    'Danh mục',
    'Tổng hóa đơn',
    'Người ứng tiền',
    'Thành viên',
    'Phải trả',
    'Đã trả',
    'Còn lại',
    'Trạng thái',
  ];

  /// Dựng nội dung tệp CSV từ danh sách hóa đơn.
  ///
  /// [members] và [categories] dùng để đổi id thành tên; thiếu thì lấy tên đã
  /// chụp lại trong hóa đơn, nhờ vậy hóa đơn của người đã xóa vẫn xuất được.
  static String build(
    List<Bill> bills, {
    Map<String, Member> members = const {},
    Map<String, ExpenseCategory> categories = const {},
  }) {
    final rows = <String>[_row(_columns)];

    for (final bill in bills) {
      // Nháp chưa có số tiền chốt, đưa vào bảng tính chỉ làm sai tổng.
      if (bill.status == BillStatus.draft) continue;

      final date = DateFormatter.short(
        DateTime.fromMillisecondsSinceEpoch(bill.billDate),
      );
      final payer = bill.payers.isEmpty
          ? ''
          : members[bill.payers.first.memberId]?.displayName ?? '';
      final category = categories[bill.categoryId]?.name ?? '';

      for (final participant in bill.participants) {
        rows.add(
          _row([
            date,
            bill.title,
            category,
            '${bill.totalAmount}',
            payer,
            members[participant.memberId]?.displayName ??
                participant.memberNameSnapshot,
            '${participant.shareAmount}',
            '${participant.paidAmount}',
            '${participant.shareAmount - participant.paidAmount}',
            bill.status.label,
          ]),
        );
      }
    }

    // Kết thúc bằng xuống dòng: một số công cụ bỏ qua dòng cuối nếu thiếu.
    return '$utf8Bom${rows.join('\r\n')}\r\n';
  }

  static String _row(List<String> cells) =>
      cells.map(_escape).join(separator);

  /// Bọc ô trong dấu nháy kép khi cần, theo RFC 4180.
  ///
  /// Tên hóa đơn do người dùng gõ nên có thể chứa chính dấu phân cách, dấu
  /// nháy, hoặc xuống dòng — không bọc thì một ô vỡ thành nhiều cột và cả bảng
  /// lệch từ đó trở đi.
  static String _escape(String value) {
    final needsQuotes =
        value.contains(separator) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');

    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// Tên tệp gợi ý, kèm ngày để nhiều lần xuất không đè lên nhau.
  static String fileName([DateTime? now]) {
    final at = now ?? DateTime.now();
    final stamp =
        '${at.year}${_two(at.month)}${_two(at.day)}-'
        '${_two(at.hour)}${_two(at.minute)}';
    return 'chia-hoa-don-$stamp.csv';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
