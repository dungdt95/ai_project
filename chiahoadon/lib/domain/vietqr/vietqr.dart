/// Sinh chuỗi VietQR theo chuẩn EMVCo (SPEC FR-6.7).
///
/// Toàn bộ việc sinh mã diễn ra **ngay trên máy**: chuỗi QR chỉ là ghép các
/// trường theo định dạng rồi tính một mã kiểm tra. Không có bước nào cần gọi
/// mạng, nên tính năng này không phá cam kết chạy offline (NFR-1).
///
/// Chuỗi sinh ra là thứ app ngân hàng đọc được khi quét — nó **không** chuyển
/// tiền, chỉ điền sẵn người nhận và số tiền để người quét tự xác nhận.
library;

import '../../core/utils/vn_text.dart';

/// Mã định danh của NAPAS trong trường 38 — cố định với mọi QR chuyển khoản.
const String _napasGuid = 'A000000727';

/// Chuyển khoản tới **số tài khoản** (khác với QRIBFTTC: tới số thẻ).
const String _serviceTransferToAccount = 'QRIBFTTA';

/// Một yêu cầu sinh QR, đã được kiểm tra hợp lệ.
class VietQrRequest {
  const VietQrRequest({
    required this.bankBin,
    required this.accountNumber,
    this.amount = 0,
    this.description = '',
  });

  /// Mã BIN 6 chữ số của ngân hàng nhận (xem `assets/data/banks.json`).
  final String bankBin;

  final String accountNumber;

  /// Số tiền, đơn vị đồng. `0` nghĩa là để người quét tự nhập (QR tĩnh).
  final int amount;

  /// Nội dung chuyển khoản. Dấu tiếng Việt sẽ bị bỏ khi đưa vào QR.
  final String description;

  /// Lỗi khiến không sinh được QR, hoặc `null` nếu hợp lệ.
  VietQrError? get error {
    if (!RegExp(r'^\d{6}$').hasMatch(bankBin)) return VietQrError.badBankBin;

    final account = accountNumber.trim();
    if (account.isEmpty) return VietQrError.noAccount;
    if (!RegExp(r'^[A-Za-z0-9]{4,19}$').hasMatch(account)) {
      return VietQrError.badAccount;
    }

    if (amount < 0) return VietQrError.negativeAmount;
    // Trường số tiền của EMVCo tối đa 13 ký tự.
    if (amount > 9999999999999) return VietQrError.amountTooLarge;

    return null;
  }

  bool get isValid => error == null;
}

/// Vì sao không sinh được QR. Thông điệp bằng tiếng Việt, hiện thẳng lên UI.
enum VietQrError {
  badBankBin('Chưa chọn ngân hàng nhận tiền.'),
  noAccount('Chưa có số tài khoản.'),
  badAccount('Số tài khoản chỉ gồm chữ và số, dài 4 đến 19 ký tự.'),
  negativeAmount('Số tiền không được âm.'),
  amountTooLarge('Số tiền vượt quá giới hạn của chuẩn QR.');

  const VietQrError(this.message);

  final String message;
}

/// Sinh chuỗi VietQR, hoặc `null` nếu [request] không hợp lệ.
///
/// Trả `null` thay vì ném lỗi vì chỗ gọi luôn là giao diện: thiếu số tài khoản
/// là chuyện bình thường, không phải lỗi lập trình.
String? buildVietQr(VietQrRequest request) {
  if (!request.isValid) return null;

  final account = request.accountNumber.trim();

  final beneficiary = _tlv('00', request.bankBin) + _tlv('01', account);
  final merchantAccount =
      _tlv('00', _napasGuid) +
      _tlv('01', beneficiary) +
      _tlv('02', _serviceTransferToAccount);

  final payload = StringBuffer()
    ..write(_tlv('00', '01'))
    // 11 = QR dùng lại nhiều lần, 12 = QR một lần. Có số tiền thì là một lần.
    ..write(_tlv('01', request.amount > 0 ? '12' : '11'))
    ..write(_tlv('38', merchantAccount))
    ..write(_tlv('53', '704')) // VND theo ISO 4217
    ;

  if (request.amount > 0) {
    payload.write(_tlv('54', request.amount.toString()));
  }

  payload.write(_tlv('58', 'VN'));

  final note = _sanitizeDescription(request.description);
  if (note.isNotEmpty) {
    payload.write(_tlv('62', _tlv('08', note)));
  }

  // Mã kiểm tra tính trên **cả** "6304" đứng trước nó, nên phải nối vào rồi
  // mới tính — đây là chỗ dễ sai nhất của định dạng này.
  final withCrcTag = '$payload' '6304';
  return withCrcTag + crc16CcittFalse(withCrcTag);
}

/// Một trường theo kiểu tag–length–value: `IDIDLLvalue`.
String _tlv(String id, String value) =>
    '$id${value.length.toString().padLeft(2, '0')}$value';

/// Bỏ dấu và cắt bớt nội dung chuyển khoản.
///
/// App ngân hàng chỉ nhận ASCII ở nội dung chuyển khoản; để nguyên dấu tiếng
/// Việt thì có máy hiện ra ký tự hỏng, có máy từ chối cả mã QR.
String _sanitizeDescription(String raw) {
  final ascii = VnText.normalize(raw)
      .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toUpperCase();

  // Trường 62-08 tối đa 99 ký tự, nhưng nhiều ngân hàng cắt ở 25 — cắt sẵn cho
  // chắc, và cắt ở ranh giới từ để nội dung còn đọc được.
  if (ascii.length <= 25) return ascii;

  final cut = ascii.substring(0, 25);
  final lastSpace = cut.lastIndexOf(' ');
  return lastSpace > 10 ? cut.substring(0, lastSpace) : cut;
}

/// CRC-16/CCITT-FALSE: khởi tạo `0xFFFF`, đa thức `0x1021`, không đảo bit.
///
/// Tự viết thay vì kéo thêm thư viện: đúng tám dòng, và biến thể CRC mà chuẩn
/// EMVCo dùng **không** phải biến thể mặc định của phần lớn thư viện — gọi
/// nhầm biến thể thì chuỗi vẫn trông đúng nhưng app ngân hàng từ chối quét.
///
/// Công khai thay vì để riêng tư để test đối chiếu được với giá trị kiểm chuẩn
/// của thuật toán: CRC của chuỗi `123456789` phải là `29B1`.
String crc16CcittFalse(String input) {
  var crc = 0xFFFF;

  for (final byte in input.codeUnits) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }

  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}
