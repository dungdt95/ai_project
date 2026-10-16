import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/app_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/payment_qr_block.dart';
import '../../../domain/models/bill.dart';
import '../../../domain/models/member.dart';
import '../../../services/image_service.dart';
import '../../../services/share_text.dart';
import '../../members/members_provider.dart';

/// S14 — Xem trước và chia sẻ kết quả chia tiền (SPEC FR-8.1, FR-8.2).
///
/// Cho xem trước đúng thứ sẽ gửi đi, rồi mới chọn gửi dạng text hay dạng ảnh.
/// Text thì sao chép được số tài khoản; ảnh thì đọc nhanh hơn trong khung chat.
class SharePreviewScreen extends ConsumerStatefulWidget {
  const SharePreviewScreen({required this.bill, super.key});

  /// Khóa của lời nhắc thiếu ngân hàng, dùng trong widget test.
  static const String missingQrKey = 'share-missing-qr-hint';

  final Bill bill;

  static Future<void> push(BuildContext context, Bill bill) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => SharePreviewScreen(bill: bill),
        ),
      );

  @override
  ConsumerState<SharePreviewScreen> createState() => _SharePreviewScreenState();
}

class _SharePreviewScreenState extends ConsumerState<SharePreviewScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final member in members) member.id: member};

    return Scaffold(
      appBar: AppBar(title: const Text('Chia sẻ')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.s16),
        children: [
          // RepaintBoundary là thứ cho phép chụp đúng vùng này thành ảnh.
          RepaintBoundary(
            key: _cardKey,
            child: ShareCard(bill: widget.bill, members: byId),
          ),
          // Nằm ngoài RepaintBoundary: lời nhắc này dành cho người gửi, không
          // được lọt vào ảnh gửi đi.
          if (_missingQrHint(byId) case final hint?) ...[
            const SizedBox(height: AppTheme.s12),
            Text(
              hint,
              key: const Key(SharePreviewScreen.missingQrKey),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.warningFg),
            ),
          ],
          const SizedBox(height: AppTheme.s24),
          Text(
            'Ảnh dễ đọc trong khung chat; text thì người nhận sao chép được '
            'số tài khoản.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                onPressed: _busy ? null : _shareText,
                icon: const Icon(Icons.text_fields),
                label: const Text('Gửi text'),
              ),
            ),
            const SizedBox(width: AppTheme.s12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _shareImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Gửi ảnh'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lý do ảnh không có mã QR, nếu người dùng có thể tự khắc phục.
  ///
  /// Chỉ nói khi người trả trước **đã có** số tài khoản mà thiếu ngân hàng —
  /// đó là trường hợp người dùng tưởng mình đã nhập đủ. Chưa có tài khoản nào
  /// thì không có gì để nhắc: họ chưa định gửi thông tin chuyển khoản.
  String? _missingQrHint(Map<String, Member> byId) {
    if (widget.bill.payers.isEmpty) return null;

    final payer = byId[widget.bill.payers.first.memberId];
    if (payer == null || !payer.hasBankInfo) return null;
    if (ShareCard.qrPayload(widget.bill, byId) != null) return null;

    return 'Ảnh chưa có mã QR vì ${payer.displayName} chưa chọn ngân hàng '
        'nhận tiền. Vào Thành viên → sửa để thêm.';
  }

  Future<void> _shareText() async {
    final members = ref.read(membersProvider).value ?? const <Member>[];
    final text = ShareText.forBill(
      widget.bill,
      members: {for (final member in members) member.id: member},
    );

    await SharePlus.instance.share(
      ShareParams(text: text, subject: widget.bill.title),
    );
  }

  Future<void> _shareImage() async {
    setState(() => _busy = true);

    final result = await ImageService.captureWidget(
      _cardKey,
      fileName: 'chia-hoa-don.png',
    );
    if (!mounted) return;
    setState(() => _busy = false);

    await result.when(
      ok: (file) async => SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: widget.bill.title),
      ),
      err: (error) async => AppSnackBar.error(context, error.message),
    );
  }
}

