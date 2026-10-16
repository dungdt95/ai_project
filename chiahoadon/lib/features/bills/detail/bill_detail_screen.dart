import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/app_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../data/data_providers.dart';
import '../../../domain/models/bill.dart';
import '../../../domain/models/bill_participant.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/member.dart';
import '../../../domain/split/split_engine.dart';
import '../../../domain/split/split_input.dart';
import '../../../services/image_service.dart';
import '../../members/members_provider.dart';
import '../bills_provider.dart';
import '../form/bill_form_screen.dart';
import '../form/bill_image_picker.dart';
import 'partial_payment_sheet.dart';
import 'share_preview_screen.dart';

/// S04 — Chi tiết hóa đơn (PLAN §5.3).
///
/// Hiển thị, sửa, nhân bản, xóa, đánh dấu đã trả và chia sẻ.
class BillDetailScreen extends ConsumerWidget {
  const BillDetailScreen({required this.billId, super.key});

  final String billId;

  static Future<void> push(BuildContext context, String billId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => BillDetailScreen(billId: billId),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = ref.watch(billDetailProvider(billId));

    return Scaffold(
      appBar: AppBar(
        title: Text(bill.value?.title ?? 'Hóa đơn'),
        actions: [
          if (bill.value != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Chia sẻ kết quả',
              onPressed: () => _share(context, ref, bill.value!),
            ),
          if (bill.value != null)
            PopupMenuButton<_BillAction>(
              onSelected: (action) =>
                  _handle(context, ref, action, bill.value!),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _BillAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Sửa'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _BillAction.duplicate,
                  child: ListTile(
                    leading: Icon(Icons.copy_outlined),
                    title: Text('Nhân bản'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _BillAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Xóa'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: switch (bill) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => ErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(billDetailProvider(billId)),
        ),
        AsyncData(:final value) =>
          value == null
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Không tìm thấy hóa đơn',
                  message: 'Có thể hóa đơn này đã bị xóa.',
                )
              : _Content(bill: value),
      },
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _BillAction action,
    Bill bill,
  ) async {
    final notifier = ref.read(billListProvider.notifier);

    switch (action) {
      case _BillAction.edit:
        await BillFormScreen.push(context, bill: bill);

      case _BillAction.duplicate:
        final result = await notifier.duplicate(bill.id);
        if (!context.mounted) return;
        result.when(
          ok: (copy) {
            AppSnackBar.success(context, 'Đã nhân bản sang hôm nay');
            unawaitedPush(context, copy.id);
          },
          err: (error) => AppSnackBar.error(context, error.message),
        );

      case _BillAction.delete:
        final confirmed = await ConfirmDialog.show(
          context,
          title: 'Xóa "${bill.title}"?',
          message:
              'Hóa đơn sẽ biến mất khỏi mọi thống kê. '
              'Bạn vẫn hoàn tác được ngay sau khi xóa.',
          confirmLabel: 'Xóa',
          isDestructive: true,
        );
        if (!context.mounted || !confirmed) return;

        final result = await notifier.delete(bill.id);
        if (!context.mounted) return;

        result.when(
          ok: (_) {
            Navigator.of(context).pop();
            AppSnackBar.undoable(
              context,
              'Đã xóa "${bill.title}"',
              onUndo: () => notifier.restore(bill.id),
            );
          },
          err: (error) => AppSnackBar.error(context, error.message),
        );
    }
  }

  /// Mở màn xem trước để chọn gửi text hay gửi ảnh (SPEC FR-8.1, FR-8.2).
  Future<void> _share(BuildContext context, WidgetRef ref, Bill bill) =>
      SharePreviewScreen.push(context, bill);

  /// Mở bản sao vừa tạo, thay cho màn hình hiện tại.
  void unawaitedPush(BuildContext context, String newBillId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => BillDetailScreen(billId: newBillId),
      ),
    );
  }
}

enum _BillAction { edit, duplicate, delete }

class _Content extends ConsumerWidget {
  const _Content({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allMembers = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final member in allMembers) member.id: member};
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final category = categories
        .where((c) => c.id == bill.categoryId)
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.s16),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.s16),
            child: Column(
              children: [
                Text(
                  'Tổng cộng',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.s4),
                Text(bill.totalAmount.toVnd(), style: MoneyTextStyle.large),
                const SizedBox(height: AppTheme.s12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppTheme.s8,
                  runSpacing: AppTheme.s4,
                  children: [
                    _Tag(
                      icon: Icons.calendar_today_outlined,
                      label: DateFormatter.short(
                        DateTime.fromMillisecondsSinceEpoch(bill.billDate),
                      ),
                    ),
                    if (category != null)
                      _Tag(
                        icon: Icons.label_outline,
                        label: '${category.icon ?? ''} ${category.name}'.trim(),
                      ),
                    _Tag(
                      icon: Icons.safety_divider,
                      label: bill.splitType.label,
                    ),
                    _Tag(
                      icon: Icons.group_outlined,
                      label: '${bill.participantCount} người',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (bill.payers.isNotEmpty) ...[
          const SizedBox(height: AppTheme.s12),
          Card(
            child: ListTile(
              leading: MemberAvatar(
                name: byId[bill.payers.first.memberId]?.displayName ?? '?',
                color: byId[bill.payers.first.memberId]?.avatarColor,
                isSelf: byId[bill.payers.first.memberId]?.isSelf ?? false,
              ),
              title: const Text('Người trả trước'),
              subtitle: Text(
                byId[bill.payers.first.memberId]?.displayName ?? '?',
              ),
              trailing: Text(
                bill.payers.first.paidAmount.toVnd(),
                style: MoneyTextStyle.small,
              ),
            ),
          ),
        ],

        if (bill.hasSurcharge || bill.roundingDelta != 0) ...[
          const SizedBox(height: AppTheme.s16),
          _BreakdownCard(bill: bill),
        ],

        const SizedBox(height: AppTheme.s16),
        Row(
          children: [
            Expanded(
              child: Text(
                'PHẦN MỖI NGƯỜI',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (bill.derivedStatus != BillStatus.settled)
              TextButton(
                onPressed: () => _settleAll(context, ref),
                child: const Text('Tất cả đã trả'),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.s8),
        Card(
          child: Column(
            children: [
              for (final participant in bill.participants)
                _ParticipantRow(
                  bill: bill,
                  participant: participant,
                  member: byId[participant.memberId],
                ),
            ],
          ),
        ),

        if (bill.hasImage) ...[
          const SizedBox(height: AppTheme.s16),
          _BillImage(path: bill.imagePath!),
        ],

        if (bill.items.isNotEmpty) ...[
          const SizedBox(height: AppTheme.s16),
          _ItemBreakdown(bill: bill, members: byId),
        ],

        if (bill.note != null && bill.note!.isNotEmpty) ...[
          const SizedBox(height: AppTheme.s16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.s16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_outlined, size: 20),
                  const SizedBox(width: AppTheme.s12),
                  Expanded(child: Text(bill.note!)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _settleAll(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(billPaymentProvider.notifier)
        .settleAll(bill.id);
    if (!context.mounted) return;

    result.when(
      ok: (_) => AppSnackBar.success(context, 'Đã đánh dấu mọi người đã trả'),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}

/// Một người trong hóa đơn, kèm trạng thái đã trả (SPEC FR-6.1).
///
/// Chạm để chuyển qua lại giữa "chưa trả" và "đã trả"; chạm giữ để nhập số
/// tiền đã trả một phần.
class _ParticipantRow extends ConsumerWidget {
  const _ParticipantRow({
    required this.bill,
    required this.participant,
    this.member,
  });

  final Bill bill;
  final BillParticipant participant;
  final Member? member;

  /// Người ứng tiền không nợ ai — phần của họ coi như đã thanh toán.
  bool get _isPayer =>
      bill.payers.any((p) => p.memberId == participant.memberId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = member?.displayName ?? participant.memberNameSnapshot;
    final status = participant.status;

    final (color, label) = switch (status) {
      ParticipantPaymentStatus.paid => (AppColors.paid, 'đã trả'),
      ParticipantPaymentStatus.partial => (
        AppColors.partial,
        'đã trả ${participant.paidAmount.toVnd()}',
      ),
      ParticipantPaymentStatus.unpaid => (AppColors.unpaid, 'chưa trả'),
    };

    return ListTile(
      leading: MemberAvatar(
        name: name,
        color: member?.avatarColor,
        isSelf: member?.isSelf ?? false,
      ),
      title: Text(name),
      subtitle: _isPayer
          ? const Text('trả trước cho cả nhóm')
          : Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTheme.s4),
                // Nhãn "đã trả 150.000 đ" dài hơn chỗ trống trên màn hình hẹp,
                // nên phải co lại thay vì tràn ra ngoài (NFR-9).
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
      trailing: Text(
        participant.shareAmount.toVnd(),
        style: MoneyTextStyle.small,
      ),
      onTap: _isPayer ? null : () => _toggle(context, ref),
      onLongPress: _isPayer ? null : () => _enterPartial(context, ref),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final paid = participant.paidAmount >= participant.shareAmount
        ? 0
        : participant.shareAmount;

    final result = await ref
        .read(billPaymentProvider.notifier)
        .setPaid(
          billId: bill.id,
          memberId: participant.memberId,
          paidAmount: paid,
          shareAmount: participant.shareAmount,
        );
    if (!context.mounted) return;

    result.when(
      ok: (_) {},
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }

  Future<void> _enterPartial(BuildContext context, WidgetRef ref) async {
    final amount = await PartialPaymentSheet.show(
      context,
      name: member?.displayName ?? participant.memberNameSnapshot,
      share: participant.shareAmount,
      paid: participant.paidAmount,
    );
    if (amount == null || !context.mounted) return;

    final result = await ref
        .read(billPaymentProvider.notifier)
        .setPaid(
          billId: bill.id,
          memberId: participant.memberId,
          paidAmount: amount,
          shareAmount: participant.shareAmount,
        );
    if (!context.mounted) return;

    result.when(
      ok: (_) => AppSnackBar.success(context, 'Đã cập nhật'),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}

/// Chi tiết theo món: mỗi món của ai, mỗi người chịu bao nhiêu (PLAN §5.3, S04).
///
/// Số tiền được tính lại bằng chính split engine từ dữ liệu đã lưu, nên con số
/// ở đây luôn khớp với phần mỗi người ở trên — không có đường nào để hai chỗ
/// nói hai điều khác nhau.
class _ItemBreakdown extends StatelessWidget {
  const _ItemBreakdown({required this.bill, required this.members});

  final Bill bill;
  final Map<String, Member> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = computeSplit(SplitInput.fromBill(bill));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHI TIẾT THEO MÓN',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppTheme.s8),
        Card(
          child: Column(
            children: [
              for (final item in bill.items)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.s16,
                    vertical: AppTheme.s12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.name} · ${item.unitPrice.toVnd()}'
                              ' × ${item.portions} phần',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            item.amount.toVnd(),
                            style: MoneyTextStyle.small,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.s4),
                      for (final entry
                          in (result.itemShares[item.id] ?? const {}).entries)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppTheme.s12,
                            top: 2,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  members[entry.key]?.displayName ?? '?',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Text(
                                entry.value.toVnd(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (item.hasNoParticipants)
                        Padding(
                          padding: const EdgeInsets.only(top: AppTheme.s4),
                          child: Text(
                            'Món chung — chia đều cho cả nhóm',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.warningFg,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bảng bóc tách từ tạm tính tới tổng (SPEC FR-5.9).
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s16),
        child: Column(
          children: [
            _line(context, 'Tạm tính', bill.subtotal),
            if (bill.discountAmount != 0)
              _line(context, 'Giảm giá', -bill.discountAmount),
            if (bill.taxAmount != 0) _line(context, 'VAT', bill.taxAmount),
            if (bill.serviceAmount != 0)
              _line(context, 'Phí dịch vụ', bill.serviceAmount),
            if (bill.tipAmount != 0) _line(context, 'Tip', bill.tipAmount),
            if (bill.roundingDelta != 0)
              _line(context, 'Làm tròn', bill.roundingDelta),
            const Divider(height: AppTheme.s24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TỔNG',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(bill.totalAmount.toVnd(), style: MoneyTextStyle.medium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String label, int amount) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            amount < 0 ? amount.toVnd() : amount.toVnd(),
            style: MoneyTextStyle.small.copyWith(
              color: amount < 0 ? AppColors.paid : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Ảnh hóa đơn đính kèm, chạm để xem toàn màn hình (SPEC FR-3.9).
class _BillImage extends StatelessWidget {
  const _BillImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: ImageService.resolve(path),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return const SizedBox.shrink();

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => BillImageViewer.show(context, file),
            child: Image.file(
              file,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}
