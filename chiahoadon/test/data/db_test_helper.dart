import 'package:chiahoadon/core/utils/avatar_color.dart';
import 'package:chiahoadon/core/utils/vn_text.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/bill.dart';
import 'package:chiahoadon/domain/models/bill_item.dart';
import 'package:chiahoadon/domain/models/bill_participant.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/domain/models/member_group.dart';
import 'package:chiahoadon/domain/models/payment.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

/// Tiện ích dựng DB trong bộ nhớ cho test.
///
/// Dùng `sqflite_common_ffi` nên test chạy trực tiếp trên máy tính, không cần
/// emulator — nhờ vậy toàn bộ bộ test chạy trong vài giây (PLAN §7, Phase 1).
class DbTestHelper {
  const DbTestHelper._();

  static const Uuid uuid = Uuid();

  /// Gọi một lần trong `setUpAll` của mỗi tệp test có dùng DB.
  static void initFfi() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  static Future<AppDatabase> openDb() => AppDatabase.openInMemory();

  /// Thành viên mẫu, đã điền sẵn các trường bắt buộc.
  static Member member(String name, {bool isSelf = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Member(
      id: uuid.v4(),
      name: name,
      nameNorm: VnText.normalize(name),
      avatarColor: AvatarColor.toStored(name),
      isSelf: isSelf,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Nhóm mẫu, kèm danh sách thành viên.
  static MemberGroup group(String name, {List<Member> members = const []}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MemberGroup(
      id: uuid.v4(),
      name: name,
      color: AvatarColor.toStored(name),
      createdAt: now,
      updatedAt: now,
      memberIds: [for (final member in members) member.id],
    );
  }

  /// Hóa đơn chia đều, đã tính sẵn phần của từng người sao cho tổng khớp.
  ///
  /// Dùng phép chia nguyên cộng phần dư dồn cho người đầu: đủ để test tầng dữ
  /// liệu. Thuật toán thật (Largest Remainder) thuộc Phase 2.
  static Bill equalBill({
    required String title,
    required int total,
    required List<Member> participants,
    required Member payer,
    DateTime? date,
    BillStatus status = BillStatus.unpaid,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final day = date ?? DateTime.now();
    final count = participants.length;
    final baseShare = total ~/ count;
    final remainder = total - baseShare * count;

    return Bill(
      id: uuid.v4(),
      title: title,
      billDate: DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
      splitType: SplitType.equal,
      inputMode: InputMode.total,
      subtotal: total,
      totalExact: total,
      totalAmount: total,
      roundingUnit: 1,
      roundingMode: RoundingMode.none,
      status: status,
      createdAt: now,
      updatedAt: now,
      payers: [BillPayer(memberId: payer.id, paidAmount: total)],
      participants: [
        for (var i = 0; i < count; i++)
          BillParticipant(
            id: uuid.v4(),
            memberId: participants[i].id,
            memberNameSnapshot: participants[i].name,
            sortOrder: i,
            baseShare: baseShare + (i == 0 ? remainder : 0),
            shareAmount: baseShare + (i == 0 ? remainder : 0),
          ),
      ],
    );
  }

  /// Một lần chuyển tiền đã ghi nhận.
  static Payment payment({
    required Member from,
    required Member to,
    required int amount,
    int? at,
  }) {
    final now = at ?? DateTime.now().millisecondsSinceEpoch;
    return Payment(
      id: uuid.v4(),
      fromMemberId: from.id,
      toMemberId: to.id,
      amount: amount,
      paidAt: now,
      createdAt: now,
    );
  }

  /// Món mẫu kèm danh sách người dùng món đó.
  /// Món mẫu. [unitPrice] là giá **một người**; thành tiền là giá × số người.
  static BillItem item({
    required String name,
    required int unitPrice,
    int sortOrder = 0,
    List<Member> users = const [],
  }) => BillItem(
    id: uuid.v4(),
    name: name,
    unitPrice: unitPrice,
    sortOrder: sortOrder,
    participants: [
      for (final user in users) ItemParticipant(memberId: user.id),
    ],
  );
}
