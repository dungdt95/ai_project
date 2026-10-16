import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/result.dart';
import '../../domain/models/bill.dart';
import '../../domain/models/bill_filter.dart';
import '../../domain/models/bill_item.dart';
import '../../domain/models/bill_participant.dart';
import '../../domain/models/enums.dart';
import '../dao/bill_dao.dart';

/// Nghiệp vụ quản lý hóa đơn (SPEC FR-3).
///
/// Phase 1 chỉ lo lưu trữ và kiểm tra tính nhất quán. Việc tính phần chia sẽ
/// được nối vào ở Phase 2, khi split engine hoàn thành: `save` sẽ gọi
/// `computeSplit` rồi mới ghi, thay vì tin vào số đã có trong [Bill].
class BillRepository {
  const BillRepository(this._billDao);

  static const Uuid _uuid = Uuid();

  final BillDao _billDao;

  static String newId() => _uuid.v4();

  Future<Result<List<Bill>>> getPage(
    BillFilter filter, {
    int limit = AppConstants.billPageSize,
    int offset = 0,
  }) => Result.guard(
    () => _billDao.getPage(filter, limit: limit, offset: offset),
  );

  Future<Result<Bill?>> getById(String id) =>
      Result.guard(() => _billDao.getById(id));

  Future<Result<int>> count(BillFilter filter) =>
      Result.guard(() => _billDao.count(filter));

  Future<Result<List<Bill>>> getDrafts() =>
      Result.guard(_billDao.getDrafts);

  /// Lưu hóa đơn.
  ///
  /// Kiểm tra bất biến `tổng các phần == tổng hóa đơn` **trước khi ghi**. Nếu
  /// để dữ liệu lệch xuống được DB thì mọi thống kê về sau đều sai, và không
  /// có cách nào phát hiện ra (SPEC FR-4).
  Future<Result<Bill>> save(Bill bill) async {
    final error = validate(bill);
    if (error != null) return Err(error);

    return Result.guard(() async {
      await _billDao.save(bill);
      return bill;
    });
  }

  /// Lưu nháp: bỏ qua kiểm tra bất biến vì hóa đơn chưa nhập xong (FR-3.10).
  Future<Result<Bill>> saveDraft(Bill bill) => Result.guard(() async {
    final draft = bill.copyWith(
      status: BillStatus.draft,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _billDao.save(draft);
    return draft;
  });

  Future<Result<void>> softDelete(String id) =>
      Result.guard(() => _billDao.softDelete(id));

  /// Hoàn tác xóa, dùng cho SnackBar 5 giây (SPEC FR-3.14).
  Future<Result<void>> restore(String id) =>
      Result.guard(() => _billDao.restore(id));

  /// Nhân bản hóa đơn sang ngày mới (SPEC FR-3.15).
  ///
  /// Sinh id mới cho hóa đơn và mọi bản ghi con, đặt lại trạng thái thanh toán
  /// về chưa trả — bản sao là một khoản chi mới, không kế thừa việc ai đã trả.
  Future<Result<Bill>> duplicate(String sourceId, {DateTime? newDate}) async {
    final source = await _billDao.getById(sourceId);
    if (source == null) {
      return const Err(AppError.notFound('Không tìm thấy hóa đơn để nhân bản.'));
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final date = newDate ?? DateTime.now();

    final copy = Bill(
      id: _uuid.v4(),
      title: source.title,
      note: source.note,
      billDate: DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
      categoryId: source.categoryId,
      groupId: source.groupId,
      splitType: source.splitType,
      inputMode: source.inputMode,
      subtotal: source.subtotal,
      discount: source.discount,
      discountAmount: source.discountAmount,
      tax: source.tax,
      taxAmount: source.taxAmount,
      service: source.service,
      serviceAmount: source.serviceAmount,
      tipAmount: source.tipAmount,
      surchargeAlloc: source.surchargeAlloc,
      roundingUnit: source.roundingUnit,
      roundingMode: source.roundingMode,
      totalExact: source.totalExact,
      totalAmount: source.totalAmount,
      roundingDelta: source.roundingDelta,
      status: BillStatus.unpaid,
      createdAt: now,
      updatedAt: now,
      payers: source.payers,
      participants: [
        for (final p in source.participants)
          BillParticipant(
            id: _uuid.v4(),
            memberId: p.memberId,
            memberNameSnapshot: p.memberNameSnapshot,
            sortOrder: p.sortOrder,
            weightNum: p.weightNum,
            weightDen: p.weightDen,
            percentBp: p.percentBp,
            exactAmount: p.exactAmount,
            baseShare: p.baseShare,
            shareAmount: p.shareAmount,
          ),
      ],
      items: _duplicateItems(source.items),
    );

    return save(copy);
  }

  /// Ghi nhận một người đã trả bao nhiêu (SPEC FR-6.1).
  Future<Result<void>> setParticipantPaid({
    required String billId,
    required String memberId,
    required int paidAmount,
    required int shareAmount,
  }) => Result.guard(
    () => _billDao.updateParticipantPayment(
      billId: billId,
      memberId: memberId,
      paidAmount: paidAmount,
      isSettled: paidAmount >= shareAmount,
    ),
  );

  Future<Result<void>> settleAll(String billId) =>
      Result.guard(() => _billDao.settleAll(billId));

  Future<Result<void>> updateStatus(String billId, BillStatus status) =>
      Result.guard(() => _billDao.updateStatus(billId, status));

  /// Kiểm tra hóa đơn đã sẵn sàng để lưu chính thức hay chưa.
  ///
  /// Trả `null` nếu hợp lệ. Nháp không đi qua hàm này.
  static AppError? validate(Bill bill) {
    if (bill.title.trim().isEmpty) {
      return const AppError.validation('Hóa đơn cần có tên.');
    }
    if (bill.participants.isEmpty) {
      return const AppError.validation(
        'Hóa đơn cần có ít nhất một người tham gia.',
      );
    }
    if (bill.totalAmount <= 0) {
      return const AppError.validation('Tổng tiền phải lớn hơn 0.');
    }

    // Bất biến cốt lõi của app (SPEC FR-4, FR-5).
    if (bill.totalShares != bill.totalAmount) {
      return AppError.validation(
        'Tổng các phần (${bill.totalShares}đ) không khớp tổng hóa đơn '
        '(${bill.totalAmount}đ). Đây là lỗi tính toán, không phải lỗi nhập liệu.',
      );
    }

    // Tổng tiền ứng trước phải bằng tổng hóa đơn (SPEC FR-3.4).
    if (bill.payers.isNotEmpty &&
        bill.totalPaidByPayers != bill.totalAmount) {
      return AppError.validation(
        'Tổng tiền ứng trước (${bill.totalPaidByPayers}đ) không bằng tổng '
        'hóa đơn (${bill.totalAmount}đ).',
      );
    }

    return null;
  }

  static List<BillItem> _duplicateItems(List<BillItem> items) => [
    for (final item in items)
      BillItem(
        id: _uuid.v4(),
        name: item.name,
        unitPrice: item.unitPrice,
        quantity: item.quantity,
        sortOrder: item.sortOrder,
        participants: item.participants,
      ),
  ];
}
