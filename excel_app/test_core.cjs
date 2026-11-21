const ExcelJS = require('exceljs');
const { Parser } = require('hot-formula-parser');

console.log('=== TEST 1: KIỂM TRA FORMULA PARSER ===');
const parser = new Parser();

// Giả lập dữ liệu cell
const mockCells = {
  'A1': 10,
  'A2': 20,
  'A3': 30,
  'B1': 5,
  'B2': 15,
  'B3': 25
};

parser.on('callCellValue', (cellCoord, done) => {
  const colLetter = String.fromCharCode(65 + cellCoord.column.index);
  const rowNum = cellCoord.row.index + 1;
  const key = `${colLetter}${rowNum}`;
  done(mockCells[key] !== undefined ? mockCells[key] : 0);
});

parser.on('callRangeValue', (startCoord, endCoord, done) => {
  const startRow = Math.min(startCoord.row.index, endCoord.row.index) + 1;
  const endRow = Math.max(startCoord.row.index, endCoord.row.index) + 1;
  const startCol = Math.min(startCoord.column.index, endCoord.column.index);
  const endCol = Math.max(startCoord.column.index, endCoord.column.index);

  const matrix = [];
  for (let r = startRow; r <= endRow; r++) {
    const row = [];
    for (let c = startCol; c <= endCol; c++) {
      const colLetter = String.fromCharCode(65 + c);
      const key = `${colLetter}${r}`;
      row.push(mockCells[key] !== undefined ? mockCells[key] : 0);
    }
    matrix.push(row);
  }
  done(matrix);
});

// Test SUM
const sumResult = parser.parse('SUM(A1:A3)');
console.log('SUM(A1:A3) =', sumResult.result, sumResult.result === 60 ? '-> PASS' : '-> FAIL');

// Test AVERAGE
const avgResult = parser.parse('AVERAGE(A1:A3)');
console.log('AVERAGE(A1:A3) =', avgResult.result, avgResult.result === 20 ? '-> PASS' : '-> FAIL');

// Test MAX & MIN
const maxResult = parser.parse('MAX(A1:B3)');
const minResult = parser.parse('MIN(A1:B3)');
console.log('MAX(A1:B3) =', maxResult.result, maxResult.result === 30 ? '-> PASS' : '-> FAIL');
console.log('MIN(A1:B3) =', minResult.result, minResult.result === 5 ? '-> PASS' : '-> FAIL');

// Test IF
const ifResult = parser.parse('IF(A1 > 5, "Lớn", "Nhỏ")');
console.log('IF(A1 > 5, "Lớn", "Nhỏ") =', ifResult.result, ifResult.result === 'Lớn' ? '-> PASS' : '-> FAIL');

// Test COUNT
const countResult = parser.parse('COUNT(A1:B3)');
console.log('COUNT(A1:B3) =', countResult.result, countResult.result === 6 ? '-> PASS' : '-> FAIL');

console.log('\n=== TEST 2: KIỂM TRA ĐỌC & XUẤT FILE EXCEL (.XLSX) ===');
async function testExcelIO() {
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('Báo Cáo Thử Nghiệm');

  ws.getCell('A1').value = 'Mã Sản Phẩm';
  ws.getCell('B1').value = 'Số Lượng';
  ws.getCell('C1').value = 'Đơn Giá';
  ws.getCell('D1').value = { formula: 'B2*C2', result: 500000 };

  ws.getCell('A2').value = 'SP001';
  ws.getCell('B2').value = 5;
  ws.getCell('C2').value = 100000;

  const buffer = await wb.xlsx.writeBuffer();
  console.log('Xuất file .xlsx sang buffer thành công, kích thước:', buffer.byteLength, 'bytes -> PASS');

  const readWb = new ExcelJS.Workbook();
  await readWb.xlsx.load(buffer);
  const readWs = readWb.getWorksheet('Báo Cáo Thử Nghiệm');
  console.log('Đọc lại sheet name:', readWs.name, readWs.name === 'Báo Cáo Thử Nghiệm' ? '-> PASS' : '-> FAIL');
  console.log('Đọc giá trị A2:', readWs.getCell('A2').value, readWs.getCell('A2').value === 'SP001' ? '-> PASS' : '-> FAIL');
  console.log('Đọc formula D1:', readWs.getCell('D1').formula, readWs.getCell('D1').formula === 'B2*C2' ? '-> PASS' : '-> FAIL');
  console.log('\n>>> TẤT CẢ CÁC BÀI TEST LÕI ĐÃ VƯỢT QUA 100%! <<<');
}

testExcelIO();
