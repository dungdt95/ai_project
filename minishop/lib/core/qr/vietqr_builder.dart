/// Builds a VietQR (Napas 247) EMVCo-compliant payload string entirely
/// offline — no network call needed. The resulting string is rendered as
/// a QR code (e.g. via `qr_flutter`) and is scannable by any Vietnamese
/// banking app that supports VietQR.
class VietQrBuilder {
  static const _napasGuid = 'A000000727';
  static const _serviceCodeToAccount = 'QRIBFTTA';

  static String build({
    required String bankBin,
    required String accountNumber,
    required int amount,
    required String addInfo,
    String merchantName = '',
  }) {
    final beneficiaryInfo = _tlv('00', bankBin) + _tlv('01', accountNumber);
    final merchantAccountInfo = _tlv('00', _napasGuid) +
        _tlv('01', beneficiaryInfo) +
        _tlv('02', _serviceCodeToAccount);
    final additionalData = _tlv('08', addInfo);

    final payload = StringBuffer()
      ..write(_tlv('00', '01')) // Payload Format Indicator
      ..write(_tlv('01', '12')) // Point of Initiation: dynamic (has amount)
      ..write(_tlv('38', merchantAccountInfo))
      ..write(_tlv('53', '704')) // Currency: VND
      ..write(_tlv('54', amount.toString()))
      ..write(_tlv('58', 'VN'))
      ..write(_tlv('59', merchantName.isEmpty ? 'NA' : merchantName))
      ..write(_tlv('60', 'VIETNAM'))
      ..write(_tlv('62', additionalData));

    final withCrcTag = '${payload.toString()}6304';
    final crc = _crc16Ccitt(withCrcTag);
    return '$withCrcTag$crc';
  }

  static String _tlv(String id, String value) {
    final length = value.length.toString().padLeft(2, '0');
    return '$id$length$value';
  }

  static String _crc16Ccitt(String data) {
    var crc = 0xFFFF;
    for (final byte in data.codeUnits) {
      crc ^= byte << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
