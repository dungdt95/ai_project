import 'package:flutter/material.dart';

import '../../../core/extensions/app_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/money_field.dart';

/// Nhập số tiền một người đã trả, khi họ mới trả một phần (SPEC FR-6.1).
///
/// Trả về số tiền đã trả, hoặc `null` nếu người dùng đóng sheet.
class PartialPaymentSheet extends StatefulWidget {
  const PartialPaymentSheet({
    required this.name,
    required this.share,
    required this.paid,
    super.key,
  });

  final String name;

  /// Số tiền người này phải chịu.
  final int share;

  /// Số tiền đã ghi nhận trước đó.
  final int paid;

  static Future<int?> show(
    BuildContext context, {
    required String name,
    required int share,
    required int paid,
  }) => showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        PartialPaymentSheet(name: name, share: share, paid: paid),
  );

  @override
  State<PartialPaymentSheet> createState() => _PartialPaymentSheetState();
}

class _PartialPaymentSheetState extends State<PartialPaymentSheet> {
  late final TextEditingController _controller;
  late int _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.paid;
    _controller = TextEditingController(
      text: widget.paid == 0 ? '' : MoneyFormatter.formatPlain(widget.paid),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = widget.share - _amount;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.s16,
        right: AppTheme.s16,
        top: AppTheme.s16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.name} đã trả bao nhiêu?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.s4),
          Text(
            'Phải chịu ${widget.share.toVnd()}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.s16),

          MoneyField(
            controller: _controller,
            large: true,
            autofocus: true,
            onChanged: (value) => setState(() => _amount = value),
          ),
          const SizedBox(height: AppTheme.s8),

          Text(
            remaining > 0
                ? 'Còn thiếu ${remaining.toVnd()}'
                : remaining == 0
                ? 'Đã trả đủ'
                : 'Trả thừa ${(-remaining).toVnd()}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: remaining == 0
                  ? AppColors.paid
                  : (remaining > 0 ? AppColors.partial : AppColors.unpaid),
            ),
          ),
          const SizedBox(height: AppTheme.s16),

          Wrap(
            spacing: AppTheme.s8,
            children: [
              ActionChip(
                label: const Text('Trả đủ'),
                onPressed: () => _set(widget.share),
              ),
              ActionChip(
                label: const Text('Một nửa'),
                onPressed: () => _set(widget.share ~/ 2),
              ),
              ActionChip(
                label: const Text('Chưa trả'),
                onPressed: () => _set(0),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s24),

          FilledButton(
            onPressed: () => Navigator.of(context).pop(_amount),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _set(int value) {
    setState(() {
      _amount = value;
      _controller.text = value == 0 ? '' : MoneyFormatter.formatPlain(value);
    });
  }
}
