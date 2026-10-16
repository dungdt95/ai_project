import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/services/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db_test_helper.dart';

/// Xuất CSV (SPEC FR-8.3).
///
/// Tệp này đi ra ngoài app và được mở bằng Excel, nên cái phải kiểm là **cấu
/// trúc tệp** chứ không chỉ nội dung: sai một dấu phân cách hay thiếu dấu bọc
/// là cả bảng lệch cột mà không có gì báo lỗi.
void main() {
  late Member an;
  late Member binh;

  setUp(() {
    an = DbTestHelper.member('An');
    binh = DbTestHelper.member('Bình');
  });

  /// Tách nội dung thành từng dòng, bỏ dòng trống ở cuối.
  List<String> linesOf(String csv) => csv
      .replaceFirst(CsvExport.utf8Bom, '')
      .split('\r\n')
      .where((line) => line.isNotEmpty)
      .toList();

  group('Cấu trúc tệp', () {
    test('mở đầu bằng dấu UTF-8 để Excel không làm hỏng chữ có dấu', () {
      final csv = CsvExport.build(const []);

      expect(csv.startsWith(CsvExport.utf8Bom), isTrue);
    });

    test('luôn có dòng tiêu đề, kể cả khi không có hóa đơn nào', () {
      final lines = linesOf(CsvExport.build(const []));

      expect(lines, hasLength(1));
      expect(lines.first.split(CsvExport.separator).first, 'Ngày');
    });

    test('mỗi người trong mỗi hóa đơn là một dòng', () {
      final csv = CsvExport.build([
        DbTestHelper.equalBill(
          title: 'Ăn trưa',
          total: 300000,
          participants: [an, binh],
          payer: an,
        ),
        DbTestHelper.equalBill(
          title: 'Cà phê',
          total: 100000,
          participants: [an],
          payer: an,
        ),
      ], members: {an.id: an, binh.id: binh});

      // 1 tiêu đề + 2 người + 1 người.
      expect(linesOf(csv), hasLength(4));
    });

    test('mọi dòng có cùng số cột', () {
      final csv = CsvExport.build([
        DbTestHelper.equalBill(
          title: 'Ăn trưa',
          total: 300000,
          participants: [an, binh],
          payer: an,
        ),
      ], members: {an.id: an, binh.id: binh});

      final lines = linesOf(csv);
      final expected = lines.first.split(CsvExport.separator).length;

      for (final line in lines) {
        expect(
          line.split(CsvExport.separator),
          hasLength(expected),
          reason: 'Dòng lệch cột: $line',
        );
      }
    });

    test('kết thúc bằng xuống dòng', () {
      final csv = CsvExport.build([
        DbTestHelper.equalBill(
          title: 'Ăn trưa',
          total: 300000,
          participants: [an],
          payer: an,
        ),
      ]);

      expect(csv.endsWith('\r\n'), isTrue);
    });
  });

  group('Nội dung', () {
    test('ghi số tiền dạng số nguyên, không có dấu phân cách nghìn', () {
      final csv = CsvExport.build([
        DbTestHelper.equalBill(
          title: 'Ăn trưa',
          total: 300000,
          participants: [an, binh],
          payer: an,
        ),
      ], members: {an.id: an, binh.id: binh});

      // "300.000 đ" là để người đọc; Excel phải nhận ra đây là số thì mới cộng
      // được, nên cột tiền giữ nguyên dạng số thô.
      expect(csv, contains('300000'));
      expect(csv, isNot(contains('300.000')));

      // Kiểm trên đúng ô tiền, vì chữ "đ" còn nằm trong cả tên cột.
      final row = linesOf(csv)[1].split(CsvExport.separator);
      expect(row[3], '300000');
      expect(row[6], '150000');
    });

    test('cột còn lại = phải trả trừ đã trả', () {
      final bill = DbTestHelper.equalBill(
        title: 'Ăn trưa',
        total: 300000,
        participants: [an, binh],
        payer: an,
      );
      final csv = CsvExport.build([bill], members: {an.id: an, binh.id: binh});

      final row = linesOf(csv)[1].split(CsvExport.separator);
      final share = int.parse(row[6]);
      final paid = int.parse(row[7]);
      final left = int.parse(row[8]);

      expect(left, share - paid);
    });

    test('dùng tên đã chụp lại khi không tra được thành viên', () {
      // Hóa đơn của người đã bị xóa vẫn phải xuất được, với tên lúc đó.
      final csv = CsvExport.build([
        DbTestHelper.equalBill(
          title: 'Ăn trưa',
          total: 100000,
          participants: [an],
          payer: an,
        ),
      ]);

      expect(csv, contains('An'));
    });

    test('bỏ nháp ra ngoài', () {
      final csv = CsvExport.build([
        DbTestHelper.equalBill(
          title: 'Hóa đơn dở dang',
          total: 0,
          participants: [an],
          payer: an,
          status: BillStatus.draft,
        ),
        DbTestHelper.equalBill(
          title: 'Ăn trưa',
          total: 100000,
          participants: [an],
          payer: an,
        ),
      ], members: {an.id: an});

      expect(csv, isNot(contains('Hóa đơn dở dang')));
      expect(csv, contains('Ăn trưa'));
      expect(linesOf(csv), hasLength(2));
    });
  });

  group('Ô có ký tự đặc biệt', () {
    test('tên chứa dấu phân cách được bọc trong nháy kép', () {
      final csv = CsvExport.build([
        DbTestHelper.equalBill(
          title: 'Ăn trưa; có cả bia',
          total: 100000,
          participants: [an],
          payer: an,
        ),
      ], members: {an.id: an});

      expect(csv, contains('"Ăn trưa; có cả bia"'));

      // Và quan trọng hơn: dòng đó vẫn đúng số cột.
      final lines = linesOf(csv);
      expect(
        _countCells(lines[1]),
        _countCells(lines.first),
        reason: 'Ô chứa dấu phân cách làm vỡ dòng thành nhiều cột',
      );
    });

    test('dấu nháy kép trong tên được nhân đôi theo RFC 4180', () {
      final csv = CsvExport.build([
        DbTestHelper.equalBill(
          title: 'Quán "Ngon"',
          total: 100000,
          participants: [an],
          payer: an,
        ),
      ], members: {an.id: an});

      expect(csv, contains('"Quán ""Ngon"""'));
    });

    test('tên xuống dòng không làm vỡ tệp thành thêm một dòng', () {
      final csv = CsvExport.build([
        DbTestHelper.equalBill(
          title: 'Ăn trưa\nvà cà phê',
          total: 100000,
          participants: [an],
          payer: an,
        ),
      ], members: {an.id: an});

      expect(csv, contains('"Ăn trưa\nvà cà phê"'));
      // Tách theo \r\n: ô có xuống dòng dùng \n nên không tạo thêm dòng CSV.
      expect(linesOf(csv), hasLength(2));
    });
  });

  group('Tên tệp', () {
    test('có ngày giờ để nhiều lần xuất không đè lên nhau', () {
      final name = CsvExport.fileName(DateTime(2026, 10, 3, 9, 5));

      expect(name, 'chia-hoa-don-20261003-0905.csv');
    });

    test('hai lần xuất ở hai phút khác nhau ra hai tên khác nhau', () {
      expect(
        CsvExport.fileName(DateTime(2026, 10, 3, 9, 5)),
        isNot(CsvExport.fileName(DateTime(2026, 10, 3, 9, 6))),
      );
    });
  });
}

/// Đếm số ô của một dòng CSV, có tính tới dấu bọc.
int _countCells(String line) {
  var cells = 1;
  var inQuotes = false;

  for (final char in line.split('')) {
    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == CsvExport.separator && !inQuotes) {
      cells++;
    }
  }

  return cells;
}
