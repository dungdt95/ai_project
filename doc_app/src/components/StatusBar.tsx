import React from 'react'
import { ZoomIn, ZoomOut, CheckCircle2, AlertCircle } from 'lucide-react'

interface StatusBarProps {
  wordCount: number
  charCount: number
  pageCount: number
  readTimeMinutes: number
  isDirty: boolean
  zoom: number
  onZoomChange: (zoom: number) => void
}

export const StatusBar: React.FC<StatusBarProps> = ({
  wordCount,
  charCount,
  pageCount,
  readTimeMinutes,
  isDirty,
  zoom,
  onZoomChange
}) => {
  return (
    <div className="statusbar">
      {/* Left statistics */}
      <div className="statusbar-left">
        <div className="statusbar-item">
          <span>Trang 1 trên {pageCount}</span>
        </div>
        <div className="statusbar-item">
          <span>{wordCount.toLocaleString()} từ</span>
        </div>
        <div className="statusbar-item">
          <span>{charCount.toLocaleString()} ký tự</span>
        </div>
        <div className="statusbar-item" title="Thời gian đọc ước tính">
          <span>~{readTimeMinutes} phút đọc</span>
        </div>
        <div className="statusbar-item" style={{ marginLeft: 8 }}>
          {isDirty ? (
            <span style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#b45309' }}>
              <AlertCircle size={13} /> Có chỉnh sửa chưa lưu
            </span>
          ) : (
            <span style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#15803d' }}>
              <CheckCircle2 size={13} /> Đã lưu vào máy
            </span>
          )}
        </div>
      </div>

      {/* Right zoom slider */}
      <div className="statusbar-right">
        <div className="zoom-container">
          <button
            className="zoom-btn"
            onClick={() => onZoomChange(Math.max(50, zoom - 10))}
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
            onChange={(e) => onZoomChange(Number(e.target.value))}
            className="zoom-slider"
          />
          <button
            className="zoom-btn"
            onClick={() => onZoomChange(Math.min(200, zoom + 10))}
            title="Phóng to"
          >
            <ZoomIn size={13} />
          </button>
          <span
            style={{ minWidth: 42, textAlign: 'right', cursor: 'pointer', fontWeight: 500 }}
            onClick={() => onZoomChange(100)}
            title="Bấm để đặt lại 100%"
          >
            {zoom}%
          </span>
        </div>
      </div>
    </div>
  )
}
