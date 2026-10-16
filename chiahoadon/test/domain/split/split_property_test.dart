import 'dart:math';

import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/surcharge.dart';
import 'package:chiahoadon/domain/split/rounding.dart';
import 'package:chiahoadon/domain/split/split_engine.dart';
import 'package:chiahoadon/domain/split/split_input.dart';
import 'package:flutter_test/flutter_test.dart';

/// Property test của split engine — TC-P1 và TC-P2 ở PLAN §8.1.
///
/// Test theo từng trường hợp cụ thể chỉ chứng minh được những tình huống mình
/// nghĩ ra. Bất biến `tổng các phần == tổng hóa đơn` phải đúng với **mọi** đầu
/// vào, kể cả những tổ hợp không ai nghĩ tới, nên ở đây sinh hàng chục nghìn
/// hóa đơn ngẫu nhiên và kiểm tra bất biến sau từng lần.
///
/// Hạt giống ngẫu nhiên là cố định, nên khi test đỏ thì lần chạy sau tái hiện
/// được đúng trường hợp đó.
void main() {
  group('TC-P1 · bất biến tổng tiền với đầu vào ngẫu nhiên', () {
    test('10.000 hóa đơn ngẫu nhiên: tổng các phần luôn bằng tổng hóa đơn', () {
      final random = Random(20261003);
      var checked = 0;

      for (var iteration = 0; iteration < 10000; iteration++) {
        final input = _randomValidInput(random);
        final result = computeSplit(input);

        if (!result.isValid) {
          fail(
            'Lần $iteration: đầu vào đáng lẽ hợp lệ nhưng bị báo lỗi\n'
            'input: $input\n'
            'lỗi: ${result.errors}',
          );
        }

        if (result.sharesTotal != result.total) {
          fail(
            'Lần $iteration: BẤT BIẾN BỊ VI PHẠM\n'
            'tổng các phần = ${result.sharesTotal}, '
            'tổng hóa đơn = ${result.total}\n'
            'kiểu chia: ${input.splitType.dbValue}, '
            'số người: ${input.participantCount}, '
            'subtotal: ${input.subtotal}, '
            'đơn vị: ${input.roundingUnit}, '
            'chế độ: ${input.roundingMode.dbValue}\n'
            'các phần: ${result.shares}',
          );
        }

        checked++;
      }

      expect(checked, 10000);
    });

    test('mọi phần là bội số của đơn vị làm tròn và không âm', () {
      final random = Random(7778889);

      for (var iteration = 0; iteration < 5000; iteration++) {
        final input = _randomValidInput(random);
        final result = computeSplit(input);
        final unit = Rounding.effectiveUnit(
          input.roundingUnit,
          input.roundingMode,
        );

        for (final entry in result.shares.entries) {
          if (entry.value < 0) {
            fail(
              'Lần $iteration: phần của ${entry.key} âm (${entry.value})\n'
              'input: $input',
            );
          }
          if (entry.value % unit != 0) {
            fail(
              'Lần $iteration: phần của ${entry.key} (${entry.value}) '
              'không phải bội của $unit\ninput: $input',
            );
          }
        }
      }
    });

    test('tổng phần gốc luôn bằng đúng subtotal', () {
      final random = Random(1234567);

      for (var iteration = 0; iteration < 5000; iteration++) {
        final input = _randomValidInput(random);
        final result = computeSplit(input);
        final baseTotal = result.baseShares.values.fold<int>(
          0,
          (sum, value) => sum + value,
        );

        if (baseTotal != input.subtotal) {
          fail(
            'Lần $iteration: tổng phần gốc ($baseTotal) != subtotal '
            '(${input.subtotal})\n'
            'kiểu chia: ${input.splitType.dbValue}\n'
            'phần gốc: ${result.baseShares}',
          );
        }
      }
    });

    test('tổng đã làm tròn khớp với roundTotal', () {
      final random = Random(99887766);

      for (var iteration = 0; iteration < 5000; iteration++) {
        final input = _randomValidInput(random);
        final result = computeSplit(input);
        final unit = Rounding.effectiveUnit(
          input.roundingUnit,
          input.roundingMode,
        );

        expect(
          result.total,
          Rounding.roundTotal(result.totalExact, unit, input.roundingMode),
          reason: 'Lần $iteration, input: $input',
        );
      }
    });

    test('chia theo món: mỗi món phân bổ khớp đúng giá món', () {
      final random = Random(55443322);

      for (var iteration = 0; iteration < 3000; iteration++) {
        final input = _randomItemizedInput(random);
        final result = computeSplit(input);

        for (final item in input.items) {
          final allocated = (result.itemShares[item.id] ?? const {})
              .values
              .fold<int>(0, (sum, value) => sum + value);

          final expected = item.amountFor(input.participantIds);
          if (allocated != expected) {
            fail(
              'Lần $iteration: món ${item.id} phân bổ $allocated '
              'nhưng giá × số phần là $expected\n'
              'số người dùng món: ${item.users.length}',
            );
          }
        }
      }
    });
  });

  group('TC-P2 · tính xác định', () {
    test('1.000 đầu vào ngẫu nhiên, gọi hai lần cho kết quả giống hệt', () {
      final random = Random(31415926);

      for (var iteration = 0; iteration < 1000; iteration++) {
        final input = _randomValidInput(random);

        final first = computeSplit(input);
        final second = computeSplit(input);

        if (first.total != second.total ||
            !_sameMap(first.shares, second.shares) ||
            !_sameMap(first.baseShares, second.baseShares)) {
          fail(
            'Lần $iteration: hai lần gọi cho kết quả khác nhau\n'
            'lần 1: ${first.shares}\nlần 2: ${second.shares}',
          );
        }
      }
    });
  });
}