/// Thẻ kết quả chia tiền, dùng để xem trước và để chụp thành ảnh.
///
/// Tự vẽ nền và màu chữ thay vì lấy từ theme: ảnh gửi đi phải đọc được trên
/// mọi nền chat, kể cả khi người gửi đang dùng chế độ tối.
class ShareCard extends StatelessWidget {
  const ShareCard({required this.bill, required this.members, super.key});

  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _ink = Color(0xFF1A1A19);
  static const Color _muted = Color(0xFF6B7280);

  /// Khóa của khung chứa mã QR, dùng trong widget test.
  static const String qrKey = PaymentQrBlock.qrKey;

  final Bill bill;
  final Map<String, Member> members;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(AppTheme.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bill.title,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: AppTheme.s4),
          Text(
            DateFormatter.withWeekday(
              DateTime.fromMillisecondsSinceEpoch(bill.billDate),
            ),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: _muted,
            ),
          ),

          const SizedBox(height: AppTheme.s16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.s12),
            decoration: BoxDecoration(
              color: AppColors.seed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
            child: Column(
              children: [
                const Text(
                  'TỔNG CỘNG',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: _muted,
                  ),
                ),
                Text(
                  bill.totalAmount.toVnd(),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.seed,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (bill.hasSurcharge)
                  Text(
                    _surchargeNote(),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: _muted,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.s16),
          for (final participant in bill.participants)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  MemberAvatar.small(
                    name:
                        members[participant.memberId]?.displayName ??
                        participant.memberNameSnapshot,
                    color: members[participant.memberId]?.avatarColor,
                  ),
                  const SizedBox(width: AppTheme.s12),
                  Expanded(
                    child: Text(
                      members[participant.memberId]?.displayName ??
                          participant.memberNameSnapshot,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        color: _ink,
                      ),
                    ),
                  ),
                  if (participant.paidAmount >= participant.shareAmount)
                    const Padding(
                      padding: EdgeInsets.only(right: AppTheme.s8),
                      child: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.paid,
                      ),
                    ),
                  Text(
                    participant.shareAmount.toVnd(),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),

          if (_payer(bill, members) != null) ...[
            const SizedBox(height: AppTheme.s16),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: AppTheme.s12),
            PaymentQrBlock(
              payee: _payer(bill, members)!,
              description: bill.title,
            ),
          ],

          const SizedBox(height: AppTheme.s16),
          const Center(
            child: Text(
              AppConstants.appName,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _surchargeNote() {
    final parts = <String>[
      if (bill.discountAmount != 0) 'giảm ${bill.discountAmount.toVnd()}',
      if (bill.taxAmount != 0) 'VAT ${bill.taxAmount.toVnd()}',
      if (bill.serviceAmount != 0) 'phí DV ${bill.serviceAmount.toVnd()}',
      if (bill.tipAmount != 0) 'tip ${bill.tipAmount.toVnd()}',
    ];
    return 'gồm ${parts.join(' + ')}';
  }

  /// Chuỗi VietQR của người trả trước, hoặc `null` nếu không sinh được.
  ///
  /// Quy tắc sinh mã (QR tĩnh, thiếu ngân hàng thì không dựng) nằm ở
  /// [PaymentQrBlock.payload], dùng chung với ảnh báo cáo.
  static String? qrPayload(Bill bill, Map<String, Member> members) {
    final payer = _payer(bill, members);
    return payer == null ? null : PaymentQrBlock.payload(payer, bill.title);
  }

  /// Người trả trước nếu đã có số tài khoản, ngược lại `null`.
  static Member? _payer(Bill bill, Map<String, Member> members) {
    if (bill.payers.isEmpty) return null;

    final payer = members[bill.payers.first.memberId];
    return payer == null || !payer.hasBankInfo ? null : payer;
  }
}
