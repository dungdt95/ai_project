import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/extensions/app_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/payment_qr_block.dart';
import '../../domain/models/member.dart';
import '../../domain/stats/stats_models.dart';
import '../../services/image_service.dart';
import '../../services/share_text.dart';

/// S15 — Xem trước và chia sẻ báo cáo theo danh mục (SPEC FR-8.7).
///
/// Nhắm tới Mattermost: gửi **text markdown** thì bảng lên đúng cột và người
/// nhận tìm kiếm được số liệu về sau; gửi **ảnh** thì đọc nhanh hơn trong khung
/// chat. Cả hai đều đi qua bảng chia sẻ của hệ điều hành, nên app vẫn không cần
/// quyền mạng nào (NFR-1).
class ReportShareScreen extends StatefulWidget {
  const ReportShareScreen({
    required this.categoryName,
    required this.periodDetail,
    required this.rows,
    this.hiddenCount = 0,
    this.payee,
    super.key,
  });

  /// Khóa của lời nhắc thiếu mã QR, dùng trong widget test.
  static const String missingQrKey = 'report-missing-qr-hint';

  final String categoryName;

  /// Khoảng ngày viết rõ, lấy từ `DateRange.detail`.
  final String periodDetail;

  final List<MemberCategoryStat> rows;

  /// Số người đang bị ẩn khỏi báo cáo, để nói rõ trong nội dung gửi đi.
  final int hiddenCount;

  /// Người nhận tiền, để ảnh có mã QR (SPEC FR-8.8).
  ///
  /// Báo cáo không có "người trả trước" như hóa đơn, nên màn gọi chọn: mặc định
  /// là "Tôi" — người đang chia sẻ, thường cũng là người thu tiền. `null` thì
  /// ảnh không có khối nhận tiền.
  final Member? payee;

  static Future<void> push(
    BuildContext context, {
    required String categoryName,
    required String periodDetail,
    required List<MemberCategoryStat> rows,
    int hiddenCount = 0,
    Member? payee,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => ReportShareScreen(
        categoryName: categoryName,
        periodDetail: periodDetail,
        rows: rows,
        hiddenCount: hiddenCount,
        payee: payee,
      ),
    ),
  );

  @override
  State<ReportShareScreen> createState() => _ReportShareScreenState();
}

