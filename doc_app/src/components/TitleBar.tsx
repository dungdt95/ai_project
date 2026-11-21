import React, { useState, useEffect } from 'react'
import {
  FilePlus,
  FolderOpen,
  Save,
  Printer,
  Undo2,
  Redo2,
  Minus,
  Square,
  Copy,
  X
} from 'lucide-react'

interface TitleBarProps {
  fileName: string
  isDirty: boolean
  canUndo: boolean
  canRedo: boolean
  onNew: () => void
  onOpen: () => void
  onSave: () => void
  onPrint: () => void
  onUndo: () => void
  onRedo: () => void
}

export const TitleBar: React.FC<TitleBarProps> = ({
  fileName,
  isDirty,
  canUndo,
  canRedo,
  onNew,
  onOpen,
  onSave,
  onPrint,
  onUndo,
  onRedo
}) => {
  const [isMaximized, setIsMaximized] = useState(false)
  const isElectron = Boolean(window.electronAPI?.isElectron)

  useEffect(() => {
    if (window.electronAPI?.isMaximized) {
      window.electronAPI.isMaximized().then(setIsMaximized)
    }
  }, [])

  const handleMinimize = () => {
    window.electronAPI?.minimize()
  }

  const handleMaximize = async () => {
    if (window.electronAPI) {
      window.electronAPI.maximize()
      const max = await window.electronAPI.isMaximized()
      setIsMaximized(max)
    }
  }

  const handleClose = () => {
    window.electronAPI?.close()
  }

  return (
    <div className="titlebar">
      {/* Quick Access Toolbar */}
      <div className="titlebar-left">
        <div className="word-logo" title="PC Word 365 Editor" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <img src="/icon.png" alt="Word" style={{ width: 18, height: 18, objectFit: 'contain' }} />
        </div>
        <button
          className="quick-btn"
          onClick={onNew}
          title="Tạo tài liệu mới (Ctrl+N)"
        >
          <FilePlus size={16} />
        </button>
        <button
          className="quick-btn"
          onClick={onOpen}
          title="Mở tài liệu từ máy tính (Ctrl+O)"
        >
          <FolderOpen size={16} />
        </button>
        <button
          className="quick-btn"
          onClick={onSave}
          title="Lưu tệp .docx (Ctrl+S)"
        >
          <Save size={16} />
        </button>
        <button
          className="quick-btn"
          onClick={onPrint}
          title="In hoặc Xuất PDF (Ctrl+P)"
        >
          <Printer size={16} />
        </button>
        <div style={{ width: 1, height: 16, backgroundColor: 'rgba(255,255,255,0.25)', margin: '0 2px' }} />
        <button
          className="quick-btn"
          onClick={onUndo}
          disabled={!canUndo}
          title="Hoàn tác (Ctrl+Z)"
        >
          <Undo2 size={16} />
        </button>
        <button
          className="quick-btn"
          onClick={onRedo}
          disabled={!canRedo}
          title="Làm lại (Ctrl+Y)"
        >
          <Redo2 size={16} />
        </button>
      </div>

      {/* Center Document Title & Status */}
      <div className="titlebar-center">
        <span className="titlebar-title">{fileName}</span>
        <span className="titlebar-separator">-</span>
        <span className="titlebar-appname">Word</span>
        {isDirty ? (
          <span className="titlebar-badge badge-dirty">Chưa lưu</span>
        ) : (
          <span className="titlebar-badge badge-saved">Đã lưu vào máy</span>
        )}
      </div>

      {/* Window Controls (Electron only or fallback) */}
      <div className="titlebar-right">
        {isElectron && (
          <>
            <button
              className="window-control-btn"
              onClick={handleMinimize}
              title="Thu nhỏ"
            >
              <Minus size={15} />
            </button>
            <button
              className="window-control-btn"
              onClick={handleMaximize}
              title={isMaximized ? 'Thu lại' : 'Phóng to'}
            >
              {isMaximized ? <Copy size={13} /> : <Square size={13} />}
            </button>
            <button
              className="window-control-btn btn-close"
              onClick={handleClose}
              title="Đóng"
            >
              <X size={16} />
            </button>
          </>
        )}
      </div>
    </div>
  )
}
