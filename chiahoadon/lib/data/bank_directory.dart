import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/utils/vn_text.dart';

/// Một ngân hàng trong danh mục dùng để sinh VietQR (SPEC FR-6.7).
class Bank {
  const Bank({
    required this.bin,
    required this.shortName,
    required this.name,
  });

  factory Bank.fromJson(Map<String, dynamic> json) => Bank(
    bin: json['bin'] as String,
    shortName: json['short'] as String,
    name: json['name'] as String,
  );

  /// Mã BIN 6 chữ số do NAPAS cấp.
  final String bin;

  /// Tên quen dùng: "Vietcombank", "MB Bank".
  final String shortName;

  /// Tên đầy đủ theo giấy phép.
  final String name;

  @override
  String toString() => '$shortName ($bin)';
}

/// Danh mục ngân hàng, đọc từ `assets/data/banks.json`.
///
/// Đi kèm app chứ không tải về: app cam kết chạy offline (NFR-1), nên danh
/// sách phải có sẵn ngay cả ở lần mở đầu tiên khi máy đang ở chế độ máy bay.
///
/// Đổi lại, danh sách có thể cũ đi khi ngân hàng đổi tên hoặc sáp nhập. Vì vậy
/// ô "Tên ngân hàng" **vẫn cho gõ tay**: chọn trong danh sách là đường nhanh,
/// không phải đường duy nhất.
class BankDirectory {
  const BankDirectory._();

  static const String assetPath = 'assets/data/banks.json';

  static List<Bank>? _cache;

  /// Toàn bộ danh mục, đọc một lần rồi giữ lại trong bộ nhớ.
  static Future<List<Bank>> all() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final banks = [
      for (final item in json['banks'] as List<dynamic>)
        Bank.fromJson(item as Map<String, dynamic>),
    ];

    return _cache = banks;
  }

  /// Tìm theo tên hoặc mã BIN, **bỏ dấu** — gõ "ky thuong" ra Techcombank.
  static Future<List<Bank>> search(String query) async {
    final banks = await all();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return banks;

    final needle = VnText.normalize(trimmed);

    return [
      for (final bank in banks)
        if (VnText.normalize(bank.shortName).contains(needle) ||
            VnText.normalize(bank.name).contains(needle) ||
            bank.bin.contains(trimmed))
          bank,
    ];
  }

  /// Ngân hàng có mã BIN cho trước, hoặc `null` nếu không có trong danh mục.
  static Future<Bank?> byBin(String? bin) async {
    if (bin == null || bin.isEmpty) return null;

    for (final bank in await all()) {
      if (bank.bin == bin) return bank;
    }
    return null;
  }

  /// Chỉ dùng trong test, để mỗi test bắt đầu với bộ nhớ đệm rỗng.
  static void clearCacheForTest() => _cache = null;
}
