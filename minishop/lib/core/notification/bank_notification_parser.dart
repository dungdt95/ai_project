class ParsedBankNotification {
  final int? amount;
  final String? invoiceCode;

  const ParsedBankNotification({this.amount, this.invoiceCode});
}

/// Extracts the transferred amount and invoice code (e.g. HD000001 — the
/// string we put in the VietQR "addInfo"/transfer content) from a raw
/// banking-app notification text.
///
/// Notification wording differs per bank and can change whenever the bank
/// updates its app, so this stays a single, easy-to-tweak generic parser
/// rather than version-specific regexes baked in elsewhere. If a particular
/// bank's notifications don't parse correctly, add an override in
/// [_packageOverrides] keyed by package name.
class BankNotificationParser {
  static ParsedBankNotification parse(String packageName, String rawText) {
    final override = _packageOverrides[packageName];
    if (override != null) return override(rawText);
    return _genericParse(rawText);
  }

  static final Map<String, ParsedBankNotification Function(String)>
      _packageOverrides = {};

  static ParsedBankNotification _genericParse(String rawText) {
    return ParsedBankNotification(
      amount: _extractAmount(rawText),
      invoiceCode: _extractInvoiceCode(rawText),
    );
  }

  static int? _extractAmount(String text) {
    final creditedPattern =
        RegExp(r'\+\s*([\d.,]+)\s*(?:đ|vnd|vnđ)', caseSensitive: false);
    final anyAmountPattern =
        RegExp(r'([\d.,]+)\s*(?:đ|vnd|vnđ)', caseSensitive: false);

    final match =
        creditedPattern.firstMatch(text) ?? anyAmountPattern.firstMatch(text);
    if (match == null) return null;

    final digitsOnly = match.group(1)!.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return null;
    return int.tryParse(digitsOnly);
  }

  static String? _extractInvoiceCode(String text) {
    final match = RegExp(r'HD\d{6}', caseSensitive: false).firstMatch(text);
    return match?.group(0)?.toUpperCase();
  }
}
