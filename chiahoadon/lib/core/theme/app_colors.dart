import 'package:flutter/material.dart';

/// Bảng màu của app (PLAN §5.4).
class AppColors {
  const AppColors._();

  /// Màu chủ đạo: xanh teal — tin cậy nhưng không trùng nhận diện app ngân hàng.
  static const Color seed = Color(0xFF0D9488);

  // ─── Màu trạng thái thanh toán ───
  /// Chưa trả.
  static const Color unpaid = Color(0xFFDC2626);

  /// Trả một phần.
  static const Color partial = Color(0xFFF59E0B);

  /// Đã trả xong.
  static const Color paid = Color(0xFF16A34A);

  /// Nháp / không áp dụng.
  static const Color neutral = Color(0xFF9CA3AF);

  /// Cảnh báo nhẹ (vd món chưa chọn ai dùng — FR-4.2).
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningFg = Color(0xFF92400E);

  /// Người khác nợ mình (số dư ròng dương).
  static const Color creditor = Color(0xFF16A34A);

  /// Mình nợ người khác (số dư ròng âm).
  static const Color debtor = Color(0xFFDC2626);

  /// 12 màu avatar, chọn theo `hash(tên) % 12` để mỗi người có màu cố định.
  ///
  /// Đã chọn độ đậm vừa phải để chữ trắng luôn đọc được trên nền này,
  /// ở cả chế độ sáng và tối.
  static const List<Color> avatarPalette = [
    Color(0xFF0D9488), // teal
    Color(0xFF2563EB), // blue
    Color(0xFF7C3AED), // violet
    Color(0xFFDB2777), // pink
    Color(0xFFDC2626), // red
    Color(0xFFEA580C), // orange
    Color(0xFFCA8A04), // yellow-dark
    Color(0xFF65A30D), // lime-dark
    Color(0xFF059669), // emerald
    Color(0xFF0891B2), // cyan
    Color(0xFF4F46E5), // indigo
    Color(0xFF9333EA), // purple
  ];

  /// Bảng màu cho biểu đồ phân loại (biểu đồ tròn tỷ trọng).
  ///
  /// **Khác với [avatarPalette] một cách có chủ ý.** Màu avatar được chọn theo
  /// hàm băm tên nên hai người cạnh nhau có thể ra hai màu rất giống nhau —
  /// chấp nhận được khi luôn có tên bên cạnh, nhưng không đủ cho các lát bánh
  /// nằm sát nhau.
  ///
  /// Bộ màu dưới đây đã qua kiểm định tự động và **đạt cả sáu tiêu chí**: dải
  /// độ sáng, sàn độ bão hòa, phân tách cho người mù màu (deutan/protan/tritan),
  /// sàn phân biệt cho mắt thường, và tương phản ≥ 3:1 với nền.
  ///
  /// Thứ tự là cố định, không được xoay vòng: màu đi theo *thực thể*, không đi
  /// theo thứ hạng, nên lọc bớt dữ liệu không làm đổi màu của phần còn lại.
  /// Quá 6 mục thì gom phần còn lại vào "Khác" thay vì sinh thêm màu.
  static const List<Color> chartPaletteLight = [
    Color(0xFF0D9488), // teal
    Color(0xFFA16207), // amber đậm
    Color(0xFFBE185D), // hồng đậm
    Color(0xFF1D4ED8), // xanh dương
    Color(0xFF65A30D), // lime
    Color(0xFF7E22CE), // tím
  ];

  /// Bộ màu riêng cho nền tối — **chọn lại từ cùng các dải màu**, không phải
  /// đảo ngược bộ sáng. Cũng đã qua kiểm định và đạt cả sáu tiêu chí.
  static const List<Color> chartPaletteDark = [
    Color(0xFF0D9488),
    Color(0xFFD97706),
    Color(0xFFEC4899),
    Color(0xFF3B82F6),
    Color(0xFF65A30D),
    Color(0xFFA855F7),
  ];

  /// Màu cho phần "Khác" khi gom các mục nhỏ lại.
  static const Color chartOther = Color(0xFF6B7280);

  static List<Color> chartPaletteFor(Brightness brightness) =>
      brightness == Brightness.dark ? chartPaletteDark : chartPaletteLight;
}
