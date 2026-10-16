import 'package:flutter_test/flutter_test.dart';
import 'package:minishop/core/qr/vietqr_builder.dart';

String _independentCrc16Ccitt(String data) {
  var crc = 0xFFFF;
  for (final byte in data.codeUnits) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

void main() {
  test('VietQR payload ends with valid CRC16/CCITT-FALSE and known structure', () {
    final qr = VietQrBuilder.build(
      bankBin: '970422',
      accountNumber: '0123456789',
      amount: 50000,
      addInfo: 'HD000001',
      merchantName: 'NGUYEN VAN A',
    );

    // Payload Format Indicator
    expect(qr.startsWith('000201'), true);
    // Ends with tag 63 (CRC), length 04, 4 hex chars
    expect(qr.substring(qr.length - 8, qr.length - 4), '6304');
    expect(RegExp(r'^[0-9A-F]{4}$').hasMatch(qr.substring(qr.length - 4)), true);
    // Contains bank bin, account number and invoice code as addInfo
    expect(qr.contains('970422'), true);
    expect(qr.contains('0123456789'), true);
    expect(qr.contains('HD000001'), true);
  });

  test('appended CRC matches an independently implemented CRC16/CCITT-FALSE', () {
    final qr = VietQrBuilder.build(
      bankBin: '970422',
      accountNumber: '0123456789',
      amount: 50000,
      addInfo: 'HD000001',
      merchantName: 'NGUYEN VAN A',
    );

    final prefixWithTag = qr.substring(0, qr.length - 4);
    final expectedCrc = _independentCrc16Ccitt(prefixWithTag);
    expect(qr.substring(qr.length - 4), expectedCrc);

    // Sanity-check the independent implementation against the well-known
    // CRC-16/CCITT-FALSE test vector for ASCII "123456789" -> 0x29B1.
    expect(_independentCrc16Ccitt('123456789'), '29B1');
  });
}
