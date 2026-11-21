import React, { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';
import {
  WorkbookData,
  SheetData,
  CellData,
  CellStyle,
  CellRange,
  SelectionState,
  RibbonTab,
  ClipboardData
} from '../types/excel';
import {
  colIndexToName,
  normalizeRange,
  formatCellValue,
  createEmptySheet
} from '../utils/cellUtils';
import { formulaEngine } from '../core/formulaEngine';
import { exportExcelFile, importExcelFile } from '../core/excelIO';

interface ExcelContextType {
  workbook: WorkbookData;
  activeSheet: SheetData;
  selection: SelectionState;
  editingCell: { r: number; c: number; value: string } | null;
  formulaBarText: string;
  activeTab: RibbonTab;
  zoom: number;
  showGridlines: boolean;
  showFormulaBar: boolean;
  showHeaders: boolean;
  canUndo: boolean;
  canRedo: boolean;

  // Actions
  setActiveTab: (tab: RibbonTab) => void;
  setZoom: (zoom: number) => void;
  setShowGridlines: (show: boolean) => void;
  setShowFormulaBar: (show: boolean) => void;
  setShowHeaders: (show: boolean) => void;
  
  // Selection
  setSelection: (activeCell: { r: number; c: number }, range?: CellRange) => void;
  updateSelectionRange: (endCell: { r: number; c: number }) => void;
  setIsSelecting: (isSelecting: boolean) => void;
  
  // Editing & Formula
  startEditing: (r: number, c: number, initialChar?: string) => void;
  cancelEditing: () => void;
  commitEditing: (newValue?: string) => void;
  setFormulaBarText: (text: string) => void;
  onFormulaBarChange: (text: string) => void;

  // Formatting & Operations
  applyFormat: (style: Partial<CellStyle>) => void;
  toggleMerge: () => void;
  clearSelection: () => void;
  autoSum: (type: 'SUM' | 'AVERAGE' | 'COUNT' | 'MAX' | 'MIN') => void;
  sortSelection: (direction: 'asc' | 'desc') => void;
  fillRange: (targetRange: CellRange) => void;
  
  // Clipboard
  copy: () => void;
  cut: () => void;
  paste: () => void;

  // Row / Col sizing & Operations
  setColWidth: (col: number, width: number) => void;
  setRowHeight: (row: number, height: number) => void;
  insertRow: (index?: number) => void;
  deleteRow: (index?: number) => void;
  insertCol: (index?: number) => void;
  deleteCol: (index?: number) => void;

  // Sheet Management
  setActiveSheet: (id: string) => void;
  addSheet: () => void;
  renameSheet: (id: string, newName: string) => void;
  deleteSheet: (id: string) => void;

  // File I/O
  newWorkbook: () => void;
  saveWorkbook: () => Promise<void>;
  openFile: (file: File | { name: string; buffer: ArrayBuffer | Uint8Array }) => Promise<void>;
  setWorkbookTitle: (title: string) => void;
  
  // History
  undo: () => void;
  redo: () => void;
}

const ExcelContext = createContext<ExcelContextType | undefined>(undefined);

// Initial Sample Workbook
function getInitialWorkbook(): WorkbookData {
  const sheet1 = createEmptySheet('sheet_1', 'Trang tính 1', 100, 26);
  
  // Prepopulate sample helpful template data
  const sampleData: { [key: string]: Partial<CellData> } = {
    '1_1': { v: 'BÁO CÁO DOANH THU & KẾ HOẠCH', s: { bold: true, fontSize: 16, color: '#107c41', align: 'left' } },
    '3_1': { v: 'STT', s: { bold: true, bgColor: '#107c41', color: '#ffffff', align: 'center', border: { top: true, bottom: true, left: true, right: true } } },
    '3_2': { v: 'Hạng mục', s: { bold: true, bgColor: '#107c41', color: '#ffffff', align: 'left', border: { top: true, bottom: true, left: true, right: true } } },
    '3_3': { v: 'Số lượng', s: { bold: true, bgColor: '#107c41', color: '#ffffff', align: 'right', border: { top: true, bottom: true, left: true, right: true } } },
    '3_4': { v: 'Đơn giá (VNĐ)', s: { bold: true, bgColor: '#107c41', color: '#ffffff', align: 'right', border: { top: true, bottom: true, left: true, right: true } } },
    '3_5': { v: 'Thành tiền', s: { bold: true, bgColor: '#107c41', color: '#ffffff', align: 'right', border: { top: true, bottom: true, left: true, right: true } } },

    '4_1': { v: 1, s: { align: 'center', border: { top: true, bottom: true, left: true, right: true } } },
    '4_2': { v: 'Phần mềm Excel Editor PC', s: { align: 'left', border: { top: true, bottom: true, left: true, right: true } } },
    '4_3': { v: 15, s: { align: 'right', numFmt: 'number', border: { top: true, bottom: true, left: true, right: true } } },
    '4_4': { v: 500000, s: { align: 'right', numFmt: 'currency_vnd', border: { top: true, bottom: true, left: true, right: true } } },
    '4_5': { f: '=C5*D5', s: { align: 'right', numFmt: 'currency_vnd', bold: true, border: { top: true, bottom: true, left: true, right: true } } },

    '5_1': { v: 2, s: { align: 'center', border: { top: true, bottom: true, left: true, right: true } } },
    '5_2': { v: 'Gói hỗ trợ kỹ thuật VIP', s: { align: 'left', border: { top: true, bottom: true, left: true, right: true } } },
    '5_3': { v: 8, s: { align: 'right', numFmt: 'number', border: { top: true, bottom: true, left: true, right: true } } },
    '5_4': { v: 1200000, s: { align: 'right', numFmt: 'currency_vnd', border: { top: true, bottom: true, left: true, right: true } } },
    '5_5': { f: '=C6*D6', s: { align: 'right', numFmt: 'currency_vnd', bold: true, border: { top: true, bottom: true, left: true, right: true } } },

    '6_1': { v: 3, s: { align: 'center', border: { top: true, bottom: true, left: true, right: true } } },
    '6_2': { v: 'Bản quyền mở rộng', s: { align: 'left', border: { top: true, bottom: true, left: true, right: true } } },
    '6_3': { v: 20, s: { align: 'right', numFmt: 'number', border: { top: true, bottom: true, left: true, right: true } } },
    '6_4': { v: 350000, s: { align: 'right', numFmt: 'currency_vnd', border: { top: true, bottom: true, left: true, right: true } } },
    '6_5': { f: '=C7*D7', s: { align: 'right', numFmt: 'currency_vnd', bold: true, border: { top: true, bottom: true, left: true, right: true } } },

    '7_1': { v: 'Tổng cộng', s: { bold: true, align: 'center', bgColor: '#f2f2f2', border: { top: true, bottom: true, left: true, right: true } } },
    '7_2': { v: '', s: { border: { top: true, bottom: true, left: true, right: true }, bgColor: '#f2f2f2' } },
    '7_3': { f: '=SUM(C5:C7)', s: { bold: true, align: 'right', numFmt: 'number', bgColor: '#f2f2f2', border: { top: true, bottom: true, left: true, right: true } } },
    '7_4': { v: '', s: { border: { top: true, bottom: true, left: true, right: true }, bgColor: '#f2f2f2' } },
    '7_5': { f: '=SUM(E5:E7)', s: { bold: true, align: 'right', numFmt: 'currency_vnd', color: '#b91c1c', bgColor: '#fef3c7', border: { top: true, bottom: true, left: true, right: true } } },

    '8_1': { v: 'Trung bình', s: { italic: true, align: 'center', border: { top: true, bottom: true, left: true, right: true } } },
    '8_2': { v: '', s: { border: { top: true, bottom: true, left: true, right: true } } },
    '8_3': { f: '=AVERAGE(C5:C7)', s: { italic: true, align: 'right', numFmt: 'number', border: { top: true, bottom: true, left: true, right: true } } },
    '8_4': { f: '=AVERAGE(D5:D7)', s: { italic: true, align: 'right', numFmt: 'currency_vnd', border: { top: true, bottom: true, left: true, right: true } } },
    '8_5': { f: '=AVERAGE(E5:E7)', s: { italic: true, align: 'right', numFmt: 'currency_vnd', border: { top: true, bottom: true, left: true, right: true } } }
  };

  // Set col widths
  sheet1.colWidths = {
    0: 45,
    1: 60,
    2: 240,
    3: 110,
    4: 150,
    5: 160
  };

  sheet1.merges = [
    { s: { r: 1, c: 1 }, e: { r: 1, c: 5 } },
    { s: { r: 7, c: 1 }, e: { r: 7, c: 2 } },
    { s: { r: 8, c: 1 }, e: { r: 8, c: 2 } }
  ];

  for (const k in sampleData) {
    sheet1.cells[k] = sampleData[k] as CellData;
  }

  sheet1.cells = formulaEngine.evaluateAll(sheet1.cells);

  return {
    title: 'Bảng_tính_1',
    sheets: [sheet1],
    activeSheetId: sheet1.id,
    isModified: false,
    filePath: null
  };
}

export const ExcelProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [workbook, setWorkbook] = useState<WorkbookData>(getInitialWorkbook);
  const [selection, setSelectionState] = useState<SelectionState>({
    activeCell: { r: 0, c: 0 },
    range: { startRow: 0, startCol: 0, endRow: 0, endCol: 0 },
    isSelecting: false
  });
  const [editingCell, setEditingCell] = useState<{ r: number; c: number; value: string } | null>(null);
  const [formulaBarText, setFormulaBarText] = useState<string>('');
  const [activeTab, setActiveTab] = useState<RibbonTab>('home');
  const [zoom, setZoom] = useState<number>(100);
  const [showGridlines, setShowGridlines] = useState<boolean>(true);
  const [showFormulaBar, setShowFormulaBar] = useState<boolean>(true);
  const [showHeaders, setShowHeaders] = useState<boolean>(true);

  // Undo / Redo stacks
  const [undoStack, setUndoStack] = useState<SheetData[]>([]);
  const [redoStack, setRedoStack] = useState<SheetData[]>([]);
  const [clipboard, setClipboard] = useState<ClipboardData | null>(null);

  const activeSheet = workbook.sheets.find(s => s.id === workbook.activeSheetId) || workbook.sheets[0];

  // Push current sheet state to undo stack before mutative operations
  const pushUndo = useCallback(() => {
    setUndoStack(prev => [...prev.slice(-30), JSON.parse(JSON.stringify(activeSheet))]);
    setRedoStack([]);
  }, [activeSheet]);

  // Update formula bar text whenever active cell changes or sheet updates
  useEffect(() => {
    if (editingCell) return;
    const key = `${selection.activeCell.r}_${selection.activeCell.c}`;
    const cell = activeSheet.cells[key];
    if (cell) {
      setFormulaBarText(cell.f || (cell.v !== undefined && cell.v !== null ? String(cell.v) : ''));
    } else {
      setFormulaBarText('');
    }
  }, [selection.activeCell, activeSheet, editingCell]);

  const updateSheet = useCallback((newSheet: SheetData, markModified = true) => {
    setWorkbook(prev => ({
      ...prev,
      isModified: markModified ? true : prev.isModified,
      sheets: prev.sheets.map(s => (s.id === newSheet.id ? newSheet : s))
    }));
  }, []);

  // Selection handlers
  const setSelection = useCallback((activeCell: { r: number; c: number }, range?: CellRange) => {
    const normRange = range || {
      startRow: activeCell.r,
      startCol: activeCell.c,
      endRow: activeCell.r,
      endCol: activeCell.c
    };
    setSelectionState({
      activeCell,
      range: normRange,
      isSelecting: false
    });
  }, []);

  const updateSelectionRange = useCallback((endCell: { r: number; c: number }) => {
    setSelectionState(prev => ({
      ...prev,
      range: normalizeRange(prev.activeCell.r, prev.activeCell.c, endCell.r, endCell.c)
    }));
  }, []);

  const setIsSelecting = useCallback((isSelecting: boolean) => {
    setSelectionState(prev => ({ ...prev, isSelecting }));
  }, []);

  // Editing handlers
  const startEditing = useCallback((r: number, c: number, initialChar?: string) => {
    const key = `${r}_${c}`;
    const cell = activeSheet.cells[key];
    const initialVal = initialChar !== undefined ? initialChar : (cell?.f || (cell?.v !== undefined && cell?.v !== null ? String(cell.v) : ''));
    setEditingCell({ r, c, value: initialVal });
    setFormulaBarText(initialVal);
  }, [activeSheet]);

  const cancelEditing = useCallback(() => {
    setEditingCell(null);
    const key = `${selection.activeCell.r}_${selection.activeCell.c}`;
    const cell = activeSheet.cells[key];
    setFormulaBarText(cell?.f || (cell?.v !== undefined && cell?.v !== null ? String(cell.v) : ''));
  }, [activeSheet, selection.activeCell]);

  const commitEditing = useCallback((overrideValue?: string) => {
    const r = editingCell ? editingCell.r : selection.activeCell.r;
    const c = editingCell ? editingCell.c : selection.activeCell.c;
    const val = overrideValue !== undefined ? overrideValue : (editingCell ? editingCell.value : formulaBarText);

    pushUndo();

    const key = `${r}_${c}`;
    const currentCell = activeSheet.cells[key] || {};
    const newCells = { ...activeSheet.cells };

    if (val.trim() === '') {
      if (newCells[key]) {
        delete newCells[key];
      }
    } else if (val.startsWith('=')) {
      newCells[key] = {
        ...currentCell,
        f: val.toUpperCase(),
        v: undefined
      };
    } else {
      // Check if number
      const num = Number(val);
      const isNum = !isNaN(num) && val.trim() !== '';
      newCells[key] = {
        ...currentCell,
        f: undefined,
        v: isNum ? num : val
      };
    }

    const reCalculated = formulaEngine.evaluateAll(newCells);
    const updatedSheet: SheetData = {
      ...activeSheet,
      cells: reCalculated
    };

    updateSheet(updatedSheet);
    setEditingCell(null);
  }, [editingCell, selection.activeCell, formulaBarText, activeSheet, pushUndo, updateSheet]);

  const onFormulaBarChange = useCallback((text: string) => {
    setFormulaBarText(text);
    if (editingCell) {
      setEditingCell(prev => (prev ? { ...prev, value: text } : null));
    }
  }, [editingCell]);

  // Apply format to selected range
  const applyFormat = useCallback((format: Partial<CellStyle>) => {
    pushUndo();
    const newCells = { ...activeSheet.cells };
    const { startRow, startCol, endRow, endCol } = selection.range;

    for (let r = startRow; r <= endRow; r++) {
      for (let c = startCol; c <= endCol; c++) {
        const key = `${r}_${c}`;
        const existing = newCells[key] || { v: '' };
        const existingStyle = existing.s || {};

        let newStyle: CellStyle = {
          ...existingStyle,
          ...format
        };

        if (format.border) {
          newStyle.border = {
            ...existingStyle.border,
            ...format.border
          };
        }

        newCells[key] = {
          ...existing,
          s: newStyle
        };
      }
    }

    const reCalculated = formulaEngine.evaluateAll(newCells);
    updateSheet({
      ...activeSheet,
      cells: reCalculated
    });
  }, [activeSheet, selection.range, pushUndo, updateSheet]);

  // Merge / Unmerge cells
  const toggleMerge = useCallback(() => {
    const { startRow, startCol, endRow, endCol } = selection.range;
    if (startRow === endRow && startCol === endCol) return; // Single cell

    pushUndo();
    // Check if range is already merged
    const existingMergeIndex = activeSheet.merges.findIndex(m =>
      m.s.r === startRow && m.s.c === startCol && m.e.r === endRow && m.e.c === endCol
    );

    let newMerges = [...activeSheet.merges];
    if (existingMergeIndex >= 0) {
      // Unmerge
      newMerges.splice(existingMergeIndex, 1);
    } else {
      // Filter out overlapping merges
      newMerges = newMerges.filter(m =>
        !(m.s.r >= startRow && m.e.r <= endRow && m.s.c >= startCol && m.e.c <= endCol)
      );
      newMerges.push({
        s: { r: startRow, c: startCol },
        e: { r: endRow, c: endCol }
      });
    }

    updateSheet({
      ...activeSheet,
      merges: newMerges
    });
  }, [activeSheet, selection.range, pushUndo, updateSheet]);

  // Clear selected cells
  const clearSelection = useCallback(() => {
    pushUndo();
    const newCells = { ...activeSheet.cells };
    const { startRow, startCol, endRow, endCol } = selection.range;

    for (let r = startRow; r <= endRow; r++) {
      for (let c = startCol; c <= endCol; c++) {
        delete newCells[`${r}_${c}`];
      }
    }

    const reCalculated = formulaEngine.evaluateAll(newCells);
    updateSheet({
      ...activeSheet,
      cells: reCalculated
    });
  }, [activeSheet, selection.range, pushUndo, updateSheet]);

  // AutoSum function insertion
  const autoSum = useCallback((type: 'SUM' | 'AVERAGE' | 'COUNT' | 'MAX' | 'MIN') => {
    const { startRow, startCol, endRow, endCol } = selection.range;
    const isSingleCell = startRow === endRow && startCol === endCol;

    pushUndo();
    const newCells = { ...activeSheet.cells };

    if (isSingleCell) {
      // Find numbers directly above active cell
      let topRow = startRow - 1;
      while (topRow >= 0) {
        const c = newCells[`${topRow}_${startCol}`];
        if (!c || c.v === undefined || c.v === null || c.v === '') break;
        topRow--;
      }
      topRow++;

      const formula = topRow < startRow
        ? `=${type}(${colIndexToName(startCol)}${topRow + 1}:${colIndexToName(startCol)}${startRow})`
        : `=${type}(${colIndexToName(startCol)}1:${colIndexToName(startCol)}${startRow})`;

      newCells[`${startRow}_${startCol}`] = {
        ...newCells[`${startRow}_${startCol}`],
        f: formula
      };
    } else {
      // Put formula right beneath the selected range
      const targetRow = endRow + 1;
      for (let c = startCol; c <= endCol; c++) {
        const colLetter = colIndexToName(c);
        const formula = `=${type}(${colLetter}${startRow + 1}:${colLetter}${endRow + 1})`;
        newCells[`${targetRow}_${c}`] = {
          ...newCells[`${targetRow}_${c}`],
          f: formula,
          s: { bold: true }
        };
      }
    }

    const reCalculated = formulaEngine.evaluateAll(newCells);
    updateSheet({
      ...activeSheet,
      cells: reCalculated
    });
  }, [activeSheet, selection.range, pushUndo, updateSheet]);

  // Sort Selection
  const sortSelection = useCallback((direction: 'asc' | 'desc') => {
    pushUndo();
    const { startRow, startCol, endRow, endCol } = selection.range;
    if (startRow >= endRow) return;

    // Extract rows in selection
    const rowList: { rowIdx: number; keyVal: any; cells: { [col: number]: CellData } }[] = [];
    for (let r = startRow; r <= endRow; r++) {
      const rowCells: { [col: number]: CellData } = {};
      for (let c = startCol; c <= endCol; c++) {
        const cell = activeSheet.cells[`${r}_${c}`];
        if (cell) rowCells[c] = { ...cell };
      }
      const sortCell = rowCells[startCol];
      rowList.push({
        rowIdx: r,
        keyVal: sortCell?.v ?? '',
        cells: rowCells
      });
    }

    rowList.sort((a, b) => {
      const vA = a.keyVal;
      const vB = b.keyVal;
      if (typeof vA === 'number' && typeof vB === 'number') {
        return direction === 'asc' ? vA - vB : vB - vA;
      }
      const strA = String(vA).toLowerCase();
      const strB = String(vB).toLowerCase();
      return direction === 'asc' ? strA.localeCompare(strB) : strB.localeCompare(strA);
    });

    const newCells = { ...activeSheet.cells };
    rowList.forEach((rowItem, idx) => {
      const targetRow = startRow + idx;
      for (let c = startCol; c <= endCol; c++) {
        delete newCells[`${targetRow}_${c}`];
        if (rowItem.cells[c]) {
          newCells[`${targetRow}_${c}`] = rowItem.cells[c];
        }
      }
    });

    const reCalculated = formulaEngine.evaluateAll(newCells);
    updateSheet({
      ...activeSheet,
      cells: reCalculated
    });
  }, [activeSheet, selection.range, pushUndo, updateSheet]);

  // Drag Fill Handle
  const fillRange = useCallback((targetRange: CellRange) => {
    pushUndo();
    const sourceRange = selection.range;
    const newCells = { ...activeSheet.cells };

    // Detect if expanding down
    const sourceHeight = sourceRange.endRow - sourceRange.startRow + 1;
    const sourceWidth = sourceRange.endCol - sourceRange.startCol + 1;

    for (let r = targetRange.startRow; r <= targetRange.endRow; r++) {
      for (let c = targetRange.startCol; c <= targetRange.endCol; c++) {
        const sourceR = sourceRange.startRow + ((r - targetRange.startRow) % sourceHeight);
        const sourceC = sourceRange.startCol + ((c - targetRange.startCol) % sourceWidth);
        const sourceCell = activeSheet.cells[`${sourceR}_${sourceC}`];

        if (sourceCell) {
          // If number and dragging vertically with single item, auto-increment
          let val = sourceCell.v;
          if (typeof val === 'number' && sourceHeight === 1 && r > sourceRange.endRow) {
            val = val + (r - sourceRange.endRow);
          }

          newCells[`${r}_${c}`] = {
            ...sourceCell,
            v: val,
            f: sourceCell.f // Maintain formula
          };
        }
      }
    }

    const reCalculated = formulaEngine.evaluateAll(newCells);
    updateSheet({
      ...activeSheet,
      cells: reCalculated
    });
  }, [activeSheet, selection.range, pushUndo, updateSheet]);

  // Clipboard operations
  const copy = useCallback(() => {
    const cells: { [key: string]: CellData } = {};
    const { startRow, startCol, endRow, endCol } = selection.range;
    for (let r = startRow; r <= endRow; r++) {
      for (let c = startCol; c <= endCol; c++) {
        const key = `${r}_${c}`;
        if (activeSheet.cells[key]) {
          cells[key] = { ...activeSheet.cells[key] };
        }
      }
    }
    setClipboard({
      range: selection.range,
      cells,
      isCut: false
    });
  }, [activeSheet.cells, selection.range]);

  const cut = useCallback(() => {
    copy();
    setClipboard(prev => (prev ? { ...prev, isCut: true } : null));
  }, [copy]);

  const paste = useCallback(() => {
    if (!clipboard) return;
    pushUndo();

    const destR = selection.activeCell.r;
    const destC = selection.activeCell.c;
    const srcRange = clipboard.range;
    const rowOffset = destR - srcRange.startRow;
    const colOffset = destC - srcRange.startCol;

    const newCells = { ...activeSheet.cells };

    for (const key in clipboard.cells) {
      const [rStr, cStr] = key.split('_');
      const r = Number(rStr) + rowOffset;
      const c = Number(cStr) + colOffset;
      newCells[`${r}_${c}`] = { ...clipboard.cells[key] };
    }

    if (clipboard.isCut) {
      for (const key in clipboard.cells) {
        delete newCells[key];
      }
      setClipboard(null);
    }

    const reCalculated = formulaEngine.evaluateAll(newCells);
    updateSheet({
      ...activeSheet,
      cells: reCalculated
    });
  }, [clipboard, selection.activeCell, activeSheet, pushUndo, updateSheet]);

  // Column / Row resizing
  const setColWidth = useCallback((col: number, width: number) => {
    updateSheet({
      ...activeSheet,
      colWidths: {
        ...activeSheet.colWidths,
        [col]: Math.max(30, width)
      }
    });
  }, [activeSheet, updateSheet]);

  const setRowHeight = useCallback((row: number, height: number) => {
    updateSheet({
      ...activeSheet,
      rowHeights: {
        ...activeSheet.rowHeights,
        [row]: Math.max(18, height)
      }
    });
  }, [activeSheet, updateSheet]);

  // Insert / Delete Rows & Cols
  const insertRow = useCallback((index?: number) => {
    const at = index !== undefined ? index : selection.activeCell.r;
    pushUndo();
    const newCells: { [key: string]: CellData } = {};

    for (const k in activeSheet.cells) {
      const [rStr, cStr] = k.split('_');
      const r = Number(rStr);
      const c = Number(cStr);
      if (r >= at) {
        newCells[`${r + 1}_${c}`] = activeSheet.cells[k];
      } else {
        newCells[k] = activeSheet.cells[k];
      }
    }

    updateSheet({
      ...activeSheet,
      rowCount: activeSheet.rowCount + 1,
      cells: newCells
    });
  }, [activeSheet, selection.activeCell.r, pushUndo, updateSheet]);

  const deleteRow = useCallback((index?: number) => {
    const at = index !== undefined ? index : selection.activeCell.r;
    pushUndo();
    const newCells: { [key: string]: CellData } = {};

    for (const k in activeSheet.cells) {
      const [rStr, cStr] = k.split('_');
      const r = Number(rStr);
      const c = Number(cStr);
      if (r === at) {
        // Deleted
        continue;
      } else if (r > at) {
        newCells[`${r - 1}_${c}`] = activeSheet.cells[k];
      } else {
        newCells[k] = activeSheet.cells[k];
      }
    }

    updateSheet({
      ...activeSheet,
      rowCount: Math.max(20, activeSheet.rowCount - 1),
      cells: newCells
    });
  }, [activeSheet, selection.activeCell.r, pushUndo, updateSheet]);

  const insertCol = useCallback((index?: number) => {
    const at = index !== undefined ? index : selection.activeCell.c;
    pushUndo();
    const newCells: { [key: string]: CellData } = {};

    for (const k in activeSheet.cells) {
      const [rStr, cStr] = k.split('_');
      const r = Number(rStr);
      const c = Number(cStr);
      if (c >= at) {
        newCells[`${r}_${c + 1}`] = activeSheet.cells[k];
      } else {
        newCells[k] = activeSheet.cells[k];
      }
    }

    updateSheet({
      ...activeSheet,
      colCount: activeSheet.colCount + 1,
      cells: newCells
    });
  }, [activeSheet, selection.activeCell.c, pushUndo, updateSheet]);

  const deleteCol = useCallback((index?: number) => {
    const at = index !== undefined ? index : selection.activeCell.c;
    pushUndo();
    const newCells: { [key: string]: CellData } = {};

    for (const k in activeSheet.cells) {
      const [rStr, cStr] = k.split('_');
      const r = Number(rStr);
      const c = Number(cStr);
      if (c === at) {
        continue;
      } else if (c > at) {
        newCells[`${r}_${c - 1}`] = activeSheet.cells[k];
      } else {
        newCells[k] = activeSheet.cells[k];
      }
    }

    updateSheet({
      ...activeSheet,
      colCount: Math.max(10, activeSheet.colCount - 1),
      cells: newCells
    });
  }, [activeSheet, selection.activeCell.c, pushUndo, updateSheet]);

  // Sheet Management
  const setActiveSheet = useCallback((id: string) => {
    setWorkbook(prev => ({ ...prev, activeSheetId: id }));
  }, []);

  const addSheet = useCallback(() => {
    const newNum = workbook.sheets.length + 1;
    const newSheet = createEmptySheet(`sheet_${Date.now()}`, `Trang tính ${newNum}`, 100, 26);
    setWorkbook(prev => ({
      ...prev,
      isModified: true,
      sheets: [...prev.sheets, newSheet],
      activeSheetId: newSheet.id
    }));
  }, [workbook.sheets.length]);

  const renameSheet = useCallback((id: string, newName: string) => {
    if (!newName.trim()) return;
    setWorkbook(prev => ({
      ...prev,
      isModified: true,
      sheets: prev.sheets.map(s => (s.id === id ? { ...s, name: newName.trim() } : s))
    }));
  }, []);

  const deleteSheet = useCallback((id: string) => {
    if (workbook.sheets.length <= 1) {
      alert('Không thể xóa sheet duy nhất còn lại!');
      return;
    }
    setWorkbook(prev => {
      const remaining = prev.sheets.filter(s => s.id !== id);
      return {
        ...prev,
        isModified: true,
        sheets: remaining,
        activeSheetId: prev.activeSheetId === id ? remaining[0].id : prev.activeSheetId
      };
    });
  }, [workbook.sheets.length]);

  // History: Undo / Redo
  const undo = useCallback(() => {
    if (undoStack.length === 0) return;
    const previous = undoStack[undoStack.length - 1];
    setUndoStack(prev => prev.slice(0, -1));
    setRedoStack(prev => [...prev, JSON.parse(JSON.stringify(activeSheet))]);
    updateSheet(previous, true);
  }, [undoStack, activeSheet, updateSheet]);

  const redo = useCallback(() => {
    if (redoStack.length === 0) return;
    const next = redoStack[redoStack.length - 1];
    setRedoStack(prev => prev.slice(0, -1));
    setUndoStack(prev => [...prev, JSON.parse(JSON.stringify(activeSheet))]);
    updateSheet(next, true);
  }, [redoStack, activeSheet, updateSheet]);

  // File I/O
  const newWorkbook = useCallback(() => {
    if (workbook.isModified && !confirm('Bạn có thay đổi chưa lưu. Bạn có muốn tạo file mới không?')) {
      return;
    }
    const initial = getInitialWorkbook();
    setWorkbook(initial);
    setSelectionState({
      activeCell: { r: 0, c: 0 },
      range: { startRow: 0, startCol: 0, endRow: 0, endCol: 0 },
      isSelecting: false
    });
    setUndoStack([]);
    setRedoStack([]);
  }, [workbook.isModified]);

  const saveWorkbook = useCallback(async () => {
    try {
      await exportExcelFile(workbook, workbook.title);
      setWorkbook(prev => ({ ...prev, isModified: false }));
    } catch (err) {
      console.error('Error saving workbook:', err);
      alert('Lỗi khi lưu file Excel: ' + (err as Error).message);
    }
  }, [workbook]);

  const openFile = useCallback(async (file: File | { name: string; buffer: ArrayBuffer | Uint8Array }) => {
    try {
      const imported = await importExcelFile(file);
      setWorkbook(imported);
      setSelectionState({
        activeCell: { r: 0, c: 0 },
        range: { startRow: 0, startCol: 0, endRow: 0, endCol: 0 },
        isSelecting: false
      });
      setUndoStack([]);
      setRedoStack([]);
    } catch (err) {
      console.error('Error opening file:', err);
      alert('Không thể đọc file Excel này: ' + (err as Error).message);
    }
  }, []);

  const setWorkbookTitle = useCallback((title: string) => {
    setWorkbook(prev => ({ ...prev, title }));
  }, []);

  return (
    <ExcelContext.Provider
      value={{
        workbook,
        activeSheet,
        selection,
        editingCell,
        formulaBarText,
        activeTab,
        zoom,
        showGridlines,
        showFormulaBar,
        showHeaders,
        canUndo: undoStack.length > 0,
        canRedo: redoStack.length > 0,

        setActiveTab,
        setZoom,
        setShowGridlines,
        setShowFormulaBar,
        setShowHeaders,

        setSelection,
        updateSelectionRange,
        setIsSelecting,

        startEditing,
        cancelEditing,
        commitEditing,
        setFormulaBarText,
        onFormulaBarChange,

        applyFormat,
        toggleMerge,
        clearSelection,
        autoSum,
        sortSelection,
        fillRange,

        copy,
        cut,
        paste,

        setColWidth,
        setRowHeight,
        insertRow,
        deleteRow,
        insertCol,
        deleteCol,

        setActiveSheet,
        addSheet,
        renameSheet,
        deleteSheet,

        newWorkbook,
        saveWorkbook,
        openFile,
        setWorkbookTitle,

        undo,
        redo
      }}
    >
      {children}
    </ExcelContext.Provider>
  );
};

export const useExcel = () => {
  const context = useContext(ExcelContext);
  if (!context) {
    throw new Error('useExcel must be used within an ExcelProvider');
  }
  return context;
};
