import 'package:chiahoadon/core/utils/date_formatter.dart';
import 'package:chiahoadon/core/utils/money_formatter.dart';
import 'package:chiahoadon/core/utils/vn_text.dart';
import 'package:chiahoadon/domain/models/surcharge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyFormatter (NFR-6: tiền là int)', () {
    test('nhóm chữ số theo kiểu Việt Nam', () {
      expect(MoneyFormatter.format(1234567), '1.234.567 đ');
      expect(MoneyFormatter.format(1000), '1.000 đ');
      expect(MoneyFormatter.format(999), '999 đ');
      expect(MoneyFormatter.format(0), '0 đ');
      expect(MoneyFormatter.format(1000000000), '1.000.000.000 đ');
    });

    test('giữ dấu âm', () {
      expect(MoneyFormatter.format(-300000), '-300.000 đ');
      expect(MoneyFormatter.formatPlain(-1234), '-1.234');
    });

    test('luôn hiện dấu cho số dư ròng', () {
      expect(MoneyFormatter.formatSigned(500000), '+500.000 đ');
      expect(MoneyFormatter.formatSigned(-300000), '-300.000 đ');
      expect(MoneyFormatter.formatSigned(0), '0 đ');
    });

    test('dạng ngắn cho nhãn biểu đồ', () {
      expect(MoneyFormatter.formatCompact(1200000), '1,2 tr');
      expect(MoneyFormatter.formatCompact(2000000), '2 tr');
      expect(MoneyFormatter.formatCompact(850000), '850 ng');
      expect(MoneyFormatter.formatCompact(1500000000), '1,5 tỷ');
      expect(MoneyFormatter.formatCompact(500), '500');
    });

    test('phân tích chuỗi người dùng nhập ở mọi định dạng', () {
      expect(MoneyFormatter.parse('1.234.567'), 1234567);
      expect(MoneyFormatter.parse('1,234,567'), 1234567);
      expect(MoneyFormatter.parse('1 234 567'), 1234567);
      expect(MoneyFormatter.parse('1234567 đ'), 1234567);
      expect(MoneyFormatter.parse('  500000  '), 500000);
      expect(MoneyFormatter.parse('-300.000'), -300000);
    });

    test('trả null khi không có chữ số', () {
      expect(MoneyFormatter.parse(''), isNull);
      expect(MoneyFormatter.parse('abc'), isNull);
      expect(MoneyFormatter.parse(null), isNull);
      expect(MoneyFormatter.parseOrZero('abc'), 0);
    });

    test('phân tích rồi định dạng lại cho ra số gốc', () {
      for (final amount in [0, 1, 999, 1000, 847500, 1234567, 999999999]) {
        final text = MoneyFormatter.formatPlain(amount);
        expect(MoneyFormatter.parse(text), amount, reason: 'với $amount');
      }
    });

    test('phần trăm lưu dạng basis point', () {
      expect(MoneyFormatter.formatPercentBp(800), '8%');
      expect(MoneyFormatter.formatPercentBp(1000), '10%');
      expect(MoneyFormatter.formatPercentBp(850), '8,5%');
      expect(MoneyFormatter.formatPercentBp(833), '8,33%');
      expect(MoneyFormatter.formatPercentBp(0), '0%');
    });

    test('phân tích phần trăm sang basis point', () {
      expect(MoneyFormatter.parsePercentToBp('8'), 800);
      expect(MoneyFormatter.parsePercentToBp('8,5'), 850);
      expect(MoneyFormatter.parsePercentToBp('8.5'), 850);
      expect(MoneyFormatter.parsePercentToBp('8%'), 800);
      expect(MoneyFormatter.parsePercentToBp('abc'), isNull);
    });
  });

  group('Surcharge — phụ phí & giảm giá (SPEC FR-5)', () {
    test('phần trăm tính trên mức gốc, kết quả luôn là int', () {
      // VAT 8% của 750.000 = 60.000
      expect(const Surcharge.percent(800).resolve(750000), 60000);
      // Phí dịch vụ 5% của 750.000 = 37.500
      expect(const Surcharge.percent(500).resolve(750000), 37500);
      // 8,5% của 100.000 = 8.500
      expect(const Surcharge.percent(850).resolve(100000), 8500);
    });

    test('số tiền tuyệt đối không phụ thuộc mức gốc', () {
      expect(const Surcharge.amount(60000).resolve(750000), 60000);
      expect(const Surcharge.amount(60000).resolve(1), 60000);
    });

    test('none luôn cho 0', () {
      expect(const Surcharge.none().resolve(999999), 0);
      expect(const Surcharge.none().isActive, isFalse);
    });

    test('làm tròn xuống, không bao giờ sinh số lẻ', () {
      // 3,33% của 1.000 = 33,3 -> 33
      expect(const Surcharge.percent(333).resolve(1000), 33);
      // 1% của 99 = 0,99 -> 0
      expect(const Surcharge.percent(100).resolve(99), 0);
    });
  });

  group('VnText — bỏ dấu tiếng Việt', () {
    test('bỏ dấu đầy đủ mọi nguyên âm', () {
      expect(VnText.normalize('Nguyễn Văn Đức'), 'nguyen van duc');
      expect(VnText.normalize('Bình'), 'binh');
      expect(VnText.normalize('Dũng'), 'dung');
      expect(VnText.normalize('Hoàng Thị Ước'), 'hoang thi uoc');
      expect(VnText.normalize('ăâêôơư đĐ'), 'aaeoou dd');
      // Phủ hết các nguyên âm có dấu, mỗi nhóm một đại diện có thanh điệu.
      expect(VnText.normalize('ầấậẩẫ'), 'aaaaa');
      expect(VnText.normalize('ềếệểễ'), 'eeeee');
      expect(VnText.normalize('ờớợởỡ'), 'ooooo');
      expect(VnText.normalize('ừứựửữ'), 'uuuuu');
      expect(VnText.normalize('ỳýỵỷỹ'), 'yyyyy');
    });

    test('gộp khoảng trắng và cắt hai đầu', () {
      expect(VnText.normalize('  Nguyễn   Văn  '), 'nguyen van');
    });

    test('so trùng tên bỏ qua dấu và hoa thường', () {
      expect(VnText.isSameName('Bình', 'binh'), isTrue);
      expect(VnText.isSameName('Anh ', ' ANH'), isTrue);
      expect(VnText.isSameName('An', 'Ân'), isTrue);
      expect(VnText.isSameName('An', 'Bình'), isFalse);
    });

    test('tìm kiếm chứa chuỗi, bỏ qua dấu', () {
      expect(VnText.contains('Nguyễn Văn Đức', 'duc'), isTrue);
      expect(VnText.contains('Nguyễn Văn Đức', 'van'), isTrue);
      expect(VnText.contains('Nguyễn Văn Đức', 'xyz'), isFalse);
      expect(VnText.contains('bất kỳ', ''), isTrue);
    });

    test('chữ cái avatar lấy từ tên, không lấy từ họ', () {
      expect(VnText.initial('Nguyễn Văn Đức'), 'Đ');
      expect(VnText.initial('An'), 'A');
      expect(VnText.initial('  Bình  '), 'B');
      expect(VnText.initial(''), '?');
    });
  });

  group('DateFormatter', () {
    test('định dạng số, không phụ thuộc dữ liệu locale', () {
      final date = DateTime(2026, 10, 2);

      expect(DateFormatter.short(date), '02/10/2026');
      expect(DateFormatter.dayMonth(date), '02/10');
      expect(DateFormatter.monthYear(date), 'Tháng 10/2026');
      expect(DateFormatter.monthLabel(date), 'T10');
      expect(DateFormatter.monthKey(date), '2026-10');
    });

    test('thứ trong tuần bằng tiếng Việt', () {
      // 02/10/2026 là thứ Sáu.
      expect(DateFormatter.withWeekday(DateTime(2026, 10, 2)),
          'Thứ Sáu, 02/10/2026');
    });

    test('ngày tương đối', () {
      final now = DateTime(2026, 10, 2, 15, 30);

      expect(DateFormatter.relative(DateTime(2026, 10, 2), now: now), 'Hôm nay');
      expect(DateFormatter.relative(DateTime(2026, 10, 1), now: now), 'Hôm qua');
      expect(DateFormatter.relative(DateTime(2026, 10, 3), now: now), 'Mai');
      expect(
        DateFormatter.relative(DateTime(2026, 9, 15), now: now),
        '15/09/2026',
      );
    });

    test('mốc đầu và cuối ngày', () {
      final date = DateTime(2026, 10, 2, 15, 30, 45);

      expect(DateFormatter.startOfDay(date), DateTime(2026, 10, 2));
      expect(
        DateFormatter.endOfDay(date),
        DateTime(2026, 10, 2, 23, 59, 59, 999),
      );
    });

    test('mốc đầu và cuối tháng, kể cả tháng 12', () {
      expect(
        DateFormatter.startOfMonth(DateTime(2026, 10, 15)),
        DateTime(2026, 10),
      );
      expect(
        DateFormatter.endOfMonth(DateTime(2026, 10, 15)),
        DateTime(2026, 10, 31, 23, 59, 59, 999),
      );
      // Tháng 12 phải sang năm sau mới lùi lại được.
      expect(
        DateFormatter.endOfMonth(DateTime(2026, 12, 5)),
        DateTime(2026, 12, 31, 23, 59, 59, 999),
      );
      // Tháng 2 năm nhuận.
      expect(
        DateFormatter.endOfMonth(DateTime(2028, 2, 1)),
        DateTime(2028, 2, 29, 23, 59, 59, 999),
      );
    });

    test('DateRange bao đúng khoảng', () {
      final range = DateRange.thisMonth(DateTime(2026, 10, 15));

      expect(range.contains(DateTime(2026, 10, 1)), isTrue);
      expect(range.contains(DateTime(2026, 10, 31, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 9, 30)), isFalse);
      expect(range.contains(DateTime(2026, 11, 1)), isFalse);
    });

    test('DateRange so sánh bằng theo mốc thời gian', () {
      expect(
        DateRange.thisMonth(DateTime(2026, 10, 15)),
        DateRange.thisMonth(DateTime(2026, 10, 2)),
      );
    });
  });
}
