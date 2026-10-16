import 'dart:io';
import 'dart:typed_data';

import 'package:bybrowser/features/excel_editor/excel_controller.dart';
import 'package:bybrowser/features/excel_editor/xlsx/number_format.dart';
import 'package:bybrowser/features/excel_editor/xlsx/xlsx_model.dart';
import 'package:bybrowser/features/excel_editor/xlsx/xlsx_reader.dart';
import 'package:bybrowser/features/excel_editor/xlsx/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _fixture() => File('test/fixtures/mau.xlsx').readAsBytesSync();

String show(Workbook wb, Worksheet ws, int r, int c) {
  final cell = ws.cellAt(r, c);
  return cell == null ? '' : XlsxNumberFormat.display(cell, wb.styles);
}

void main() {
  controllerTests();
  group('tham chiếu ô', () {
    test('columnLetters / parseCellRef', () {
      expect(columnLetters(0), 'A');
      expect(columnLetters(25), 'Z');
      expect(columnLetters(26), 'AA');
      expect(columnLetters(701), 'ZZ');
      expect(columnLetters(702), 'AAA');
      expect(parseCellRef('B12'), (11, 1));
      expect(parseCellRef(r'$AA$1'), (0, 26));
      expect(parseCellRef('12'), isNull);
      expect(CellRange.parse('A6:C6'), const CellRange(5, 0, 5, 2));
    });
  });

  group('định dạng số', () {
    test('General', () {
      expect(XlsxNumberFormat.general(25000), '25000');
      expect(XlsxNumberFormat.general(7500.5), '7500.5');
      expect(XlsxNumberFormat.general(1 / 3), '0.3333333333');
      expect(XlsxNumberFormat.general(0.1 + 0.2), '0.3');
    });
    test('#,##0.00 / 0% / ngày', () {
      expect(XlsxNumberFormat.formatNumber(25000, '#,##0.00'), '25,000.00');
      expect(XlsxNumberFormat.formatNumber(0.1, '0%'), '10%');
      expect(XlsxNumberFormat.formatNumber(46278, 'dd/mm/yyyy'), '13/09/2026');
      expect(XlsxNumberFormat.isDateFormat('dd/mm/yyyy'), isTrue);
      expect(XlsxNumberFormat.isDateFormat('#,##0.00'), isFalse);
      expect(XlsxNumberFormat.isDateFormat('"Ngày: "dd'), isTrue);
    });
  });

  group('XlsxReader với file do Excel tạo', () {
    late Workbook wb;
    late Worksheet ws;
    setUpAll(() {
      wb = XlsxReader.read(_fixture());
      ws = wb.sheets.first;
    });

    test('sheet, kích thước, cols', () {
      expect(wb.sheets.map((s) => s.name), ['Dữ liệu', 'Sheet2']);
      expect(ws.maxRow, 9);
      expect(ws.maxCol, 3);
      expect(ws.columnWidth(0), greaterThan(17)); // đặt 18 trong Excel
    });

    test('giá trị & kiểu ô', () {
      expect(show(wb, ws, 0, 0), 'Tên hàng');
      expect(wb.styles.bold(ws.cellAt(0, 0)!.styleIndex), isTrue);
      expect(wb.styles.bold(ws.cellAt(1, 0)!.styleIndex), isFalse);
      expect(ws.cellAt(1, 1)!.type, CellType.number);
      expect(show(wb, ws, 1, 1), '10');
      expect(show(wb, ws, 3, 2), '7,500.50');
      expect(show(wb, ws, 8, 1), 'TRUE');
      expect(show(wb, ws, 6, 1), '13/09/2026');
      expect(show(wb, ws, 7, 1), '10%');
    });

    test('công thức giữ nguyên + giá trị cache', () {
      final d2 = ws.cellAt(1, 3)!;
      expect(d2.formula, 'B2*C2');
      expect(show(wb, ws, 1, 3), '25,000.00');
      final total = ws.cellAt(4, 3)!;
      expect(total.formula, 'SUM(D2:D4)');
      expect(show(wb, ws, 4, 3), '100,001.00');
      final label = ws.cellAt(9, 1)!;
      expect(label.formula, 'A2&" x"&B2');
      expect(label.type, CellType.text);
      expect(label.raw, 'Bút bi x10');
    });

    test('merge', () {
      expect(ws.merges, [const CellRange(5, 0, 5, 2)]);
      expect(ws.mergeAt(5, 1), isNotNull);
    });
  });

  group('XlsxWriter round-trip', () {
    test('không sửa → không sheet nào dirty, zip vẫn hợp lệ', () {
      final wb = XlsxReader.read(_fixture());
      final out = XlsxWriter.write(wb);
      final again = XlsxReader.read(out);
      expect(again.sheets.length, 2);
      expect(show(again, again.sheets.first, 4, 3), '100,001.00');
    });

    test('sửa ô, thêm dòng, xóa cột rồi đọc lại', () {
      final wb = XlsxReader.read(_fixture());
      final ws = wb.sheets.first;
      // sửa text (ô gốc là shared string) và số
      ws.ensureCell(1, 0)
        ..type = CellType.text
        ..raw = 'Bút chì <2B> & tẩy'
        ..sharedIndex = null;
      ws.ensureCell(1, 1)
        ..type = CellType.number
        ..raw = '12';
      // ô mới có công thức
      ws.ensureCell(11, 0)
        ..formula = 'B2+1'
        ..type = CellType.empty
        ..raw = null;
      ws.dirty = true;
      ws.insertRow(1); // dòng 2 mới trống; dữ liệu cũ dịch xuống
      ws.deleteColumn(2); // bỏ cột Đơn giá

      final out = XlsxWriter.write(wb);
      final again = XlsxReader.read(out);
      final s = again.sheets.first;
      expect(show(again, s, 2, 0), 'Bút chì <2B> & tẩy');
      expect(show(again, s, 2, 1), '12');
      expect(s.cellAt(1, 0), isNull); // dòng chèn trống
      expect(show(again, s, 1 + 0, 0), ''); // header vẫn ở dòng 0
      expect(show(again, s, 0, 0), 'Tên hàng');
      // cột D (Thành tiền) giờ là cột C
      expect(s.cellAt(2, 2)!.formula, 'B2*C2'); // công thức không được cập nhật (giới hạn đã nêu)
      expect(show(again, s, 0, 2), 'Thành tiền');
      expect(s.cellAt(12, 0)!.formula, 'B2+1');
      // merge A6:C6 → dịch xuống 1 và co lại còn A7:B7
      expect(s.merges, [const CellRange(6, 0, 6, 1)]);
      // cột A vẫn rộng 18
      expect(s.columnWidth(0), greaterThan(17));
      // calcChain đã bị bỏ, workbook yêu cầu tính lại
      expect(again.parts.containsKey('xl/calcChain.xml'), isFalse);
      expect(String.fromCharCodes(again.parts['xl/workbook.xml']!), contains('fullCalcOnLoad="1"'));
      // ghi ra để kiểm tra bằng Excel thật
      File('test/fixtures/mau_out.xlsx').writeAsBytesSync(out);
    });
  });
}

