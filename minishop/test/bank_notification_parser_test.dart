import 'package:flutter_test/flutter_test.dart';
import 'package:minishop/core/notification/bank_notification_parser.dart';

void main() {
  group('BankNotificationParser', () {
    test('parses amount with comma thousands separator and + sign', () {
      final result = BankNotificationParser.parse(
        'com.mbmobile',
        'So du TK: +50,000VND luc 10:00. ND: chuyen tien HD000001. SD: 1,000,000VND',
      );
      expect(result.amount, 50000);
      expect(result.invoiceCode, 'HD000001');
    });

    test('parses amount with dot thousands separator and đ suffix', () {
      final result = BankNotificationParser.parse(
        'com.VCB',
        'Tai khoan cua ban vua nhan +120.000đ. Noi dung: HD000045 thanh toan',
      );
      expect(result.amount, 120000);
      expect(result.invoiceCode, 'HD000045');
    });

    test('falls back to first amount-like number when no + sign present', () {
      final result = BankNotificationParser.parse(
        'com.techcombank.bb.app.te',
        'Bien dong so du: 75,000 VND. Noi dung CK: HD000099',
      );
      expect(result.amount, 75000);
      expect(result.invoiceCode, 'HD000099');
    });

    test('invoice code matching is case-insensitive but normalized to uppercase', () {
      final result = BankNotificationParser.parse(
        'com.mservice.momotransfer',
        'Ban da nhan 5,000d tu nguoi gui. Loi nhan: hd000007',
      );
      expect(result.invoiceCode, 'HD000007');
    });

    test('returns nulls when notification has no recognizable amount or code', () {
      final result = BankNotificationParser.parse('com.mbmobile', 'Khuyen mai moi danh cho ban!');
      expect(result.amount, null);
      expect(result.invoiceCode, null);
    });
  });
}
