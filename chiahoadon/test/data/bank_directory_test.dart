import 'package:chiahoadon/data/bank_directory.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kiểm danh mục ngân hàng đi kèm app (SPEC FR-6.7).
///
/// Mã BIN sai thì QR sinh ra vẫn quét được nhưng trỏ sang ngân hàng khác, nên
/// các kiểm tra ở đây nhắm vào **tính toàn vẹn của dữ liệu**: đúng định dạng,
/// không trùng, không thiếu tên.
void main() {
  // `rootBundle` cần binding của Flutter mới đọc được asset.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(BankDirectory.clearCacheForTest);

  group('Tính toàn vẹn của danh mục', () {
    test('đọc được và có đủ các ngân hàng lớn', () async {
      final banks = await BankDirectory.all();

      expect(banks.length, greaterThan(40));

      final shortNames = [for (final bank in banks) bank.shortName];
      for (final must in [
        'Vietcombank',
        'VietinBank',
        'BIDV',
        'Agribank',
        'Techcombank',
        'MB Bank',
        'ACB',
        'VPBank',
      ]) {
        expect(shortNames, contains(must));
      }
    });

    test('mọi mã BIN đều đúng 6 chữ số', () async {
      for (final bank in await BankDirectory.all()) {
        expect(
          bank.bin,
          matches(RegExp(r'^\d{6}$')),
          reason: '${bank.shortName} có mã BIN không hợp lệ: ${bank.bin}',
        );
      }
    });

    test('không có mã BIN nào trùng nhau', () async {
      final banks = await BankDirectory.all();
      final bins = {for (final bank in banks) bank.bin};

      expect(
        bins.length,
        banks.length,
        reason: 'Trùng mã BIN thì chọn ngân hàng này lại ra ngân hàng kia',
      );
    });

    test('không ngân hàng nào thiếu tên', () async {
      for (final bank in await BankDirectory.all()) {
        expect(bank.shortName.trim(), isNotEmpty);
        expect(bank.name.trim(), isNotEmpty);
      }
    });

    test('vài mã BIN đã biết trỏ đúng ngân hàng', () async {
      expect((await BankDirectory.byBin('970436'))?.shortName, 'Vietcombank');
      expect((await BankDirectory.byBin('970415'))?.shortName, 'VietinBank');
      expect((await BankDirectory.byBin('970418'))?.shortName, 'BIDV');
      expect((await BankDirectory.byBin('970405'))?.shortName, 'Agribank');
    });

    test('mã BIN không có trong danh mục trả null, không ném lỗi', () async {
      expect(await BankDirectory.byBin('000000'), isNull);
      expect(await BankDirectory.byBin(null), isNull);
      expect(await BankDirectory.byBin(''), isNull);
    });
  });

  group('Tìm kiếm', () {
    test('tìm theo tên quen dùng', () async {
      final found = await BankDirectory.search('vietcom');

      expect(found, isNotEmpty);
      expect(found.first.bin, '970436');
    });

    test('bỏ dấu: gõ "ky thuong" ra Techcombank', () async {
      final found = await BankDirectory.search('ky thuong');

      expect(
        [for (final bank in found) bank.shortName],
        contains('Techcombank'),
      );
    });

    test('gõ có dấu cũng ra kết quả', () async {
      final found = await BankDirectory.search('Quân đội');

      expect([for (final bank in found) bank.shortName], contains('MB Bank'));
    });

    test('tìm theo mã BIN', () async {
      final found = await BankDirectory.search('970422');

      expect(found, hasLength(1));
      expect(found.first.shortName, 'MB Bank');
    });

    test('ô tìm kiếm rỗng thì trả cả danh mục', () async {
      expect(
        (await BankDirectory.search('   ')).length,
        (await BankDirectory.all()).length,
      );
    });

    test('không khớp gì thì trả danh sách rỗng, không ném lỗi', () async {
      expect(await BankDirectory.search('ngân hàng không tồn tại'), isEmpty);
    });
  });
}
