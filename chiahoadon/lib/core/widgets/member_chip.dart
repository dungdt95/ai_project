import 'package:flutter/material.dart';

import '../../domain/models/member.dart';
import '../theme/app_theme.dart';
import 'member_avatar.dart';

/// Chip bật/tắt để chọn một thành viên.
///
/// Dùng ở bước chọn người tham gia hóa đơn và ở chọn người dùng từng món
/// (SPEC FR-3.2, FR-4.2). Vùng chạm cao 40dp để bấm nhanh bằng ngón tay.
class MemberChip extends StatelessWidget {
  const MemberChip({
    required this.member,
    required this.selected,
    super.key,
    this.onTap,
    this.trailing,
  });

  final Member member;
  final bool selected;
  final VoidCallback? onTap;

  /// Nội dung phụ bên phải, ví dụ số tiền người này phải chịu.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppTheme.radiusChip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusChip),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemberAvatar.small(
                name: member.displayName,
                color: member.avatarColor,
                isSelf: member.isSelf,
              ),
              const SizedBox(width: AppTheme.s8),
              Text(
                member.displayName,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppTheme.s8),
                trailing!,
              ],
              const SizedBox(width: AppTheme.s4),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 18,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
