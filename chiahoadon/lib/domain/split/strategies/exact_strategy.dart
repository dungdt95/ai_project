import '../split_input.dart';
import 'split_strategy.dart';

/// Chia theo số tiền chỉ định cho từng người (SPEC FR-4.5).
///
/// Số tiền người dùng nhập là phần gốc, tức phần ứng với `subtotal`. Phụ phí,
/// giảm giá và làm tròn vẫn áp lên trên như mọi kiểu chia khác, nên khi hóa đơn
/// không có phụ phí thì số tiền hiện ra đúng bằng số đã nhập.
///
/// `split_validator.dart` đã bảo đảm tổng số tiền nhập bằng `subtotal`.
class ExactStrategy implements SplitStrategy {
  const ExactStrategy();

  @override
  BaseShares baseShares(SplitInput input) => BaseShares(
    byMember: {
      for (final p in input.participants) p.memberId: p.exactAmount,
    },
  );
}
