import 'package:flutter/material.dart';

import '../../../data/models/invoice.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      Invoice.statusPaid => ('Đã thanh toán', Colors.green),
      Invoice.statusCancelled => ('Đã hủy', Colors.grey),
      _ => ('Chưa thanh toán', Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
