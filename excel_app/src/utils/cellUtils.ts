import { CellData, CellFormatType, CellRange } from '../types/excel';

/**
 * Converts a 0-based column index to an Excel column name (0 -> "A", 25 -> "Z", 26 -> "AA")
 */
export function colIndexToName(col: number): string {
  let temp = col + 1;
  let letter = '';
  while (temp > 0) {
    const mod = (temp - 1) % 26;
    letter = String.fromCharCode(65 + mod) + letter;
    temp = Math.floor((temp - mod) / 26);
  }
  return letter;
}

/**
 * Converts an Excel column name to a 0-based column index ("A" -> 0, "Z" -> 25, "AA" -> 26)
 */
export function colNameToIndex(name: string): number {
  let col = 0;
  const upper = name.toUpperCase();
  for (let i = 0; i < upper.length; i++) {
    col = col * 26 + (upper.charCodeAt(i) - 64);
  }
  return col - 1;
}

/**
 * Converts 0-based row and column to Excel cell label (0, 0 -> "A1")
 */
export function cellCoordsToLabel(r: number, c: number): string {
  return `${colIndexToName(c)}${r + 1}`;
}

/**
 * Parses an Excel cell label to 0-based coordinates ("A1" -> { r: 0, c: 0 })
 */
export function cellLabelToCoords(label: string): { r: number; c: number } | null {
  const match = label.trim().toUpperCase().match(/^([A-Z]+)(\d+)$/);
  if (!match) return null;
  const col = colNameToIndex(match[1]);
  const row = parseInt(match[2], 10) - 1;
  if (isNaN(row) || col < 0) return null;
  return { r: row, c: col };
}

/**
 * Formats a cell's value based on its numFmt configuration
 */
export function formatCellValue(value: any, numFmt?: CellFormatType): string {
  if (value === undefined || value === null || value === '') {
    return '';
  }

  // If boolean
  if (typeof value === 'boolean') {
    return value ? 'TRUE' : 'FALSE';
  }

  const num = Number(value);
  const isNumber = !isNaN(num) && typeof value !== 'boolean';

  switch (numFmt) {
    case 'number':
      if (isNumber) {
        return num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      }
      break;

    case 'currency_vnd':
      if (isNumber) {
        return num.toLocaleString('vi-VN') + ' ₫';
      }
      break;

    case 'currency_usd':
      if (isNumber) {
        return '$' + num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      }
      break;

    case 'percent':
      if (isNumber) {
        return (num * 100).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + '%';
      }
      break;

    case 'date':
      if (value instanceof Date) {
        return value.toLocaleDateString('vi-VN');
      }
      if (typeof value === 'string' || typeof value === 'number') {
        const d = new Date(value);
        if (!isNaN(d.getTime())) {
          return d.toLocaleDateString('vi-VN');
        }
      }
      break;

    case 'general':
    default:
      if (isNumber) {
        // Return standard number format without unnecessary trailing zeros
        return Number.isInteger(num) ? num.toString() : num.toLocaleString('en-US', { maximumFractionDigits: 10 });
      }
      break;
  }

  return String(value);
}

/**
 * Normalize range so start is top-left and end is bottom-right
 */
export function normalizeRange(r1: number, c1: number, r2: number, c2: number): CellRange {
  return {
    startRow: Math.min(r1, r2),
    startCol: Math.min(c1, c2),
    endRow: Math.max(r1, r2),
    endCol: Math.max(c1, c2)
  };
}

/**
 * Format range to label: e.g. "A1:B10" or "A1" if 1 cell
 */
export function rangeToLabel(range: CellRange): string {
  const start = cellCoordsToLabel(range.startRow, range.startCol);
  const end = cellCoordsToLabel(range.endRow, range.endCol);
  if (start === end) return start;
  return `${start}:${end}`;
}

/**
 * Check if cell (r, c) is inside range
 */
export function isCellInRange(r: number, c: number, range: CellRange): boolean {
  return (
    r >= range.startRow &&
    r <= range.endRow &&
    c >= range.startCol &&
    c <= range.endCol
  );
}

/**
 * Generates an empty grid of cells for new sheet
 */
export function createEmptySheet(id: string, name: string, rowCount = 100, colCount = 26) {
  return {
    id,
    name,
    rowCount,
    colCount,
    cells: {},
    rowHeights: {},
    colWidths: {},
    merges: []
  };
}
