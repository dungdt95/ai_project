import 'package:flutter/material.dart';
import '../utils/formatters.dart';
import '../constants/app_colors.dart';

class AmountText extends StatelessWidget {
  final double amount;
  final bool isExpense;
  final double fontSize;
  final FontWeight fontWeight;

  const AmountText({
    super.key,
    required this.amount,
    this.isExpense = false,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '${isExpense ? '-' : '+'}${formatCurrency(amount)}',
      style: TextStyle(
        color: isExpense ? AppColors.expense : AppColors.income,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }
}
