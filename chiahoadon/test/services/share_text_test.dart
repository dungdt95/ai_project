import 'package:chiahoadon/core/utils/avatar_color.dart';
import 'package:chiahoadon/core/utils/vn_text.dart';
import 'package:chiahoadon/domain/models/bill.dart';
import 'package:chiahoadon/domain/models/bill_participant.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/domain/models/surcharge.dart';
import 'package:chiahoadon/services/share_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test đoạn text chia sẻ (SPEC FR-8.1).
///
/// Đây là thứ duy nhất của app đi ra ngoài tới người khác, nên nội dung phải
/// đúng và đọc được mà không cần mở app.
void main() {
  Member member(
    String name, {
    String? bankName,
    String? bankAccount,
    String? bankHolder,
  }) => Member(
    id: name,
    name: name,
    nameNorm: VnText.normalize(name),
    avatarColor: AvatarColor.toStored(name),
    bankName: bankName,
    bankAccount: bankAccount,
    bankHolder: bankHolder,
    createdAt: 0,
    updatedAt: 0,
  );

  final dung = member(
    'Dũng',
    bankName: 'Vietcombank',
    bankAccount: '0123456789',
    bankHolder: 'DAO TRONG DUNG',
  );
  final an = member('An');
  final binh = member('Bình');
  final chi = member('Chi');

  final members = {
    for (final m in [dung, an, binh, chi]) m.id: m,
  };

  BillParticipant participant(String id, int share, {int paid = 0}) =>
      BillParticipant(
        id: 'bp-$id',
        memberId: id,
        memberNameSnapshot: id,
        shareAmount: share,
        paidAmount: paid,
      );

  Bill bill({
    String title = 'Ăn lẩu tất niên',
    int total = 848000,
    List<BillParticipant>? participants,
    List<BillPayer>? payers,
    Surcharge tax = const Surcharge.none(),
    Surcharge service = const Surcharge.none(),
    Surcharge discount = const Surcharge.none(),
    int taxAmount = 0,
    int serviceAmount = 0,
    int discountAmount = 0,
    int tip = 0,
    String? note,
  }) => Bill(
    id: 'bill-1',
    title: title,
    note: note,
    billDate: DateTime(2026, 10, 2).millisecondsSinceEpoch,
    splitType: SplitType.itemized,
    inputMode: InputMode.items,
    subtotal: 750000,
    tax: tax,
    taxAmount: taxAmount,
    service: service,
    serviceAmount: serviceAmount,
    discount: discount,
    discountAmount: discountAmount,
    tipAmount: tip,
    totalAmount: total,
    status: BillStatus.unpaid,
    createdAt: 0,
    updatedAt: 0,
    payers: payers ?? [BillPayer(memberId: dung.id, paidAmount: total)],
    participants:
        participants ??
        [
          participant('An', 302000),
          participant('Bình', 301000),
          participant('Chi', 245000),
        ],
  );

  group('Nội dung đoạn chia sẻ', () {
    test('có tên hóa đơn, ngày, tổng tiền và người trả trước', () {
      final text = ShareText.forBill(bill(), members: members);

      expect(text, contains('🧾 Ăn lẩu tất niên — 02/10/2026'));
      expect(text, contains('Tổng: 848.000 đ'));
      expect(text, contains('Trả trước: Dũng'));
    });

    test('liệt kê phần của từng người', () {
      final text = ShareText.forBill(bill(), members: members);

      expect(text, contains('An'));
      expect(text, contains('302.000 đ'));
      expect(text, contains('301.000 đ'));
      expect(text, contains('245.000 đ'));
    });

    test('căn cột tiền bằng cách đệm tên cho bằng nhau', () {
      final text = ShareText.forBill(bill(), members: members);
      final lines = text
          .split('\n')
          .where((line) => line.startsWith('• '))
          .toList();

      expect(lines, hasLength(3));
      // Tên dài nhất là "Bình" (4 ký tự), nên mọi dòng tiền bắt đầu cùng cột.
      final moneyColumns = lines
          .map((line) => line.indexOf(RegExp(r'\d')))
          .toSet();
      expect(
        moneyColumns,
        hasLength(1),
        reason: 'Số tiền phải thẳng cột: $lines',
      );
    });

    test('đánh dấu người đã trả', () {
      final text = ShareText.forBill(
        bill(
          participants: [
            participant('An', 302000, paid: 302000),
            participant('Bình', 301000),
          ],
        ),
        members: members,
      );

      final anLine = text
          .split('\n')
          .firstWhere((line) => line.contains('An'));
      final binhLine = text
          .split('\n')
          .firstWhere((line) => line.contains('Bình'));

      expect(anLine, contains('✅'));
      expect(binhLine, isNot(contains('✅')));
    });

    test('nêu rõ phụ phí để người nhận hiểu vì sao tổng lớn hơn tiền món', () {
      final text = ShareText.forBill(
        bill(
          tax: const Surcharge.percent(800),
          taxAmount: 60000,
          service: const Surcharge.percent(500),
          serviceAmount: 37500,
        ),
        members: members,
      );

      expect(text, contains('VAT 8%'));
      expect(text, contains('phí DV 5%'));
    });

    test('phụ phí dạng số tiền thì ghi số tiền, không ghi phần trăm', () {
      final text = ShareText.forBill(
        bill(tax: const Surcharge.amount(60000), taxAmount: 60000),
        members: members,
      );

      expect(text, contains('VAT 60.000 đ'));
      expect(text, isNot(contains('%')));
    });

    test('có giảm giá và tip thì cũng nêu', () {
      final text = ShareText.forBill(
        bill(
          discount: const Surcharge.amount(50000),
          discountAmount: 50000,
          tip: 20000,
        ),
        members: members,
      );

      expect(text, contains('giảm 50.000 đ'));
      expect(text, contains('tip 20.000 đ'));
    });

    test('không có phụ phí thì không thêm ngoặc trống', () {
      final text = ShareText.forBill(bill(), members: members);

      expect(text, contains('Tổng: 848.000 đ\n'));
      expect(text, isNot(contains('()')));
    });

    test('kèm số tài khoản của người trả trước', () {
      final text = ShareText.forBill(bill(), members: members);

      expect(text, contains('💸 Chuyển khoản'));
      expect(text, contains('DAO TRONG DUNG'));
      expect(text, contains('Vietcombank'));
      expect(text, contains('0123456789'));
    });

    test('người trả trước chưa nhập số tài khoản thì bỏ dòng đó', () {
      final text = ShareText.forBill(
        bill(payers: [BillPayer(memberId: an.id, paidAmount: 848000)]),
        members: members,
      );

      expect(text, isNot(contains('Chuyển khoản')));
      expect(text, contains('Trả trước: An'));
    });

    test('kèm ghi chú nếu có', () {
      final text = ShareText.forBill(
        bill(note: 'Chi trả tiền taxi về'),
        members: members,
      );

      expect(text, contains('📝 Chi trả tiền taxi về'));
    });

    test('ghi chú rỗng thì không thêm dòng trống', () {
      final text = ShareText.forBill(bill(note: '   '), members: members);

      expect(text, isNot(contains('📝')));
    });

    test('không có người trả trước thì bỏ dòng đó', () {
      final text = ShareText.forBill(
        bill(payers: const []),
        members: members,
      );

      expect(text, isNot(contains('Trả trước')));
      expect(text, isNot(contains('Chuyển khoản')));
    });

    test('dùng tên đã chụp lại khi thành viên không còn trong danh sách', () {
      // Thành viên bị xóa khỏi app, nhưng hóa đơn cũ vẫn phải đọc được.
      final text = ShareText.forBill(bill(), members: const {});

      expect(text, contains('An'));
      expect(text, contains('Bình'));
      expect(text, contains('302.000 đ'));
    });

    test('không có dòng trống thừa ở cuối', () {
      final text = ShareText.forBill(bill(), members: members);

      expect(text, isNot(endsWith('\n')));
    });
  });

  group('Báo cáo theo danh mục, gửi lên Mattermost (FR-8.7)', () {
    String report({int hiddenCount = 0}) => ShareText.forCategoryReport(
      categoryName: 'Ăn uống',
      periodDetail: 'Tháng 10/2026',
      rows: const [
        (name: 'An', amount: 300000, billCount: 2),
        (name: 'Bình', amount: 100000, billCount: 1),
      ],
      hiddenCount: hiddenCount,
    );

    test('dựng bảng markdown để Mattermost render đúng cột', () {
      final text = report();

      expect(text, contains('| Thành viên | Số tiền | Tỷ trọng | Hóa đơn |'));
      expect(
        text,
        contains('|---|---:|---:|---:|'),
        reason: 'cột tiền phải canh phải, nếu không bảng đọc rất khó',
      );
      expect(text, contains('| An | 300.000 đ | 75% | 2 |'));
      expect(text, contains('| Bình | 100.000 đ | 25% | 1 |'));
    });

    test('có dòng tổng và nói rõ kỳ nào', () {
      final text = report();

      expect(text, contains('Ăn uống — Tháng 10/2026'));
      expect(
        text,
        contains('| **Tổng** | **400.000 đ** | | |'),
        reason: 'người nhận không mở app nên phải thấy tổng ngay trong tin',
      );
    });

    test('★ nói rõ khi báo cáo đang ẩn bớt người', () {
      // Gửi đi một báo cáo đang lọc mà không nói gì thì người đọc tưởng đó là
      // toàn bộ nhóm — đây là chỗ dễ gây hiểu nhầm về tiền bạc nhất.
      expect(report(), isNot(contains('Đang ẩn')));
      expect(report(hiddenCount: 2), contains('_Đang ẩn 2 người'));
    });

    test('không người nào thì vẫn ra bảng rỗng chứ không lỗi', () {
      final text = ShareText.forCategoryReport(
        categoryName: 'Tất cả danh mục',
        periodDetail: 'Tuần này · 28/09 – 04/10/2026',
        rows: const [],
      );

      expect(text, contains('Tuần này · 28/09 – 04/10/2026'));
      expect(text, contains('**0 đ**'));
    });

    test('không có dòng trống thừa ở cuối', () {
      expect(report(), isNot(endsWith('\n')));
      expect(report(hiddenCount: 1), isNot(endsWith('\n')));
    });
  });
}
