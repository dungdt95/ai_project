import React from 'react';
import { ZoomIn, ZoomOut } from 'lucide-react';
import { useExcel } from '../context/ExcelContext';

export const StatusBar: React.FC = () => {
  const { activeSheet, selection, zoom, setZoom } = useExcel();
  const { range } = selection;

  // Calculate Quick Stats on selected range
  let cellCount = 0;
  let numCount = 0;
  let sum = 0;

  const isMultiCell = range.startRow !== range.endRow || range.startCol !== range.endCol;

  if (isMultiCell) {
    for (let r = range.startRow; r <= range.endRow; r++) {
      for (let c = range.startCol; c <= range.endCol; c++) {
        cellCount++;
        const key = `${r}_${c}`;
        const cell = activeSheet.cells[key];
        if (cell && cell.v !== undefined && cell.v !== null && cell.v !== '') {
          const num = Number(cell.v);
          if (!isNaN(num) && typeof cell.v !== 'boolean') {
            numCount++;
            sum += num;
          }
        }
      }
    }
  }

  const average = numCount > 0 ? (sum / numCount).toLocaleString('en-US', { maximumFractionDigits: 2 }) : 0;
  const formattedSum = sum.toLocaleString('en-US', { maximumFractionDigits: 2 });

  return (
    <div className="status-bar-container">
      {/* Left: Status */}
      <div className="status-left">
        <span className="status-ready">Sẵn sàng (Ready)</span>
      </div>

      {/* Center: Calculations (Average, Count, Sum) */}
      <div className="status-center">
        {isMultiCell && (
          <div className="stats-group">
            {numCount > 0 && (
              <span className="stat-item">
                Trung bình: <strong>{average}</strong>
              </span>
            )}
            <span className="stat-item">
              Số ô: <strong>{cellCount}</strong>
            </span>
            {numCount > 0 && (
              <span className="stat-item">
                Tổng cộng: <strong>{formattedSum}</strong>
              </span>
            )}
          </div>
        )}
      </div>

      {/* Right: Zoom controls */}
      <div className="status-right">
        <button
          className="zoom-icon-btn"
          onClick={() => setZoom(Math.max(50, zoom - 10))}
          title="Thu nhỏ"
        >
          <ZoomOut size={13} />
        </button>

        <input
          type="range"
          min="50"
          max="200"
          step="5"
          value={zoom}
          onChange={e => setZoom(Number(e.target.value))}
          className="zoom-slider"
          title={`Thu phóng: ${zoom}%`}
        />

        <button
          className="zoom-icon-btn"
          onClick={() => setZoom(Math.min(200, zoom + 10))}
          title="Phóng to"
        >
          <ZoomIn size={13} />
        </button>

        <button
          className="zoom-percent-btn"
          onClick={() => setZoom(100)}
          title="Đặt lại 100%"
        >
          {zoom}%
        </button>
      </div>
    </div>
  );
};
