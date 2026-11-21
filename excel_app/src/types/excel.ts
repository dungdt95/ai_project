export type CellFormatType = 
  | 'general' 
  | 'number' 
  | 'currency_vnd' 
  | 'currency_usd' 
  | 'percent' 
  | 'date';

export interface CellBorder {
  top?: boolean;
  bottom?: boolean;
  left?: boolean;
  right?: boolean;
  color?: string;
  style?: 'thin' | 'medium' | 'thick' | 'double';
}

export interface CellStyle {
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strike?: boolean;
  fontSize?: number; // e.g. 11
  fontFamily?: string; // 'Segoe UI', 'Arial', etc.
  color?: string; // Hex e.g. #000000
  bgColor?: string; // Hex e.g. #ffffff
  align?: 'left' | 'center' | 'right';
  verticalAlign?: 'top' | 'middle' | 'bottom';
  wrapText?: boolean;
  numFmt?: CellFormatType;
  border?: CellBorder;
}

export interface CellData {
  v?: string | number | boolean | null; // Raw value
  f?: string; // Formula string, starts with '='
  m?: string; // Formatted display text
  s?: CellStyle; // Cell style
}

export interface CellRange {
  startRow: number;
  startCol: number;
  endRow: number;
  endCol: number;
}

export interface MergeRange {
  s: { r: number; c: number };
  e: { r: number; c: number };
}

export interface SheetData {
  id: string;
  name: string;
  rowCount: number;
  colCount: number;
  cells: { [key: string]: CellData }; // Key is 'r_c' e.g. '0_0' for A1
  rowHeights: { [row: number]: number };
  colWidths: { [col: number]: number };
  merges: MergeRange[];
}

export interface WorkbookData {
  title: string;
  sheets: SheetData[];
  activeSheetId: string;
  isModified?: boolean;
  filePath?: string | null;
}

export interface SelectionState {
  activeCell: { r: number; c: number };
  range: CellRange;
  isSelecting: boolean;
}

export type RibbonTab = 'home' | 'insert' | 'data' | 'view';

export interface ClipboardData {
  range: CellRange;
  cells: { [key: string]: CellData };
  isCut?: boolean;
}
