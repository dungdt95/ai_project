import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/result.dart';
import '../../core/utils/vn_text.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/bill_repository.dart';
import '../../domain/models/bill.dart';
import '../../domain/models/bill_filter.dart';
import '../../domain/models/enums.dart';

/// Điều kiện lọc đang áp dụng cho danh sách hóa đơn (SPEC FR-3.12).
class BillFilterNotifier extends Notifier<BillFilter> {
  @override
  BillFilter build() => const BillFilter();

  /// Từ khóa được bỏ dấu trước khi lưu, để khớp với cách `BillDao` so sánh.
  void setQuery(String value) =>
      state = state.copyWith(query: VnText.normalize(value));

  void setRange(DateRangeFilter value) => state = value.apply(state);

  void setCategory(String? id) =>
      state = state.copyWith(categoryId: id, clearCategory: id == null);

  void setGroup(String? id) =>
      state = state.copyWith(groupId: id, clearGroup: id == null);

  void setMember(String? id) =>
      state = state.copyWith(memberId: id, clearMember: id == null);

  void toggleStatus(BillStatus value) {
    final next = {...state.statuses};
    if (!next.remove(value)) next.add(value);
    state = state.copyWith(statuses: next);
  }

  void clear() => state = const BillFilter();
}

final billFilterProvider =
    NotifierProvider<BillFilterNotifier, BillFilter>(BillFilterNotifier.new);

/// Một trang danh sách hóa đơn, tải thêm khi cuộn tới cuối (NFR-3).
class BillListState {
  const BillListState({
    required this.bills,
    required this.total,
    this.loadingMore = false,
  });

  static const BillListState empty = BillListState(bills: [], total: 0);

  final List<Bill> bills;

  /// Tổng số hóa đơn khớp bộ lọc, kể cả phần chưa tải.
  final int total;

  final bool loadingMore;

  bool get hasMore => bills.length < total;

  BillListState copyWith({
    List<Bill>? bills,
    int? total,
    bool? loadingMore,
  }) => BillListState(
    bills: bills ?? this.bills,
    total: total ?? this.total,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Danh sách hóa đơn theo bộ lọc hiện tại.
class BillListNotifier extends AsyncNotifier<BillListState> {
  @override
  Future<BillListState> build() async {
    // Đổi bộ lọc là nạp lại từ trang đầu.
    final filter = ref.watch(billFilterProvider);
    final repository = ref.watch(billRepositoryProvider);

    final page = await repository.getPage(filter);
    final count = await repository.count(filter);

    return BillListState(
      bills: page.when(ok: (bills) => bills, err: (error) => throw error),
      total: count.valueOr(0),
    );
  }

  /// Tải thêm một trang khi người dùng cuộn tới cuối danh sách.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));

    final result = await ref
        .read(billRepositoryProvider)
        .getPage(
          ref.read(billFilterProvider),
          offset: current.bills.length,
          limit: AppConstants.billPageSize,
        );

    state = AsyncData(
      result.when(
        ok: (more) => current.copyWith(
          bills: [...current.bills, ...more],
          loadingMore: false,
        ),
        err: (_) => current.copyWith(loadingMore: false),
      ),
    );
  }

  BillRepository get _repository => ref.read(billRepositoryProvider);

  Future<Result<Bill>> save(Bill bill) async {
    final result = await _repository.save(bill);
    if (result.isOk) _reload(bill.id);
    return result;
  }

  Future<Result<Bill>> saveDraft(Bill bill) async {
    final result = await _repository.saveDraft(bill);
    if (result.isOk) _reload(bill.id);
    return result;
  }

  /// Xóa mềm; `restore` đưa lại được trong 5 giây (SPEC FR-3.14).
  Future<Result<void>> delete(String id) async {
    final result = await _repository.softDelete(id);
    if (result.isOk) _reload(id);
    return result;
  }

  Future<Result<void>> restore(String id) async {
    final result = await _repository.restore(id);
    if (result.isOk) _reload(id);
    return result;
  }

  /// Nhân bản sang ngày mới (SPEC FR-3.15).
  Future<Result<Bill>> duplicate(String id, {DateTime? date}) async {
    final result = await _repository.duplicate(id, newDate: date);
    if (result.isOk) _reload(id);
    return result;
  }

  void _reload(String billId) {
    ref.invalidate(billDetailProvider(billId));
    ref.invalidateSelf();
  }
}

final billListProvider =
    AsyncNotifierProvider<BillListNotifier, BillListState>(
      BillListNotifier.new,
    );

/// Ghi nhận ai đã trả trong một hóa đơn (SPEC FR-6.1, FR-6.3).
///
/// Tách khỏi [BillListNotifier] vì đây là thao tác trên một hóa đơn đang mở,
/// không liên quan tới danh sách đang lọc. Nhưng vẫn hủy cả hai provider sau
/// khi ghi, vì trạng thái thanh toán hiện cả ở danh sách lẫn ở quyết toán.
class BillPaymentNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<Result<void>> setPaid({
    required String billId,
    required String memberId,
    required int paidAmount,
    required int shareAmount,
  }) async {
    final result = await ref
        .read(billRepositoryProvider)
        .setParticipantPaid(
          billId: billId,
          memberId: memberId,
          paidAmount: paidAmount,
          shareAmount: shareAmount,
        );
    if (result.isOk) _reload(billId);
    return result;
  }

  Future<Result<void>> settleAll(String billId) async {
    final result = await ref.read(billRepositoryProvider).settleAll(billId);
    if (result.isOk) _reload(billId);
    return result;
  }

  void _reload(String billId) {
    ref.invalidate(billDetailProvider(billId));
    ref.invalidate(billListProvider);
  }
}

final billPaymentProvider =
    NotifierProvider<BillPaymentNotifier, void>(BillPaymentNotifier.new);

/// Một hóa đơn kèm đầy đủ người tham gia, người ứng tiền và món.
final billDetailProvider = FutureProvider.family<Bill?, String>((
  ref,
  billId,
) async {
  final result = await ref.watch(billRepositoryProvider).getById(billId);
  return result.when(ok: (bill) => bill, err: (error) => throw error);
});

/// Các khoảng thời gian lọc nhanh (SPEC FR-3.12).
enum DateRangeFilter {
  all('Tất cả'),
  thisMonth('Tháng này'),
  lastMonth('Tháng trước'),
  last3Months('3 tháng'),
  thisYear('Năm nay');

  const DateRangeFilter(this.label);

  final String label;

  BillFilter apply(BillFilter filter) => switch (this) {
    DateRangeFilter.all => filter.copyWith(clearRange: true),
    DateRangeFilter.thisMonth => filter.copyWith(range: DateRange.thisMonth()),
    DateRangeFilter.lastMonth => filter.copyWith(range: DateRange.lastMonth()),
    DateRangeFilter.last3Months => filter.copyWith(
      range: DateRange.last3Months(),
    ),
    DateRangeFilter.thisYear => filter.copyWith(range: DateRange.thisYear()),
  };
}