// ─────────────────────── sinh đầu vào ngẫu nhiên ───────────────────────

/// Một [SplitInput] ngẫu nhiên nhưng **hợp lệ về cấu trúc**, để property test
/// kiểm tra đường tính toán chứ không phải đường báo lỗi.
SplitInput _randomValidInput(Random random) {
  final type = SplitType.values[random.nextInt(SplitType.values.length)];

  if (type == SplitType.itemized) return _randomItemizedInput(random);

  final count = 1 + random.nextInt(20);
  final ids = _ids(count);
  final subtotal = _randomAmount(random);

  final participants = switch (type) {
    SplitType.percentage => () {
      final parts = _partition(10000, count, random);
      return [
        for (var i = 0; i < count; i++)
          SplitParticipant(memberId: ids[i], percentBp: parts[i]),
      ];
    }(),
    SplitType.exact => () {
      final parts = _partition(subtotal, count, random);
      return [
        for (var i = 0; i < count; i++)
          SplitParticipant(memberId: ids[i], exactAmount: parts[i]),
      ];
    }(),
    SplitType.shares => () {
      final nums = [for (var i = 0; i < count; i++) random.nextInt(6)];
      // Phải có ít nhất một người được tính phần, nếu không là lỗi cấu trúc.
      if (nums.every((value) => value == 0)) nums[0] = 1;
      return [
        for (var i = 0; i < count; i++)
          SplitParticipant(
            memberId: ids[i],
            weightNum: nums[i],
            weightDen: 1 + random.nextInt(4),
          ),
      ];
    }(),
    _ => [for (final id in ids) SplitParticipant(memberId: id)],
  };

  return SplitInput(
    participants: participants,
    splitType: type,
    manualTotal: subtotal,
    discount: _randomSurcharge(random),
    tax: _randomSurcharge(random),
    service: _randomSurcharge(random),
    tip: random.nextInt(4) == 0 ? random.nextInt(200000) : 0,
    surchargeAlloc: random.nextBool()
        ? SurchargeAlloc.proportional
        : SurchargeAlloc.equal,
    roundingUnit: const [1, 500, 1000, 5000][random.nextInt(4)],
    roundingMode: RoundingMode.values[random.nextInt(
      RoundingMode.values.length,
    )],
  );
}

SplitInput _randomItemizedInput(Random random) {
  final count = 1 + random.nextInt(20);
  final ids = _ids(count);
  final itemCount = random.nextInt(31);

  return SplitInput(
    participants: [for (final id in ids) SplitParticipant(memberId: id)],
    splitType: SplitType.itemized,
    inputMode: InputMode.items,
    items: [
      for (var i = 0; i < itemCount; i++)
        SplitItem(
          id: 'item$i',
          unitPrice: random.nextInt(500000),
          users: _randomUsers(ids, random),
        ),
    ],
    discount: _randomSurcharge(random),
    tax: _randomSurcharge(random),
    service: _randomSurcharge(random),
    tip: random.nextInt(4) == 0 ? random.nextInt(200000) : 0,
    surchargeAlloc: random.nextBool()
        ? SurchargeAlloc.proportional
        : SurchargeAlloc.equal,
    roundingUnit: const [1, 500, 1000, 5000][random.nextInt(4)],
    roundingMode: RoundingMode.values[random.nextInt(
      RoundingMode.values.length,
    )],
  );
}

/// Tập con ngẫu nhiên của [ids], **có thể rỗng** — món chung phải được phủ.
List<SplitItemShare> _randomUsers(List<String> ids, Random random) {
  final users = <SplitItemShare>[];

  for (final id in ids) {
    if (random.nextBool()) {
      users.add(
        SplitItemShare(
          memberId: id,
          weightNum: 1 + random.nextInt(3),
          weightDen: 1 + random.nextInt(2),
        ),
      );
    }
  }

  return users;
}

Surcharge _randomSurcharge(Random random) => switch (random.nextInt(3)) {
  0 => const Surcharge.none(),
  // Tối đa 20% (2000 basis point).
  1 => Surcharge.percent(random.nextInt(2001)),
  _ => Surcharge.amount(random.nextInt(500000)),
};

int _randomAmount(Random random) => switch (random.nextInt(10)) {
  // Thỉnh thoảng trả về 0 và các số rất nhỏ — đó là nơi phép chia dễ sai nhất.
  0 => 0,
  1 => random.nextInt(10),
  2 => random.nextInt(1000),
  _ => random.nextInt(50000000),
};

List<String> _ids(int count) => [for (var i = 0; i < count; i++) 'M$i'];

/// Chia [total] thành [count] phần nguyên không âm, tổng đúng bằng [total].
List<int> _partition(int total, int count, Random random) {
  if (count <= 1) return [total];

  final cuts = List.generate(count - 1, (_) => random.nextInt(total + 1))
    ..sort();

  final parts = <int>[];
  var previous = 0;
  for (final cut in cuts) {
    parts.add(cut - previous);
    previous = cut;
  }
  parts.add(total - previous);

  return parts;
}

bool _sameMap(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
