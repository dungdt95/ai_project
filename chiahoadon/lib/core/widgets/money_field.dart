import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/money_formatter.dart';

/// Chèn dấu phân cách hàng nghìn ngay khi người dùng gõ.
///
/// Con trỏ luôn nhảy về cuối. Với ô nhập tiền thì đó là hành vi đúng: người
/// dùng gõ số từ trái sang phải và gần như không bao giờ sửa vào giữa.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  /// Chặn số quá dài — `SplitLimits.maxAmount` là 13 chữ số.
  static const int _maxDigits = 15;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp('[^0-9]'), '');

    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > _maxDigits) return oldValue;

    final value = int.tryParse(digits);
    if (value == null) return oldValue;

    final formatted = MoneyFormatter.formatPlain(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Ô nhập số tiền, đơn vị đồng (SPEC NFR-6).
class MoneyField extends StatelessWidget {
  const MoneyField({
    required this.controller,
    super.key,
    this.label,
    this.hint,
    this.autofocus = false,
    this.enabled = true,
    this.large = false,
    this.onChanged,
    this.textInputAction,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool autofocus;
  final bool enabled;

  /// Kiểu chữ lớn, dùng cho ô nhập tổng tiền của hóa đơn.
  final bool large;

  /// Nhận số đồng đã phân tích, không phải chuỗi đang hiển thị.
  final ValueChanged<int>? onChanged;

  final TextInputAction? textInputAction;
  final Widget? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      textInputAction: textInputAction,
      textAlign: large ? TextAlign.center : TextAlign.end,
      inputFormatters: const [MoneyInputFormatter()],
      style: large
          ? MoneyTextStyle.large.copyWith(color: theme.colorScheme.onSurface)
          : MoneyTextStyle.medium.copyWith(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? '0',
        prefixIcon: prefixIcon,
        suffixText: MoneyFormatter.symbol,
        suffixStyle: large
            ? MoneyTextStyle.large.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
        contentPadding: large
            ? const EdgeInsets.symmetric(
                horizontal: AppTheme.s16,
                vertical: AppTheme.s16,
              )
            : null,
      ),
      onChanged: (text) => onChanged?.call(MoneyFormatter.parseOrZero(text)),
    );
  }
}

/// Ô nhập phần trăm, lưu dưới dạng basis point (SPEC FR-5).
class PercentField extends StatelessWidget {
  const PercentField({
    required this.controller,
    super.key,
    this.label,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? label;
  final bool enabled;

  /// Nhận basis point: người dùng gõ `8` thì trả về `800`.
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.end,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      style: MoneyTextStyle.medium,
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        suffixText: '%',
      ),
      onChanged: (text) =>
          onChanged?.call(MoneyFormatter.parsePercentToBp(text) ?? 0),
    );
  }
}
