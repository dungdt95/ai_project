import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/extensions/app_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../domain/models/member.dart';
import '../../domain/vietqr/vietqr.dart';

/// Mã QR chuyển khoản tới một thành viên (SPEC FR-6.7).
///
/// Mã sinh ngay trên máy từ số tài khoản đã lưu, không gọi dịch vụ nào — nên
/// vẫn quét được khi đang ở chế độ máy bay (NFR-1).
///
/// Đây **không** phải thanh toán trong app: app chỉ điền sẵn người nhận, số
/// tiền và nội dung; việc chuyển tiền do app ngân hàng của người quét làm.
class TransferQrSheet extends StatelessWidget {
  const TransferQrSheet({
    required this.payee,
    required this.amount,
    required this.note,
    super.key,
  });

  /// Người **nhận** tiền — QR mang số tài khoản của người này.
  final Member payee;

  /// Số tiền điền sẵn, đơn vị đồng. `0` để người quét tự nhập.
  final int amount;

  final String note;

  static Future<void> show(
    BuildContext context, {
    required Member payee,
    int amount = 0,
    String note = '',
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        TransferQrSheet(payee: payee, amount: amount, note: note),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = VietQrRequest(
      bankBin: payee.bankBin ?? '',
      accountNumber: payee.bankAccount ?? '',
      amount: amount,
      description: note,
    );
    final payload = buildVietQr(request);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chuyển cho ${payee.displayName}',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.s16),

            if (payload == null)
              _CannotGenerate(error: request.error!)
            else ...[
              // Nền trắng cố định, không theo theme: máy quét đọc mã bằng độ
              // tương phản, nền tối là nhiều máy không bắt được.
              Container(
                padding: const EdgeInsets.all(AppTheme.s16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                ),
                child: QrImageView(
                  data: payload,
                  size: 220,
                  backgroundColor: Colors.white,
                  // Mức sửa lỗi M: đủ để quét khi ảnh hơi mờ, mà mã không quá
                  // dày ô khiến màn hình nhỏ khó bắt nét.
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: AppTheme.s16),

              if (amount > 0)
                Text(
                  amount.toVnd(),
                  style: MoneyTextStyle.large.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Text(
                  'Người quét tự nhập số tiền',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

              const SizedBox(height: AppTheme.s16),
              _AccountRow(payee: payee),
              const SizedBox(height: AppTheme.s8),
              Text(
                'Quét bằng app ngân hàng để chuyển khoản.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: AppTheme.s16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Số tài khoản kèm nút sao chép.
///
/// Có nút sao chép vì không phải máy nào cũng quét được QR từ màn hình máy
/// khác — khi đó người dùng nhập tay, và nhập sai một chữ số là tiền đi lạc.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.payee});

  final Member payee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = payee.bankAccount ?? '';

    return Column(
      children: [
        Text(
          payee.bankName ?? '',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              account,
              style: MoneyTextStyle.small,
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Sao chép số tài khoản',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: account));
                if (context.mounted) {
                  AppSnackBar.success(context, 'Đã sao chép số tài khoản');
                }
              },
            ),
          ],
        ),
        if (payee.bankHolder != null)
          Text(
            payee.bankHolder!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Nói rõ thiếu gì thay vì hiện một ô trống.
class _CannotGenerate extends StatelessWidget {
  const _CannotGenerate({required this.error});

  final VietQrError error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          Icons.qr_code_2_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppTheme.s8),
        Text(
          error.message,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.s4),
        Text(
          'Mở hồ sơ thành viên để bổ sung thông tin nhận tiền.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
