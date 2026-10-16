import 'package:bybrowser/features/excel_editor/xlsx/formula_shift.dart';
import 'package:flutter_test/flutter_test.dart';

String ins(String f, {bool rows = true, required int at, String own = 'S', String target = 'S'}) =>
    FormulaShift.shift(f, ownSheet: own, targetSheet: target, rows: rows, insert: true, at: at);

String del(String f, {bool rows = true, required int at, String own = 'S', String target = 'S'}) =>
    FormulaShift.shift(f, ownSheet: own, targetSheet: target, rows: rows, insert: false, at: at);

void main() {
  group('chèn dòng', () {
    test('ô đơn, tuyệt đối, vùng', () {
      expect(ins('B2*C2', at: 1), 'B3*C3'); // chèn tại dòng 2 (0-based 1)
      expect(ins('B2*C2', at: 2), 'B2*C2'); // chèn dưới → không đổi
      expect(ins(r'$B$2+B$2+$B2', at: 0), r'$B$3+B$3+$B3');
      expect(ins('SUM(D2:D4)', at: 2), 'SUM(D2:D5)');
      expect(ins('SUM(D2:D4)', at: 1), 'SUM(D3:D5)');
    });
    test('cột nguyên, dòng nguyên', () {
      expect(ins('SUM(A:A)', at: 0), 'SUM(A:A)');
      expect(ins('SUM(2:3)', at: 1), 'SUM(3:4)');
      expect(ins('SUM(A:B)', rows: false, at: 0), 'SUM(B:C)');
    });
    test('không đụng chuỗi, tên hàm, sheet khác', () {
      expect(ins('"A1"&A1', at: 0), '"A1"&A2');
      expect(ins('LOG10(A1)', at: 0), 'LOG10(A2)');
      expect(ins('Sheet2!A1+A1', at: 0), 'Sheet2!A1+A2');
      expect(ins("'Dữ liệu'!A1+A1", at: 0, own: 'Sheet2', target: 'Dữ liệu'), "'Dữ liệu'!A2+A1");
      expect(ins('S!A1', at: 0, own: 'Other', target: 'S'), 'S!A2');
    });
  });

  group('xóa dòng/cột', () {
    test('ô đơn bị xóa → #REF!, ô dưới lùi lên', () {
      expect(del('B2*C2', at: 1), '#REF!*#REF!');
      expect(del('B3*C3', at: 1), 'B2*C2');
      expect(del('B1', at: 1), 'B1');
    });
    test('vùng co lại; xóa hết vùng → #REF!', () {
      expect(del('SUM(D2:D4)', at: 2), 'SUM(D2:D3)');
      expect(del('SUM(D2:D4)', at: 1), 'SUM(D2:D3)');
      expect(del('SUM(D2:D4)', at: 3), 'SUM(D2:D3)');
      expect(del('SUM(D2:D2)', at: 1), 'SUM(#REF!)');
      expect(del('SUM(B2:D2)', rows: false, at: 2), 'SUM(B2:C2)');
      expect(del('SUM(B2:D2)', rows: false, at: 1), 'SUM(B2:C2)');
    });
  });
}
