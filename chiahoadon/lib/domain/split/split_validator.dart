import '../models/enums.dart';
import 'split_input.dart';

/// Mã lỗi của split engine.
///
/// UI dựa vào mã để biết hiện lỗi ở ô nhập nào; test dựa vào mã thay vì so
/// chuỗi tiếng Việt, nên sửa lại câu thông báo không làm vỡ test.
enum SplitErrorCode {
  /// Hóa đơn chưa có người tham gia.
  noParticipants,

  /// Cùng một người xuất hiện hai lần.
  duplicateParticipant,

  /// Quá số người cho phép.
  tooManyParticipants,

  /// Số tiền vượt ngưỡng hợp lý — gần như luôn là lỗi gõ máy.
  amountTooLarge,

  /// Tổng phần trăm khác 100%.
  percentageNotHundred,

  /// Tổng số tiền chỉ định khác tổng hóa đơn.
  exactMismatch,

  /// Mọi người đều có 0 phần, không biết chia theo tỷ lệ nào.
  zeroWeightTotal,

  /// Số phần âm hoặc mẫu số bằng 0.
  invalidWeight,

  /// Chia theo món nhưng hóa đơn không ở chế độ nhập theo món.
  itemizedNeedsItems,

  /// Món có người dùng không nằm trong danh sách người tham gia hóa đơn.
  itemUserNotParticipant,

  /// Món có cùng một người được chọn hai lần.
  duplicateItemUser,

  /// Món có số tiền âm.
  negativeItemAmount,
}

/// Một lỗi của đầu vào, kèm thông điệp tiếng Việt hiển thị được ngay.
class SplitError {
  const SplitError(this.code, this.message, {this.memberId, this.itemId});

  final SplitErrorCode code;

  /// Thông điệp đã sẵn sàng hiện lên UI.
  final String message;

  /// Người liên quan, để UI tô đỏ đúng dòng.
  final String? memberId;

  /// Món liên quan.
  final String? itemId;

  @override
  String toString() => '${code.name}: $message';
}

/// Kiểm tra đầu vào trước khi tính (SPEC FR-4).
///
/// Chỉ báo lỗi về **cấu trúc** — những trường hợp không thể chia tiền một cách
/// có nghĩa. Tổng tiền bằng 0 **không** phải lỗi: trong lúc người dùng còn
/// đang gõ, khung xem trước cần hiện 0 chứ không nên nhảy thông báo đỏ.
/// Việc chặn lưu hóa đơn có tổng 0 là của `BillRepository.validate`.
class SplitValidator {
  const SplitValidator._();

  static List<SplitError> validate(SplitInput input) {
    final errors = <SplitError>[];

    _validateParticipants(input, errors);
    _validateAmounts(input, errors);

    switch (input.splitType) {
      case SplitType.equal:
        break;
      case SplitType.percentage:
        _validatePercentage(input, errors);
      case SplitType.shares:
        _validateShares(input, errors);
      case SplitType.exact:
        _validateExact(input, errors);
      case SplitType.itemized:
        _validateItemized(input, errors);
    }

    return errors;
  }

  static void _validateParticipants(
    SplitInput input,
    List<SplitError> errors,
  ) {
    if (input.participants.isEmpty) {
      errors.add(
        const SplitError(
          SplitErrorCode.noParticipants,
          'Hóa đơn cần có ít nhất một người tham gia.',
        ),
      );
      return;
    }

    if (input.participantCount > SplitLimits.maxParticipants) {
      errors.add(
        const SplitError(
          SplitErrorCode.tooManyParticipants,
          'Một hóa đơn chỉ hỗ trợ tối đa '
          '${SplitLimits.maxParticipants} người.',
        ),
      );
    }

    final seen = <String>{};
    for (final participant in input.participants) {
      if (!seen.add(participant.memberId)) {
        errors.add(
          SplitError(
            SplitErrorCode.duplicateParticipant,
            'Một người được thêm hai lần vào hóa đơn.',
            memberId: participant.memberId,
          ),
        );
      }
    }
  }

