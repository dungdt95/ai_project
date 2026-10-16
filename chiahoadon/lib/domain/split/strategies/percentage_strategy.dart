import '../rounding.dart';
import '../split_input.dart';
import 'split_strategy.dart';

/// Chia theo tỷ lệ phần trăm (SPEC FR-4.3).
///
/// Tỷ lệ lưu dạng basis point (`33,33%` → `3333`) nên vẫn là số nguyên.
/// `split_validator.dart` đã bảo đảm tổng bằng đúng 10.000 bp trước khi tới đây.
class PercentageStrategy implements SplitStrategy {
  const PercentageStrategy();

  @override
  BaseShares baseShares(SplitInput input) => BaseShares(
    byMember: Rounding.distribute(
      ids: input.participantIds,
      weights: [for (final p in input.participants) p.percentBp],
      total: input.subtotal,
      unit: 1,
    ),
  );
}
