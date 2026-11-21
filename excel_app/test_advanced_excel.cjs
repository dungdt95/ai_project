const ExcelJS = require('exceljs');
const { Parser } = require('hot-formula-parser');
const fs = require('fs');
const path = require('path');

console.log('================================================================');
console.log('  TEST NÂNG CAO: KIỂM THỬ ĐỘC LẬP TÍNH NĂNG VÀ IMPORT/EXPORT EXCEL');
console.log('================================================================\n');

let passCount = 0;
let failCount = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  [PASS] ${message}`);
    passCount++;
  } else {
    console.error(`  [FAIL] ${message}`);
    failCount++;
  }
}

// -------------------------------------------------------------------------
// Bộ máy tính toán FormulaEngine mô phỏng lại src/core/formulaEngine.ts
// -------------------------------------------------------------------------
class TestFormulaEngine {
  constructor() {
    this.parser = new Parser();
    this.currentCells = {};

    this.parser.on('callCellValue', (cellCoord, done) => {
      const col = cellCoord.column.index;
      const row = cellCoord.row.index;
      const key = `${row}_${col}`;
      const cell = this.currentCells[key];

      if (!cell) {
        done(0);
        return;
      }
      const val = cell.v;
      if (val === undefined || val === null || val === '') {
        done(0);
      } else if (!isNaN(Number(val)) && typeof val !== 'boolean') {
        done(Number(val));
      } else {
        done(val);
      }
    });

    this.parser.on('callRangeValue', (startCoord, endCoord, done) => {
      const startRow = Math.min(startCoord.row.index, endCoord.row.index);
      const endRow = Math.max(startCoord.row.index, endCoord.row.index);
      const startCol = Math.min(startCoord.column.index, endCoord.column.index);
      const endCol = Math.max(startCoord.column.index, endCoord.column.index);

      const matrix = [];
      for (let r = startRow; r <= endRow; r++) {
        const rowData = [];
        for (let c = startCol; c <= endCol; c++) {
          const key = `${r}_${c}`;
          const cell = this.currentCells[key];
          if (!cell) {
            rowData.push(0);
          } else {
            const val = cell.v;
            if (val === undefined || val === null || val === '') {
              rowData.push(0);
            } else if (!isNaN(Number(val)) && typeof val !== 'boolean') {
              rowData.push(Number(val));
            } else {
              rowData.push(val);
            }
          }
        }
        matrix.push(rowData);
      }
      done(matrix);
    });
  }

  evaluateAll(cells) {
    const result = { ...cells };
    this.currentCells = result;

    const formulaKeys = Object.keys(result).filter(k => {
      const f = result[k].f;
      return f && f.startsWith('=');
    });

    for (let pass = 0; pass < 8; pass++) {
      let changed = false;
      for (const k of formulaKeys) {
        const formulaStr = (result[k].f || '').substring(1);
        const parseResult = this.parser.parse(formulaStr);
        let newValue;
        if (parseResult.error) {
          newValue = parseResult.error;
        } else {
          newValue = parseResult.result;
        }

        if (result[k].v !== newValue) {
          result[k].v = newValue;
          changed = true;
        }
      }
      if (!changed) break;
    }
    return result;
  }
}

const formulaEngine = new TestFormulaEngine();

// -------------------------------------------------------------------------
// Helper functions mô phỏng src/core/excelIO.ts
// -------------------------------------------------------------------------
function argbToHex(argb) {
  if (!argb) return undefined;
  if (typeof argb === 'string') {
    if (argb.length === 8) {
      return '#' + argb.substring(2);
    }
    if (argb.startsWith('#')) return argb;
    return '#' + argb;
  }
  return undefined;
}

function hexToArgb(hex) {
  if (!hex) return undefined;
  const clean = hex.replace('#', '');
  if (clean.length === 6) {
    return 'FF' + clean.toUpperCase();
  }
  if (clean.length === 8) {
    return clean.toUpperCase();
  }
  return undefined;
}

async function convertWorkbookToAppData(workbook) {
  const sheets = [];

  workbook.eachSheet((worksheet, sheetId) => {
    const cells = {};
    const rowHeights = {};
    const colWidths = {};
    const merges = [];

    // Read merges
    const modelMerges = worksheet.model?.merges;
    if (Array.isArray(modelMerges)) {
      for (const m of modelMerges) {
        const parts = m.split(':');
        if (parts.length === 2) {
          const c1 = worksheet.getCell(parts[0]);
          const c2 = worksheet.getCell(parts[1]);
          merges.push({
            s: { r: Number(c1.row) - 1, c: Number(c1.col) - 1 },
            e: { r: Number(c2.row) - 1, c: Number(c2.col) - 1 }
          });
        }
      }
    }

    // Read cells & rows
    worksheet.eachRow({ includeEmpty: false }, (row, rowNumber) => {
      const r = rowNumber - 1;
      if (row.height) rowHeights[r] = Math.round(row.height * 1.33);

      row.eachCell({ includeEmpty: false }, (cell, colNumber) => {
        const c = colNumber - 1;
        const cellKey = `${r}_${c}`;

        let val = cell.value;
        let formula = undefined;

        if (val && typeof val === 'object') {
          if ('formula' in val) {
            formula = '=' + val.formula;
            val = val.result !== undefined ? val.result : 0;
          } else if ('richText' in val) {
            val = val.richText.map(t => t.text).join('');
          } else if ('text' in val) {
            val = val.text;
          }
        }

        const s = {};
        if (cell.font) {
          if (cell.font.bold) s.bold = true;
          if (cell.font.italic) s.italic = true;
          if (cell.font.underline) s.underline = true;
          if (cell.font.size) s.fontSize = cell.font.size;
          if (cell.font.name) s.fontFamily = cell.font.name;
          if (cell.font.color?.argb) s.color = argbToHex(cell.font.color.argb);
        }

        if (cell.fill && cell.fill.type === 'pattern' && cell.fill.fgColor?.argb) {
          s.bgColor = argbToHex(cell.fill.fgColor.argb);
        }

        if (cell.alignment) {
          if (cell.alignment.horizontal) s.align = cell.alignment.horizontal;
          if (cell.alignment.vertical) s.verticalAlign = cell.alignment.vertical;
        }

        if (cell.border) {
          s.border = {
            top: !!cell.border.top,
            bottom: !!cell.border.bottom,
            left: !!cell.border.left,
            right: !!cell.border.right,
            style: cell.border.top?.style || cell.border.bottom?.style || 'thin'
          };
        }

        cells[cellKey] = {
          v: val,
          f: formula,
          s: Object.keys(s).length > 0 ? s : undefined
        };
      });
    });

    const evaluatedCells = formulaEngine.evaluateAll(cells);

    sheets.push({
      id: `sheet_${sheetId}`,
      name: worksheet.name,
      rowCount: 100,
      colCount: 26,
      cells: evaluatedCells,
      rowHeights,
      colWidths,
      merges
    });
  });

  return {
    title: 'TestWorkbook',
    sheets,
    activeSheetId: sheets[0]?.id || ''
  };
}

async function exportAppDataToExcel(appData) {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'Excel PC Editor Tester';

  for (const sheet of appData.sheets) {
    const ws = wb.addWorksheet(sheet.name);

    for (const key in sheet.cells) {
      const [rStr, cStr] = key.split('_');
      const r = Number(rStr) + 1;
      const c = Number(cStr) + 1;
      const cellData = sheet.cells[key];
      const excelCell = ws.getCell(r, c);

      if (cellData.f && cellData.f.startsWith('=')) {
        excelCell.value = {
          formula: cellData.f.substring(1),
          result: cellData.v
        };
      } else {
        excelCell.value = cellData.v;
      }

      const s = cellData.s;
      if (s) {
        const font = {};
        if (s.fontFamily) font.name = s.fontFamily;
        if (s.fontSize) font.size = s.fontSize;
        if (s.bold) font.bold = true;
        if (s.italic) font.italic = true;
        if (s.underline) font.underline = true;
        if (s.color) {
          const argb = hexToArgb(s.color);
          if (argb) font.color = { argb };
        }
        if (Object.keys(font).length > 0) excelCell.font = font;

        if (s.bgColor && s.bgColor !== '#ffffff') {
          const argb = hexToArgb(s.bgColor);
          if (argb) {
            excelCell.fill = {
              type: 'pattern',
              pattern: 'solid',
              fgColor: { argb }
            };
          }
        }

        const alignment = {};
        if (s.align) alignment.horizontal = s.align;
        if (s.verticalAlign) alignment.vertical = s.verticalAlign;
        if (Object.keys(alignment).length > 0) excelCell.alignment = alignment;

        if (s.border) {
          const borders = {};
          const style = s.border.style || 'thin';
          const argb = 'FF000000';
          if (s.border.top) borders.top = { style, color: { argb } };
          if (s.border.bottom) borders.bottom = { style, color: { argb } };
          if (s.border.left) borders.left = { style, color: { argb } };
          if (s.border.right) borders.right = { style, color: { argb } };
          excelCell.border = borders;
        }
      }
    }

    for (const m of sheet.merges) {
      try {
        ws.mergeCells(m.s.r + 1, m.s.c + 1, m.e.r + 1, m.e.c + 1);
      } catch (e) {}
    }
  }

  return await wb.xlsx.writeBuffer();
}

// -------------------------------------------------------------------------
// CHẠY TEST CHÍNH
// -------------------------------------------------------------------------
async function runAdvancedTest() {
  console.log('--- GIAI ĐOẠN 1: TẠO FILE EXCEL MẪU PHỨC TẠP BẰNG EXCELJS ---');
  const wbOriginal = new ExcelJS.Workbook();
  wbOriginal.creator = 'Enterprise Test Generator';

  // SHEET 1: Sheet1 (Tổng Quan)
  const ws1 = wbOriginal.addWorksheet('Sheet1');
  ws1.mergeCells('A1:D1');
  const titleCell = ws1.getCell('A1');
  titleCell.value = 'BÁO CÁO TỔNG QUAN TẬP ĐOÀN 2026';
  titleCell.font = { name: 'Arial', size: 16, bold: true, color: { argb: 'FFFFFFFF' } };
  titleCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF107C41' } }; // Màu xanh Excel 365
  titleCell.alignment = { horizontal: 'center', vertical: 'middle' };

  ws1.getCell('A3').value = 'Kỳ báo cáo';
  ws1.getCell('B3').value = 'Q4/2026';
  ws1.getCell('A3').font = { bold: true };

  // SHEET 2: DoanhThu (Tính toán số học, SUM, AVERAGE, IF)
  const ws2 = wbOriginal.addWorksheet('DoanhThu');
  ws2.mergeCells('A1:E1');
  ws2.getCell('A1').value = 'BẢNG THEO DÕI DOANH THU & LỢI NHUẬN';
  ws2.getCell('A1').font = { bold: true, size: 14, color: { argb: 'FFFFFFFF' } };
  ws2.getCell('A1').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1F4E78' } };
  ws2.getCell('A1').alignment = { horizontal: 'center', vertical: 'middle' };

  // Headers
  const headers = ['Mã Đơn', 'Số Lượng', 'Đơn Giá', 'Thành Tiền', 'Đánh Giá'];
  headers.forEach((h, idx) => {
    const c = ws2.getCell(2, idx + 1);
    c.value = h;
    c.font = { bold: true };
    c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFD9E1F2' } };
    c.border = {
      top: { style: 'thin' },
      bottom: { style: 'medium' },
      left: { style: 'thin' },
      right: { style: 'thin' }
    };
    c.alignment = { horizontal: 'center' };
  });

  // Data rows
  const rowData = [
    ['DH001', 10, 200000],
    ['DH002', 25, 150000],
    ['DH003', 5, 800000],
    ['DH004', 50, 50000],
    ['DH005', 12, 350000]
  ];

  rowData.forEach((item, index) => {
    const rowNum = 3 + index;
    ws2.getCell(`A${rowNum}`).value = item[0];
    ws2.getCell(`B${rowNum}`).value = item[1];
    ws2.getCell(`C${rowNum}`).value = item[2];

    // Phép tính nhân: B * C
    ws2.getCell(`D${rowNum}`).value = { formula: `B${rowNum}*C${rowNum}`, result: item[1] * item[2] };

    // Hàm điều kiện IF
    ws2.getCell(`E${rowNum}`).value = {
      formula: `IF(D${rowNum}>3000000, "Doanh Thu Cao", "Bình Thường")`,
      result: (item[1] * item[2] > 3000000) ? 'Doanh Thu Cao' : 'Bình Thường'
    };

    // Border cho dữ liệu
    ['A', 'B', 'C', 'D', 'E'].forEach(col => {
      ws2.getCell(`${col}${rowNum}`).border = {
        top: { style: 'thin' },
        bottom: { style: 'thin' },
        left: { style: 'thin' },
        right: { style: 'thin' }
      };
    });
  });

  // Row Tổng Cộng (SUM)
  ws2.getCell('A8').value = 'Tổng cộng:';
  ws2.getCell('A8').font = { bold: true };
  ws2.getCell('B8').value = { formula: 'SUM(B3:B7)', result: 102 };
  ws2.getCell('D8').value = { formula: 'SUM(D3:D7)', result: 16450000 };
  ws2.getCell('D8').font = { bold: true, color: { argb: 'FFC00000' } };

  // Row Trung Bình (AVERAGE)
  ws2.getCell('A9').value = 'Trung bình đơn:';
  ws2.getCell('A9').font = { bold: true };
  ws2.getCell('D9').value = { formula: 'AVERAGE(D3:D7)', result: 3290000 };

  // SHEET 3: NhanVien (COUNT, định dạng văn bản)
  const ws3 = wbOriginal.addWorksheet('NhanVien');
  ws3.getCell('A1').value = 'DANH SÁCH NHÂN VIÊN';
  ws3.getCell('A1').font = { bold: true, size: 13, italic: true };

  const nvList = [
    ['NV01', 'Nguyễn Văn A', 'Kỹ thuật', 8.5],
    ['NV02', 'Trần Thị B', 'Kế toán', 9.0],
    ['NV03', 'Lê Văn C', 'Kinh doanh', 7.5],
    ['NV04', 'Phạm Minh D', 'Marketing', 8.0]
  ];

  ws3.getCell('A2').value = 'Mã';
  ws3.getCell('B2').value = 'Họ Tên';
  ws3.getCell('C2').value = 'Phòng Ban';
  ws3.getCell('D2').value = 'Đánh Giá';

  nvList.forEach((nv, idx) => {
    const r = 3 + idx;
    ws3.getCell(`A${r}`).value = nv[0];
    ws3.getCell(`B${r}`).value = nv[1];
    ws3.getCell(`C${r}`).value = nv[2];
    ws3.getCell(`D${r}`).value = nv[3];
  });

  ws3.getCell('A8').value = 'Tổng số NV:';
  ws3.getCell('A8').font = { bold: true };
  ws3.getCell('B8').value = { formula: 'COUNT(D3:D6)', result: 4 };

  const originalBuffer = await wbOriginal.xlsx.writeBuffer();
  const originalFilePath = path.join(__dirname, 'sample_complex.xlsx');
  fs.writeFileSync(originalFilePath, originalBuffer);
  console.log(`Đã xuất file kiểm thử mẫu: ${originalFilePath} (${originalBuffer.byteLength} bytes)`);

  console.log('\n--- GIAI ĐOẠN 2: IMPORT VÀO APP VÀ KIỂM TRA LÕI TÍNH TOÁN ---');
  const appData = await convertWorkbookToAppData(wbOriginal);

  // 1. Kiểm tra số lượng Sheet
  assert(appData.sheets.length === 3, 'File có đúng 3 sheet: Sheet1, DoanhThu, NhanVien');
  assert(appData.sheets.map(s => s.name).join(',') === 'Sheet1,DoanhThu,NhanVien', 'Tên các sheet bảo toàn chính xác');

  // 2. Kiểm tra Merged cells
  const sheet1Merges = appData.sheets[0].merges;
  assert(sheet1Merges.length > 0 && sheet1Merges[0].s.r === 0 && sheet1Merges[0].e.c === 3, 'Sheet1 gộp ô A1:D1 chính xác');
  
  const doanhThuMerges = appData.sheets[1].merges;
  assert(doanhThuMerges.length > 0 && doanhThuMerges[0].s.r === 0 && doanhThuMerges[0].e.c === 4, 'DoanhThu gộp ô A1:E1 chính xác');

  // 3. Kiểm tra Styles & Format
  const s1Title = appData.sheets[0].cells['0_0'];
  assert(s1Title.s?.bold === true, 'Tiêu đề Sheet1 có in đậm (Bold)');
  assert(s1Title.s?.bgColor === '#107C41', 'Tiêu đề Sheet1 giữ đúng mã màu nền Office Green #107C41');
  assert(s1Title.s?.align === 'center', 'Tiêu đề Sheet1 căn giữa (Center align)');

  // 4. Kiểm tra Lõi công thức & Đánh giá (Re-calculation)
  const dtCells = appData.sheets[1].cells;
  
  // Kiểm tra phép nhân: row 3 (0-indexed: row 2, col 3 -> '2_3' cho D3 = B3*C3 = 10 * 200000 = 2000000)
  assert(dtCells['2_3'].f === '=B3*C3', 'Công thức D3 được nạp chính xác: =B3*C3');
  assert(Number(dtCells['2_3'].v) === 2000000, `Kết quả tính toán phép nhân D3 = 2,000,000 (Thực tế: ${dtCells['2_3'].v})`);

  // Kiểm tra phép nhân D4 = 25 * 150000 = 3750000
  assert(Number(dtCells['3_3'].v) === 3750000, `Kết quả tính toán phép nhân D4 = 3,750,000 (Thực tế: ${dtCells['3_3'].v})`);

  // Kiểm tra hàm IF: E3 (row 2, col 4: 2000000 <= 3000000 -> Bình Thường)
  assert(dtCells['2_4'].f === '=IF(D3>3000000, "Doanh Thu Cao", "Bình Thường")', 'Công thức IF ô E3 chính xác');
  assert(dtCells['2_4'].v === 'Bình Thường', `Hàm IF ô E3 cho kết quả: ${dtCells['2_4'].v}`);

  // Kiểm tra hàm IF: E4 (row 3, col 4: 3750000 > 3000000 -> Doanh Thu Cao)
  assert(dtCells['3_4'].v === 'Doanh Thu Cao', `Hàm IF ô E4 cho kết quả: ${dtCells['3_4'].v}`);

  // Kiểm tra hàm SUM: D8 (row 7, col 3 = SUM(D3:D7) = 16450000)
  assert(dtCells['7_3'].f === '=SUM(D3:D7)', 'Công thức SUM ô D8 chính xác: =SUM(D3:D7)');
  assert(Number(dtCells['7_3'].v) === 16450000, `Kết quả hàm SUM D8 = 16,450,000 (Thực tế: ${dtCells['7_3'].v})`);

  // Kiểm tra hàm SUM cột số lượng B8 (row 7, col 1 = SUM(B3:B7) = 102)
  assert(Number(dtCells['7_1'].v) === 102, `Kết quả hàm SUM B8 = 102 (Thực tế: ${dtCells['7_1'].v})`);

  // Kiểm tra hàm AVERAGE: D9 (row 8, col 3 = AVERAGE(D3:D7) = 3290000)
  assert(dtCells['8_3'].f === '=AVERAGE(D3:D7)', 'Công thức AVERAGE ô D9 chính xác: =AVERAGE(D3:D7)');
  assert(Number(dtCells['8_3'].v) === 3290000, `Kết quả hàm AVERAGE D9 = 3,290,000 (Thực tế: ${dtCells['8_3'].v})`);

  // Kiểm tra Sheet 3: NhanVien hàm COUNT
  const nvCells = appData.sheets[2].cells;
  assert(nvCells['7_1'].f === '=COUNT(D3:D6)', 'Công thức COUNT ô B8 chính xác: =COUNT(D3:D6)');
  assert(Number(nvCells['7_1'].v) === 4, `Kết quả hàm COUNT B8 = 4 (Thực tế: ${nvCells['7_1'].v})`);

  console.log('\n--- GIAI ĐOẠN 3: EXPORT RA FILE MỚI VÀ ROUND-TRIP VERIFICATION ---');
  // Chỉnh sửa thêm dữ liệu để mô phỏng người dùng nhập liệu trên app trước khi lưu
  // Thay đổi số lượng đơn hàng DH001 từ 10 thành 20 -> D3 phải thành 4,000,000, E3 đổi thành "Doanh Thu Cao", SUM D8 phải thành 18,450,000
  console.log('Mô phỏng người dùng sửa ô B3 (Số lượng DH001) từ 10 lên 20...');
  appData.sheets[1].cells['2_1'].v = 20;
  // Kích hoạt re-evaluate
  appData.sheets[1].cells = formulaEngine.evaluateAll(appData.sheets[1].cells);
  
  assert(Number(appData.sheets[1].cells['2_3'].v) === 4000000, 'D3 tự động nhảy từ 2,000,000 lên 4,000,000');
  assert(appData.sheets[1].cells['2_4'].v === 'Doanh Thu Cao', 'E3 tự động đổi từ "Bình Thường" sang "Doanh Thu Cao"');
  assert(Number(appData.sheets[1].cells['7_3'].v) === 18450000, 'Tổng SUM(D3:D7) tự động cập nhật lên 18,450,000');

  // Xuất file mới
  const exportedBuffer = await exportAppDataToExcel(appData);
  const exportedFilePath = path.join(__dirname, 'sample_exported.xlsx');
  fs.writeFileSync(exportedFilePath, exportedBuffer);
  console.log(`Đã xuất file sau chỉnh sửa: ${exportedFilePath} (${exportedBuffer.byteLength} bytes)`);

  // Đọc lại file exported bằng ExcelJS độc lập
  const wbVerify = new ExcelJS.Workbook();
  await wbVerify.xlsx.readFile(exportedFilePath);

  assert(wbVerify.worksheets.length === 3, 'File exported đọc lại vẫn đầy đủ 3 sheets');
  const wsVerifyDT = wbVerify.getWorksheet('DoanhThu');
  assert(wsVerifyDT !== undefined, 'Sheet DoanhThu tồn tại');

  // Kiểm tra công thức và giá trị trong file Excel chuẩn
  const cellD3 = wsVerifyDT.getCell('D3');
  assert(cellD3.formula === 'B3*C3', `Công thức D3 được lưu nguyên bản trong file Excel: ${cellD3.formula}`);
  assert(cellD3.result === 4000000, `Giá trị tính toán đã lưu của D3: ${cellD3.result}`);

  const cellE3 = wsVerifyDT.getCell('E3');
  assert(cellE3.formula === 'IF(D3>3000000, "Doanh Thu Cao", "Bình Thường")', `Công thức IF của E3 được lưu nguyên bản`);
  assert(cellE3.result === 'Doanh Thu Cao', `Kết quả IF của E3 đã cập nhật: ${cellE3.result}`);

  const cellD8 = wsVerifyDT.getCell('D8');
  assert(cellD8.formula === 'SUM(D3:D7)', `Công thức SUM D8 được lưu nguyên bản: ${cellD8.formula}`);
  assert(cellD8.result === 18450000, `Kết quả SUM D8: ${cellD8.result}`);

  const cellD9 = wsVerifyDT.getCell('D9');
  assert(cellD9.formula === 'AVERAGE(D3:D7)', `Công thức AVERAGE D9 được lưu nguyên bản`);

  // Kiểm tra định dạng còn nguyên
  const titleVerify = wbVerify.getWorksheet('Sheet1').getCell('A1');
  assert(titleVerify.font?.bold === true, 'Định dạng in đậm A1 Sheet1 giữ nguyên khi xuất ra');
  assert(titleVerify.fill?.fgColor?.argb === 'FF107C41', 'Màu nền A1 Sheet1 (FF107C41) giữ nguyên khi xuất ra');

  // Kiểm tra Merged cells
  const mergedModel = wsVerifyDT.model.merges;
  const hasA1E1Merge = mergedModel && mergedModel.some(m => m === 'A1:E1');
  assert(hasA1E1Merge, 'Merged cell A1:E1 của sheet DoanhThu được bảo toàn 100%');

  console.log('\n================================================================');
  console.log(`  KẾT QUẢ KIỂM THỬ: TỔNG SỐ TEST: ${passCount + failCount} | PASS: ${passCount} | FAIL: ${failCount}`);
  console.log('================================================================\n');

  if (failCount === 0) {
    console.log('>>> KẾT LUẬN: TOÀN BỘ CÁC TIÊU CHÍ IMPORT/EXPORT VÀ CÔNG THỨC ĐẠT 100%! <<<\n');
  } else {
    console.error('>>> CẢNH BÁO: CÓ TEST CASE BỊ THẤT BẠI! CẦN KIỂM TRA LẠI MÃ NGUỒN. <<<\n');
    process.exit(1);
  }
}

runAdvancedTest().catch(err => {
  console.error('Test gặp lỗi nghiêm trọng:', err);
  process.exit(1);
});
