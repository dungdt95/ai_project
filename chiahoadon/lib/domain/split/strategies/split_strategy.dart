import '../../models/enums.dart';
import '../split_input.dart';
import 'equal_strategy.dart';
import 'exact_strategy.dart';
import 'itemized_strategy.dart';
import 'percentage_strategy.dart';
import 'shares_strategy.dart';

/// Phần gốc của từng người, trước khi phân bổ phụ phí và giảm giá.
class BaseShares {
  const BaseShares({required this.byMember, this.byItem = const {}});

  /// Phần gốc của từng người. Tổng luôn bằng đúng `subtotal`.
  final Map<String, int> byMember;

  /// Chi tiết theo món: `itemId` → (`memberId` → số tiền).
  ///
  /// Chỉ kiểu chia theo món sinh ra dữ liệu này; dùng cho mục "Chi tiết theo
  /// món" ở màn hình hóa đơn (PLAN §5.3, S04).
  final Map<String, Map<String, int>> byItem;

  int get total => byMember.values.fold(0, (sum, value) => sum + value);
}

/// Cách tính phần gốc của từng người, theo từng kiểu chia (SPEC FR-4).
///
/// Mỗi chiến lược chỉ phân bổ `subtotal`. Phụ phí, giảm giá và làm tròn do
/// `split_engine.dart` lo, nên thêm kiểu chia mới không phải sửa lại phần đó.
abstract interface class SplitStrategy {
  /// Chiến lược ứng với [type].
  static SplitStrategy of(SplitType type) => switch (type) {
    SplitType.equal => const EqualStrategy(),
    SplitType.itemized => const ItemizedStrategy(),
    SplitType.percentage => const PercentageStrategy(),
    SplitType.shares => const SharesStrategy(),
    SplitType.exact => const ExactStrategy(),
  };

  /// Phân bổ `input.subtotal` cho từng người tham gia.
  ///
  /// Hậu điều kiện: `kết quả.total == input.subtotal`.
  BaseShares baseShares(SplitInput input);
}
