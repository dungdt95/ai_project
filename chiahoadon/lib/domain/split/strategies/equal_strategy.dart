import '../rounding.dart';
import '../split_input.dart';
import 'split_strategy.dart';

/// Chia đều cho mọi người tham gia (SPEC FR-4.1).
///
/// Phần dư không chia hết được phát thêm cho những người đầu danh sách, nên
/// `1.000.000 / 3` ra `333.334 + 333.333 + 333.333` chứ không mất một đồng nào.
class EqualStrategy implements SplitStrategy {
  const EqualStrategy();

  @override
  BaseShares baseShares(SplitInput input) {
    final ids = input.participantIds;

    return BaseShares(
      byMember: Rounding.distribute(
        ids: ids,
        weights: List.filled(ids.length, 1),
        total: input.subtotal,
        unit: 1,
      ),
    );
  }
}
