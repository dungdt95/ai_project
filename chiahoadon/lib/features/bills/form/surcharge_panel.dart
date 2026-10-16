import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/app_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/money_field.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/surcharge.dart';
import '../../../domain/split/split_result.dart';
import 'bill_form_state.dart';

/// Panel gập lại chứa phụ phí, giảm giá và tùy chọn làm tròn (SPEC FR-5).
///
/// Mặc định gập vì phần lớn hóa đơn không có phụ phí; mở sẵn khi hóa đơn đang
/// sửa đã có sẵn khoản nào đó.
class SurchargePanel extends StatefulWidget {
  const SurchargePanel({
    required this.form,
    required this.preview,
    required this.onChanged,
    super.key,
  });

  final BillFormState form;
  final SplitResult preview;
  final ValueChanged<BillFormState> onChanged;

  @override
  State<SurchargePanel> createState() => _SurchargePanelState();
}

class _SurchargePanelState extends State<SurchargePanel> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.form.hasSurcharge;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final form = widget.form;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.percent),
            title: const Text('Phụ phí & giảm giá'),
            subtitle: Text(_summary(form)),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),

          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.s16,
                0,
                AppTheme.s16,
                AppTheme.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SurchargeRow(
                    label: 'Giảm giá',
                    value: form.discount,
                    computed: widget.preview.discountAmount,
                    onChanged: (value) =>
                        widget.onChanged(form.withDiscount(value)),
                  ),
                  const Divider(height: AppTheme.s24),
                  _SurchargeRow(
                    label: 'VAT',
                    value: form.tax,
                    computed: widget.preview.taxAmount,
                    hint: 'Thường là 8% hoặc 10%',
                    onChanged: (value) =>
                        widget.onChanged(form.withTax(value)),
                  ),
                  const Divider(height: AppTheme.s24),
                  _SurchargeRow(
                    label: 'Phí dịch vụ',
                    value: form.service,
                    computed: widget.preview.serviceAmount,
                    onChanged: (value) =>
                        widget.onChanged(form.withService(value)),
                  ),
                  const Divider(height: AppTheme.s24),
                  _TipRow(
                    value: form.tip,
                    onChanged: (value) => widget.onChanged(form.withTip(value)),
                  ),

                  const SizedBox(height: AppTheme.s16),
                  Text(
                    'VAT và phí dịch vụ được tính trên số tiền SAU giảm giá, '
                    'đúng cách ghi của hóa đơn Việt Nam.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: AppTheme.s16),
                  Text('Phân bổ phụ phí', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppTheme.s8),
                  SegmentedButton<SurchargeAlloc>(
                    segments: const [
                      ButtonSegment(
                        value: SurchargeAlloc.proportional,
                        label: Text('Theo tỷ lệ'),
                      ),
                      ButtonSegment(
                        value: SurchargeAlloc.equal,
                        label: Text('Chia đều'),
                      ),
                    ],
                    selected: {form.surchargeAlloc},
                    onSelectionChanged: (selected) => widget.onChanged(
                      form.withSurchargeAlloc(selected.first),
                    ),
                  ),
                  const SizedBox(height: AppTheme.s4),
                  Text(
                    form.surchargeAlloc == SurchargeAlloc.proportional
                        ? 'Ai ăn nhiều chịu nhiều — đúng bản chất VAT.'
                        : 'Chia đều đầu người — hợp với phí ship, phí phòng.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _summary(BillFormState form) {
    final parts = <String>[
      if (form.discount.isActive) 'giảm ${_describe(form.discount)}',
      if (form.tax.isActive) 'VAT ${_describe(form.tax)}',
      if (form.service.isActive) 'phí DV ${_describe(form.service)}',
      if (form.tip != 0) 'tip ${form.tip.toVnd()}',
    ];
    return parts.isEmpty ? 'Không có' : parts.join(' · ');
  }

  String _describe(Surcharge surcharge) => surcharge.isPercent
      ? MoneyFormatter.formatPercentBp(surcharge.value)
      : surcharge.value.toVnd();
}

