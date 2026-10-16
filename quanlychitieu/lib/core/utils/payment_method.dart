import 'package:flutter/material.dart';

/// Các loại tiền (phương thức thanh toán) khi thêm giao dịch.
class PaymentMethods {
  static const cash = 'cash';
  static const qr = 'qr';
  static const credit = 'credit';

  /// Thứ tự hiển thị
  static const all = [cash, qr, credit];

  static String label(String? value) {
    switch (value) {
      case cash:
        return 'Tiền mặt';
      case qr:
        return 'QR';
      case credit:
        return 'Tín dụng';
      default:
        return '';
    }
  }

  static IconData icon(String? value) {
    switch (value) {
      case cash:
        return Icons.payments_outlined;
      case qr:
        return Icons.qr_code;
      case credit:
        return Icons.credit_card;
      default:
        return Icons.help_outline;
    }
  }
}
