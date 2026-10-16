import 'split_validator.dart';

/// Kết quả chia tiền của một hóa đơn.
///
/// Chứa đủ mọi con số để màn hình chi tiết hiển thị được bảng bóc tách (tạm
/// tính → giảm giá → VAT → phí dịch vụ → làm tròn → tổng) mà không phải tính
/// lại gì (PLAN §5.3, S04).
class SplitResult {
  const SplitResult({
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.serviceAmount,
    required this.tipAmount,
    required this.totalExact,
    required this.total,
    required this.roundingDelta,
    required this.baseShares,
    required this.shares,
    this.itemShares = const {},
    this.errors = const [],
  });

  /// Kết quả rỗng khi đầu vào không hợp lệ.
  ///
  /// Vẫn trả về một [SplitResult] thay vì ném ngoại lệ, để khung xem trước ở
  /// màn hình nhập hóa đơn hiện được danh sách lỗi mà không phải bọc try/catch.
  factory SplitResult.invalid(
    List<SplitError> errors, {
    List<String> memberIds = const [],
  }) => SplitResult(
    subtotal: 0,
    discountAmount: 0,
    taxAmount: 0,
    serviceAmount: 0,
    tipAmount: 0,
    totalExact: 0,
    total: 0,
    roundingDelta: 0,
    baseShares: {for (final id in memberIds) id: 0},
    shares: {for (final id in memberIds) id: 0},
    errors: errors,
  );

  /// Tổng tiền các món, trước giảm giá và phụ phí.
  final int subtotal;

  final int discountAmount;
  final int taxAmount;
  final int serviceAmount;
  final int tipAmount;

  /// Tổng trước khi làm tròn.
  final int totalExact;

  /// Tổng sau làm tròn. **Luôn bằng đúng tổng của [shares]**.
  final int total;

  /// `total - totalExact`. Hiện lên UI để người dùng hiểu vì sao lệch vài trăm
  /// đồng (SPEC FR-5.9).
  final int roundingDelta;

  /// Phần gốc của từng người, trước phụ phí. Tổng bằng [subtotal].
  final Map<String, int> baseShares;

  /// Số tiền cuối cùng từng người phải chịu. Tổng bằng [total].
  final Map<String, int> shares;

  /// Chi tiết theo món: `itemId` → (`memberId` → số tiền). Rỗng nếu không
  /// chia theo món.
  final Map<String, Map<String, int>> itemShares;

  final List<SplitError> errors;

  bool get isValid => errors.isEmpty;

  /// Mức tiền sau giảm giá — gốc để tính VAT và phí dịch vụ.
  int get base => subtotal - discountAmount;

  /// Tổng phụ phí cộng thêm.
  int get surchargeTotal => taxAmount + serviceAmount + tipAmount;

  /// Chênh lệch giữa tổng hóa đơn và tổng tiền món. Âm khi giảm giá lớn hơn
  /// phụ phí.
  int get netAdjustment => total - subtotal;

  int shareOf(String memberId) => shares[memberId] ?? 0;

  int baseShareOf(String memberId) => baseShares[memberId] ?? 0;

  /// Phần phụ phí và giảm giá mà một người phải gánh.
  int surchargeShareOf(String memberId) =>
      shareOf(memberId) - baseShareOf(memberId);

  /// Số tiền một người phải chịu cho một món cụ thể.
  int itemShareOf(String itemId, String memberId) =>
      itemShares[itemId]?[memberId] ?? 0;

  /// Các món mà một người có tham gia.
  List<String> itemIdsOf(String memberId) => [
    for (final entry in itemShares.entries)
      if ((entry.value[memberId] ?? 0) > 0) entry.key,
  ];

  /// Tổng của [shares]. Dùng để kiểm tra bất biến `== total`.
  int get sharesTotal => shares.values.fold(0, (sum, value) => sum + value);

  bool get hasSurcharge =>
      discountAmount != 0 ||
      taxAmount != 0 ||
      serviceAmount != 0 ||
      tipAmount != 0;

  @override
  String toString() => 'SplitResult(total=$total, shares=$shares)';
}
