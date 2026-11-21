import React, { useState, useRef, useEffect, useCallback } from 'react';
import { useExcel } from '../context/ExcelContext';
import { colIndexToName, isCellInRange, normalizeRange } from '../utils/cellUtils';
import { ContextMenu } from './ContextMenu';

export const Grid: React.FC = () => {
  const {
    activeSheet,
    selection,
    setSelection,
    updateSelectionRange,
    editingCell,
    startEditing,
    cancelEditing,
    commitEditing,
    setColWidth,
    setRowHeight,
    fillRange,
    clearSelection,
    undo,
    redo,
    copy,
    cut,
    paste,
    saveWorkbook,
    openFile,
    zoom,
    showGridlines,
    showHeaders
  } = useExcel();

  const gridContainerRef = useRef<HTMLDivElement>(null);
  const inlineInputRef = useRef<HTMLInputElement>(null);

  // Drag selection state
  const isMouseDownRef = useRef<boolean>(false);
  const isDraggingFillHandleRef = useRef<boolean>(false);
  const [fillPreviewRange, setFillPreviewRange] = useState<{ startRow: number; startCol: number; endRow: number; endCol: number } | null>(null);

  // Column / Row Resizing state
  const resizingColRef = useRef<{ col: number; startX: number; startWidth: number } | null>(null);
  const resizingRowRef = useRef<{ row: number; startY: number; startHeight: number } | null>(null);

  // Context Menu State
  const [contextMenuPos, setContextMenuPos] = useState<{ x: number; y: number } | null>(null);

  // Default dimensions
  const defaultColWidth = 85;
  const defaultRowHeight = 24;

  const getColWidth = (c: number) => activeSheet.colWidths[c] || defaultColWidth;
  const getRowHeight = (r: number) => activeSheet.rowHeights[r] || defaultRowHeight;

  // Auto focus input when editing starts
  useEffect(() => {
    if (editingCell && inlineInputRef.current) {
      inlineInputRef.current.focus();
    }
  }, [editingCell]);

  // Global mouseup handler
  useEffect(() => {
    const handleMouseUp = () => {
      if (isDraggingFillHandleRef.current && fillPreviewRange) {
        fillRange(fillPreviewRange);
      }
      isMouseDownRef.current = false;
      isDraggingFillHandleRef.current = false;
      resizingColRef.current = null;
      resizingRowRef.current = null;
      setFillPreviewRange(null);
    };

    const handleMouseMove = (e: MouseEvent) => {
      // Handle Column Resize
      if (resizingColRef.current) {
        const delta = e.clientX - resizingColRef.current.startX;
        const newWidth = Math.max(30, resizingColRef.current.startWidth + delta);
        setColWidth(resizingColRef.current.col, newWidth);
      }
      // Handle Row Resize
      if (resizingRowRef.current) {
        const delta = e.clientY - resizingRowRef.current.startY;
        const newHeight = Math.max(18, resizingRowRef.current.startHeight + delta);
        setRowHeight(resizingRowRef.current.row, newHeight);
      }
    };

    window.addEventListener('mouseup', handleMouseUp);
    window.addEventListener('mousemove', handleMouseMove);
    return () => {
      window.removeEventListener('mouseup', handleMouseUp);
      window.removeEventListener('mousemove', handleMouseMove);
    };
  }, [fillPreviewRange, fillRange, setColWidth, setRowHeight]);

  // Global Keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // If user is editing in inline input or formula bar or name box, don't override basic arrows
      const activeTag = (document.activeElement?.tagName || '').toLowerCase();
      const isInputFocused = activeTag === 'input' || activeTag === 'textarea';

      // Global hotkeys
      if (e.ctrlKey || e.metaKey) {
        if (e.key === 's' || e.key === 'S') {
          e.preventDefault();
          saveWorkbook();
          return;
        }
        if (e.key === 'z' || e.key === 'Z') {
          if (!isInputFocused) {
            e.preventDefault();
            undo();
            return;
          }
        }
        if (e.key === 'y' || e.key === 'Y') {
          if (!isInputFocused) {
            e.preventDefault();
            redo();
            return;
          }
        }
        if (e.key === 'c' || e.key === 'C') {
          if (!isInputFocused) {
            e.preventDefault();
            copy();
            return;
          }
        }
        if (e.key === 'x' || e.key === 'X') {
          if (!isInputFocused) {
            e.preventDefault();
            cut();
            return;
          }
        }
        if (e.key === 'v' || e.key === 'V') {
          if (!isInputFocused) {
            e.preventDefault();
            paste();
            return;
          }
        }
      }

      if (isInputFocused) {
        return;
      }

      // Navigation keys
      const { r, c } = selection.activeCell;
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (e.shiftKey) {
          updateSelectionRange({ r: Math.max(0, selection.range.endRow - 1), c: selection.range.endCol });
        } else {
          setSelection({ r: Math.max(0, r - 1), c });
        }
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        if (e.shiftKey) {
          updateSelectionRange({ r: Math.min(activeSheet.rowCount - 1, selection.range.endRow + 1), c: selection.range.endCol });
        } else {
          setSelection({ r: Math.min(activeSheet.rowCount - 1, r + 1), c });
        }
      } else if (e.key === 'ArrowLeft') {
        e.preventDefault();
        if (e.shiftKey) {
          updateSelectionRange({ r: selection.range.endRow, c: Math.max(0, selection.range.endCol - 1) });
        } else {
          setSelection({ r, c: Math.max(0, c - 1) });
        }
      } else if (e.key === 'ArrowRight') {
        e.preventDefault();
        if (e.shiftKey) {
          updateSelectionRange({ r: selection.range.endRow, c: Math.min(activeSheet.colCount - 1, selection.range.endCol + 1) });
        } else {
          setSelection({ r, c: Math.min(activeSheet.colCount - 1, c + 1) });
        }
      } else if (e.key === 'Enter') {
        e.preventDefault();
        setSelection({ r: Math.min(activeSheet.rowCount - 1, r + 1), c });
      } else if (e.key === 'Tab') {
        e.preventDefault();
        setSelection({ r, c: Math.min(activeSheet.colCount - 1, c + 1) });
      } else if (e.key === 'Delete' || e.key === 'Backspace') {
        e.preventDefault();
        clearSelection();
      } else if (e.key === 'F2') {
        e.preventDefault();
        startEditing(r, c);
      } else if (e.key.length === 1 && !e.ctrlKey && !e.altKey && !e.metaKey) {
        // Start typing directly into active cell
        startEditing(r, c, e.key);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [
    selection,
    activeSheet.rowCount,
    activeSheet.colCount,
    setSelection,
    updateSelectionRange,
    startEditing,
    clearSelection,
    saveWorkbook,
    undo,
    redo,
    copy,
    cut,
    paste
  ]);

  // Drag & drop file into grid
  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    const file = e.dataTransfer.files?.[0];
    if (file && (file.name.endsWith('.xlsx') || file.name.endsWith('.xls') || file.name.endsWith('.csv'))) {
      openFile(file);
    }
  };

  // Build lookup maps for Merged cells
  const mergeMasterMap = new Map<string, { spanR: number; spanC: number }>();
  const mergeHiddenSet = new Set<string>();

  for (const m of activeSheet.merges) {
    const masterKey = `${m.s.r}_${m.s.c}`;
    mergeMasterMap.set(masterKey, {
      spanR: m.e.r - m.s.r + 1,
      spanC: m.e.c - m.s.c + 1
    });

    for (let r = m.s.r; r <= m.e.r; r++) {
      for (let c = m.s.c; c <= m.e.c; c++) {
        if (r !== m.s.r || c !== m.s.c) {
          mergeHiddenSet.add(`${r}_${c}`);
        }
      }
    }
  }

  // Cell Click & Drag Handlers
  const handleCellMouseDown = (r: number, c: number, e: React.MouseEvent) => {
    if (e.button === 2) {
      // Right click: if clicked outside selection, set active to clicked cell
      if (!isCellInRange(r, c, selection.range)) {
        setSelection({ r, c });
      }
      setContextMenuPos({ x: e.clientX, y: e.clientY });
      return;
    }

    if (editingCell) {
      commitEditing();
    }

    isMouseDownRef.current = true;
    if (e.shiftKey) {
      updateSelectionRange({ r, c });
    } else {
      setSelection({ r, c });
    }
  };

  const handleCellMouseEnter = (r: number, c: number) => {
    if (isDraggingFillHandleRef.current) {
      // Calculate preview fill range
      const baseRange = selection.range;
      const targetRow = Math.max(baseRange.endRow, r);
      const targetCol = Math.max(baseRange.endCol, c);
      setFillPreviewRange({
        startRow: baseRange.startRow,
        startCol: baseRange.startCol,
        endRow: targetRow,
        endCol: targetCol
      });
    } else if (isMouseDownRef.current) {
      updateSelectionRange({ r, c });
    }
  };

  const handleFillHandleMouseDown = (e: React.MouseEvent) => {
    e.stopPropagation();
    isDraggingFillHandleRef.current = true;
  };

  // Select entire column
  const handleColHeaderClick = (colIndex: number) => {
    setSelection(
      { r: 0, c: colIndex },
      { startRow: 0, startCol: colIndex, endRow: activeSheet.rowCount - 1, endCol: colIndex }
    );
  };

  // Select entire row
  const handleRowHeaderClick = (rowIndex: number) => {
    setSelection(
      { r: rowIndex, c: 0 },
      { startRow: rowIndex, startCol: 0, endRow: rowIndex, endCol: activeSheet.colCount - 1 }
    );
  };

  // Select All corner
  const handleCornerClick = () => {
    setSelection(
      { r: 0, c: 0 },
      { startRow: 0, startCol: 0, endRow: activeSheet.rowCount - 1, endCol: activeSheet.colCount - 1 }
    );
  };

  // Col Resize Start
  const startColResize = (col: number, e: React.MouseEvent) => {
    e.stopPropagation();
    resizingColRef.current = {
      col,
      startX: e.clientX,
      startWidth: getColWidth(col)
    };
  };

  // Row Resize Start
  const startRowResize = (row: number, e: React.MouseEvent) => {
    e.stopPropagation();
    resizingRowRef.current = {
      row,
      startY: e.clientY,
      startHeight: getRowHeight(row)
    };
  };

  const { range, activeCell } = selection;

  return (
    <div
      className="grid-wrapper"
      ref={gridContainerRef}
      onDragOver={handleDragOver}
      onDrop={handleDrop}
    >
      <div
        className="grid-scrollable"
        style={{ transform: `scale(${zoom / 100})`, transformOrigin: 'top left' }}
      >
        <table className={`excel-grid ${!showGridlines ? 'hide-gridlines' : ''}`}>
          {showHeaders && (
            <thead>
              <tr>
                {/* Top-left Select All Corner */}
                <th className="grid-corner-header" onClick={handleCornerClick} title="Chọn toàn bộ bảng">
                  <div className="corner-triangle" />
                </th>

                {/* Column Headers */}
                {Array.from({ length: activeSheet.colCount }).map((_, c) => {
                  const isColSelected = range.startCol <= c && c <= range.endCol && range.startRow === 0 && range.endRow === activeSheet.rowCount - 1;
                  return (
                    <th
                      key={c}
                      className={`grid-col-header ${isColSelected ? 'header-selected' : ''}`}
                      style={{ width: `${getColWidth(c)}px`, minWidth: `${getColWidth(c)}px` }}
                      onClick={() => handleColHeaderClick(c)}
                    >
                      <div className="header-cell-text">{colIndexToName(c)}</div>
                      <div
                        className="col-resize-divider"
                        onMouseDown={e => startColResize(c, e)}
                        title="Kéo để thay đổi độ rộng cột"
                      />
                    </th>
                  );
                })}
              </tr>
            </thead>
          )}

          <tbody>
            {Array.from({ length: activeSheet.rowCount }).map((_, r) => {
              const isRowSelected = range.startRow <= r && r <= range.endRow && range.startCol === 0 && range.endCol === activeSheet.colCount - 1;

              return (
                <tr key={r} style={{ height: `${getRowHeight(r)}px` }}>
                  {showHeaders && (
                    <th
                      className={`grid-row-header ${isRowSelected ? 'header-selected' : ''}`}
                      onClick={() => handleRowHeaderClick(r)}
                    >
                      <div className="header-cell-text">{r + 1}</div>
                      <div
                        className="row-resize-divider"
                        onMouseDown={e => startRowResize(r, e)}
                        title="Kéo để thay đổi chiều cao hàng"
                      />
                    </th>
                  )}

                  {Array.from({ length: activeSheet.colCount }).map((_, c) => {
                    const key = `${r}_${c}`;

                    // If part of merged area but not the top-left cell, skip rendering
                    if (mergeHiddenSet.has(key)) {
                      return null;
                    }

                    const masterMerge = mergeMasterMap.get(key);
                    const cell = activeSheet.cells[key];
                    const isActive = activeCell.r === r && activeCell.c === c;
                    const inRange = isCellInRange(r, c, range);
                    const isBottomRightOfSelection = range.endRow === r && range.endCol === c;
                    const isEditing = editingCell && editingCell.r === r && editingCell.c === c;

                    // Compute borders and styles
                    const s = cell?.s || {};
                    const styleObj: React.CSSProperties = {
                      fontWeight: s.bold ? 'bold' : 'normal',
                      fontStyle: s.italic ? 'italic' : 'normal',
                      textDecoration: [
                        s.underline ? 'underline' : '',
                        s.strike ? 'line-through' : ''
                      ].filter(Boolean).join(' ') || undefined,
                      fontSize: s.fontSize ? `${s.fontSize}pt` : '10pt',
                      fontFamily: s.fontFamily || 'Segoe UI, Tahoma, sans-serif',
                      color: s.color || '#000000',
                      backgroundColor: s.bgColor || undefined,
                      textAlign: s.align || (typeof cell?.v === 'number' ? 'right' : 'left'),
                      verticalAlign: s.verticalAlign || 'middle',
                      whiteSpace: s.wrapText ? 'normal' : 'nowrap',
                      width: `${getColWidth(c)}px`,
                      minWidth: `${getColWidth(c)}px`
                    };

                    if (s.border) {
                      const bStyle = `${s.border.style === 'thick' ? '2px solid' : '1px solid'} ${s.border.color || '#333'}`;
                      if (s.border.top) styleObj.borderTop = bStyle;
                      if (s.border.bottom) styleObj.borderBottom = bStyle;
                      if (s.border.left) styleObj.borderLeft = bStyle;
                      if (s.border.right) styleObj.borderRight = bStyle;
                    }

                    // Border classes for range box
                    let cellClasses = 'grid-cell';
                    if (inRange) cellClasses += ' in-range';
                    if (isActive) cellClasses += ' active-cell';
                    if (inRange && r === range.startRow) cellClasses += ' range-top';
                    if (inRange && r === range.endRow) cellClasses += ' range-bottom';
                    if (inRange && c === range.startCol) cellClasses += ' range-left';
                    if (inRange && c === range.endCol) cellClasses += ' range-right';

                    return (
                      <td
                        key={c}
                        rowSpan={masterMerge?.spanR || 1}
                        colSpan={masterMerge?.spanC || 1}
                        className={cellClasses}
                        style={styleObj}
                        onMouseDown={e => handleCellMouseDown(r, c, e)}
                        onMouseEnter={() => handleCellMouseEnter(r, c)}
                        onDoubleClick={() => startEditing(r, c)}
                      >
                        {isEditing ? (
                          <input
                            ref={inlineInputRef}
                            className="inline-cell-input"
                            value={editingCell.value}
                            onChange={e => {
                              useExcel; // access
                              startEditing(r, c, e.target.value);
                            }}
                            onKeyDown={e => {
                              if (e.key === 'Enter') {
                                commitEditing();
                              } else if (e.key === 'Escape') {
                                cancelEditing();
                              }
                            }}
                            onBlur={() => commitEditing()}
                          />
                        ) : (
                          <span className="cell-content">
                            {cell?.m !== undefined ? cell.m : (cell?.v !== undefined && cell?.v !== null ? String(cell.v) : '')}
                          </span>
                        )}

                        {/* Fill Handle at Bottom-Right of selection */}
                        {isBottomRightOfSelection && !editingCell && (
                          <div
                            className="fill-handle"
                            onMouseDown={handleFillHandleMouseDown}
                            title="Kéo để tự động điền (Auto-fill)"
                          />
                        )}
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* Context Menu */}
      {contextMenuPos && (
        <ContextMenu
          x={contextMenuPos.x}
          y={contextMenuPos.y}
          onClose={() => setContextMenuPos(null)}
        />
      )}
    </div>
  );
};
