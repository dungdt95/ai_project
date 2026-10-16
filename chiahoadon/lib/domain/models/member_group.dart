/// Nhóm thành viên hay đi cùng nhau (SPEC FR-2).
///
/// Chỉ là lối tắt để chọn nhanh người tham gia. Hóa đơn đã lưu không phụ thuộc
/// vào nhóm: xóa nhóm không làm thay đổi hóa đơn cũ (FR-2.5).
class MemberGroup {
  const MemberGroup({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.deletedAt,
    this.memberIds = const [],
  });

  factory MemberGroup.fromMap(
    Map<String, Object?> map, {
    List<String> memberIds = const [],
  }) => MemberGroup(
    id: map['id']! as String,
    name: map['name']! as String,
    description: map['description'] as String?,
    color: map['color']! as int,
    createdAt: map['created_at']! as int,
    updatedAt: map['updated_at']! as int,
    deletedAt: map['deleted_at'] as int?,
    memberIds: memberIds,
  );

  final String id;
  final String name;
  final String? description;

  /// Màu nhận diện nhóm, dạng ARGB.
  final int color;

  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  /// Thành viên của nhóm. Nạp rời từ bảng `group_members`, nên có thể rỗng
  /// khi chỉ đọc danh sách nhóm mà chưa cần chi tiết.
  final List<String> memberIds;

  int get memberCount => memberIds.length;

  /// Các cột của chính bảng `member_groups`; `memberIds` lưu ở bảng nối.
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'color': color,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };

  MemberGroup copyWith({
    String? name,
    String? description,
    int? color,
    int? updatedAt,
    int? deletedAt,
    List<String>? memberIds,
    bool clearDeletedAt = false,
  }) => MemberGroup(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    color: color ?? this.color,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    memberIds: memberIds ?? this.memberIds,
  );

  @override
  bool operator ==(Object other) =>
      other is MemberGroup &&
      other.id == id &&
      other.updatedAt == updatedAt &&
      other.memberCount == memberCount;

  @override
  int get hashCode => Object.hash(id, updatedAt, memberCount);

  @override
  String toString() => 'MemberGroup($id, $name, $memberCount người)';
}
