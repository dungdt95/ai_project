import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/models/member.dart';
import '../../domain/vietqr/vietqr.dart';
import '../theme/app_theme.dart';

/// Khối "nhận tiền" của ảnh chia sẻ: mã QR cạnh số tài khoản (SPEC FR-8.8).
///
/// Dùng chung cho ảnh hóa đơn và ảnh báo cáo theo danh mục, để hai ảnh không
/// sinh mã theo hai cách khác nhau — hai nơi ra hai chuỗi QR cho cùng một
/// tài khoản là một nơi sai mà không ai biết nơi nào.
///
/// Tự vẽ màu thay vì lấy từ theme, như mọi thứ nằm trong ảnh gửi đi: ảnh phải
/// đọc được trên mọi nền chat, kể cả khi người gửi đang dùng chế độ tối.
class PaymentQrBlock extends StatelessWidget {
  const PaymentQrBlock({
    required this.payee,
    required this.description,
    super.key,
  });

  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _ink = Color(0xFF1A1A19);
  static const Color _muted = Color(0xFF6B7280);

  /// Cạnh mã QR, đơn vị logic. Chụp ở pixelRatio 3 nên ra 336px — đủ nét để
  /// quét lại từ ảnh đã bị chat nén.
  static const double qrSize = 112;

  /// Khóa của khung chứa mã QR, dùng trong widget test.
  static const String qrKey = 'payment-qr-frame';

  /// Người nhận tiền.
  final Member payee;

  /// Nội dung chuyển khoản điền sẵn (bỏ dấu và cắt ngắn khi đưa vào QR).
  final String description;

  /// Chuỗi VietQR của [payee], hoặc `null` nếu không sinh được.
  ///
  /// **Không điền số tiền**: ảnh chia sẻ có nhiều người nợ những số khác nhau
  /// mà chỉ một mã. Điền tổng hay phần của một người thì những người còn lại
  /// quét ra sai tiền; để trống thì người quét tự nhập phần của mình, đọc ngay
  /// trong danh sách phía trên mã (QR tĩnh, SPEC FR-8.8).
  ///
  /// Trả `null` khi chưa chọn ngân hàng: chỉ có số tài khoản thì thiếu mã BIN,
  /// mà đoán BIN là chuyển tiền sang nhầm ngân hàng (PLAN 13.17).
  static String? payload(Member payee, String description) {
    if (!payee.hasBankInfo) return null;

    return buildVietQr(
      VietQrRequest(
        bankBin: payee.bankBin ?? '',
        accountNumber: payee.bankAccount ?? '',
        description: description,
      ),
    );
  }

  /// Dòng chữ số tài khoản: `💸 Tôi · Vietcombank 0123456789`.
  static String bankLine(Member payee) =>
      '💸 ${payee.bankHolder ?? payee.name} · '
              '${payee.bankName ?? ''} ${payee.bankAccount}'
          .trim();

  @override
  Widget build(BuildContext context) {
    final qr = payload(payee, description);

    // Số tài khoản bằng chữ **luôn** có, kể cả khi có QR: không phải máy nào
    // cũng quét được mã từ một tấm ảnh trong khung chat, và khi đó người ta
    // nhập tay.
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bankLine(payee),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: _ink,
          ),
        ),
        if (qr != null) ...[
          const SizedBox(height: AppTheme.s4),
          const Text(
            'Quét bằng app ngân hàng, rồi nhập số tiền phần của bạn.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: _muted,
            ),
          ),
        ],
      ],
    );

    if (qr == null) return text;

    return Row(
      children: [
        // Nền trắng và vùng đệm quanh mã là bắt buộc, không phải trang trí:
        // máy quét cần viền trống mới bắt được mã. Ảnh nằm trên nền chat tối
        // vẫn quét được vì viền trắng nằm sẵn trong ảnh.
        Container(
          key: const Key(qrKey),
          padding: const EdgeInsets.all(AppTheme.s8),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: QrImageView(
            data: qr,
            size: qrSize,
            backgroundColor: _surface,
            // Mức M như màn QR chuyển khoản: ảnh gửi qua chat bị nén, cần dư
            // chút khả năng sửa lỗi, mà không dày ô tới mức khó bắt nét.
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        const SizedBox(width: AppTheme.s12),
        Expanded(child: text),
      ],
    );
  }
}
