import 'package:chiahoadon/core/utils/avatar_color.dart';
import 'package:chiahoadon/core/utils/vn_text.dart';
import 'package:chiahoadon/domain/models/bill_item.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/domain/models/surcharge.dart';
import 'package:chiahoadon/domain/split/split_engine.dart';
import 'package:chiahoadon/features/bills/form/bill_form_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test lõi của form nhập hóa đơn.
///
/// `BillFormState` là lớp bất biến với các phương thức thuần, nên kiểm tra
/// được toàn bộ quy tắc của form mà không cần dựng widget nào.
void main() {
  Member member(String id, {bool isSelf = false}) => Member(
    id: id,
    name: id,
    nameNorm: VnText.normalize(id),
    avatarColor: AvatarColor.toStored(id),
    isSelf: isSelf,
    createdAt: 0,
    updatedAt: 0,
  );

  final self = member('Tôi', isSelf: true);
  final names = {
    'Tôi': 'Tôi',
    'An': 'An',
    'Bình': 'Bình',
    'Chi': 'Chi',
  };

  /// Form mới ở kiểu chia **đều**, vì phần lớn test dưới đây kiểm tiền theo
  /// tổng. Mặc định thật của app là chia theo món — xem test riêng bên dưới.
  BillFormState newForm() => BillFormState.create(
    date: DateTime(2026, 10, 2),
    self: self,
  ).withSplitType(SplitType.equal);

  BillFormState freshForm() =>
      BillFormState.create(date: DateTime(2026, 10, 2), self: self);

  group('Tạo hóa đơn mới', () {
    test('chọn sẵn "Tôi" làm người trả trước và người tham gia', () {
      final form = freshForm();

      expect(form.payerId, self.id);
      expect(form.participantIds, [self.id]);
      // Mở thẳng ở chia theo món, và chế độ nhập phải đi cùng — lệch nhau là
      // validator báo `itemizedNeedsItems` ngay khi chưa ai làm gì.
      expect(form.splitType, SplitType.itemized);
      expect(form.inputMode, InputMode.items);
      expect(form.isEditing, isFalse);
    });

    test('ngày được cắt về 00:00 để khớp cách lưu trong DB', () {
      final form = BillFormState.create(
        date: DateTime(2026, 10, 2, 19, 30, 45),
        self: self,
      );

      expect(form.date, DateTime(2026, 10, 2));
    });
  });

  group('Điều kiện lưu', () {
    test('thiếu tên thì chặn và nói rõ lý do', () {
      final form = newForm().withTotal(100000);

      expect(form.canSave, isFalse);
      expect(form.blockingReason, 'Hóa đơn cần có tên');
    });

    test('không có người tham gia thì chặn', () {
      final form = newForm()
          .withTitle('Ăn trưa')
          .withParticipants({})
          .withTotal(100000);

      expect(form.blockingReason, contains('người tham gia'));
    });

    test('tổng tiền bằng 0 thì chặn', () {
      final form = newForm().withTitle('Ăn trưa');

      expect(form.blockingReason, 'Nhập tổng tiền lớn hơn 0');
    });

    test('đủ tên, người và tiền thì lưu được', () {
      final form = newForm().withTitle('Ăn trưa').withTotal(100000);

      expect(form.canSave, isTrue);
      expect(form.blockingReason, isNull);
    });

    test('chế độ theo món thì nhắc thêm món, không nhắc nhập tổng', () {
      final form = newForm()
          .withTitle('Ăn lẩu')
          .withSplitType(SplitType.itemized);

      expect(form.blockingReason, contains('món'));
    });
  });

  group('Chọn người tham gia', () {
    test('giữ nguyên thứ tự người cũ, người mới nối vào cuối', () {
      final form = newForm()
          .withParticipants({'An', 'Bình', 'Chi'})
          .withParticipants({'Bình', 'Chi', 'Dũng'});

      // "An" bị bỏ ra; "Bình" và "Chi" giữ nguyên thứ tự cũ; "Dũng" vào cuối.
      expect(form.participantIds, ['Bình', 'Chi', 'Dũng']);
    });

    test('thứ tự ổn định giữ cho người nhận phần dư không đổi', () {
      final before = newForm()
          .withTitle('Ăn')
          .withParticipants({'An', 'Bình', 'Chi'})
          .withTotal(1000000)
          .copyWith(roundingUnit: 1000);

      // Thêm rồi bỏ một người: danh sách phải quay về đúng thứ tự ban đầu.
      final after = before.toggleParticipant('Dũng').toggleParticipant('Dũng');

      expect(after.participantIds, before.participantIds);
      expect(
        computeSplit(after.toSplitInput()).shares,
        computeSplit(before.toSplitInput()).shares,
      );
    });

    test('bật tắt một người', () {
      final form = newForm().withParticipants({'An', 'Bình'});

      expect(form.toggleParticipant('Bình').participantIds, ['An']);
      expect(form.toggleParticipant('Chi').participantIds, [
        'An',
        'Bình',
        'Chi',
      ]);
    });

    test('bỏ người trả trước khỏi danh sách tham gia vẫn giữ họ làm payer', () {
      // Trường hợp "bố trả hộ nhóm con" (SPEC FR-3, quy tắc nghiệp vụ).
      final form = newForm()
          .withPayer('Tôi')
          .withParticipants({'An', 'Bình'});

      expect(form.payerId, 'Tôi');
      expect(form.participantIds, isNot(contains('Tôi')));
    });

    test('chọn cả nhóm thay danh sách và ghi nhớ nhóm', () {
      final form = newForm().withGroup(
        'group-1',
        memberIds: {'An', 'Bình', 'Chi'},
      );

      expect(form.groupId, 'group-1');
      expect(form.participantIds.toSet(), {'An', 'Bình', 'Chi'});
    });
  });

  group('Đổi kiểu chia', () {
    test('chọn chia theo món thì tự chuyển sang nhập theo danh sách món', () {
      // Nếu không tự chuyển, split engine sẽ báo lỗi `itemizedNeedsItems`.
      final form = newForm().withSplitType(SplitType.itemized);

      expect(form.inputMode, InputMode.items);
    });

    test('quay lại chia đều thì về nhập tổng tiền', () {
      final form = newForm()
          .withSplitType(SplitType.itemized)
          .withSplitType(SplitType.equal);

      expect(form.inputMode, InputMode.total);
    });

    test('tổng tiền lấy từ danh sách món khi ở chế độ theo món', () {
      final form = newForm()
          .withSplitType(SplitType.itemized)
          .withParticipants({'An', 'Bình'})
          .copyWith(
            items: const [
              BillItem(
                id: 'a',
                name: 'Phở',
                unitPrice: 60000,
                participants: [
                  ItemParticipant(memberId: 'An'),
                  ItemParticipant(memberId: 'Bình'),
                ],
              ),
              BillItem(
                id: 'b',
                name: 'Cà phê',
                unitPrice: 25000,
                participants: [ItemParticipant(memberId: 'An')],
              ),
            ],
          );

      // 60.000 × 2 người + 25.000 × 1 người
      expect(form.subtotal, 145000);
    });
  });

  group('Nối với split engine', () {
    test('chia đều 1.000.000 cho 3 người, làm tròn 1.000đ', () {
      final form = newForm()
          .withTitle('Ăn lẩu')
          .withParticipants({'An', 'Bình', 'Chi'})
          .withTotal(1000000)
          .copyWith(roundingUnit: 1000);

      final result = computeSplit(form.toSplitInput());

      expect(result.shares, {'An': 334000, 'Bình': 333000, 'Chi': 333000});
      expect(result.sharesTotal, result.total);
    });

    test('phụ phí được chuyển đúng sang đầu vào của engine', () {
      final form = newForm()
          .withTitle('Ăn lẩu')
          .withParticipants({'An', 'Bình', 'Chi'})
          .withTotal(750000)
          .withTax(const Surcharge.percent(800))
          .withService(const Surcharge.percent(500))
          .copyWith(roundingUnit: 1000);

      final result = computeSplit(form.toSplitInput());

      expect(result.taxAmount, 60000);
      expect(result.serviceAmount, 37500);
      expect(result.total, 848000);
      expect(result.sharesTotal, 848000);
    });
  });

  group('Dựng bản ghi để lưu', () {
    test('mang đủ số tiền đã tính và chụp lại tên từng người', () {
      final form = newForm()
          .withTitle('  Ăn lẩu tất niên  ')
          .withParticipants({'An', 'Bình', 'Chi'})
          .withTotal(1000000)
          .copyWith(roundingUnit: 1000);

      final result = computeSplit(form.toSplitInput());
      final bill = form.toBill(result, names);

      expect(bill.title, 'Ăn lẩu tất niên', reason: 'tên được cắt khoảng trắng');
      expect(bill.totalAmount, 1000000);
      expect(bill.participants, hasLength(3));
      expect(bill.participants.first.memberNameSnapshot, 'An');
      expect(bill.participants.first.shareAmount, 334000);

      // Bất biến cốt lõi phải đúng ngay từ lúc dựng bản ghi.
      expect(bill.totalShares, bill.totalAmount);
    });

    test('người trả trước ứng đúng tổng hóa đơn', () {
      final form = newForm()
          .withTitle('Ăn lẩu')
          .withPayer('Tôi')
          .withParticipants({'An', 'Bình'})
          .withTotal(500000)
          .copyWith(roundingUnit: 1000);

      final bill = form.toBill(computeSplit(form.toSplitInput()), names);

      expect(bill.payers, hasLength(1));
      expect(bill.payers.first.memberId, 'Tôi');
      expect(bill.payers.first.paidAmount, 500000);
      expect(bill.totalPaidByPayers, bill.totalAmount);
    });

    test('ghi chú rỗng được lưu thành null, không phải chuỗi rỗng', () {
      final form = newForm()
          .withTitle('Ăn lẩu')
          .withTotal(100000)
          .withNote('   ');

      final bill = form.toBill(computeSplit(form.toSplitInput()), names);

      expect(bill.note, isNull);
    });

    test('nháp không cần đủ dữ liệu và luôn mang trạng thái draft', () {
      final form = newForm().withParticipants({'An'});
      final draft = form.toDraft(names);

      expect(draft.status, BillStatus.draft);
      expect(draft.title, 'Hóa đơn chưa đặt tên');
      expect(draft.participants, hasLength(1));
      // Nháp chưa chạy split engine nên chưa có số tiền.
      expect(draft.totalAmount, 0);
    });
  });

  group('Sửa hóa đơn đã lưu', () {
    test('nạp lại đủ mọi trường rồi tính ra đúng số cũ', () {
      final original = newForm()
          .withTitle('Ăn lẩu')
          .withParticipants({'An', 'Bình', 'Chi'})
          .withTotal(750000)
          .withTax(const Surcharge.percent(800))
          .copyWith(roundingUnit: 1000);

      final bill = original.toBill(
        computeSplit(original.toSplitInput()),
        names,
      );

      final reopened = BillFormState.edit(bill);

      expect(reopened.isEditing, isTrue);
      expect(reopened.id, bill.id);
      expect(reopened.title, 'Ăn lẩu');
      expect(reopened.participantIds, ['An', 'Bình', 'Chi']);
      expect(reopened.manualTotal, 750000);
      expect(reopened.tax, const Surcharge.percent(800));
      expect(reopened.roundingUnit, 1000);

      // Tính lại phải ra đúng con số đã lưu (SPEC FR-3.13).
      final recomputed = computeSplit(reopened.toSplitInput());
      expect(recomputed.total, bill.totalAmount);
      expect(
        recomputed.shareOf('An'),
        bill.participantOf('An')!.shareAmount,
      );
    });

    test('giữ nguyên id và thời điểm tạo khi lưu lại', () {
      final original = newForm()
          .withTitle('Ăn lẩu')
          .withParticipants({'An'})
          .withTotal(100000);
      final bill = original.toBill(
        computeSplit(original.toSplitInput()),
        names,
      );

      final edited = BillFormState.edit(bill).withTitle('Ăn lẩu (sửa)');
      final saved = edited.toBill(computeSplit(edited.toSplitInput()), names);

      expect(saved.id, bill.id);
      expect(saved.createdAt, bill.createdAt);
      expect(saved.title, 'Ăn lẩu (sửa)');
      expect(saved.updatedAt, greaterThanOrEqualTo(bill.updatedAt));
    });
  });
}
