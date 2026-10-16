import 'enums.dart';

/// Một khoản phụ phí hoặc giảm giá: VAT, phí dịch vụ, voucher (SPEC FR-5).
///
/// Khai báo được theo hai cách và lưu cả hai dưới dạng `int`:
/// - [SurchargeMode.percent]: `value` là basis point, `8%` → `800`
/// - [SurchargeMode.amount]: `value` là số đồng
class Surcharge {
  const Surcharge({required this.mode, required this.value});

  const Surcharge.none() : mode = SurchargeMode.none, value = 0;

  /// `Surcharge.percent(800)` = 8%.
  const Surcharge.percent(this.value) : mode = SurchargeMode.percent;

  /// `Surcharge.amount(60000)` = 60.000đ.
  const Surcharge.amount(this.value) : mode = SurchargeMode.amount;

  factory Surcharge.fromDb({required String? mode, required int value}) =>
      Surcharge(mode: SurchargeMode.fromDb(mode), value: value);

  final SurchargeMode mode;
  final int value;

  bool get isActive => mode != SurchargeMode.none && value != 0;

  bool get isPercent => mode == SurchargeMode.percent;

  /// Tính ra số tiền của khoản này trên một mức [base] cho trước.
  ///
  /// Phép chia nguyên `~/ 10000` làm tròn xuống, nên tổng tiền luôn là `int`
  /// và không bao giờ sinh số lẻ thập phân (SPEC NFR-6).
  int resolve(int base) => switch (mode) {
    SurchargeMode.none => 0,
    SurchargeMode.percent => (base * value) ~/ 10000,
    SurchargeMode.amount => value,
  };

  Surcharge copyWith({SurchargeMode? mode, int? value}) =>
      Surcharge(mode: mode ?? this.mode, value: value ?? this.value);

  @override
  bool operator ==(Object other) =>
      other is Surcharge && other.mode == mode && other.value == value;

  @override
  int get hashCode => Object.hash(mode, value);

  @override
  String toString() => switch (mode) {
    SurchargeMode.none => 'Surcharge.none',
    SurchargeMode.percent => 'Surcharge.percent(${value / 100}%)',
    SurchargeMode.amount => 'Surcharge.amount($value)',
  };
}
