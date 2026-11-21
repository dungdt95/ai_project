import React, { useState, useEffect } from 'react';
import { Check, X } from 'lucide-react';
import { useExcel } from '../context/ExcelContext';
import { cellCoordsToLabel, cellLabelToCoords, rangeToLabel } from '../utils/cellUtils';

interface FormulaBarProps {
  onOpenFunctionDialog: () => void;
}

export const FormulaBar: React.FC<FormulaBarProps> = ({ onOpenFunctionDialog }) => {
  const {
    selection,
    formulaBarText,
    onFormulaBarChange,
    commitEditing,
    cancelEditing,
    setSelection,
    showFormulaBar
  } = useExcel();

  const [nameBoxValue, setNameBoxValue] = useState<string>('A1');

  // Update Name Box text when selection changes
  useEffect(() => {
    if (selection.range.startRow === selection.range.endRow && selection.range.startCol === selection.range.endCol) {
      setNameBoxValue(cellCoordsToLabel(selection.activeCell.r, selection.activeCell.c));
    } else {
      setNameBoxValue(rangeToLabel(selection.range));
    }
  }, [selection]);

  if (!showFormulaBar) return null;

  const handleNameBoxKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      const coords = cellLabelToCoords(nameBoxValue);
      if (coords) {
        setSelection(coords);
      } else {
        setNameBoxValue(cellCoordsToLabel(selection.activeCell.r, selection.activeCell.c));
      }
    }
  };

  const handleFormulaKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      commitEditing();
    } else if (e.key === 'Escape') {
      cancelEditing();
    }
  };

  return (
    <div className="formula-bar-container">
      {/* Name Box */}
      <div className="name-box-wrapper">
        <input
          type="text"
          className="name-box-input"
          value={nameBoxValue}
          onChange={e => setNameBoxValue(e.target.value.toUpperCase())}
          onKeyDown={handleNameBoxKeyDown}
          title="Địa chỉ ô hiện tại (Nhập địa chỉ và Enter để di chuyển)"
        />
      </div>

      <div className="formula-divider" />

      {/* Function and Action Buttons */}
      <div className="formula-actions">
        <button
          className="formula-action-btn cancel-btn"
          onClick={cancelEditing}
          title="Hủy bỏ (Escape)"
        >
          <X size={14} />
        </button>

        <button
          className="formula-action-btn check-btn"
          onClick={() => commitEditing()}
          title="Nhập (Enter)"
        >
          <Check size={14} />
        </button>

        <button
          className="formula-action-btn fx-btn"
          onClick={onOpenFunctionDialog}
          title="Chèn hàm tính toán (fx)"
        >
          <em>fx</em>
        </button>
      </div>

      <div className="formula-divider" />

      {/* Formula Input */}
      <div className="formula-input-wrapper">
        <input
          type="text"
          className="formula-input"
          value={formulaBarText}
          onChange={e => onFormulaBarChange(e.target.value)}
          onKeyDown={handleFormulaKeyDown}
          placeholder="Nhập giá trị hoặc công thức (ví dụ: =SUM(A1:A10))"
        />
      </div>
    </div>
  );
};
