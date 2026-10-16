import '../rounding.dart';
import '../split_input.dart';
import 'split_strategy.dart';

/// Chia theo số phần (SPEC FR-4.4).
///
/// Dùng cho tiền nhà (phòng đôi tính 2 phần) hoặc "người ăn ít tính 0,5 phần".
/// Trọng số lưu dạng phân số `num/den`; ở đây chúng được quy về cùng mẫu số
/// chung để phép chia vẫn hoàn toàn trên số nguyên (SPEC NFR-6).
class SharesStrategy implements SplitStrategy {
  const SharesStrategy();

  @override
  BaseShares baseShares(SplitInput input) {
    final denominators = [
      for (final p in input.participants)
        if (p.weightDen > 0) p.weightDen,
    ];
    final common = Rounding.lcm(denominators);

    return BaseShares(
      byMember: Rounding.distribute(
        ids: input.participantIds,
        weights: [
          for (final p in input.participants)
            if (p.weightDen > 0 && p.weightNum > 0)
              p.weightNum * (common ~/ p.weightDen)
            else
              0,
        ],
        total: input.subtotal,
        unit: 1,
      ),
    );
  }
}