/// Một dòng phụ phí: chuyển được giữa nhập theo % và nhập số tiền (FR-5.1).
class _SurchargeRow extends StatefulWidget {
  const _SurchargeRow({
    required this.label,
    required this.value,
    required this.computed,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final Surcharge value;

  /// Số tiền engine đã tính ra, hiện bên cạnh để người dùng thấy ngay hệ quả.
  final int computed;

  final String? hint;
  final ValueChanged<Surcharge> onChanged;

  @override
  State<_SurchargeRow> createState() => _SurchargeRowState();
}

class _SurchargeRowState extends State<_SurchargeRow> {
  late final TextEditingController _controller;
  late bool _asPercent;

  @override
  void initState() {
    super.initState();
    _asPercent = widget.value.mode != SurchargeMode.amount;
    _controller = TextEditingController(text: _initialText());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _initialText() {
    if (!widget.value.isActive) return '';
    return widget.value.isPercent
        ? MoneyFormatter.formatPercentBp(widget.value.value).replaceAll('%', '')
        : MoneyFormatter.formatPlain(widget.value.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.label, style: theme.textTheme.labelLarge),
            ),
            if (widget.computed != 0)
              Text(
                widget.computed.toVnd(),
                style: MoneyTextStyle.small.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.s8),
        Row(
          children: [
            Expanded(
              child: _asPercent
                  ? PercentField(
                      controller: _controller,
                      onChanged: (bp) => widget.onChanged(
                        bp == 0
                            ? const Surcharge.none()
                            : Surcharge.percent(bp),
                      ),
                    )
                  : MoneyField(
                      controller: _controller,
                      onChanged: (amount) => widget.onChanged(
                        amount == 0
                            ? const Surcharge.none()
                            : Surcharge.amount(amount),
                      ),
                    ),
            ),
            const SizedBox(width: AppTheme.s8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('%')),
                ButtonSegment(value: false, label: Text('đ')),
              ],
              selected: {_asPercent},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onSelectionChanged: (selected) => setState(() {
                _asPercent = selected.first;
                // Đổi đơn vị thì xóa giá trị cũ: "8" hiểu theo % và theo đồng
                // là hai con số cách nhau rất xa, giữ lại chỉ gây nhầm.
                _controller.clear();
                widget.onChanged(const Surcharge.none());
              }),
            ),
          ],
        ),
        if (widget.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.s4),
            child: Text(
              widget.hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _TipRow extends StatefulWidget {
  const _TipRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_TipRow> createState() => _TipRowState();
}

class _TipRowState extends State<_TipRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value == 0 ? '' : MoneyFormatter.formatPlain(widget.value),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tip / phí khác', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppTheme.s8),
        MoneyField(controller: _controller, onChanged: widget.onChanged),
      ],
    );
  }
}

/// Chọn đơn vị và cách làm tròn (SPEC FR-5.7, FR-5.8, FR-5.9).
class RoundingPanel extends StatelessWidget {
  const RoundingPanel({
    required this.form,
    required this.preview,
    required this.onChanged,
    super.key,
  });

  final BillFormState form;
  final SplitResult preview;
  final ValueChanged<BillFormState> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rule, size: 20),
                const SizedBox(width: AppTheme.s12),
                Expanded(
                  child: Text(
                    'Làm tròn',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                if (preview.roundingDelta != 0)
                  Text(
                    '${preview.roundingDelta > 0 ? '+' : ''}'
                    '${preview.roundingDelta.toVnd()}',
                    style: MoneyTextStyle.small.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.s12),

            Wrap(
              spacing: AppTheme.s8,
              children: [
                for (final unit in AppConstants.roundingUnits)
                  ChoiceChip(
                    label: Text(unit == 1 ? 'Từng đồng' : unit.toVnd()),
                    selected: form.roundingUnit == unit,
                    onSelected: (_) =>
                        onChanged(form.withRounding(unit: unit)),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.s12),

            Wrap(
              spacing: AppTheme.s8,
              children: [
                for (final mode in RoundingMode.values)
                  ChoiceChip(
                    label: Text(mode.label),
                    selected: form.roundingMode == mode,
                    onSelected: (_) =>
                        onChanged(form.withRounding(mode: mode)),
                  ),
              ],
            ),

            if (preview.roundingDelta != 0) ...[
              const SizedBox(height: AppTheme.s8),
              Text(
                'Tổng gốc ${preview.totalExact.toVnd()} đã được làm tròn thành '
                '${preview.total.toVnd()}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