void controllerTests() {
  group('ExcelController', () {
    test('chèn dòng / xóa cột dịch công thức, undo khôi phục', () {
      final ctl = ExcelController(XlsxReader.read(_fixture()));
      final ws = ctl.sheet;
      ctl.insertRow(1);
      expect(ws.cellAt(2, 3)!.formula, 'B3*C3');
      expect(ws.cellAt(5, 3)!.formula, 'SUM(D3:D5)');
      expect(ws.cellAt(10, 1)!.formula, 'A3&" x"&B3');
      ctl.deleteColumn(2); // bỏ Đơn giá
      expect(ws.cellAt(2, 2)!.formula, 'B3*#REF!');
      expect(ws.cellAt(5, 2)!.formula, 'SUM(C3:C5)');
      expect(ctl.isDirty, isTrue);
      ctl.undo();
      expect(ws.cellAt(2, 3)!.formula, 'B3*C3');
      ctl.undo();
      expect(ws.cellAt(1, 3)!.formula, 'B2*C2');
      expect(ctl.canUndo, isFalse);
      ctl.redo();
      expect(ws.cellAt(2, 3)!.formula, 'B3*C3');
    });

    test('nhập liệu: số, bool, công thức, text; tìm kiếm', () {
      final ctl = ExcelController(XlsxReader.read(_fixture()));
      ctl.setCellInput(20, 0, ' 1,5 ');
      expect(ctl.sheet.cellAt(20, 0)!.type, CellType.text);
      ctl.setCellInput(20, 1, '1.5');
      expect(ctl.sheet.cellAt(20, 1)!.type, CellType.number);
      expect(ctl.displayFor(20, 1), '1.5');
      ctl.setCellInput(20, 2, 'true');
      expect(ctl.displayFor(20, 2), 'TRUE');
      ctl.setCellInput(20, 3, '=SUM(B2:B4)');
      expect(ctl.sheet.cellAt(20, 3)!.formula, 'SUM(B2:B4)');
      expect(ctl.inputFor(20, 3), '=SUM(B2:B4)');
      expect(ctl.findNext('vở'), const CellPos(2, 0));
      expect(ctl.findNext('sum'), const CellPos(4, 3));
      expect(ctl.findNext('không có'), isNull);
    });
  });
}
