import ExcelJS from 'exceljs';
import { WorkbookData, SheetData, CellData, CellStyle } from '../types/excel';
import { formulaEngine } from './formulaEngine';

/**
 * Converts ARGB or RGB color from ExcelJS to Hex (#RRGGBB)
 */
function argbToHex(argb: any): string | undefined {
  if (!argb) return undefined;
  if (typeof argb === 'string') {
    if (argb.length === 8) {
      // AARRGGBB -> #RRGGBB
      return '#' + argb.substring(2);
    }
    if (argb.startsWith('#')) return argb;
    return '#' + argb;
  }
  return undefined;
}

/**
 * Converts Hex (#RRGGBB) to ARGB (FFRRGGBB) for ExcelJS
 */
function hexToArgb(hex: string | undefined): string | undefined {
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

/**
 * Reads an Excel file (.xlsx, .xls, .csv) and converts it to WorkbookData
 */
export async function importExcelFile(fileOrBuffer: File | { name: string; buffer: ArrayBuffer | Uint8Array }): Promise<WorkbookData> {
  let arrayBuffer: ArrayBuffer;
  let fileName = 'Workbook';

  if (fileOrBuffer instanceof File) {
    arrayBuffer = await fileOrBuffer.arrayBuffer();
    fileName = fileOrBuffer.name;
  } else {
    fileName = fileOrBuffer.name;
    const buf = fileOrBuffer.buffer;
    if (buf instanceof ArrayBuffer) {
      arrayBuffer = buf;
    } else {
      // Uint8Array or Buffer
      arrayBuffer = buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength) as ArrayBuffer;
    }
  }

  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(arrayBuffer);

  const sheets: SheetData[] = [];

  workbook.eachSheet((worksheet, sheetId) => {
    const cells: { [key: string]: CellData } = {};
    const rowHeights: { [row: number]: number } = {};
    const colWidths: { [col: number]: number } = {};
    const merges: SheetData['merges'] = [];

    let maxRow = Math.max(worksheet.rowCount || 0, 50);
    let maxCol = Math.max(worksheet.columnCount || 0, 26);

    // Read column widths
    worksheet.columns?.forEach((col, index) => {
      if (col && col.width) {
        colWidths[index] = Math.round(col.width * 8); // approximate pixels
      }
    });

    // Read merges
    const modelMerges = (worksheet.model as any)?.merges;
    if (Array.isArray(modelMerges)) {
      for (const m of modelMerges) {
        const parts = m.split(':');
        if (parts.length === 2) {
          try {
            const c1 = worksheet.getCell(parts[0]);
            const c2 = worksheet.getCell(parts[1]);
            merges.push({
              s: { r: Number(c1.row) - 1, c: Number(c1.col) - 1 },
              e: { r: Number(c2.row) - 1, c: Number(c2.col) - 1 }
            });
          } catch (e) {
            console.error('Error parsing merge:', m, e);
          }
        }
      }
    }

    // Read rows & cells
    worksheet.eachRow({ includeEmpty: false }, (row, rowNumber) => {
      const r = rowNumber - 1;
      if (row.height) {
        rowHeights[r] = Math.round(row.height * 1.33); // points to px
      }

      row.eachCell({ includeEmpty: false }, (cell, colNumber) => {
        const c = colNumber - 1;
        const cellKey = `${r}_${c}`;

        let val: any = cell.value;
        let formula: string | undefined = undefined;

        if (val && typeof val === 'object') {
          if ('formula' in val) {
            formula = '=' + (val as any).formula;
            val = (val as any).result !== undefined ? (val as any).result : 0;
          } else if ('richText' in val) {
            val = (val as any).richText.map((t: any) => t.text).join('');
          } else if ('text' in val) {
            val = (val as any).text;
          }
        }

        const s: CellStyle = {};
        if (cell.font) {
          if (cell.font.bold) s.bold = true;
          if (cell.font.italic) s.italic = true;
          if (cell.font.underline) s.underline = true;
          if (cell.font.strike) s.strike = true;
          if (cell.font.size) s.fontSize = cell.font.size;
          if (cell.font.name) s.fontFamily = cell.font.name;
          if (cell.font.color?.argb) {
            s.color = argbToHex(cell.font.color.argb);
          }
        }

        if (cell.fill && cell.fill.type === 'pattern' && (cell.fill as any).fgColor?.argb) {
          s.bgColor = argbToHex((cell.fill as any).fgColor.argb);
        }

        if (cell.alignment) {
          if (cell.alignment.horizontal) {
            s.align = cell.alignment.horizontal as any;
          }
          if (cell.alignment.vertical) {
            s.verticalAlign = cell.alignment.vertical === 'middle' ? 'middle' : cell.alignment.vertical as any;
          }
          if (cell.alignment.wrapText) {
            s.wrapText = true;
          }
        }

        if (cell.numFmt) {
          const nf = cell.numFmt.toLowerCase();
          if (nf.includes('vnd') || nf.includes('₫')) s.numFmt = 'currency_vnd';
          else if (nf.includes('$')) s.numFmt = 'currency_usd';
          else if (nf.includes('%')) s.numFmt = 'percent';
          else if (nf.includes('yy') || nf.includes('mm') || nf.includes('dd')) s.numFmt = 'date';
          else if (nf.includes('0.00') || nf.includes('#,##0')) s.numFmt = 'number';
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
      id: `sheet_${sheetId}_${Date.now()}`,
      name: worksheet.name || `Sheet${sheetId}`,
      rowCount: Math.max(maxRow + 20, 100),
      colCount: Math.max(maxCol + 10, 26),
      cells: evaluatedCells,
      rowHeights,
      colWidths,
      merges
    });
  });

  if (sheets.length === 0) {
    sheets.push({
      id: `sheet_default_${Date.now()}`,
      name: 'Sheet1',
      rowCount: 100,
      colCount: 26,
      cells: {},
      rowHeights: {},
      colWidths: {},
      merges: []
    });
  }

  return {
    title: fileName.replace(/\.[^/.]+$/, ''),
    sheets,
    activeSheetId: sheets[0].id,
    isModified: false,
    filePath: (fileOrBuffer as any).path || null
  };
}

/**
 * Exports WorkbookData to an Excel (.xlsx) file and triggers download / save
 */
export async function exportExcelFile(workbookData: WorkbookData, filename?: string): Promise<Uint8Array> {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'Excel PC Editor';
  wb.created = new Date();

  for (const sheet of workbookData.sheets) {
    const ws = wb.addWorksheet(sheet.name);

    // Apply column widths
    for (const cStr in sheet.colWidths) {
      const c = Number(cStr);
      const col = ws.getColumn(c + 1);
      col.width = Math.max(sheet.colWidths[c] / 8, 8);
    }

    // Apply cells
    for (const key in sheet.cells) {
      const [rStr, cStr] = key.split('_');
      const r = Number(rStr) + 1;
      const c = Number(cStr) + 1;
      const cellData = sheet.cells[key];
      const excelCell = ws.getCell(r, c);

      // Formula or Value
      if (cellData.f && cellData.f.startsWith('=')) {
        excelCell.value = {
          formula: cellData.f.substring(1),
          result: cellData.v as any
        };
      } else {
        excelCell.value = cellData.v as any;
      }

      // Styles
      const s = cellData.s;
      if (s) {
        // Font
        const font: any = {};
        if (s.fontFamily) font.name = s.fontFamily;
        if (s.fontSize) font.size = s.fontSize;
        if (s.bold) font.bold = true;
        if (s.italic) font.italic = true;
        if (s.underline) font.underline = true;
        if (s.strike) font.strike = true;
        if (s.color) {
          const argb = hexToArgb(s.color);
          if (argb) font.color = { argb };
        }
        if (Object.keys(font).length > 0) {
          excelCell.font = font;
        }

        // Fill background
        if (s.bgColor && s.bgColor !== '#ffffff' && s.bgColor !== 'transparent') {
          const argb = hexToArgb(s.bgColor);
          if (argb) {
            excelCell.fill = {
              type: 'pattern',
              pattern: 'solid',
              fgColor: { argb }
            };
          }
        }

        // Alignment
        const alignment: any = {};
        if (s.align) alignment.horizontal = s.align;
        if (s.verticalAlign) alignment.vertical = s.verticalAlign;
        if (s.wrapText) alignment.wrapText = true;
        if (Object.keys(alignment).length > 0) {
          excelCell.alignment = alignment;
        }

        // Number format
        if (s.numFmt) {
          switch (s.numFmt) {
            case 'currency_vnd':
              excelCell.numFmt = '#,##0 "₫"';
              break;
            case 'currency_usd':
              excelCell.numFmt = '"$"#,##0.00';
              break;
            case 'percent':
              excelCell.numFmt = '0.00%';
              break;
            case 'date':
              excelCell.numFmt = 'dd/mm/yyyy';
              break;
            case 'number':
              excelCell.numFmt = '#,##0.00';
              break;
          }
        }

        // Border
        if (s.border) {
          const borders: any = {};
          const style = s.border.style || 'thin';
          const argb = hexToArgb(s.border.color || '#d4d4d4') || 'FFD4D4D4';

          if (s.border.top) borders.top = { style, color: { argb } };
          if (s.border.bottom) borders.bottom = { style, color: { argb } };
          if (s.border.left) borders.left = { style, color: { argb } };
          if (s.border.right) borders.right = { style, color: { argb } };

          if (Object.keys(borders).length > 0) {
            excelCell.border = borders;
          }
        }
      }
    }

    // Apply row heights
    for (const rStr in sheet.rowHeights) {
      const r = Number(rStr) + 1;
      const row = ws.getRow(r);
      row.height = sheet.rowHeights[Number(rStr)] / 1.33;
    }

    // Apply merges
    for (const m of sheet.merges) {
      try {
        ws.mergeCells(m.s.r + 1, m.s.c + 1, m.e.r + 1, m.e.c + 1);
      } catch (e) {
        console.warn('Merge error:', m, e);
      }
    }
  }

  // Generate buffer
  const buffer = await wb.xlsx.writeBuffer();
  const uint8Array = new Uint8Array(buffer);

  // If in Electron, save via IPC dialog
  if (typeof window !== 'undefined' && (window as any).electronAPI?.saveFileDialog) {
    const res = await (window as any).electronAPI.saveFileDialog({
      defaultName: (filename || workbookData.title || 'Workbook') + '.xlsx',
      buffer: uint8Array
    });
    if (res?.success) {
      return uint8Array;
    }
  }

  // If in web / browser, trigger download
  if (typeof window !== 'undefined') {
    const blob = new Blob([uint8Array], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = (filename || workbookData.title || 'Workbook') + '.xlsx';
    a.click();
    URL.revokeObjectURL(url);
  }

  return uint8Array;
}
