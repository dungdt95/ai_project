import '../core/utils/date_formatter.dart';
import '../core/utils/money_formatter.dart';
import '../domain/models/bill.dart';
import '../domain/models/member.dart';
import '../domain/models/surcharge.dart';

/// Dựng đoạn text chia sẻ kết quả chia tiền (SPEC FR-8.1).
///
/// Hàm **thuần**, không phụ thuộc Flutter, nên test được trực tiếp. Tách khỏi
/// `share_service.dart` vì phần khó là nội dung, còn việc mở bảng chia sẻ của
/// hệ điều hành thì không có gì để kiểm.
///
/// Định dạng nhắm tới Zalo và Messenger: emoji dẫn dòng, tiền căn theo cột bằng
/// khoảng trắng, không dùng bảng hay markdown vì các ứng dụng đó không hiểu.
class ShareText {
  const ShareText._();

  static String forBill(
    Bill bill, {
    required Map<String, Member> members,
  }) {
    final buffer = StringBuffer()
      ..writeln('🧾 ${bill.title} — ${DateFormatter.short(bill.date)}');

    final surcharges = _surchargeNote(bill);
    buffer.writeln(
      'Tổng: ${MoneyFormatter.format(bill.totalAmount)}'
      '${surcharges.isEmpty ? '' : ' ($surcharges)'}',
    );

    if (bill.payers.isNotEmpty) {
      final payer = members[bill.payers.first.memberId];
      buffer.writeln('Trả trước: ${payer?.displayName ?? '?'}');
    }

    buffer.writeln();

    // Căn cột tiền cho dễ đọc: tên đệm khoảng trắng tới cùng một độ rộng.
    final rows = [
      for (final participant in bill.participants)
        (
          name:
              members[participant.memberId]?.displayName ??
              participant.memberNameSnapshot,
          amount: participant.shareAmount,
          paid: participant.paidAmount >= participant.shareAmount,
        ),
    ];
    final nameWidth = rows.fold<int>(
      0,
      (width, row) => row.name.length > width ? row.name.length : width,
    );

    for (final row in rows) {
      final padded = row.name.padRight(nameWidth);
      final mark = row.paid ? ' ✅' : '';
      buffer.writeln(
        '• $padded  ${MoneyFormatter.format(row.amount)}$mark',
      );
    }

    final bank = _bankLine(bill, members);
    if (bank != null) {
      buffer
        ..writeln()
        ..writeln(bank);
    }

    if (bill.note != null && bill.note!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('📝 ${bill.note!.trim()}');
    }

    return buffer.toString().trimRight();
  }

  /// Báo cáo chi phí từng người theo danh mục, dạng Mattermost (SPEC FR-8.7).
  ///
  /// Khác hẳn [forBill] ở một điểm: chỗ này **dùng markdown**. `forBill` nhắm
  /// tới Zalo và Messenger vốn không hiểu bảng, còn Mattermost render bảng
  /// markdown nên cột tiền thẳng hàng thật chứ không phải đệm bằng khoảng
  /// trắng — và vẫn đọc được nếu người nhận xem bằng ứng dụng khác.
  ///
  /// [periodDetail] là khoảng ngày viết rõ ("01/10 – 31/10/2026"), lấy từ
  /// `DateRange.detail`: người nhận không mở app nên không thấy app đang lọc kỳ
  /// nào (SPEC FR-7.12).
  ///
  /// [hiddenCount] lớn hơn 0 thì phải ghi ra. Gửi đi một báo cáo đang bật bộ
  /// lọc mà không nói gì thì người đọc tưởng đó là toàn bộ nhóm (SPEC FR-7.14).
  static String forCategoryReport({
    required String categoryName,
    required String periodDetail,
    required List<({String name, int amount, int billCount})> rows,
    int hiddenCount = 0,
  }) {
    final total = rows.fold(0, (sum, row) => sum + row.amount);

    final buffer = StringBuffer()
      ..writeln('#### 💸 $categoryName — $periodDetail')
      ..writeln()
      ..writeln('| Thành viên | Số tiền | Tỷ trọng | Hóa đơn |')
      ..writeln('|---|---:|---:|---:|');

    for (final row in rows) {
      final percent = total == 0 ? 0 : (row.amount * 100 / total).round();
      buffer.writeln(
        '| ${row.name} | ${MoneyFormatter.format(row.amount)} '
        '| $percent% | ${row.billCount} |',
      );
    }

    buffer.writeln(
      '| **Tổng** | **${MoneyFormatter.format(total)}** | | |',
    );

    if (hiddenCount > 0) {
      buffer
        ..writeln()
        ..writeln('_Đang ẩn $hiddenCount người khỏi báo cáo này._');
    }

    return buffer.toString().trimRight();
  }

  /// Mô tả ngắn các khoản phụ phí, để người nhận hiểu vì sao tổng lớn hơn
  /// tiền món.
  static String _surchargeNote(Bill bill) {
    final parts = <String>[
      if (bill.discountAmount != 0)
        'giảm ${MoneyFormatter.format(bill.discountAmount)}',
      if (bill.taxAmount != 0) _describe('VAT', bill.tax, bill.taxAmount),
      if (bill.serviceAmount != 0)
        _describe('phí DV', bill.service, bill.serviceAmount),
      if (bill.tipAmount != 0)
        'tip ${MoneyFormatter.format(bill.tipAmount)}',
    ];
    return parts.join(' + ');
  }

  static String _describe(String label, Surcharge surcharge, int amount) =>
      surcharge.isPercent
      ? '$label ${MoneyFormatter.formatPercentBp(surcharge.value)}'
      : '$label ${MoneyFormatter.format(amount)}';

  /// Dòng số tài khoản của người trả trước, để người khác chuyển khoản lại.
  static String? _bankLine(Bill bill, Map<String, Member> members) {
    if (bill.payers.isEmpty) return null;

    final payer = members[bill.payers.first.memberId];
    if (payer == null || !payer.hasBankInfo) return null;

    final parts = [
      payer.bankHolder ?? payer.name,
      if (payer.bankName != null) payer.bankName!,
      payer.bankAccount!,
    ];
    return '💸 Chuyển khoản: ${parts.join(' · ')}';
  }
}

extension on Bill {
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(billDate);
}
