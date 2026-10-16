import 'package:flutter/material.dart';

import '../../../core/extensions/app_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../domain/models/member.dart';
import '../../../domain/split/split_result.dart';

/// Khung XEM TRƯỚC ở bước chia tiền (PLAN §5.3, S03).
///
/// Cập nhật ngay theo từng ký tự người dùng gõ, vì `computeSplit` là hàm thuần
/// và đồng bộ (NFR-4). Đây là chi tiết quan trọng nhất của trải nghiệm nhập
/// hóa đơn: người dùng thấy ngay hệ quả của mỗi thay đổi, không phải bấm
/// "tính" rồi chờ.
class SplitPreviewCard extends StatelessWidget {
  const SplitPreviewCard({
    required this.result,
    required this.members,
    super.key,
    this.payerId,
  });

  final SplitResult result;

  /// Tra tên và màu avatar; chỉ cần những người có trong hóa đơn.
  final Map<String, Member> members;

  final String? payerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!result.isValid) {
      return Card(
        color: AppColors.warningBg,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warningFg,
                  ),
                  const SizedBox(width: AppTheme.s8),
                  Text(
                    'Chưa chia được',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.warningFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.s8),
              for (final error in result.errors)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.s4),
                  child: Text(
                    '• ${error.message}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warningFg,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.s8),
                Text(
                  'XEM TRƯỚC',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  result.total.toVnd(),
                  style: MoneyTextStyle.medium.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            if (result.roundingDelta != 0)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.s4),
                child: Text(
                  'Đã làm tròn ${result.roundingDelta > 0 ? '+' : ''}'
                  '${result.roundingDelta.toVnd()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            const Divider(height: AppTheme.s24),

            for (final entry in result.shares.entries)
              _ShareRow(
                member: members[entry.key],
                memberId: entry.key,
                amount: entry.value,
                isPayer: entry.key == payerId,
              ),

            if (result.hasSurcharge) ...[
              const Divider(height: AppTheme.s24),
              _Breakdown(result: result),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.memberId,
    required this.amount,
    required this.isPayer,
    this.member,
  });

  final Member? member;
  final String memberId;
  final int amount;
  final bool isPayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = member?.displayName ?? '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.s4),
      child: Row(
        children: [
          MemberAvatar.small(
            name: name,
            color: member?.avatarColor,
            isSelf: member?.isSelf ?? false,
          ),
          const SizedBox(width: AppTheme.s12),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (isPayer) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'trả trước',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.s8),
          ],
          Text(amount.toVnd(), style: MoneyTextStyle.small),
        ],
      ),
    );
  }
}

/// Bảng bóc tách các mốc tiền, chỉ hiện khi hóa đơn có phụ phí (SPEC FR-5.9).
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.result});

  final SplitResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _line(context, 'Tạm tính', result.subtotal),
        if (result.discountAmount != 0)
          _line(context, 'Giảm giá', -result.discountAmount),
        if (result.taxAmount != 0) _line(context, 'VAT', result.taxAmount),
        if (result.serviceAmount != 0)
          _line(context, 'Phí dịch vụ', result.serviceAmount),
        if (result.tipAmount != 0) _line(context, 'Tip', result.tipAmount),
        if (result.roundingDelta != 0)
          _line(context, 'Làm tròn', result.roundingDelta),
      ],
    );
  }

  Widget _line(BuildContext context, String label, int amount) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            amount < 0 ? amount.toVnd() : '+${amount.toVnd()}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
