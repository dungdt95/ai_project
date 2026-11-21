import { Parser } from 'hot-formula-parser';
import { CellData } from '../types/excel';
import { formatCellValue } from '../utils/cellUtils';

export class FormulaEngine {
  private parser: Parser;
  private currentCells: { [key: string]: CellData } = {};

  constructor() {
    this.parser = new Parser();
    this.setupParserEvents();
  }

  private setupParserEvents() {
    // When formula parser needs a single cell value, e.g. A1
    this.parser.on('callCellValue', (cellCoord, done) => {
      const col = cellCoord.column.index;
      const row = cellCoord.row.index;
      const key = `${row}_${col}`;
      const cell = this.currentCells[key];

      if (!cell) {
        done(0);
        return;
      }

      // If it's a number, return as number
      const val = cell.v;
      if (val === undefined || val === null || val === '') {
        done(0);
      } else if (!isNaN(Number(val)) && typeof val !== 'boolean') {
        done(Number(val));
      } else {
        done(val);
      }
    });

    // When formula parser needs a range of values, e.g. A1:B10
    this.parser.on('callRangeValue', (startCoord, endCoord, done) => {
      const startRow = Math.min(startCoord.row.index, endCoord.row.index);
      const endRow = Math.max(startCoord.row.index, endCoord.row.index);
      const startCol = Math.min(startCoord.column.index, endCoord.column.index);
      const endCol = Math.max(startCoord.column.index, endCoord.column.index);

      const matrix: any[][] = [];
      for (let r = startRow; r <= endRow; r++) {
        const rowData: any[] = [];
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

  /**
   * Recalculates all formulas in a sheet cells map.
   * Resolves dependencies in multiple passes (up to 5 passes to resolve chained formulas).
   */
  public evaluateAll(cells: { [key: string]: CellData }): { [key: string]: CellData } {
    // Clone cells object to avoid direct mutations
    const result: { [key: string]: CellData } = {};
    for (const k in cells) {
      result[k] = { ...cells[k] };
    }
    this.currentCells = result;

    // Collect cells that have formulas
    const formulaKeys = Object.keys(result).filter(k => {
      const f = result[k].f;
      return f && f.startsWith('=');
    });

    if (formulaKeys.length === 0) {
      // Just ensure formatted values 'm' are populated
      for (const k of Object.keys(result)) {
        result[k].m = formatCellValue(result[k].v, result[k].s?.numFmt);
      }
      return result;
    }

    // Run iterative passes (max 8 passes to resolve formulas pointing to formulas)
    for (let pass = 0; pass < 8; pass++) {
      let changed = false;
      for (const k of formulaKeys) {
        const formulaStr = (result[k].f || '').substring(1); // remove '='
        const parseResult = this.parser.parse(formulaStr);
        let newValue: any;

        if (parseResult.error) {
          newValue = parseResult.error;
        } else {
          newValue = parseResult.result;
        }

        if (result[k].v !== newValue) {
          result[k].v = newValue;
          result[k].m = formatCellValue(newValue, result[k].s?.numFmt);
          changed = true;
        }
      }
      if (!changed) break;
    }

    // Format all cells
    for (const k of Object.keys(result)) {
      result[k].m = formatCellValue(result[k].v, result[k].s?.numFmt);
    }

    return result;
  }

  /**
   * Evaluates a single formula expression
   */
  public evaluateExpression(expression: string, cells: { [key: string]: CellData }): any {
    this.currentCells = cells;
    const cleanExpr = expression.startsWith('=') ? expression.substring(1) : expression;
    const res = this.parser.parse(cleanExpr);
    if (res.error) return res.error;
    return res.result;
  }
}

export const formulaEngine = new FormulaEngine();
