/// Tên bảng và cột trong SQLite.
///
/// Dùng hằng số thay vì chuỗi rời rạc để đổi tên cột không bị sót chỗ nào,
/// và để trình phân tích bắt được lỗi đánh máy ngay lúc biên dịch.
class Tables {
  const Tables._();

  static const String members = 'members';
  static const String memberGroups = 'member_groups';
  static const String groupMembers = 'group_members';
  static const String categories = 'categories';
  static const String bills = 'bills';
  static const String billPayers = 'bill_payers';
  static const String billParticipants = 'bill_participants';
  static const String billItems = 'bill_items';
  static const String billItemParticipants = 'bill_item_participants';
  static const String payments = 'payments';
  static const String billTemplates = 'bill_templates';
  static const String itemPresets = 'item_presets';
  static const String appSettings = 'app_settings';

  /// Thứ tự xóa an toàn khi reset dữ liệu (con trước, cha sau).
  static const List<String> deletionOrder = [
    billItemParticipants,
    billItems,
    billParticipants,
    billPayers,
    payments,
    bills,
    groupMembers,
    memberGroups,
    billTemplates,
    itemPresets,
    members,
    categories,
  ];
}

/// Cột dùng chung ở nhiều bảng.
class Cols {
  const Cols._();

  static const String id = 'id';
  static const String name = 'name';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String deletedAt = 'deleted_at';
  static const String sortOrder = 'sort_order';
  static const String memberId = 'member_id';
  static const String billId = 'bill_id';
  static const String groupId = 'group_id';
  static const String itemId = 'item_id';
  static const String amount = 'amount';
}
