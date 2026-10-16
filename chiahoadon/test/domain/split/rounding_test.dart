import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/split/rounding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rounding.effectiveUnit', () {
    test('chế độ không làm tròn thì phân bổ đến từng đồng', () {
      // Tổng 847.500 không thể chia thành các phần đều là bội của 1.000.
      expect(Rounding.effectiveUnit(1000, RoundingMode.none), 1);
    });

    test('các chế độ khác giữ nguyên đơn vị người dùng chọn', () {
      expect(Rounding.effectiveUnit(1000, RoundingMode.up), 1000);
      expect(Rounding.effectiveUnit(5000, RoundingMode.nearest), 5000);
    });

    test('đơn vị không hợp lệ được nâng về 1', () {
      expect(Rounding.effectiveUnit(0, RoundingMode.up), 1);
      expect(Rounding.effectiveUnit(-5, RoundingMode.up), 1);
    });
  });

  group('Rounding.roundTotal', () {
    test('làm tròn lên', () {
      expect(Rounding.roundTotal(847500, 1000, RoundingMode.up), 848000);
      expect(Rounding.roundTotal(847001, 1000, RoundingMode.up), 848000);
      expect(Rounding.roundTotal(847000, 1000, RoundingMode.up), 847000);
      expect(Rounding.roundTotal(847500, 5000, RoundingMode.up), 850000);
    });

    test('làm tròn tới bội gần nhất', () {
      expect(Rounding.roundTotal(847500, 1000, RoundingMode.nearest), 848000);
      expect(Rounding.roundTotal(847400, 1000, RoundingMode.nearest), 847000);
      expect(Rounding.roundTotal(847499, 1000, RoundingMode.nearest), 847000);
    });

    test('không làm tròn thì giữ nguyên', () {
      expect(Rounding.roundTotal(847500, 1000, RoundingMode.none), 847500);
    });

    test('số không dương trả về 0', () {
      expect(Rounding.roundTotal(0, 1000, RoundingMode.up), 0);
      expect(Rounding.roundTotal(-500, 1000, RoundingMode.up), 0);
    });
  });

  group('Rounding.distribute — Largest Remainder', () {
    test('chia hết thì không có phần dư', () {
      final result = Rounding.distribute(
        ids: ['a', 'b', 'c'],
        weights: [1, 1, 1],
        total: 900000,
        unit: 1000,
      );

      expect(result, {'a': 300000, 'b': 300000, 'c': 300000});
    });

    test('phần dư dồn cho người đầu khi mọi người đồng hạng', () {
      final result = Rounding.distribute(
        ids: ['a', 'b', 'c'],
        weights: [1, 1, 1],
        total: 1000000,
        unit: 1000,
      );

      expect(result, {'a': 334000, 'b': 333000, 'c': 333000});
      expect(_sum(result), 1000000);
    });

    test('phần dư ưu tiên người có phần dư lớn nhất', () {
      // 100 đồng chia theo trọng số 1:1:4 -> 16,67 / 16,67 / 66,67
      final result = Rounding.distribute(
        ids: ['a', 'b', 'c'],
        weights: [1, 1, 4],
        total: 100,
        unit: 1,
      );

      expect(_sum(result), 100);
      // c có phần gốc lớn nhất nên cũng là người nhận thêm trước.
      expect(result['c'], greaterThan(result['a']!));
    });

    test('trọng số 0 thì nhận 0, tổng vẫn khớp', () {
      final result = Rounding.distribute(
        ids: ['a', 'b', 'c'],
        weights: [1, 0, 1],
        total: 999999,
        unit: 1,
      );

      expect(result['b'], 0);
      expect(_sum(result), 999999);
    });

    test('mọi trọng số bằng 0 thì chia đều', () {
      final result = Rounding.distribute(
        ids: ['a', 'b', 'c'],
        weights: [0, 0, 0],
        total: 300000,
        unit: 1000,
      );

      expect(result, {'a': 100000, 'b': 100000, 'c': 100000});
    });

    test('tổng 0 thì mọi người nhận 0', () {
      final result = Rounding.distribute(
        ids: ['a', 'b'],
        weights: [3, 1],
        total: 0,
        unit: 1000,
      );

      expect(result, {'a': 0, 'b': 0});
    });

    test('một người nhận toàn bộ', () {
      final result = Rounding.distribute(
        ids: ['a'],
        weights: [1],
        total: 777000,
        unit: 1000,
      );

      expect(result, {'a': 777000});
    });

    test('mọi kết quả là bội số của đơn vị làm tròn', () {
      final result = Rounding.distribute(
        ids: ['a', 'b', 'c', 'd'],
        weights: [7, 11, 13, 17],
        total: 850000,
        unit: 5000,
      );

      expect(_sum(result), 850000);
      for (final amount in result.values) {
        expect(amount % 5000, 0, reason: 'phần $amount không phải bội 5.000');
      }
    });

    test('số tiền rất lớn không tràn số (dùng BigInt bên trong)', () {
      // 1 nghìn tỷ đồng, trọng số cũng rất lớn.
      final result = Rounding.distribute(
        ids: ['a', 'b', 'c'],
        weights: [333333333333, 333333333333, 333333333334],
        total: 1000000000000,
        unit: 1000,
      );

      expect(_sum(result), 1000000000000);
      for (final amount in result.values) {
        expect(amount, greaterThan(0));
      }
    });

    test('danh sách rỗng trả về map rỗng', () {
      expect(
        Rounding.distribute(ids: [], weights: [], total: 1000, unit: 1000),
        isEmpty,
      );
    });

    test('tái lập được: gọi hai lần cho kết quả giống hệt', () {
      Map<String, int> run() => Rounding.distribute(
        ids: ['a', 'b', 'c', 'd', 'e'],
        weights: [3, 3, 3, 3, 3],
        total: 1000000,
        unit: 1000,
      );

      expect(run(), run());
    });
  });

  group('Rounding.lcm', () {
    test('bội số chung nhỏ nhất của các mẫu số', () {
      expect(Rounding.lcm([1, 1, 1]), 1);
      expect(Rounding.lcm([2, 3]), 6);
      expect(Rounding.lcm([2, 4, 8]), 8);
      expect(Rounding.lcm([1, 2, 3, 4, 5]), 60);
    });

    test('bỏ qua giá trị không dương', () {
      expect(Rounding.lcm([0, 2, 3]), 6);
      expect(Rounding.lcm([-2, 3]), 3);
      expect(Rounding.lcm([]), 1);
    });

    test('bị chặn trên để mẫu số chung không phình vô hạn', () {
      expect(Rounding.lcm([7919, 7920, 7921], limit: 1000), 1000);
    });
  });
}

int _sum(Map<String, int> values) =>
    values.values.fold(0, (sum, value) => sum + value);
