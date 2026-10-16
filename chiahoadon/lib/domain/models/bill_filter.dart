import '../../core/utils/date_formatter.dart';
import 'enums.dart';

/// Điều kiện lọc danh sách hóa đơn (SPEC FR-3.12).
///
/// Bất biến để dùng được làm state của Riverpod và làm khóa cache.
class BillFilter {
  const BillFilter({
    this.query = '',
    this.range,
    this.groupId,
    this.categoryId,
    this.memberId,
    this.statuses = const {},
    this.includeDrafts = true,
  });

  /// Từ khóa tìm theo tên hóa đơn, đã bỏ dấu.
  final String query;

  /// Khoảng ngày; `null` nghĩa là không giới hạn thời gian.
  final DateRange? range;

  final String? groupId;
  final String? categoryId;

  /// Chỉ lấy hóa đơn có thành viên này tham gia.
  final String? memberId;

  /// Rỗng nghĩa là mọi trạng thái.
  final Set<BillStatus> statuses;

  /// Nháp có hiện trong danh sách hay không. Thống kê luôn loại nháp.
  final bool includeDrafts;

  bool get isEmpty =>
      query.isEmpty &&
      range == null &&
      groupId == null &&
      categoryId == null &&
      memberId == null &&
      statuses.isEmpty;

  /// Số điều kiện đang bật, để hiện badge trên nút lọc.
  int get activeCount => [
    query.isNotEmpty,
    range != null,
    groupId != null,
    categoryId != null,
    memberId != null,
    statuses.isNotEmpty,
  ].where((active) => active).length;

  BillFilter copyWith({
    String? query,
    DateRange? range,
    String? groupId,
    String? categoryId,
    String? memberId,
    Set<BillStatus>? statuses,
    bool? includeDrafts,
    bool clearRange = false,
    bool clearGroup = false,
    bool clearCategory = false,
    bool clearMember = false,
  }) => BillFilter(
    query: query ?? this.query,
    range: clearRange ? null : (range ?? this.range),
    groupId: clearGroup ? null : (groupId ?? this.groupId),
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    memberId: clearMember ? null : (memberId ?? this.memberId),
    statuses: statuses ?? this.statuses,
    includeDrafts: includeDrafts ?? this.includeDrafts,
  );

  BillFilter cleared() => const BillFilter();

  @override
  bool operator ==(Object other) =>
      other is BillFilter &&
      other.query == query &&
      other.range == range &&
      other.groupId == groupId &&
      other.categoryId == categoryId &&
      other.memberId == memberId &&
      other.includeDrafts == includeDrafts &&
      other.statuses.length == statuses.length &&
      other.statuses.containsAll(statuses);

  @override
  int get hashCode => Object.hash(
    query,
    range,
    groupId,
    categoryId,
    memberId,
    includeDrafts,
    Object.hashAllUnordered(statuses),
  );
}
