import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/avatar_color.dart';
import '../utils/vn_text.dart';

/// Avatar tròn của một thành viên: chữ cái đầu trên nền màu cố định.
///
/// Không dùng ảnh — tên và màu là đủ để nhận ra nhau trong một nhóm vài người,
/// và tránh hẳn chuyện quản lý tệp ảnh trong một app offline (SPEC FR-1.3).
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    required this.name,
    super.key,
    this.color,
    this.size = 40,
    this.isSelf = false,
    this.isInactive = false,
  });

  /// Cỡ nhỏ dùng trong chip và danh sách dày.
  const MemberAvatar.small({
    required this.name,
    super.key,
    this.color,
    this.isSelf = false,
    this.isInactive = false,
  }) : size = 28;

  /// Cỡ lớn dùng ở đầu màn hình chi tiết thành viên.
  const MemberAvatar.large({
    required this.name,
    super.key,
    this.color,
    this.isSelf = false,
    this.isInactive = false,
  }) : size = 72;

  final String name;

  /// Màu nền dạng ARGB, thường lấy từ `members.avatar_color`. Khi để `null`
  /// thì màu được tính từ tên — dùng cho thành viên chưa lưu vào DB.
  final int? color;

  final double size;

  /// Thành viên "Tôi" được viền nổi để tìm thấy ngay trong danh sách.
  final bool isSelf;

  /// Thành viên ngừng hoạt động hiện mờ đi.
  final bool isInactive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = color != null
        ? AvatarColor.fromStored(color!)
        : AvatarColor.forName(name);

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isInactive
            ? background.withValues(alpha: 0.35)
            : background,
        shape: BoxShape.circle,
        border: isSelf
            ? Border.all(color: scheme.primary, width: 2.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        VnText.initial(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.42,
          height: 1,
        ),
      ),
    );

    if (!isSelf || size < 36) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: scheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star_rounded, size: size * 0.3, color: scheme.primary),
          ),
        ),
      ],
    );
  }
}

/// Chồng nhiều avatar lên nhau, dùng để hiện thành viên của một nhóm hoặc
/// người tham gia một hóa đơn trong danh sách.
class MemberAvatarStack extends StatelessWidget {
  const MemberAvatarStack({
    required this.names,
    super.key,
    this.colors = const [],
    this.size = 28,
    this.maxVisible = 4,
  });

  final List<String> names;

  /// Màu ARGB tương ứng từng tên; thiếu thì tính từ tên.
  final List<int> colors;

  final double size;

  /// Quá số này thì phần còn lại gom vào một vòng tròn "+N".
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = names.take(maxVisible).toList();
    final hidden = names.length - visible.length;
    final overlap = size * 0.3;

    return SizedBox(
      height: size,
      width: visible.isEmpty
          ? 0
          : size + (visible.length - 1 + (hidden > 0 ? 1 : 0)) * (size - overlap),
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
                child: MemberAvatar(
                  name: visible[i],
                  color: i < colors.length ? colors[i] : null,
                  size: size,
                ),
              ),
            ),
          if (hidden > 0)
            Positioned(
              left: visible.length * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.neutral,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$hidden',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
