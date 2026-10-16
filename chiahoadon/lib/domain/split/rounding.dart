import '../models/enums.dart';

/// Làm tròn và phân bổ số tiền.
///
/// Đây là phần đảm bảo bất biến cốt lõi của app: **tổng các phần luôn bằng
/// đúng tổng hóa đơn** (SPEC FR-4, FR-5).
class Rounding {
  const Rounding._();

  /// Đơn vị thực sự dùng khi phân bổ.
  ///
  /// Khi người dùng chọn "không làm tròn", tổng giữ nguyên số lẻ (vd 847.500đ)
  /// và không thể chia thành các phần đều là bội của 1.000đ. Lúc đó đơn vị
  /// phân bổ phải là 1 đồng — đúng ý "chia chính xác đến từng đồng".
  static int effectiveUnit(int unit, RoundingMode mode) =>
      mode == RoundingMode.none ? 1 : (unit < 1 ? 1 : unit);

  /// Làm tròn tổng hóa đơn — bước 7 của SPEC §FR-5.
  ///
  /// Phải làm tròn **tổng trước**, rồi mới phân bổ cho từng người. Nếu làm
  /// ngược lại thì tổng các phần sau khi làm tròn sẽ lệch khỏi tổng hóa đơn.
  static int roundTotal(int exact, int unit, RoundingMode mode) {
    if (exact <= 0) return 0;
    if (unit < 1) return exact;

    return switch (mode) {
      RoundingMode.none => exact,
      RoundingMode.up => ((exact + unit - 1) ~/ unit) * unit,
      RoundingMode.nearest => ((exact + unit ~/ 2) ~/ unit) * unit,
    };
  }

  /// Phân bổ [total] cho từng người theo [weights], bằng phương pháp
  /// **Largest Remainder** (Hamilton) — bước 10 của SPEC §FR-5.
  ///
  /// Bảo đảm cả ba tính chất:
  /// 1. `tổng kết quả == total`, tuyệt đối, không bao giờ lệch một đồng;
  /// 2. mọi kết quả là bội số của [unit];
  /// 3. kết quả tái lập được — cùng đầu vào luôn cho cùng đầu ra.
  ///
  /// Phép nhân `total × weight` chạy trên [BigInt] nên không tràn số dù tổng
  /// tiền lớn và trọng số lớn; so sánh phần dư cũng là so sánh số nguyên,
  /// không có `double` nào trong đường tính toán (SPEC NFR-6).
  ///
  /// [total] phải là bội số của [unit]; [roundTotal] đã bảo đảm điều đó.
  static Map<String, int> distribute({
    required List<String> ids,
    required List<int> weights,
    required int total,
    required int unit,
  }) {
    assert(
      ids.length == weights.length,
      'Số id (${ids.length}) phải bằng số trọng số (${weights.length})',
    );
    assert(unit >= 1, 'Đơn vị làm tròn phải >= 1, nhận được $unit');
    assert(
      total % unit == 0,
      'Tổng ($total) phải là bội của đơn vị làm tròn ($unit)',
    );

    final count = ids.length;
    if (count == 0) return const {};

    if (total <= 0) {
      return {for (final id in ids) id: 0};
    }

    final totalWeight = weights.fold<int>(0, (sum, w) => sum + (w < 0 ? 0 : w));

    // Không ai có trọng số: chia đều. Xảy ra khi tổng tiền chỉ gồm phụ phí
    // (vd hóa đơn chỉ có tiền tip) hoặc khi mọi phần gốc bị giảm giá về 0.
    if (totalWeight <= 0) {
      return distribute(
        ids: ids,
        weights: List.filled(count, 1),
        total: total,
        unit: unit,
      );
    }

    final bigTotal = BigInt.from(total);
    final bigUnit = BigInt.from(unit);
    final divisor = BigInt.from(totalWeight) * bigUnit;

    final floors = List<int>.filled(count, 0);
    final remainders = List<BigInt>.filled(count, BigInt.zero);
    var distributed = 0;

    for (var i = 0; i < count; i++) {
      final weight = weights[i] < 0 ? 0 : weights[i];
      final numerator = bigTotal * BigInt.from(weight);

      // Phần nguyên tính theo đơn vị, rồi nhân lại ra số đồng.
      final wholeUnits = numerator ~/ divisor;
      final floor = (wholeUnits * bigUnit).toInt();

      floors[i] = floor;
      remainders[i] = numerator.remainder(divisor);
      distributed += floor;
    }

    // Số suất `unit` còn lại để phát thêm. Luôn nhỏ hơn số người, vì phần dư
    // của mỗi người đều nhỏ hơn một đơn vị.
    final extraUnits = (total - distributed) ~/ unit;

    final order = List.generate(count, (i) => i)
      ..sort((a, b) {
        final byRemainder = remainders[b].compareTo(remainders[a]);
        if (byRemainder != 0) return byRemainder;

        // Đồng hạng phần dư: ưu tiên người có phần chịu lớn hơn.
        final byWeight = weights[b].compareTo(weights[a]);
        if (byWeight != 0) return byWeight;

        // Vẫn đồng hạng: theo thứ tự thêm vào hóa đơn, để kết quả tái lập được.
        return a.compareTo(b);
      });

    final amounts = List<int>.of(floors);
    for (var i = 0; i < extraUnits && i < count; i++) {
      amounts[order[i]] += unit;
    }

    return {for (var i = 0; i < count; i++) ids[i]: amounts[i]};
  }

  /// Bội số chung nhỏ nhất, dùng để quy các trọng số phân số về cùng mẫu số.
  ///
  /// Chặn trên [limit] để trọng số do người dùng nhập bừa không làm mẫu số
  /// chung phình ra vô hạn; vượt ngưỡng thì trả về [limit] và phép chia chỉ
  /// kém chính xác ở mức dưới một đồng.
  static int lcm(Iterable<int> values, {int limit = 1000000}) {
    var result = 1;
    for (final value in values) {
      if (value <= 0) continue;
      result = result ~/ _gcd(result, value) * value;
      if (result >= limit) return limit;
    }
    return result;
  }

  static int _gcd(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final temp = y;
      y = x % y;
      x = temp;
    }
    return x == 0 ? 1 : x;
  }
}
