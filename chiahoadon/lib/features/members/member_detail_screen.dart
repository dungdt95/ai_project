import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/app_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/member_avatar.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/member.dart';
import '../../domain/stats/stats_models.dart';
import '../bills/detail/bill_detail_screen.dart';
import '../settlement/transfer_qr_sheet.dart';
import '../stats/stats_provider.dart';
import '../stats/stats_screen.dart';
import 'member_form_screen.dart';
import 'members_provider.dart';

/// S07 — Chi tiết thành viên: tổng chi và chi phí từng lần (SPEC FR-7.1, FR-7.2).
///
/// Đây là màn hình trả lời trực tiếp yêu cầu gốc: *"thống kê chi phí theo từng
/// thành viên, cần biết tổng chi phí và chi phí từng lần theo mỗi hóa đơn"*.
class MemberDetailScreen extends ConsumerStatefulWidget {
  const MemberDetailScreen({required this.member, super.key});

  final Member member;

  static Future<void> push(BuildContext context, Member member) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => MemberDetailScreen(member: member),
        ),
      );

  @override
  ConsumerState<MemberDetailScreen> createState() =>
      _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  StatsPeriod _period = StatsPeriod.allTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Đọc lại từ danh sách đang theo dõi thay vì dùng bản ghi được truyền vào:
    // bản truyền vào là một bản chụp tại lúc mở màn, nên sau khi người dùng bấm
    // sửa và lưu, màn này vẫn hiện dữ liệu cũ cho tới khi thoát ra vào lại.
    // Danh sách chưa nạp xong thì tạm dùng bản chụp, để không chớp màn trống.
    final member =
        (ref.watch(membersProvider).value ?? const <Member>[]).firstWhere(
          (each) => each.id == widget.member.id,
          orElse: () => widget.member,
        );

    final args = (memberId: member.id, period: _period);

    final summary = ref.watch(memberSummaryProvider(args));
    final timeline = ref.watch(memberTimelineProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: Text(member.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Sửa thành viên',
            onPressed: () => MemberFormScreen.push(context, member: member),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.s16),
        children: [
          Center(
            child: Column(
              children: [
                MemberAvatar.large(
                  name: member.displayName,
                  color: member.avatarColor,
                  isSelf: member.isSelf,
                ),
                const SizedBox(height: AppTheme.s12),
                Text(
                  member.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (member.phone != null)
                  Text(
                    member.phone!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (member.hasBankInfo) ...[
                  Text(
                    '${member.bankName ?? ''} · ${member.bankAccount}'.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // QR ở đây không điền sẵn số tiền: màn này chưa biết người
                  // xem đang nợ bao nhiêu, nên để họ tự nhập.
                  TextButton.icon(
                    onPressed: () =>
                        TransferQrSheet.show(context, payee: member),
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('QR nhận tiền'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.s24),

          // Bộ lọc thời gian (SPEC FR-7.3).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final period in StatsPeriod.values) ...[
                  ChoiceChip(
                    label: Text(period.label),
                    selected: _period == period,
                    onSelected: (_) => setState(() => _period = period),
                  ),
                  const SizedBox(width: AppTheme.s8),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.s8),
          PeriodRangeLabel(range: _period.range),

          // Hai số lớn: tổng chi và số đang nợ (SPEC FR-7.1).
          switch (summary) {
            AsyncData(:final value) => Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'TỔNG CHI PHÍ',
                    value: value.totalSpent.toVnd(),
                    caption: '${value.billCount} hóa đơn',
                  ),
                ),
                const SizedBox(width: AppTheme.s12),
                Expanded(
                  child: _StatTile(
                    label: 'ĐANG NỢ',
                    value: value.unpaidAmount.toVnd(),
                    caption: '${value.unpaidBillCount} hóa đơn',
                    accent: value.unpaidAmount > 0
                        ? AppColors.unpaid
                        : AppColors.paid,
                  ),
                ),
              ],
            ),
            AsyncError() => const SizedBox.shrink(),
            _ => const Center(child: CircularProgressIndicator()),
          },

          const SizedBox(height: AppTheme.s24),
          Text(
            'LỊCH SỬ TỪNG HÓA ĐƠN',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppTheme.s8),

          switch (timeline) {
            AsyncData(:final value) => value.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Chưa có hóa đơn nào',
                    message: 'Người này chưa tham gia hóa đơn nào trong kỳ đã '
                        'chọn.',
                  )
                : Card(
                    child: Column(
                      children: [
                        for (final entry in value) _TimelineRow(entry: entry),
                      ],
                    ),
                  ),
            AsyncError(:final error) => ErrorView.fromError(error),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ],
      ),
    );
  }
}

/// Một ô số lớn.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.caption,
    this.accent,
  });

  final String label;
  final String value;
  final String caption;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppTheme.s4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: MoneyTextStyle.medium.copyWith(color: accent),
              ),
            ),
            const SizedBox(height: AppTheme.s4),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một dòng trong lịch sử: ngày, tên hóa đơn, phần phải chịu, đã trả chưa.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry});

  final MemberBillEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (color, label) = switch (entry.paymentStatus) {
      ParticipantPaymentStatus.paid => (AppColors.paid, 'đã trả'),
      ParticipantPaymentStatus.partial => (
        AppColors.partial,
        'còn ${entry.remaining.toVnd()}',
      ),
      ParticipantPaymentStatus.unpaid => (AppColors.unpaid, 'chưa trả'),
    };

    return ListTile(
      // Một dòng ngày thay vì hai: ô `leading` của `ListTile` chỉ cao bằng
      // dòng, hai dòng chữ sẽ tràn ra ngoài. Năm chỉ hiện khi khác năm nay.
      leading: SizedBox(
        width: 48,
        child: Text(
          entry.date.year == DateTime.now().year
              ? DateFormatter.dayMonth(entry.date)
              : '${DateFormatter.dayMonth(entry.date)}\n${entry.date.year}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(entry.title, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppTheme.s4),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
      trailing: Text(entry.shareAmount.toVnd(), style: MoneyTextStyle.small),
      onTap: () => BillDetailScreen.push(context, entry.billId),
    );
  }
}
