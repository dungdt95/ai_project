import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/surcharge.dart';
import 'package:chiahoadon/domain/split/split_engine.dart';
import 'package:chiahoadon/domain/split/split_input.dart';
import 'package:chiahoadon/domain/split/split_result.dart';
import 'package:chiahoadon/domain/split/split_validator.dart';
import 'package:chiahoadon/domain/split/strategies/itemized_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'split_test_helper.dart';

/// Các nhánh biên: đầu vào bất thường, lỗi hiếm, và những getter mà UI sẽ dùng.
void main() {
  group('Nhánh biên của chia theo món', () {
    test('người có 0 phần trong món thì không phải trả gì', () {
      final result = computeSplit(
        Split.itemizedWeighted(
          members: ['An', 'Bình', 'Chi'],
          items: [
            (
              id: 'lau',
              price: 300000,
              users: [
                (user: 'An', num: 0, den: 1),
                (user: 'Bình', num: 0, den: 1),
              ],
            ),
          ],
        ),
      );

      // Giá nhân với số phần, nên 0 phần là 0 đồng — không còn phải quy ước
      // "0 trọng số thì chia đều" như hồi tiền món bị đem chia.
      expect(result.shares, {'An': 0, 'Bình': 0, 'Chi': 0});
      expect(result.subtotal, 0);
      expectSumMatchesTotal(result);
    });

    test('hóa đơn không có người tham gia thì chiến lược trả về rỗng', () {
      // Qua computeSplit thì validator đã chặn trước, nên gọi trực tiếp
      // chiến lược để chắc chắn nó không nổ khi danh sách người rỗng.
      final result = const ItemizedStrategy().baseShares(
        const SplitInput(
          participants: [],
          splitType: SplitType.itemized,
          inputMode: InputMode.items,
          items: [SplitItem(id: 'lau', unitPrice: 500000)],
        ),
      );

      expect(result.byMember, isEmpty);
      expect(result.byItem['lau'], isEmpty);
    });

    test('hóa đơn không có món nào thì tổng bằng 0, không lỗi', () {
      final result = computeSplit(
        Split.itemized(members: ['An', 'Bình'], items: []),
      );

      expect(result.isValid, isTrue);
      expect(result.subtotal, 0);
      expect(result.shares, {'An': 0, 'Bình': 0});
    });

    test('món giá 0 đồng không làm sai tổng', () {
      final result = computeSplit(
        Split.itemized(
          members: ['An', 'Bình'],
          items: [
            (id: 'free', price: 0, users: ['An']),
            (id: 'tra', price: 100000, users: ['An', 'Bình']),
          ],
        ),
      );

      expect(result.itemShareOf('free', 'An'), 0);
      // Trà 100.000 cho hai người là 100.000 mỗi người.
      expect(result.shares, {'An': 100000, 'Bình': 100000});
      expectSumMatchesTotal(result);
    });

    test('mọi món đều là món chung thì thành chia đều', () {
      final result = computeSplit(
        Split.itemized(
          members: ['An', 'Bình', 'Chi'],
          items: [
            (id: 'a', price: 300000, users: []),
            (id: 'b', price: 600000, users: []),
          ],
        ),
      );

      // Mỗi món tính một phần cho mỗi người: (300.000 + 600.000) mỗi người.
      expect(result.shares, {'An': 900000, 'Bình': 900000, 'Chi': 900000});
      expectSumMatchesTotal(result);
    });
  });

  group('Nhánh biên của validator', () {
    test('quá số người cho phép thì báo lỗi', () {
      final result = computeSplit(
        Split.equal(
          total: 1000000,
          members: [
            for (var i = 0; i <= SplitLimits.maxParticipants; i++) 'M$i',
          ],
        ),
      );

      expectError(result, SplitErrorCode.tooManyParticipants);
    });

    test('đúng ngưỡng số người thì vẫn hợp lệ', () {
      final result = computeSplit(
        Split.equal(
          total: 1000000,
          members: [
            for (var i = 0; i < SplitLimits.maxParticipants; i++) 'M$i',
          ],
        ),
      );

      expect(result.isValid, isTrue);
      expectSumMatchesTotal(result);
    });

    test('món có số tiền âm thì báo lỗi', () {
      const input = SplitInput(
        participants: [SplitParticipant(memberId: 'An')],
        splitType: SplitType.itemized,
        inputMode: InputMode.items,
        items: [SplitItem(id: 'xau', unitPrice: -50000)],
      );

      expectError(computeSplit(input), SplitErrorCode.negativeItemAmount);
    });

    test('trọng số trong món có mẫu số 0 thì báo lỗi', () {
      final result = computeSplit(
        Split.itemizedWeighted(
          members: ['An', 'Bình'],
          items: [
            (
              id: 'lau',
              price: 300000,
              users: [
                (user: 'An', num: 1, den: 0),
                (user: 'Bình', num: 1, den: 1),
              ],
            ),
          ],
        ),
      );

      expectError(result, SplitErrorCode.invalidWeight);
      expect(result.errors.first.itemId, 'lau');
      expect(result.errors.first.memberId, 'An');
    });

    test('một đầu vào có thể sinh nhiều lỗi cùng lúc', () {
      const input = SplitInput(
        participants: [
          SplitParticipant(memberId: 'An'),
          SplitParticipant(memberId: 'An'),
        ],
        splitType: SplitType.percentage,
        manualTotal: 100000,
      );

      final result = computeSplit(input);
      final codes = result.errors.map((error) => error.code).toSet();

      expect(codes, contains(SplitErrorCode.duplicateParticipant));
      expect(codes, contains(SplitErrorCode.percentageNotHundred));
    });

    test('SplitError.toString có cả mã lỗi và thông điệp', () {
      final result = computeSplit(Split.equal(total: 1000, members: []));

      expect(result.errors.first.toString(), contains('noParticipants'));
      expect(result.errors.first.toString(), contains('người tham gia'));
    });
  });

  group('Các getter của SplitResult mà UI sẽ dùng', () {
    final result = computeSplit(
      Split.itemized(
        members: ['An', 'Bình', 'Chi'],
        items: [
          (id: 'pho', price: 60000, users: ['An', 'Bình']),
          (id: 'buncha', price: 55000, users: ['Chi']),
          (id: 'trada', price: 5000, users: ['An', 'Bình', 'Chi']),
        ],
        unit: 1000,
        tax: const Surcharge.percent(800),
        service: const Surcharge.percent(500),
      ),
    );

    test('các mốc tiền bóc tách cho màn hình chi tiết', () {
      // Phở 60.000×2 + bún chả 55.000 + trà đá 5.000×3 = 190.000
      expect(result.base, 190000);
      expect(result.surchargeTotal, 24700); // VAT 15.200 + DV 9.500
      expect(result.netAdjustment, 25000); // 215.000 − 190.000
      expect(result.hasSurcharge, isTrue);
    });

    test('itemIdsOf trả về các món một người có tham gia', () {
      expect(result.itemIdsOf('An'), containsAll(['pho', 'trada']));
      expect(result.itemIdsOf('An'), isNot(contains('buncha')));
      expect(result.itemIdsOf('Chi'), containsAll(['buncha', 'trada']));
      expect(result.itemIdsOf('Chi'), isNot(contains('pho')));
    });

    test('tra cứu người hoặc món không tồn tại trả về 0, không nổ', () {
      expect(result.shareOf('KhôngCó'), 0);
      expect(result.baseShareOf('KhôngCó'), 0);
      expect(result.itemShareOf('mónLạ', 'An'), 0);
      expect(result.itemShareOf('lau', 'KhôngCó'), 0);
      expect(result.surchargeShareOf('KhôngCó'), 0);
    });

    test('hóa đơn không phụ phí thì hasSurcharge là false', () {
      final plain = computeSplit(
        Split.equal(total: 300000, members: ['An', 'Bình']),
      );

      expect(plain.hasSurcharge, isFalse);
      expect(plain.surchargeTotal, 0);
      expect(plain.netAdjustment, 0);
    });

    test('toString hiện tổng và các phần', () {
      expect(result.toString(), contains('215000'));
    });

    test('kết quả không hợp lệ vẫn có khóa cho mọi người tham gia', () {
      final invalid = SplitResult.invalid(
        const [
          SplitError(SplitErrorCode.noParticipants, 'test'),
        ],
        memberIds: ['An', 'Bình'],
      );

      expect(invalid.isValid, isFalse);
      expect(invalid.shares, {'An': 0, 'Bình': 0});
      expect(invalid.baseShares, {'An': 0, 'Bình': 0});
      expect(invalid.total, 0);
    });
  });
}
