import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'vn_text.dart';

/// Sinh màu avatar cố định từ tên thành viên (SPEC FR-1.3).
///
/// Cùng một tên luôn cho ra cùng một màu, kể cả sau khi cài lại app, vì màu
/// được tính từ hàm băm của tên đã bỏ dấu — không lưu trạng thái, không random.
class AvatarColor {
  const AvatarColor._();

  /// Chỉ số màu trong [AppColors.avatarPalette] ứng với tên này.
  static int indexFor(String name) {
    final normalized = VnText.normalize(name);
    if (normalized.isEmpty) return 0;

    // FNV-1a 32-bit: phân bố đều và cho kết quả giống nhau trên mọi nền tảng.
    var hash = 0x811c9dc5;
    for (final codeUnit in normalized.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    return hash % AppColors.avatarPalette.length;
  }

  /// Màu nền avatar cho tên này.
  static Color forName(String name) =>
      AppColors.avatarPalette[indexFor(name)];

  /// Màu nền avatar từ giá trị đã lưu trong cột `members.avatar_color`.
  ///
  /// Lưu màu vào DB thay vì tính lại mỗi lần để người dùng đổi tên thành viên
  /// mà avatar không nhảy sang màu khác.
  static Color fromStored(int argb) => Color(argb);

  /// Giá trị ARGB để lưu vào DB.
  static int toStored(String name) => forName(name).toARGB32();
}
