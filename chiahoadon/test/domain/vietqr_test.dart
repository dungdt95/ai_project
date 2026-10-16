import 'package:chiahoadon/domain/vietqr/vietqr.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kiểm chuỗi VietQR (SPEC FR-6.7).
///
/// Chuỗi sai một ký tự là app ngân hàng từ chối quét, mà lúc đó không có cách
/// nào biết sai ở đâu — nên các trường được bóc tách và đối chiếu từng cái,
/// chứ không chỉ so chuỗi cuối với một giá trị chép sẵn.
void main() {
  /// Đọc giá trị của trường [id] ở mức ngoài cùng của [payload].
  String? fieldOf(String payload, String id) {
    var i = 0;
    while (i + 4 <= payload.length) {
      final tag = payload.substring(i, i + 2);
      final length = int.parse(payload.substring(i + 2, i + 4));
      final value = payload.substring(i + 4, i + 4 + length);
      if (tag == id) return value;
      i += 4 + length;
    }
    return null;
  }

  group('Cấu trúc chuỗi', () {
    test('QR có số tiền chứa đủ các trường bắt buộc', () {
      final qr = buildVietQr(
        const VietQrRequest(
          bankBin: '970436',
          accountNumber: '1234567890',
          amount: 250000,
          description: 'An trả tiền lẩu',
        ),
      )!;

      expect(fieldOf(qr, '00'), '01', reason: 'Phiên bản định dạng');
      expect(fieldOf(qr, '01'), '12', reason: 'Có số tiền thì là QR một lần');
      expect(fieldOf(qr, '53'), '704', reason: 'Tiền tệ VND');
      expect(fieldOf(qr, '54'), '250000', reason: 'Số tiền, không có số lẻ');
      expect(fieldOf(qr, '58'), 'VN');

      // Trường 38 lồng ba tầng: GUID của NAPAS, thông tin người nhận, mã dịch vụ.
      final merchant = fieldOf(qr, '38')!;
      expect(fieldOf(merchant, '00'), 'A000000727');
      expect(fieldOf(merchant, '02'), 'QRIBFTTA');

      final beneficiary = fieldOf(merchant, '01')!;
      expect(fieldOf(beneficiary, '00'), '970436', reason: 'Mã BIN ngân hàng');
      expect(fieldOf(beneficiary, '01'), '1234567890');
    });

    test('không có số tiền thì là QR tĩnh và bỏ hẳn trường 54', () {
      final qr = buildVietQr(
        const VietQrRequest(bankBin: '970436', accountNumber: '1234567890'),
      )!;

      expect(fieldOf(qr, '01'), '11', reason: 'QR dùng lại nhiều lần');
      expect(
        fieldOf(qr, '54'),
        isNull,
        reason: 'Để trường rỗng khác hẳn với không có trường — app ngân hàng '
            'có thể từ chối trường rỗng',
      );
    });

    test('mọi trường đều khai đúng độ dài của chính nó', () {
      final qr = buildVietQr(
        const VietQrRequest(
          bankBin: '970415',
          accountNumber: '113000000001',
          amount: 1000,
          description: 'Test',
        ),
      )!;

      // Đi hết chuỗi: nếu một trường khai sai độ dài thì vòng lặp sẽ lệch và
      // không kết thúc đúng ở cuối chuỗi.
      var i = 0;
      var fields = 0;
      while (i + 4 <= qr.length) {
        final length = int.parse(qr.substring(i + 2, i + 4));
        i += 4 + length;
        fields++;
      }

      expect(i, qr.length, reason: 'Có trường khai sai độ dài');
      expect(fields, greaterThanOrEqualTo(7));
    });
  });

  group('Mã kiểm tra CRC', () {
    test('khớp giá trị kiểm chuẩn đã công bố của CRC-16/CCITT-FALSE', () {
      // Giá trị kiểm chuẩn của thuật toán: CRC của "123456789" là 0x29B1.
      // Không có mốc ngoài này thì mọi test CRC khác chỉ chứng minh mã nhất
      // quán với chính nó — kể cả khi dùng nhầm biến thể CRC.
      expect(crc16CcittFalse('123456789'), '29B1');
    });

    test('bốn ký tự cuối là CRC viết hoa, tính trên cả tag 6304', () {
      final qr = buildVietQr(
        const VietQrRequest(
          bankBin: '970436',
          accountNumber: '1234567890',
          amount: 250000,
        ),
      )!;

      expect(qr.substring(qr.length - 8, qr.length - 4), '6304');

      final crc = qr.substring(qr.length - 4);
      expect(crc, matches(RegExp(r'^[0-9A-F]{4}$')));
      expect(crc, crc.toUpperCase());
    });

    test('đổi một ký tự bất kỳ thì CRC phải khác đi', () {
      String crcOf(String account) => buildVietQr(
        VietQrRequest(bankBin: '970436', accountNumber: account),
      )!.substring(buildVietQr(
        VietQrRequest(bankBin: '970436', accountNumber: account),
      )!.length - 4);

      expect(crcOf('1234567890'), isNot(crcOf('1234567891')));
    });

    test('cùng đầu vào luôn ra cùng một chuỗi', () {
      const request = VietQrRequest(
        bankBin: '970422',
        accountNumber: '0987654321',
        amount: 500000,
        description: 'Tien nha thang 10',
      );

      expect(buildVietQr(request), buildVietQr(request));
    });
  });

  group('Nội dung chuyển khoản', () {
    /// Lấy nội dung chuyển khoản (trường 62, mục 08) ra khỏi chuỗi.
    String? noteOf(String qr) {
      final extra = fieldOf(qr, '62');
      return extra == null ? null : fieldOf(extra, '08');
    }

    test('bỏ dấu tiếng Việt vì app ngân hàng chỉ nhận ASCII', () {
      final qr = buildVietQr(
        const VietQrRequest(
          bankBin: '970436',
          accountNumber: '1234567890',
          description: 'Ăn lẩu tất niên',
        ),
      )!;

      expect(noteOf(qr), 'AN LAU TAT NIEN');
    });

    test('bỏ ký tự đặc biệt, gộp khoảng trắng', () {
      final qr = buildVietQr(
        const VietQrRequest(
          bankBin: '970436',
          accountNumber: '1234567890',
          description: 'Lẩu  &  bia  (chia 3)',
        ),
      )!;

      expect(noteOf(qr), 'LAU BIA CHIA 3');
    });

    test('cắt nội dung dài ở ranh giới từ', () {
      final qr = buildVietQr(
        const VietQrRequest(
          bankBin: '970436',
          accountNumber: '1234567890',
          description: 'Tien an trua va ca phe cua ca phong ky thuat',
        ),
      )!;

      final note = noteOf(qr)!;
      expect(note.length, lessThanOrEqualTo(25));
      expect(note, isNot(endsWith(' ')));
      expect(
        note.split(' ').last.length,
        greaterThan(1),
        reason: 'Cắt giữa từ thì từ cuối thành mẩu vô nghĩa',
      );
    });

    test('nội dung rỗng thì bỏ hẳn trường 62', () {
      final qr = buildVietQr(
        const VietQrRequest(
          bankBin: '970436',
          accountNumber: '1234567890',
          description: '   ',
        ),
      )!;

      expect(fieldOf(qr, '62'), isNull);
    });
  });

  group('Từ chối dữ liệu không hợp lệ', () {
    test('thiếu mã ngân hàng', () {
      const request = VietQrRequest(bankBin: '', accountNumber: '1234567890');

      expect(request.error, VietQrError.badBankBin);
      expect(buildVietQr(request), isNull);
    });

    test('mã ngân hàng không phải 6 chữ số', () {
      expect(
        const VietQrRequest(
          bankBin: '97043',
          accountNumber: '1234567890',
        ).error,
        VietQrError.badBankBin,
      );
      expect(
        const VietQrRequest(
          bankBin: '97043X',
          accountNumber: '1234567890',
        ).error,
        VietQrError.badBankBin,
      );
    });

    test('thiếu số tài khoản', () {
      expect(
        const VietQrRequest(bankBin: '970436', accountNumber: '  ').error,
        VietQrError.noAccount,
      );
    });

    test('số tài khoản có ký tự lạ hoặc quá ngắn', () {
      expect(
        const VietQrRequest(
          bankBin: '970436',
          accountNumber: '123-456',
        ).error,
        VietQrError.badAccount,
      );
      expect(
        const VietQrRequest(bankBin: '970436', accountNumber: '12').error,
        VietQrError.badAccount,
      );
    });

    test('số tiền âm', () {
      expect(
        const VietQrRequest(
          bankBin: '970436',
          accountNumber: '1234567890',
          amount: -1,
        ).error,
        VietQrError.negativeAmount,
      );
    });

    test('mọi lỗi đều có thông điệp tiếng Việt đọc được', () {
      for (final error in VietQrError.values) {
        expect(error.message, isNotEmpty);
        expect(error.message, endsWith('.'));
      }
    });
  });
}
