import '../models/enums.dart';

/// Quyết định trọng số dùng để phân bổ tổng hóa đơn cho từng người, sau khi
/// phần gốc đã được tính (SPEC FR-5.5, FR-5.6).
class SurchargeAllocator {
  const SurchargeAllocator(this.mode);

  final SurchargeAlloc mode;

  /// Trọng số phân bổ của từng người.
  ///
  /// - [SurchargeAlloc.proportional]: trọng số chính là phần gốc, nên VAT, phí
  ///   dịch vụ và giảm giá tự động chia theo tỷ lệ ai ăn nhiều chịu nhiều. Đây
  ///   là bản chất của VAT nên là mặc định.
  ///
  /// - [SurchargeAlloc.equal]: phần gốc vẫn theo tỷ lệ, nhưng khoản chênh
  ///   `netAdjustment` (phụ phí trừ giảm giá) chia đều đầu người. Phù hợp phí
  ///   ship hay phí thuê phòng — những khoản không liên quan tới ai ăn gì.
  ///
  ///   Quy về một bộ trọng số duy nhất bằng cách nhân phần gốc lên `n` lần rồi
  ///   cộng khoản chênh: `w_i = baseShare_i × n + netAdjustment`. Khi đó
  ///   `Σw / n = subtotal + netAdjustment = totalExact`, nên tỷ lệ `w_i / Σw`
  ///   đúng bằng tỷ lệ mong muốn, và cả hai chế độ dùng chung một đường tính.
  ///
  /// Giảm giá lớn có thể đẩy trọng số xuống âm — khi đó phần của người đó bị
  /// kẹp về 0, vì không ai được *nhận* tiền từ một hóa đơn.
  List<int> weightsFor({
    required List<int> baseShares,
    required int netAdjustment,
  }) {
    if (mode == SurchargeAlloc.proportional) return baseShares;

    final count = baseShares.length;
    if (count == 0) return const [];

    return [
      for (final share in baseShares)
        if (share * count + netAdjustment > 0) share * count + netAdjustment
        else 0,
    ];
  }
}
