import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/surcharge.dart';
import 'package:chiahoadon/domain/split/split_engine.dart';
import 'package:chiahoadon/domain/split/split_input.dart';
import 'package:chiahoadon/domain/split/split_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'split_test_helper.dart';

/// Bộ test của split engine, theo đúng danh sách test case ở PLAN §8.1.
void main() {
  group('Chia đều — SPEC FR-4.1', () {
    test('TC-01 · 1.000.000 cho 3 người, làm tròn 1.000đ', () {
      final result = computeSplit(
        Split.equal(
          total: 1000000,
          members: ['An', 'Bình', 'Chi'],
          unit: 1000,
        ),
      );

      expect(result.shares, {'An': 334000, 'Bình': 333000, 'Chi': 333000});
      expectSumMatchesTotal(result, unit: 1000);
    });

    test('TC-02 · 100.000 cho 3 người, đến từng đồng', () {
      final result = computeSplit(
        Split.equal(total: 100000, members: ['An', 'Bình', 'Chi']),
      );

      expect(result.shares, {'An': 33334, 'Bình': 33333, 'Chi': 33333});
      expectSumMatchesTotal(result);
    });

    test('TC-03 · 7 đồng cho 3 người', () {
      final result = computeSplit(
        Split.equal(total: 7, members: ['An', 'Bình', 'Chi']),
      );

      expect(result.shares, {'An': 3, 'Bình': 2, 'Chi': 2});
      expectSumMatchesTotal(result);
    });

    test('TC-04 · một người nhận toàn bộ', () {
      final result = computeSplit(
        Split.equal(total: 250000, members: ['An'], unit: 1000),
      );

      expect(result.shares, {'An': 250000});
      expectSumMatchesTotal(result, unit: 1000);
    });

    test('TC-05 · không có người tham gia thì báo lỗi, không crash', () {
      final result = computeSplit(Split.equal(total: 100000, members: []));

      expectError(result, SplitErrorCode.noParticipants);
      expect(result.shares, isEmpty);
    });

    test('một người được thêm hai lần thì báo lỗi', () {
      final result = computeSplit(
        Split.equal(total: 100000, members: ['An', 'An']),
      );

      expectError(result, SplitErrorCode.duplicateParticipant);
    });
  });

  group('Chia theo món — SPEC FR-4.2', () {
    /// Ví dụ chuẩn của SPEC: giá ghi trên món là giá **một người**.
    SplitInput specExample({
      int unit = 1,
      RoundingMode mode = RoundingMode.up,
      Surcharge tax = const Surcharge.none(),
      Surcharge service = const Surcharge.none(),
    }) => Split.itemized(
      members: ['An', 'Bình', 'Chi'],
      items: [
        (id: 'pho', price: 60000, users: ['An', 'Bình']),
        (id: 'buncha', price: 55000, users: ['Chi']),
        (id: 'trada', price: 5000, users: ['An', 'Bình', 'Chi']),
        (id: 'caphe', price: 25000, users: ['An']),
      ],
      unit: unit,
      mode: mode,
      tax: tax,
      service: service,
    );

    test('TC-06 · ví dụ chuẩn của SPEC, không phụ phí', () {
      final result = computeSplit(specExample());

      // Giá món × số người: phở 60.000 × 2, bún chả 55.000 × 1,
      // trà đá 5.000 × 3, cà phê 25.000 × 1.
      expect(result.subtotal, 215000);
      expect(result.shares, {'An': 90000, 'Bình': 65000, 'Chi': 60000});
      expectSumMatchesTotal(result);
    });

    test('TC-06b · mỗi người trả đúng giá món, không bị chia nhỏ', () {
      final result = computeSplit(specExample());

      // Đây chính là chỗ hay bị hiểu nhầm: hai người ăn phở thì **mỗi người**
      // trả 60.000, tổng món là 120.000 — không phải mỗi người 30.000.
      expect(result.itemShareOf('pho', 'An'), 60000);
      expect(result.itemShareOf('pho', 'Bình'), 60000);
      expect(result.itemShares['pho']!.values.reduce((a, b) => a + b), 120000);

      expect(result.itemShareOf('trada', 'Chi'), 5000);
      expect(result.itemShareOf('caphe', 'An'), 25000);
      expect(result.itemShareOf('caphe', 'Bình'), 0);
    });

    test('TC-06c · không có phép chia nên không có phần dư', () {
      // Giá lẻ không chia hết cho số người: với quy tắc nhân thì điều đó không
      // còn là vấn đề, mỗi người vẫn trả đúng một bội số nguyên của giá.
      final result = computeSplit(
        Split.itemized(
          members: ['An', 'Bình', 'Chi'],
          items: [(id: 'le', price: 33333, users: ['An', 'Bình', 'Chi'])],
        ),
      );

      expect(result.shares, {'An': 33333, 'Bình': 33333, 'Chi': 33333});
      expect(result.subtotal, 99999);
      expectSumMatchesTotal(result);
    });

    test('TC-07 · món chưa chọn ai thì tính mỗi người một phần', () {
      final result = computeSplit(
        Split.itemized(
          members: ['An', 'Bình', 'Chi'],
          items: [
            (id: 'pho', price: 60000, users: ['An', 'Bình']),
            (id: 'chung', price: 30000, users: []),
          ],
        ),
      );

      // Phở 60.000 × 2 người = 120.000; món chung 30.000 × 3 người = 90.000.
      expect(result.subtotal, 210000);
      expect(result.shares, {'An': 90000, 'Bình': 90000, 'Chi': 30000});
      expectSumMatchesTotal(result);
      expect(result.itemShareOf('chung', 'Chi'), 30000);
    });

    test('TC-08 · số phần trong món: Bình uống 2 lon, An 1 lon', () {
      final result = computeSplit(
        Split.itemizedWeighted(
          members: ['An', 'Bình'],
          items: [
            (
              id: 'bia',
              price: 20000,
              users: [
                (user: 'An', num: 1, den: 1),
                (user: 'Bình', num: 2, den: 1),
              ],
            ),
          ],
        ),
      );

      expect(result.shares, {'An': 20000, 'Bình': 40000});
      expect(result.subtotal, 60000);
      expectSumMatchesTotal(result);
    });

    test('món có người ngoài danh sách tham gia thì báo lỗi', () {
      final result = computeSplit(
        Split.itemized(
          members: ['An', 'Bình'],
          items: [(id: 'pho', price: 60000, users: ['An', 'NgườiLạ'])],
        ),
      );

      expectError(result, SplitErrorCode.itemUserNotParticipant);
    });

    test('chọn cùng một người hai lần trong một món thì báo lỗi', () {
      final result = computeSplit(
        Split.itemized(
          members: ['An', 'Bình'],
          items: [(id: 'pho', price: 60000, users: ['An', 'An'])],
        ),
      );

      expectError(result, SplitErrorCode.duplicateItemUser);
    });

    test('chia theo món nhưng nhập tổng tiền thì báo lỗi', () {
      const input = SplitInput(
        participants: [SplitParticipant(memberId: 'An')],
        splitType: SplitType.itemized,
        manualTotal: 100000,
      );

      expectError(computeSplit(input), SplitErrorCode.itemizedNeedsItems);
    });
  });

  group('Chia theo phần trăm — SPEC FR-4.3', () {
    test('TC-09 · 50% / 30% / 20% của 1.000.000', () {
      final result = computeSplit(
        Split.percentage(
          total: 1000000,
          percents: {'An': 5000, 'Bình': 3000, 'Chi': 2000},
        ),
      );

      expect(result.shares, {'An': 500000, 'Bình': 300000, 'Chi': 200000});
      expectSumMatchesTotal(result, unit: 1000);
    });

    test('TC-09b · 33,33% / 33,33% / 33,34% vẫn khớp tổng', () {
      final result = computeSplit(
        Split.percentage(
          total: 1000000,
          percents: {'An': 3333, 'Bình': 3333, 'Chi': 3334},
          unit: 1,
        ),
      );

      expectSumMatchesTotal(result);
      expect(result.shareOf('Chi'), greaterThanOrEqualTo(result.shareOf('An')));
    });

    test('TC-10 · tổng 99% thì báo lỗi', () {
      final result = computeSplit(
        Split.percentage(
          total: 1000000,
          percents: {'An': 5000, 'Bình': 3000, 'Chi': 1900},
        ),
      );

      expectError(result, SplitErrorCode.percentageNotHundred);
      expect(result.errors.first.message, contains('còn thiếu'));
    });

    test('tổng 101% thì báo lỗi vượt', () {
      final result = computeSplit(
        Split.percentage(
          total: 1000000,
          percents: {'An': 5000, 'Bình': 3000, 'Chi': 2100},
        ),
      );

      expectError(result, SplitErrorCode.percentageNotHundred);
      expect(result.errors.first.message, contains('vượt'));
    });
  });

  group('Chia theo số phần — SPEC FR-4.4', () {
    test('TC-11 · tiền nhà 6.000.000, phòng đôi tính 2 phần', () {
      final result = computeSplit(
        Split.shares(
          total: 6000000,
          shares: {
            'An': (num: 2, den: 1),
            'Bình': (num: 1, den: 1),
            'Chi': (num: 1, den: 1),
          },
        ),
      );

      expect(result.shares, {
        'An': 3000000,
        'Bình': 1500000,
        'Chi': 1500000,
      });
      expectSumMatchesTotal(result, unit: 1000);
    });

    test('TC-11b · nửa phần: 1 / 1 / 0,5', () {
      final result = computeSplit(
        Split.shares(
          total: 500000,
          shares: {
            'An': (num: 1, den: 1),
            'Bình': (num: 1, den: 1),
            'Chi': (num: 1, den: 2),
          },
        ),
      );

      // Tỷ lệ 2 : 2 : 1 của 500.000
      expect(result.shares, {'An': 200000, 'Bình': 200000, 'Chi': 100000});
      expectSumMatchesTotal(result, unit: 1000);
    });

    test('TC-12 · mọi người 0 phần thì báo lỗi', () {
      final result = computeSplit(
        Split.shares(
          total: 500000,
          shares: {'An': (num: 0, den: 1), 'Bình': (num: 0, den: 1)},
        ),
      );

      expectError(result, SplitErrorCode.zeroWeightTotal);
    });

    test('mẫu số 0 thì báo lỗi', () {
      final result = computeSplit(
        Split.shares(
          total: 500000,
          shares: {'An': (num: 1, den: 0), 'Bình': (num: 1, den: 1)},
        ),
      );

      expectError(result, SplitErrorCode.invalidWeight);
    });

    test('TC-19 · một người 0 phần thì nhận 0, tổng vẫn khớp', () {
      final result = computeSplit(
        Split.shares(
          total: 999000,
          shares: {
            'An': (num: 1, den: 1),
            'Bình': (num: 0, den: 1),
            'Chi': (num: 1, den: 1),
          },
        ),
      );

      expect(result.shareOf('Bình'), 0);
      expectSumMatchesTotal(result, unit: 1000);
    });
  });

  group('Chia theo số tiền chỉ định — SPEC FR-4.5', () {
    test('TC-13 · tổng khớp thì giữ nguyên số đã nhập', () {
      final result = computeSplit(
        Split.exact(
          total: 500000,
          amounts: {'An': 200000, 'Bình': 180000, 'Chi': 120000},
        ),
      );

      expect(result.shares, {'An': 200000, 'Bình': 180000, 'Chi': 120000});
      expectSumMatchesTotal(result);
    });

    test('TC-13b · tổng thiếu thì báo lỗi kèm số còn lại', () {
      final result = computeSplit(
        Split.exact(
          total: 500000,
          amounts: {'An': 200000, 'Bình': 180000, 'Chi': 100000},
        ),
      );

      expectError(result, SplitErrorCode.exactMismatch);
      expect(result.errors.first.message, contains('20000'));
    });

    test('TC-13c · tổng vượt thì báo lỗi', () {
      final result = computeSplit(
        Split.exact(
          total: 500000,
          amounts: {'An': 300000, 'Bình': 300000},
        ),
      );

      expectError(result, SplitErrorCode.exactMismatch);
      expect(result.errors.first.message, contains('vượt'));
    });
  });

  group('Phụ phí, giảm giá, làm tròn — SPEC FR-5', () {
    test('TC-14 · thứ tự tính: giảm giá trước, VAT và phí dịch vụ sau', () {
      final result = computeSplit(
        Split.equal(
          total: 750000,
          members: ['An', 'Bình'],
          discount: const Surcharge.percent(1000), // 10%
          tax: const Surcharge.percent(800), // 8%
          service: const Surcharge.percent(500), // 5%
        ),
      );

      expect(result.subtotal, 750000);
      expect(result.discountAmount, 75000);
      expect(result.base, 675000);
      expect(result.taxAmount, 54000); // 8% của 675.000
      expect(result.serviceAmount, 33750); // 5% của 675.000
      expect(result.totalExact, 762750);
      expectSumMatchesTotal(result);
    });

    test('TC-14b · giảm giá dạng số tiền tuyệt đối', () {
      final result = computeSplit(
        Split.equal(
          total: 500000,
          members: ['An'],
          discount: const Surcharge.amount(50000),
          tax: const Surcharge.percent(800),
        ),
      );

      expect(result.discountAmount, 50000);
      expect(result.base, 450000);
      expect(result.taxAmount, 36000);
      expect(result.totalExact, 486000);
    });

    test('TC-15 · giảm giá lớn hơn tiền món bị kẹp, hóa đơn không âm', () {
      final result = computeSplit(
        Split.equal(
          total: 100000,
          members: ['An', 'Bình'],
          discount: const Surcharge.amount(500000),
        ),
      );

      expect(result.discountAmount, 100000);
      expect(result.base, 0);
      expect(result.total, 0);
      expect(result.shares.values.every((share) => share >= 0), isTrue);
      expectSumMatchesTotal(result);
    });

    test('TC-16 · tổng bằng 0 thì mọi phần bằng 0, không chia cho 0', () {
      final result = computeSplit(
        Split.equal(total: 0, members: ['An', 'Bình', 'Chi'], unit: 1000),
      );

      expect(result.total, 0);
      expect(result.shares, {'An': 0, 'Bình': 0, 'Chi': 0});
      expect(result.isValid, isTrue, reason: 'tổng 0 không phải lỗi cấu trúc');
    });

    test('TC-17 · đơn vị 5.000đ, làm tròn lên', () {
      final result = computeSplit(
        Split.equal(
          total: 750000,
          members: ['An', 'Bình', 'Chi'],
          unit: 5000,
          tax: const Surcharge.percent(800),
          service: const Surcharge.percent(500),
        ),
      );

      expect(result.totalExact, 847500);
      expect(result.total, 850000);
      expect(result.roundingDelta, 2500);
      expectSumMatchesTotal(result, unit: 5000);
    });

    test('TC-17b · chế độ không làm tròn giữ nguyên số lẻ', () {
      final result = computeSplit(
        Split.equal(
          total: 750000,
          members: ['An', 'Bình', 'Chi'],
          unit: 1000,
          mode: RoundingMode.none,
          tax: const Surcharge.percent(800),
          service: const Surcharge.percent(500),
        ),
      );

      expect(result.total, 847500);
      expect(result.roundingDelta, 0);
      expectSumMatchesTotal(result);
    });

    test('TC-18 · phụ phí chia đều thay vì theo tỷ lệ', () {
      final result = computeSplit(
        Split.itemized(
          members: ['An', 'Bình'],
          items: [
            (id: 'lau', price: 900000, users: ['An']),
            (id: 'tra', price: 100000, users: ['Bình']),
          ],
          tip: 100000,
          alloc: SurchargeAlloc.equal,
        ),
      );

      // Tiền món của ai người đó chịu; 100.000 tip chia đều 50.000 mỗi người.
      expect(result.shares, {'An': 950000, 'Bình': 150000});
      expectSumMatchesTotal(result);
    });

    test('TC-18b · cùng dữ liệu nhưng phụ phí theo tỷ lệ thì khác hẳn', () {
      final result = computeSplit(
        Split.itemized(
          members: ['An', 'Bình'],
          items: [
            (id: 'lau', price: 900000, users: ['An']),
            (id: 'tra', price: 100000, users: ['Bình']),
          ],
          tip: 100000,
        ),
      );

      // Theo tỷ lệ 9:1 -> An gánh 90.000 tip, Bình gánh 10.000.
      expect(result.shares, {'An': 990000, 'Bình': 110000});
      expectSumMatchesTotal(result);
    });

    test('phụ phí chia đều nhưng giảm giá rất lớn thì không ai nhận tiền', () {
      final result = computeSplit(
        Split.itemized(
          members: ['An', 'Bình'],
          items: [
            (id: 'to', price: 990000, users: ['An']),
            (id: 'nho', price: 10000, users: ['Bình']),
          ],
          discount: const Surcharge.amount(900000),
          alloc: SurchargeAlloc.equal,
        ),
      );

      expect(result.shares.values.every((share) => share >= 0), isTrue);
      expectSumMatchesTotal(result);
    });

    test('số tiền vượt ngưỡng hợp lý thì báo lỗi', () {
      final result = computeSplit(
        Split.equal(total: SplitLimits.maxAmount + 1, members: ['An']),
      );

      expectError(result, SplitErrorCode.amountTooLarge);
    });
  });

  group('★ Ví dụ kiểm chứng của SPEC §FR-5', () {
    test(
      'phở + bún chả + trà đá + cà phê, VAT 8%, phí DV 5%, làm tròn lên '
      '1.000đ → 102.000 / 73.000 / 68.000',
      () {
        final result = computeSplit(
          Split.itemized(
            members: ['An', 'Bình', 'Chi'],
            items: [
              (id: 'pho', price: 60000, users: ['An', 'Bình']),
              (id: 'buncha', price: 55000, users: ['Chi']),
              (id: 'trada', price: 5000, users: ['An', 'Bình', 'Chi']),
              (id: 'caphe', price: 25000, users: ['An']),
            ],
            unit: 1000,
            tax: const Surcharge.percent(800),
            service: const Surcharge.percent(500),
          ),
        );

        // Các mốc tiền của cả hóa đơn
        expect(result.subtotal, 215000);
        expect(result.taxAmount, 17200);
        expect(result.serviceAmount, 10750);
        expect(result.totalExact, 242950);
        expect(result.total, 243000);
        expect(result.roundingDelta, 50);

        // Phần gốc từng người, trước phụ phí — giá món × số phần, không chia
        expect(result.baseShares, {'An': 90000, 'Bình': 65000, 'Chi': 60000});

        // Kết quả cuối — đúng con số đã ghi trong SPEC
        expect(result.shares, {'An': 102000, 'Bình': 73000, 'Chi': 68000});
        expectSumMatchesTotal(result, unit: 1000);

        // Phần phụ phí mỗi người gánh, cộng lại đúng bằng chênh lệch tổng
        expect(
          result.shares.values.reduce((a, b) => a + b) - result.subtotal,
          28000,
        );
      },
    );
  });

  group('Tính xác định và tính thuần', () {
    test('TC-P2 · gọi hai lần với cùng đầu vào cho kết quả giống hệt', () {
      final input = Split.itemized(
        members: ['An', 'Bình', 'Chi', 'Dũng'],
        items: [
          (id: 'a', price: 333333, users: ['An', 'Bình', 'Chi']),
          (id: 'b', price: 777777, users: ['Bình', 'Dũng']),
          (id: 'c', price: 11111, users: []),
        ],
        unit: 1000,
        tax: const Surcharge.percent(833),
      );

      final first = computeSplit(input);
      final second = computeSplit(input);

      expect(first.shares, second.shares);
      expect(first.total, second.total);
      expect(first.baseShares, second.baseShares);
    });

    test('đổi thứ tự người tham gia không làm đổi tổng', () {
      final forward = computeSplit(
        Split.equal(
          total: 1000000,
          members: ['An', 'Bình', 'Chi'],
          unit: 1000,
        ),
      );
      final reversed = computeSplit(
        Split.equal(
          total: 1000000,
          members: ['Chi', 'Bình', 'An'],
          unit: 1000,
        ),
      );

      expect(forward.total, reversed.total);
      expect(forward.sharesTotal, reversed.sharesTotal);
      // Phần dư đi theo thứ tự danh sách, nên người đầu tiên là người nhận thêm.
      expect(forward.shareOf('An'), 334000);
      expect(reversed.shareOf('Chi'), 334000);
    });
  });
}
