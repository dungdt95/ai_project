import 'rounding.dart';
import 'split_input.dart';
import 'split_result.dart';
import 'split_validator.dart';
import 'strategies/split_strategy.dart';
import 'surcharge_allocator.dart';

/// Chia tiền một hóa đơn.
///
/// Hàm **thuần**: không I/O, không trạng thái, không phụ thuộc Flutter hay cơ
/// sở dữ liệu. Nhờ vậy khung xem trước ở màn hình nhập hóa đơn gọi lại được
/// sau mỗi ký tự người dùng gõ, trong cùng một frame (NFR-4).
///
/// Thứ tự tính toán cố định theo SPEC §FR-5 — đổi thứ tự là ra số khác:
///
/// ```
/// 1. subtotal      = tổng tiền món, hoặc tổng nhập tay
/// 2. discount      = subtotal × %giảm, hoặc số tiền giảm
/// 3. base          = subtotal − discount
/// 4. tax           = base × %VAT              ← tính SAU giảm giá
/// 5. service       = base × %phí dịch vụ      ← tính SAU giảm giá
/// 6. totalExact    = base + tax + service + tip
/// 7. total         = làm tròn(totalExact)
/// 8. baseShares    = phân bổ subtotal theo kiểu chia
/// 9. weights       = trọng số phân bổ, tùy cách phân bổ phụ phí
/// 10. shares       = phân bổ total theo weights (Largest Remainder)
/// ```
///
/// Bất biến được bảo đảm: `tổng shares == total`, tuyệt đối, mọi trường hợp.
SplitResult computeSplit(SplitInput input) {
  final errors = SplitValidator.validate(input);
  if (errors.isNotEmpty) {
    return SplitResult.invalid(errors, memberIds: input.participantIds);
  }

  // Bước 1–6: các mốc tiền của cả hóa đơn.
  final subtotal = input.subtotal;

  // Giảm giá không vượt quá tiền món — hóa đơn không thể âm.
  final rawDiscount = input.discount.resolve(subtotal);
  final discountAmount = rawDiscount.clamp(0, subtotal);

  final base = subtotal - discountAmount;
  final taxAmount = input.tax.resolve(base);
  final serviceAmount = input.service.resolve(base);
  final tipAmount = input.tip < 0 ? 0 : input.tip;

  final totalExact = base + taxAmount + serviceAmount + tipAmount;

  // Bước 7: làm tròn TỔNG trước, để mọi phần đều là bội của đơn vị làm tròn.
  final unit = Rounding.effectiveUnit(input.roundingUnit, input.roundingMode);
  final total = Rounding.roundTotal(totalExact, unit, input.roundingMode);

  // Bước 8: phần gốc theo kiểu chia. Tổng phần gốc luôn bằng subtotal.
  final baseShares = SplitStrategy.of(input.splitType).baseShares(input);

  final ids = input.participantIds;
  final baseList = [for (final id in ids) baseShares.byMember[id] ?? 0];

  // Bước 9–10: phân bổ tổng đã làm tròn.
  final weights = SurchargeAllocator(input.surchargeAlloc).weightsFor(
    baseShares: baseList,
    netAdjustment: totalExact - subtotal,
  );
  final shares = Rounding.distribute(
    ids: ids,
    weights: weights,
    total: total,
    unit: unit,
  );

  assert(
    shares.values.fold<int>(0, (sum, value) => sum + value) == total,
    'BẤT BIẾN BỊ VI PHẠM: tổng các phần '
    '(${shares.values.fold<int>(0, (s, v) => s + v)}) != tổng hóa đơn ($total)',
  );
  assert(
    baseShares.total == subtotal,
    'Tổng phần gốc (${baseShares.total}) != subtotal ($subtotal)',
  );

  return SplitResult(
    subtotal: subtotal,
    discountAmount: discountAmount,
    taxAmount: taxAmount,
    serviceAmount: serviceAmount,
    tipAmount: tipAmount,
    totalExact: totalExact,
    total: total,
    roundingDelta: total - totalExact,
    baseShares: {for (final id in ids) id: baseShares.byMember[id] ?? 0},
    shares: shares,
    itemShares: baseShares.byItem,
  );
}