class _ReportShareScreenState extends State<ReportShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  String get _text => ShareText.forCategoryReport(
    categoryName: widget.categoryName,
    periodDetail: widget.periodDetail,
    rows: [
      for (final row in widget.rows)
        (name: row.memberName, amount: row.total, billCount: row.billCount),
    ],
    hiddenCount: widget.hiddenCount,
  );

  /// Vì sao ảnh không có mã QR, nếu người dùng tự khắc phục được.
  ///
  /// Khác ảnh hóa đơn ở chỗ này: người dùng **chủ động** bấm chia sẻ báo cáo để
  /// đi thu tiền, nên thiếu thông tin nhận tiền thì phải nói, chứ không im lặng
  /// bỏ khối QR đi.
  String? get _missingQrHint {
    final payee = widget.payee;
    if (payee == null || !payee.hasBankInfo) {
      return 'Ảnh chưa có mã QR nhận tiền. Vào Thành viên → Tôi → thêm thông '
          'tin nhận tiền.';
    }
    if (PaymentQrBlock.payload(payee, widget.categoryName) == null) {
      return 'Ảnh chưa có mã QR vì ${payee.displayName} chưa chọn ngân hàng '
          'nhận tiền. Vào Thành viên → sửa để thêm.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chia sẻ báo cáo'),
        actions: [
          IconButton(
            tooltip: 'Chép nội dung',
            icon: const Icon(Icons.copy_outlined),
            onPressed: _copy,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.s16),
        children: [
          // RepaintBoundary là thứ cho phép chụp đúng vùng này thành ảnh.
          RepaintBoundary(
            key: _cardKey,
            child: ReportShareCard(
              categoryName: widget.categoryName,
              periodDetail: widget.periodDetail,
              rows: widget.rows,
              hiddenCount: widget.hiddenCount,
              payee: widget.payee,
              qrDescription: widget.categoryName,
            ),
          ),
          // Nằm ngoài RepaintBoundary: lời nhắc này dành cho người gửi, không
          // được lọt vào ảnh gửi đi.
          if (_missingQrHint case final hint?) ...[
            const SizedBox(height: AppTheme.s12),
            Text(
              hint,
              key: const Key(ReportShareScreen.missingQrKey),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.warningFg,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.s24),
          Text(
            'Gửi text thì Mattermost dựng thành bảng và tìm kiếm được về sau; '
            'gửi ảnh thì đọc nhanh hơn trong khung chat.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppTheme.s16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _shareImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Gửi ảnh'),
              ),
            ),
            const SizedBox(width: AppTheme.s12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _shareText,
                icon: const Icon(Icons.text_fields),
                label: const Text('Gửi text'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareText() => SharePlus.instance.share(
    ShareParams(text: _text, subject: widget.categoryName),
  );

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));
    if (!mounted) return;
    // Dán vào Mattermost trên máy tính là đường đi khác hẳn với bảng chia sẻ
    // của điện thoại, nên nút chép đứng riêng chứ không nằm trong bảng đó.
    AppSnackBar.success(context, 'Đã chép nội dung báo cáo.');
  }

  Future<void> _shareImage() async {
    setState(() => _busy = true);

    final result = await ImageService.captureWidget(
      _cardKey,
      fileName: 'bao-cao-theo-danh-muc.png',
    );
    if (!mounted) return;
    setState(() => _busy = false);

    await result.when(
      ok: (file) async => SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: widget.categoryName),
      ),
      err: (error) async => AppSnackBar.error(context, error.message),
    );
  }
}

/// Thẻ báo cáo, dùng để xem trước và để chụp thành ảnh.
///
/// Tự vẽ nền và màu chữ thay vì lấy từ theme: ảnh gửi đi phải đọc được trên
/// mọi nền chat, kể cả khi người gửi đang dùng chế độ tối.
class ReportShareCard extends StatelessWidget {
  const ReportShareCard({
    required this.categoryName,
    required this.periodDetail,
    required this.rows,
    this.hiddenCount = 0,
    this.payee,
    this.qrDescription = '',
    super.key,
  });

  final String categoryName;
  final String periodDetail;
  final List<MemberCategoryStat> rows;
  final int hiddenCount;

  /// Người nhận tiền; `null` thì không có khối QR.
  final Member? payee;

  /// Nội dung chuyển khoản điền sẵn trong QR.
  final String qrDescription;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold(0, (sum, row) => sum + row.total);

    return Container(
      padding: const EdgeInsets.all(AppTheme.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16201C),
            ),
          ),
          const SizedBox(height: AppTheme.s4),
          Text(
            periodDetail,
            style: const TextStyle(fontSize: 13, color: Color(0xFF3F4947)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.s12),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),

          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.s8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.memberName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF16201C),
                      ),
                    ),
                  ),
                  Text(
                    total == 0 ? '' : '${(row.total * 100 / total).round()}%  ',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF3F4947),
                    ),
                  ),
                  Text(
                    row.total.toVnd(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16201C),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: AppTheme.s16, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tổng',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16201C),
                  ),
                ),
              ),
              Text(
                total.toVnd(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.seed,
                ),
              ),
            ],
          ),

          if (hiddenCount > 0) ...[
            const SizedBox(height: AppTheme.s8),
            Text(
              'Đang ẩn $hiddenCount người khỏi báo cáo này.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF3F4947)),
            ),
          ],

          if (payee case final payee? when payee.hasBankInfo) ...[
            const SizedBox(height: AppTheme.s16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: AppTheme.s12),
            PaymentQrBlock(payee: payee, description: qrDescription),
          ],
        ],
      ),
    );
  }
}
