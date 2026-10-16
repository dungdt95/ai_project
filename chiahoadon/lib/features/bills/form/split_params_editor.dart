import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/extensions/app_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/money_field.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/member.dart';
import 'bill_form_state.dart';

/// Phần nhập tham số riêng của kiểu chia theo %, theo số phần, hoặc theo số
/// tiền chỉ định (SPEC FR-4.3 → FR-4.5).
class SplitParamsEditor extends StatelessWidget {
  const SplitParamsEditor({
    required this.form,
    required this.members,
    required this.onChanged,
    super.key,
  });

  final BillFormState form;
  final Map<String, Member> members;
  final ValueChanged<BillFormState> onChanged;

  @override
  Widget build(BuildContext context) => switch (form.splitType) {
    SplitType.percentage => _PercentageEditor(
      form: form,
      members: members,
      onChanged: onChanged,
    ),
    SplitType.shares => _SharesEditor(
      form: form,
      members: members,
      onChanged: onChanged,
    ),
    SplitType.exact => _ExactEditor(
      form: form,
      members: members,
      onChanged: onChanged,
    ),
    _ => const SizedBox.shrink(),
  };
}

/// Chia theo tỷ lệ phần trăm (SPEC FR-4.3).
class _PercentageEditor extends StatelessWidget {
  const _PercentageEditor({
    required this.form,
    required this.members,
    required this.onChanged,
  });

  final BillFormState form;
  final Map<String, Member> members;
  final ValueChanged<BillFormState> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = form.totalPercentBp;
    final remaining = 10000 - total;
    final isExact = remaining == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Tỷ lệ từng người', style: theme.textTheme.labelLarge),
            ),
            TextButton(
              onPressed: () => onChanged(form.withEvenPercents()),
              child: const Text('Chia đều'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.s8),

        // Thanh tiến trình cho thấy ngay còn thiếu hay đã vượt 100%.
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (total / 10000).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: isExact
                ? AppColors.paid
                : (remaining < 0 ? AppColors.unpaid : AppColors.partial),
          ),
        ),
        const SizedBox(height: AppTheme.s4),
        Text(
          isExact
              ? 'Đủ 100%'
              : remaining > 0
              ? 'Còn thiếu ${MoneyFormatter.formatPercentBp(remaining)}'
              : 'Vượt ${MoneyFormatter.formatPercentBp(-remaining)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isExact ? AppColors.paid : theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: AppTheme.s12),

        Card(
          child: Column(
            children: [
              for (final id in form.participantIds)
                _ParamRow(
                  member: members[id],
                  child: SizedBox(
                    width: 110,
                    child: TextFormField(
                      initialValue: (form.percentBp[id] ?? 0) == 0
                          ? ''
                          : MoneyFormatter.formatPercentBp(
                              form.percentBp[id]!,
                            ).replaceAll('%', ''),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.end,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        suffixText: '%',
                      ),
                      onChanged: (text) => onChanged(
                        form.withPercent(
                          id,
                          MoneyFormatter.parsePercentToBp(text) ?? 0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chia theo số phần (SPEC FR-4.4).
class _SharesEditor extends StatelessWidget {
  const _SharesEditor({
    required this.form,
    required this.members,
    required this.onChanged,
  });

  final BillFormState form;
  final Map<String, Member> members;
  final ValueChanged<BillFormState> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Số phần từng người', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppTheme.s4),
        Text(
          'Ví dụ tiền nhà: phòng đôi tính 2 phần, phòng đơn 1 phần. '
          'Tổng hiện tại ${form.totalWeight} phần.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.s12),

        Card(
          child: Column(
            children: [
              for (final id in form.participantIds)
                _ParamRow(
                  member: members[id],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: form.weightOf(id) > 0
                            ? () => onChanged(
                                form.withWeight(id, form.weightOf(id) - 1),
                              )
                            : null,
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${form.weightOf(id)}',
                          textAlign: TextAlign.center,
                          style: MoneyTextStyle.medium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => onChanged(
                          form.withWeight(id, form.weightOf(id) + 1),
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

/// Chia theo số tiền chỉ định (SPEC FR-4.5).
class _ExactEditor extends StatelessWidget {
  const _ExactEditor({
    required this.form,
    required this.members,
    required this.onChanged,
  });

  final BillFormState form;
  final Map<String, Member> members;
  final ValueChanged<BillFormState> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = form.unallocatedAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Số tiền từng người',
                style: theme.textTheme.labelLarge,
              ),
            ),
            if (remaining != 0 && form.participantIds.isNotEmpty)
              TextButton(
                onPressed: () => onChanged(
                  form.withExactAmount(
                    form.participantIds.last,
                    (form.exactAmounts[form.participantIds.last] ?? 0) +
                        remaining,
                  ),
                ),
                child: const Text('Dồn phần dư'),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.s4),
        Text(
          remaining == 0
              ? 'Đã phân bổ đủ ${form.subtotal.toVnd()}'
              : remaining > 0
              ? 'Còn ${remaining.toVnd()} chưa phân bổ'
              : 'Đã vượt ${(-remaining).toVnd()}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: remaining == 0 ? AppColors.paid : theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: AppTheme.s12),

        Card(
          child: Column(
            children: [
              for (final id in form.participantIds)
                _ParamRow(
                  member: members[id],
                  child: SizedBox(
                    width: 150,
                    child: TextFormField(
                      initialValue: (form.exactAmounts[id] ?? 0) == 0
                          ? ''
                          : MoneyFormatter.formatPlain(form.exactAmounts[id]!),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                      ),
                      textAlign: TextAlign.end,
                      inputFormatters: const [MoneyInputFormatter()],
                      style: MoneyTextStyle.small,
                      decoration: const InputDecoration(
                        isDense: true,
                        suffixText: MoneyFormatter.symbol,
                      ),
                      onChanged: (text) => onChanged(
                        form.withExactAmount(
                          id,
                          MoneyFormatter.parseOrZero(text),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Một dòng "avatar + tên + ô nhập", dùng chung cho cả ba kiểu chia.
class _ParamRow extends StatelessWidget {
  const _ParamRow({required this.member, required this.child});

  final Member? member;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final name = member?.displayName ?? '?';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.s12,
        vertical: AppTheme.s8,
      ),
      child: Row(
        children: [
          MemberAvatar.small(
            name: name,
            color: member?.avatarColor,
            isSelf: member?.isSelf ?? false,
          ),
          const SizedBox(width: AppTheme.s12),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          child,
        ],
      ),
    );
  }
}
