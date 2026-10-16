import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/surcharge.dart';
import 'package:chiahoadon/domain/split/split_input.dart';
import 'package:chiahoadon/domain/split/split_result.dart';
import 'package:chiahoadon/domain/split/split_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tiện ích dựng [SplitInput] cho test, để mỗi test chỉ nêu đúng thứ nó quan tâm.
class Split {
  const Split._();

  /// Chia đều: chỉ cần tổng tiền và danh sách tên.
  static SplitInput equal({
    required int total,
    required List<String> members,
    int unit = 1,
    RoundingMode mode = RoundingMode.up,
    Surcharge discount = const Surcharge.none(),
    Surcharge tax = const Surcharge.none(),
    Surcharge service = const Surcharge.none(),
    int tip = 0,
    SurchargeAlloc alloc = SurchargeAlloc.proportional,
  }) => SplitInput(
    participants: [
      for (final member in members) SplitParticipant(memberId: member),
    ],
    splitType: SplitType.equal,
    manualTotal: total,
    discount: discount,
    tax: tax,
    service: service,
    tip: tip,
    surchargeAlloc: alloc,
    roundingUnit: unit,
    roundingMode: mode,
  );

  /// Chia theo món. [items] là danh sách `(tên món, số tiền, người dùng)`.
  static SplitInput itemized({
    required List<String> members,
    required List<({String id, int price, List<String> users})> items,
    int unit = 1,
    RoundingMode mode = RoundingMode.up,
    Surcharge discount = const Surcharge.none(),
    Surcharge tax = const Surcharge.none(),
    Surcharge service = const Surcharge.none(),
    int tip = 0,
    SurchargeAlloc alloc = SurchargeAlloc.proportional,
  }) => SplitInput(
    participants: [
      for (final member in members) SplitParticipant(memberId: member),
    ],
    splitType: SplitType.itemized,
    inputMode: InputMode.items,
    items: [
      for (final item in items)
        SplitItem(
          id: item.id,
          unitPrice: item.price,
          users: [
            for (final user in item.users) SplitItemShare(memberId: user),
          ],
        ),
    ],
    discount: discount,
    tax: tax,
    service: service,
    tip: tip,
    surchargeAlloc: alloc,
    roundingUnit: unit,
    roundingMode: mode,
  );

  /// Chia theo món, có trọng số trong món: `(tên, trọng số num, den)`.
  static SplitInput itemizedWeighted({
    required List<String> members,
    required List<({String id, int price, List<({String user, int num, int den})> users})> items,
    int unit = 1,
    RoundingMode mode = RoundingMode.up,
  }) => SplitInput(
    participants: [
      for (final member in members) SplitParticipant(memberId: member),
    ],
    splitType: SplitType.itemized,
    inputMode: InputMode.items,
    items: [
      for (final item in items)
        SplitItem(
          id: item.id,
          unitPrice: item.price,
          users: [
            for (final user in item.users)
              SplitItemShare(
                memberId: user.user,
                weightNum: user.num,
                weightDen: user.den,
              ),
          ],
        ),
    ],
    roundingUnit: unit,
    roundingMode: mode,
  );

  /// Chia theo phần trăm: [percents] tính bằng basis point (8% = 800).
  static SplitInput percentage({
    required int total,
    required Map<String, int> percents,
    int unit = 1000,
    RoundingMode mode = RoundingMode.up,
  }) => SplitInput(
    participants: [
      for (final entry in percents.entries)
        SplitParticipant(memberId: entry.key, percentBp: entry.value),
    ],
    splitType: SplitType.percentage,
    manualTotal: total,
    roundingUnit: unit,
    roundingMode: mode,
  );

  /// Chia theo số phần. [shares] là `tên → (num, den)`.
  static SplitInput shares({
    required int total,
    required Map<String, ({int num, int den})> shares,
    int unit = 1000,
    RoundingMode mode = RoundingMode.up,
  }) => SplitInput(
    participants: [
      for (final entry in shares.entries)
        SplitParticipant(
          memberId: entry.key,
          weightNum: entry.value.num,
          weightDen: entry.value.den,
        ),
    ],
    splitType: SplitType.shares,
    manualTotal: total,
    roundingUnit: unit,
    roundingMode: mode,
  );

  /// Chia theo số tiền chỉ định.
  static SplitInput exact({
    required int total,
    required Map<String, int> amounts,
    int unit = 1,
    RoundingMode mode = RoundingMode.up,
  }) => SplitInput(
    participants: [
      for (final entry in amounts.entries)
        SplitParticipant(memberId: entry.key, exactAmount: entry.value),
    ],
    splitType: SplitType.exact,
    manualTotal: total,
    roundingUnit: unit,
    roundingMode: mode,
  );
}

/// Kiểm tra bất biến cốt lõi của app: tổng các phần bằng đúng tổng hóa đơn,
/// và mọi phần là bội số của đơn vị làm tròn (SPEC FR-4, FR-5).
void expectSumMatchesTotal(SplitResult result, {int? unit}) {
  expect(
    result.sharesTotal,
    result.total,
    reason: 'Tổng các phần (${result.sharesTotal}) phải bằng tổng hóa đơn '
        '(${result.total}). Các phần: ${result.shares}',
  );

  if (unit != null && unit > 1) {
    for (final entry in result.shares.entries) {
      expect(
        entry.value % unit,
        0,
        reason: 'Phần của ${entry.key} (${entry.value}) không phải bội của $unit',
      );
    }
  }
}

/// Khẳng định kết quả có đúng một lỗi với mã cho trước.
void expectError(SplitResult result, SplitErrorCode code) {
  expect(result.isValid, isFalse, reason: 'Mong đợi lỗi ${code.name}');
  expect(
    result.errors.map((error) => error.code),
    contains(code),
    reason: 'Các lỗi thực tế: ${result.errors}',
  );
}
