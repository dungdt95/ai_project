import 'dart:convert';
import 'dart:typed_data';

import 'package:bybrowser/core/encoding/text_codec.dart';
import 'package:bybrowser/features/excel_editor/csv/csv_codec.dart';
import 'package:bybrowser/features/excel_editor/csv/csv_controller.dart';
import 'package:bybrowser/features/excel_editor/csv/csv_document.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

CsvDocument _read(String s, {String? delimiter, String preferred = ','}) =>
    CsvDocument.read(_b(s), sheetName: 'S', delimiter: delimiter, preferred: preferred);

CsvController _ctl(String s) {
  final bytes = _b(s);
  return CsvController(CsvDocument.read(bytes, sheetName: 'S'), bytes: bytes, sheetName: 'S');
}

String _cell(CsvDocument d, int r, int c) => d.sheet.cellAt(r, c)?.raw ?? '';

/// Ghi lại toàn bộ sheet (như khi đã sửa) để kiểm tra bộ ghi.
String _rewrite(CsvDocument d) => utf8.decode(d.write());

void main() {
  group('CsvCodec.parse', () {
    List<List<String>> values(String s, [String d = ',']) =>
        CsvCodec.parse(s, d).map((r) => r.map((f) => f.value).toList()).toList();

    test('cơ bản, ô trống, dòng cuối không xuống dòng', () {
      expect(values('a,b,c\n1,,3'), [
        ['a', 'b', 'c'],
        ['1', '', '3'],
      ]);
      expect(values('a,\n'), [
        ['a', ''],
      ]);
      expect(values(''), isEmpty);
    });

    test('ngoặc kép, "" bên trong, xuống dòng trong ô', () {
      expect(values('"x, y","he said ""hi""","dòng 1\ndòng 2"\nz'), [
        ['x, y', 'he said "hi"', 'dòng 1\ndòng 2'],
        ['z'],
      ]);
      final f = CsvCodec.parse('"a",b', ',').first;
      expect(f[0].quoted, isTrue);
      expect(f[1].quoted, isFalse);
    });

    test('dòng trống ở giữa', () {
      expect(values('a\n\nb\n'), [
        ['a'],
        [''],
        ['b'],
      ]);
    });

    test('ngoặc không đóng không ném lỗi', () {
      expect(values('"abc,def\nxyz'), [
        ['abc,def\nxyz'],
      ]);
    });
  });

  group('nhận diện dấu phân cách', () {
    test('phẩy, chấm phẩy, tab, gạch đứng', () {
      expect(CsvCodec.detectDelimiter('a,b,c\n1,2,3\n'), ',');
      expect(CsvCodec.detectDelimiter('Tên;Giá\nCam;1,5\nTáo;2,25\n'), ';');
      expect(CsvCodec.detectDelimiter('a\tb\n1\t2\n'), '\t');
      expect(CsvCodec.detectDelimiter('a|b|c\n1|2|3\n'), '|');
    });

    test('dấu phẩy trong ngoặc không làm nhiễu', () {
      expect(CsvCodec.detectDelimiter('"a,b";c\n"1,2";3\n'), ';');
    });

    test('một cột → dùng dấu ưu tiên', () {
      expect(CsvCodec.detectDelimiter('a\nb\n', preferred: '\t'), '\t');
    });

    test('dòng sep= của Excel', () {
      final d = _read('sep=;\na;b\n1;2\n');
      expect(d.format.delimiter, ';');
      expect(d.format.sepLine, isTrue);
      expect(_cell(d, 0, 1), 'b');
      expect(_rewrite(d), 'sep=;\na;b\n1;2\n');
    });
  });

  group('CsvDocument', () {
    test('giữ nguyên chuỗi số (007, 1.50)', () {
      final d = _read('id,giá\n007,1.50\n');
      expect(_cell(d, 1, 0), '007');
      expect(_cell(d, 1, 1), '1.50');
    });

    test('ghi lại giống hệt: phẩy, LF, có xuống dòng cuối', () {
      const s = 'a,b,c\n1,,3\n"x, y",z,"q""q"\n';
      expect(_rewrite(_read(s)), s);
    });

    test('ghi lại giống hệt: CRLF + BOM + tiếng Việt', () {
      final bytes = Uint8List.fromList([
        0xEF, 0xBB, 0xBF,
        ...utf8.encode('Họ tên;Tuổi\r\nNguyễn Văn A;30\r\n'),
      ]);
      final d = CsvDocument.read(bytes, sheetName: 'S');
      expect(d.format.encoding, TextEncoding.utf8Bom);
      expect(d.format.lineEnding, LineEnding.crlf);
      expect(d.write(), bytes);
    });

    test('ghi lại giống hệt: không xuống dòng cuối, dòng trống ở giữa', () {
      const s = 'a,b\n\nc,d';
      expect(_rewrite(_read(s)), s);
    });

    test('ghi lại giống hệt: dòng thiếu cột (file không đều)', () {
      const s = 'a,b,c\n1\n2,3\n';
      expect(_rewrite(_read(s)), s);
    });

    test('kiểu ngoặc: tất cả / chỉ ô chữ', () {
      const all = '"a","b"\n"1","2"\n';
      expect(_read(all).format.quoteStyle, CsvQuoteStyle.all);
      expect(_rewrite(_read(all)), all);

      const nonNum = '"tên",tuổi\n"An",30\n';
      // "tuổi" không ngoặc → không phải nonNumeric.
      expect(_read(nonNum).format.quoteStyle, CsvQuoteStyle.minimal);

      const nonNum2 = '"tên","nhóm"\n"An",30\n';
      expect(_read(nonNum2).format.quoteStyle, CsvQuoteStyle.nonNumeric);
      expect(_rewrite(_read(nonNum2)), nonNum2);
    });

    test('TSV', () {
      final d = _read('a\tb\n1\t2\n', preferred: '\t');
      expect(d.format.delimiter, '\t');
      expect(_cell(d, 1, 1), '2');
    });

    test('độ rộng cột theo nội dung', () {
      final d = _read('ngắn,một chuỗi khá là dài ở đây\n');
      expect(d.sheet.columnWidth(1), greaterThan(d.sheet.columnWidth(0)));
    });
  });

  group('CsvController', () {
    test('chưa sửa → encode trả lại đúng byte gốc', () async {
      const s = 'a ,  b\n"1",2\n'; // khoảng trắng + ngoặc lẻ: ghi lại sẽ khác
      final ctl = _ctl(s);
      expect(ctl.isDirty, isFalse);
      expect(utf8.decode(await ctl.encode()), s);
    });

    test('sửa ô giữ nguyên chuỗi, không thành công thức', () async {
      final ctl = _ctl('a,b\n1,2\n');
      ctl.setCellInput(1, 0, '007');
      ctl.setCellInput(1, 1, '=SUM(A1)');
      ctl.setCellInput(0, 1, 'x, "y"');
      expect(ctl.isDirty, isTrue);
      expect(utf8.decode(await ctl.encode()), 'a,"x, ""y"""\n007,=SUM(A1)\n');
    });

    test('chèn / xóa dòng, cột', () async {
      final ctl = _ctl('a,b\n1,2\n');
      ctl.insertRow(1);
      ctl.setCellInput(1, 0, 'new');
      expect(utf8.decode(await ctl.encode()), 'a,b\nnew,\n1,2\n');
      ctl.insertColumn(1);
      expect(utf8.decode(await ctl.encode()), 'a,,b\nnew,,\n1,,2\n');
      ctl.deleteColumn(0);
      ctl.deleteRow(1);
      expect(utf8.decode(await ctl.encode()), ',b\n,2\n');
    });

    test('chèn cột ở file không đều: dòng ngắn không bị kéo dài', () async {
      final ctl = _ctl('a,b,c\n1\n');
      ctl.insertColumn(1);
      expect(utf8.decode(await ctl.encode()), 'a,,b,c\n1\n');
    });

    test('undo trở lại nội dung gốc', () async {
      final ctl = _ctl('a,b\n');
      ctl.setCellInput(0, 0, 'z');
      ctl.undo();
      expect(utf8.decode(await ctl.encode()), 'a,b\n');
    });

    test('lưu xong rồi encode lại → trả bản vừa lưu', () async {
      final ctl = _ctl('a,b\n');
      ctl.setCellInput(0, 0, 'z');
      final saved = await ctl.encode();
      ctl.markSaved();
      expect(await ctl.encode(), saved);
    });

    test('đổi dấu phân cách đọc lại file', () {
      final ctl = _ctl('a;b;c,d\n1;2;3,4\n');
      expect(ctl.format.delimiter, ';');
      ctl.changeDelimiter(',');
      expect(ctl.format.delimiter, ',');
      expect(ctl.sheet.cellAt(0, 0)?.raw, 'a;b;c');
      expect(ctl.sheet.cellAt(1, 1)?.raw, '4');
      expect(ctl.isDirty, isFalse);
    });

    test('căn phải ô trông như số', () {
      final ctl = _ctl('x,1.5,"2,5",12%\n');
      final row = ctl.sheet.cells[0]!;
      expect(ctl.alignRight(row[0]!), isFalse);
      expect(ctl.alignRight(row[1]!), isTrue);
      expect(ctl.alignRight(row[2]!), isTrue);
      expect(ctl.alignRight(row[3]!), isTrue);
    });
  });
}
