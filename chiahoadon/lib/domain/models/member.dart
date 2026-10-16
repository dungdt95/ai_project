/// Một thành viên có thể tham gia hóa đơn (SPEC FR-1).
///
/// Bất biến. Mọi thay đổi đi qua [copyWith] để state của Riverpod luôn so sánh
/// được bằng tham chiếu.
class Member {
  const Member({
    required this.id,
    required this.name,
    required this.nameNorm,
    required this.avatarColor,
    required this.createdAt,
    required this.updatedAt,
    this.nickname,
    this.phone,
    this.bankName,
    this.bankBin,
    this.bankAccount,
    this.bankHolder,
    this.note,
    this.isSelf = false,
    this.isActive = true,
    this.deletedAt,
  });

  factory Member.fromMap(Map<String, Object?> map) => Member(
    id: map['id']! as String,
    name: map['name']! as String,
    nameNorm: map['name_norm']! as String,
    nickname: map['nickname'] as String?,
    phone: map['phone'] as String?,
    bankName: map['bank_name'] as String?,
    bankBin: map['bank_bin'] as String?,
    bankAccount: map['bank_account'] as String?,
    bankHolder: map['bank_holder'] as String?,
    avatarColor: map['avatar_color']! as int,
    note: map['note'] as String?,
    isSelf: (map['is_self']! as int) == 1,
    isActive: (map['is_active']! as int) == 1,
    createdAt: map['created_at']! as int,
    updatedAt: map['updated_at']! as int,
    deletedAt: map['deleted_at'] as int?,
  );

  final String id;
  final String name;

  /// Tên đã bỏ dấu và chuyển chữ thường, dùng để tìm kiếm và so trùng.
  final String nameNorm;

  final String? nickname;
  final String? phone;

  // ─── Thông tin nhận tiền (FR-1.2) ───
  final String? bankName;

  /// Mã BIN ngân hàng, dùng sinh VietQR ở v1.1.
  final String? bankBin;
  final String? bankAccount;
  final String? bankHolder;

  /// Màu avatar dạng ARGB. Lưu xuống DB để đổi tên không làm đổi màu.
  final int avatarColor;

  final String? note;

  /// Đánh dấu chính người dùng app (FR-1.6). Toàn DB chỉ có đúng một bản ghi.
  final bool isSelf;

  /// `false` = ngừng hoạt động: ẩn khỏi danh sách chọn nhưng giữ nguyên lịch sử.
  final bool isActive;

  final int createdAt;
  final int updatedAt;

  /// Soft delete (SPEC §5.4). Khác `null` nghĩa là đã xóa.
  final int? deletedAt;

  /// Tên hiển thị: ưu tiên biệt danh vì nhóm thường gọi nhau bằng biệt danh.
  String get displayName =>
      (nickname != null && nickname!.trim().isNotEmpty) ? nickname! : name;

  bool get hasBankInfo =>
      bankAccount != null && bankAccount!.trim().isNotEmpty;

  /// Có thể chọn vào hóa đơn mới hay không.
  bool get isSelectable => isActive && deletedAt == null;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'name_norm': nameNorm,
    'nickname': nickname,
    'phone': phone,
    'bank_name': bankName,
    'bank_bin': bankBin,
    'bank_account': bankAccount,
    'bank_holder': bankHolder,
    'avatar_color': avatarColor,
    'note': note,
    'is_self': isSelf ? 1 : 0,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };

  Member copyWith({
    String? name,
    String? nameNorm,
    String? nickname,
    String? phone,
    String? bankName,
    String? bankBin,
    String? bankAccount,
    String? bankHolder,
    int? avatarColor,
    String? note,
    bool? isSelf,
    bool? isActive,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) => Member(
    id: id,
    name: name ?? this.name,
    nameNorm: nameNorm ?? this.nameNorm,
    nickname: nickname ?? this.nickname,
    phone: phone ?? this.phone,
    bankName: bankName ?? this.bankName,
    bankBin: bankBin ?? this.bankBin,
    bankAccount: bankAccount ?? this.bankAccount,
    bankHolder: bankHolder ?? this.bankHolder,
    avatarColor: avatarColor ?? this.avatarColor,
    note: note ?? this.note,
    isSelf: isSelf ?? this.isSelf,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );

  @override
  bool operator ==(Object other) =>
      other is Member && other.id == id && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, updatedAt);

  @override
  String toString() => 'Member($id, $name)';
}
