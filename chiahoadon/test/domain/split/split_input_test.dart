import 'package:chiahoadon/domain/models/bill.dart';
import 'package:chiahoadon/domain/models/bill_item.dart';
import 'package:chiahoadon/domain/models/bill_participant.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/surcharge.dart';
import 'package:chiahoadon/domain/split/split_engine.dart';
import 'package:chiahoadon/domain/split/split_input.dart';
import 'package:flutter_test/flutter_test.dart';

import 'split_test_helper.dart';

/// Test cầu nối giữa tầng dữ liệu và split engine.
///
/// `SplitInput.fromBill` là đường mà Phase 4 dùng để tính lại phần chia khi
/// người dùng sửa một hóa đơn đã lưu (SPEC FR-3.13), nên nó phải cho ra đúng
/// kết quả như khi dựng đầu vào trực tiếp.
void main() {
  BillParticipant participant(
    String memberId, {
    int sortOrder = 0,
    int weightNum = 1,
    int weightDen = 1,
    int percentBp = 0,
    int exactAmount = 0,
  }) => BillParticipant(
    id: 'bp-$memberId',
    memberId: memberId,
    memberNameSnapshot: memberId,
    sortOrder: sortOrder,
    weightNum: weightNum,
    weightDen: weightDen,
    percentBp: percentBp,
    exactAmount: exactAmount,
  );

  Bill bill({
    required SplitType splitType,
    required List<BillParticipant> participants,
    InputMode inputMode = InputMode.total,
    int subtotal = 0,
    List<BillItem> items = const [],
    Surcharge discount = const Surcharge.none(),
    Surcharge tax = const Surcharge.none(),
    Surcharge service = const Surcharge.none(),
    int tip = 0,
    SurchargeAlloc alloc = SurchargeAlloc.proportional,
    int unit = 1000,
    RoundingMode mode = RoundingMode.up,
  }) => Bill(
    id: 'bill-1',
    title: 'Hóa đơn test',
    billDate: DateTime(2026, 10, 2).millisecondsSinceEpoch,
    splitType: splitType,
    inputMode: inputMode,
    subtotal: subtotal,
    discount: discount,
    tax: tax,
    service: service,
    tipAmount: tip,
    surchargeAlloc: alloc,
    roundingUnit: unit,
    roundingMode: mode,
    createdAt: 0,
    updatedAt: 0,
    participants: participants,
    items: items,
  );

  group('SplitInput.fromBill — cầu nối tính lại hóa đơn đã lưu', () {
    test('hóa đơn chia đều: giữ nguyên tổng và danh sách người', () {
      final input = SplitInput.fromBill(
        bill(
          splitType: SplitType.equal,
          subtotal: 1000000,
          participants: [
            participant('An'),
            participant('Bình', sortOrder: 1),
            participant('Chi', sortOrder: 2),
          ],
        ),
      );

      expect(input.splitType, SplitType.equal);
      expect(input.inputMode, InputMode.total);
      expect(input.subtotal, 1000000);
      expect(input.participantIds, ['An', 'Bình', 'Chi']);
      expect(input.roundingUnit, 1000);

      final result = computeSplit(input);
      expect(result.shares, {'An': 334000, 'Bình': 333000, 'Chi': 333000});
      expectSumMatchesTotal(result, unit: 1000);
    });

    test('★ hóa đơn theo món có VAT và phí dịch vụ: khớp ví dụ SPEC', () {
      final input = SplitInput.fromBill(
        bill(
          splitType: SplitType.itemized,
          inputMode: InputMode.items,
          participants: [
            participant('An'),
            participant('Bình', sortOrder: 1),
            participant('Chi', sortOrder: 2),
          ],
          items: [
            const BillItem(
              id: 'pho',
              name: 'Phở bò',
              unitPrice: 60000,
              participants: [
                ItemParticipant(memberId: 'An'),
                ItemParticipant(memberId: 'Bình'),
              ],
            ),
            const BillItem(
              id: 'buncha',
              name: 'Bún chả',
              unitPrice: 55000,
              sortOrder: 1,
              participants: [ItemParticipant(memberId: 'Chi')],
            ),
            const BillItem(
              id: 'trada',
              name: 'Trà đá',
              unitPrice: 5000,
              sortOrder: 2,
              participants: [
                ItemParticipant(memberId: 'An'),
                ItemParticipant(memberId: 'Bình'),
                ItemParticipant(memberId: 'Chi'),
              ],
            ),
            const BillItem(
              id: 'caphe',
              name: 'Cà phê',
              unitPrice: 25000,
              sortOrder: 3,
              participants: [ItemParticipant(memberId: 'An')],
            ),
          ],
          tax: const Surcharge.percent(800),
          service: const Surcharge.percent(500),
        ),
      );

      // Tổng tiền món được tính lại từ giá × số người, không lấy từ cột
      // subtotal đã lưu — để thêm bớt người là tổng tự cập nhật.
      expect(input.subtotal, 215000);
      expect(input.items, hasLength(4));

      final result = computeSplit(input);
      expect(result.total, 243000);
      expect(result.shares, {'An': 102000, 'Bình': 73000, 'Chi': 68000});
      expectSumMatchesTotal(result, unit: 1000);
    });

    test('giữ nguyên trọng số khi chia theo số phần', () {
      final input = SplitInput.fromBill(
        bill(
          splitType: SplitType.shares,
          subtotal: 6000000,
          participants: [
            participant('An', weightNum: 2),
            participant('Bình', sortOrder: 1),
            participant('Chi', sortOrder: 2, weightNum: 1, weightDen: 2),
          ],
        ),
      );

      expect(input.participants[0].weightNum, 2);
      expect(input.participants[2].weightDen, 2);

      // Tỷ lệ 2 : 1 : 0,5 = 4 : 2 : 1 của 6.000.000
      final result = computeSplit(input);
      expect(result.shareOf('An'), 3429000);
      expectSumMatchesTotal(result, unit: 1000);
    });

    test('giữ nguyên phần trăm khi chia theo %', () {
      final input = SplitInput.fromBill(
        bill(
          splitType: SplitType.percentage,
          subtotal: 1000000,
          participants: [
            participant('An', percentBp: 6000),
            participant('Bình', sortOrder: 1, percentBp: 4000),
          ],
        ),
      );

      expect(input.participants.map((p) => p.percentBp), [6000, 4000]);

      final result = computeSplit(input);
      expect(result.shares, {'An': 600000, 'Bình': 400000});
    });

    test('giữ nguyên số tiền chỉ định', () {
      final input = SplitInput.fromBill(
        bill(
          splitType: SplitType.exact,
          subtotal: 500000,
          unit: 1,
          participants: [
            participant('An', exactAmount: 300000),
            participant('Bình', sortOrder: 1, exactAmount: 200000),
          ],
        ),
      );

      final result = computeSplit(input);
      expect(result.shares, {'An': 300000, 'Bình': 200000});
    });

    test('giữ nguyên trọng số trong từng món', () {
      final input = SplitInput.fromBill(
        bill(
          splitType: SplitType.itemized,
          inputMode: InputMode.items,
          unit: 1,
          participants: [participant('An'), participant('Bình', sortOrder: 1)],
          items: [
            const BillItem(
              id: 'bia',
              name: 'Bia',
              unitPrice: 20000,
              participants: [
                ItemParticipant(memberId: 'An'),
                ItemParticipant(memberId: 'Bình', weightNum: 2),
              ],
            ),
          ],
        ),
      );

      expect(input.items.first.users[1].weightNum, 2);

      // Bình uống 2 lon nên trả gấp đôi: 20.000 × 1 và 20.000 × 2.
      final result = computeSplit(input);
      expect(result.shares, {'An': 20000, 'Bình': 40000});
    });

    test('giữ nguyên toàn bộ cấu hình phụ phí và làm tròn', () {
      final source = bill(
        splitType: SplitType.equal,
        subtotal: 500000,
        participants: [participant('An')],
        discount: const Surcharge.percent(1000),
        tax: const Surcharge.amount(30000),
        service: const Surcharge.percent(500),
        tip: 20000,
        alloc: SurchargeAlloc.equal,
        unit: 5000,
        mode: RoundingMode.nearest,
      );

      final input = SplitInput.fromBill(source);

      expect(input.discount, const Surcharge.percent(1000));
      expect(input.tax, const Surcharge.amount(30000));
      expect(input.service, const Surcharge.percent(500));
      expect(input.tip, 20000);
      expect(input.surchargeAlloc, SurchargeAlloc.equal);
      expect(input.roundingUnit, 5000);
      expect(input.roundingMode, RoundingMode.nearest);
    });
  });

  group('SplitInput.copyWith', () {
    final base = Split.equal(
      total: 300000,
      members: ['An', 'Bình'],
      unit: 1000,
    );

    test('đổi một trường, các trường còn lại giữ nguyên', () {
      final changed = base.copyWith(manualTotal: 600000);

      expect(changed.manualTotal, 600000);
      expect(changed.participantIds, base.participantIds);
      expect(changed.splitType, base.splitType);
      expect(changed.roundingUnit, base.roundingUnit);
    });

    test('đổi kiểu chia và danh sách người', () {
      final changed = base.copyWith(
        splitType: SplitType.shares,
        participants: const [
          SplitParticipant(memberId: 'An', weightNum: 3),
          SplitParticipant(memberId: 'Bình'),
          SplitParticipant(memberId: 'Chi'),
        ],
      );

      expect(changed.splitType, SplitType.shares);
      expect(changed.participantCount, 3);
    });

    test('đổi phụ phí, cách phân bổ và làm tròn', () {
      final changed = base.copyWith(
        inputMode: InputMode.items,
        items: const [SplitItem(id: 'a', unitPrice: 500)],
        discount: const Surcharge.percent(500),
        tax: const Surcharge.percent(800),
        service: const Surcharge.amount(1000),
        tip: 5000,
        surchargeAlloc: SurchargeAlloc.equal,
        roundingUnit: 500,
        roundingMode: RoundingMode.none,
      );

      expect(changed.inputMode, InputMode.items);
      expect(
        changed.subtotal,
        1000,
        reason: 'subtotal lấy từ danh sách món: 500 × 2 người',
      );
      expect(changed.discount.value, 500);
      expect(changed.tax.value, 800);
      expect(changed.service, const Surcharge.amount(1000));
      expect(changed.tip, 5000);
      expect(changed.surchargeAlloc, SurchargeAlloc.equal);
      expect(changed.roundingUnit, 500);
      expect(changed.roundingMode, RoundingMode.none);
    });
  });

  group('Các getter tiện dụng', () {
    test('SplitItem tính thành tiền theo số phần', () {
      const pho = SplitItem(
        id: 'pho',
        unitPrice: 60000,
        users: [
          SplitItemShare(memberId: 'An'),
          SplitItemShare(memberId: 'Bình'),
        ],
      );

      // Hai người ăn là hai lần giá, không phải chia đôi.
      expect(pho.portions(['An', 'Bình']), 2);
      expect(pho.amountFor(['An', 'Bình']), 120000);

      // Người đã bị bỏ khỏi hóa đơn thì không còn tính phần.
      expect(pho.amountFor(['An']), 60000);
    });

    test('món chung tính mỗi người tham gia một phần', () {
      const chung = SplitItem(id: 'chung', unitPrice: 30000);

      expect(chung.amountFor(['An', 'Bình', 'Chi']), 90000);
    });

    test('SplitItem.isShared cho biết món có phải món chung', () {
      expect(const SplitItem(id: 'a', unitPrice: 1000).isShared, isTrue);
      expect(
        const SplitItem(
          id: 'a',
          unitPrice: 1000,
          users: [SplitItemShare(memberId: 'An')],
        ).isShared,
        isFalse,
      );
    });

    test('toString của các kiểu dữ liệu đầu vào đọc được', () {
      expect(
        Split.equal(total: 1000, members: ['An']).toString(),
        contains('equal'),
      );
      expect(
        const SplitParticipant(memberId: 'An').toString(),
        contains('An'),
      );
      expect(
        const SplitItemShare(memberId: 'An', weightNum: 2).toString(),
        contains('2/1'),
      );
      expect(
        const SplitItem(id: 'lau', unitPrice: 500000).toString(),
        contains('500000'),
      );
    });
  });
}