  static void _validateAmounts(SplitInput input, List<SplitError> errors) {
    if (input.subtotal > SplitLimits.maxAmount) {
      errors.add(
        const SplitError(
          SplitErrorCode.amountTooLarge,
          'Số tiền quá lớn. Kiểm tra lại xem có gõ thừa số 0 không.',
        ),
      );
    }

    for (final item in input.items) {
      if (item.unitPrice < 0) {
        errors.add(
          SplitError(
            SplitErrorCode.negativeItemAmount,
            'Món có đơn giá âm.',
            itemId: item.id,
          ),
        );
      }
    }
  }

  static void _validatePercentage(SplitInput input, List<SplitError> errors) {
    final total = input.participants.fold<int>(
      0,
      (sum, p) => sum + p.percentBp,
    );

    if (total != 10000) {
      final percent = (total / 100).toStringAsFixed(2).replaceAll('.', ',');
      final missing = ((10000 - total) / 100)
          .abs()
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      errors.add(
        SplitError(
          SplitErrorCode.percentageNotHundred,
          total < 10000
              ? 'Tổng phần trăm đang là $percent%, còn thiếu $missing%.'
              : 'Tổng phần trăm đang là $percent%, vượt $missing%.',
        ),
      );
    }
  }

  static void _validateShares(SplitInput input, List<SplitError> errors) {
    var totalWeight = 0;

    for (final participant in input.participants) {
      if (participant.weightDen <= 0 || participant.weightNum < 0) {
        errors.add(
          SplitError(
            SplitErrorCode.invalidWeight,
            'Số phần không hợp lệ.',
            memberId: participant.memberId,
          ),
        );
        continue;
      }
      totalWeight += participant.weightNum;
    }

    if (totalWeight <= 0) {
      errors.add(
        const SplitError(
          SplitErrorCode.zeroWeightTotal,
          'Cần có ít nhất một người được tính số phần lớn hơn 0.',
        ),
      );
    }
  }

  static void _validateExact(SplitInput input, List<SplitError> errors) {
    final total = input.participants.fold<int>(
      0,
      (sum, p) => sum + p.exactAmount,
    );

    if (total != input.subtotal) {
      final diff = input.subtotal - total;
      errors.add(
        SplitError(
          SplitErrorCode.exactMismatch,
          diff > 0
              ? 'Còn $diff đồng chưa được phân bổ.'
              : 'Đã phân bổ vượt ${-diff} đồng.',
        ),
      );
    }
  }

  static void _validateItemized(SplitInput input, List<SplitError> errors) {
    if (input.inputMode != InputMode.items) {
      errors.add(
        const SplitError(
          SplitErrorCode.itemizedNeedsItems,
          'Chia theo món cần nhập danh sách món, không phải tổng tiền.',
        ),
      );
    }

    final participantIds = input.participantIds.toSet();

    for (final item in input.items) {
      final seen = <String>{};

      for (final user in item.users) {
        if (!seen.add(user.memberId)) {
          errors.add(
            SplitError(
              SplitErrorCode.duplicateItemUser,
              'Một người được chọn hai lần trong cùng một món.',
              memberId: user.memberId,
              itemId: item.id,
            ),
          );
        }

        if (!participantIds.contains(user.memberId)) {
          errors.add(
            SplitError(
              SplitErrorCode.itemUserNotParticipant,
              'Món có người không nằm trong danh sách người tham gia hóa đơn.',
              memberId: user.memberId,
              itemId: item.id,
            ),
          );
        }

        if (user.weightDen <= 0 || user.weightNum < 0) {
          errors.add(
            SplitError(
              SplitErrorCode.invalidWeight,
              'Trọng số trong món không hợp lệ.',
              memberId: user.memberId,
              itemId: item.id,
            ),
          );
        }
      }
    }
  }
}
