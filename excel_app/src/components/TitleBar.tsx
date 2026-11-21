import React, { useRef } from 'react';
import {
  Save,
  Undo2,
  Redo2,
  FilePlus,
  FolderOpen,
  FileSpreadsheet,
  Minus,
  Square,
  X
} from 'lucide-react';
import { useExcel } from '../context/ExcelContext';

export const TitleBar: React.FC = () => {
  const {
    workbook,
    setWorkbookTitle,
    newWorkbook,
    saveWorkbook,
    openFile,
    undo,
    redo,
    canUndo,
    canRedo
  } = useExcel();

  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleOpenClick = async () => {
    if ((window as any).electronAPI?.openFileDialog) {
      try {
        const fileInfo = await (window as any).electronAPI.openFileDialog();
        if (fileInfo) {
          await openFile(fileInfo);
        }
      } catch (err) {
        console.error('Electron open file error:', err);
      }
      return;
    }
    fileInputRef.current?.click();
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      openFile(file);
      e.target.value = '';
    }
  };

  // Window controls for Electron (if available)
  const handleMinimize = () => {
    (window as any).electronAPI?.minimize?.();
  };

  const handleMaximize = () => {
    (window as any).electronAPI?.maximize?.();
  };

  const handleClose = () => {
    if (workbook.isModified) {
      if (!confirm('Bạn có thay đổi chưa lưu. Bạn có chắc chắn muốn thoát không?')) {
        return;
      }
    }
    (window as any).electronAPI?.close?.() || window.close();
  };

  return (
    <div className="title-bar">
      <input
        type="file"
        ref={fileInputRef}
        onChange={handleFileChange}
        accept=".xlsx, .xls, .csv"
        style={{ display: 'none' }}
      />

      {/* Left: Quick Access Toolbar */}
      <div className="quick-access-toolbar">
        <div className="app-brand" title="PC Excel Editor 365">
          <img src="/icon.png" alt="Excel" style={{ width: 20, height: 20, objectFit: 'contain' }} />
          <span className="brand-text">Excel</span>
        </div>

        <div className="quick-divider" />

        <button
          className="quick-btn"
          onClick={newWorkbook}
          title="Tạo bảng tính mới (New)"
        >
          <FilePlus size={15} />
        </button>

        <button
          className="quick-btn"
          onClick={handleOpenClick}
          title="Mở file Excel (.xlsx, .xls, .csv) (Ctrl+O)"
        >
          <FolderOpen size={15} />
        </button>

        <button
          className="quick-btn"
          onClick={() => saveWorkbook()}
          title="Lưu file Excel (.xlsx) (Ctrl+S)"
        >
          <Save size={15} />
        </button>

        <button
          className={`quick-btn ${!canUndo ? 'disabled' : ''}`}
          onClick={undo}
          disabled={!canUndo}
          title="Hoàn tác (Undo) (Ctrl+Z)"
        >
          <Undo2 size={15} />
        </button>

        <button
          className={`quick-btn ${!canRedo ? 'disabled' : ''}`}
          onClick={redo}
          disabled={!canRedo}
          title="Làm lại (Redo) (Ctrl+Y)"
        >
          <Redo2 size={15} />
        </button>
      </div>

      {/* Center: File Name Title */}
      <div className="title-center">
        <input
          type="text"
          className="title-input"
          value={workbook.title}
          onChange={e => setWorkbookTitle(e.target.value)}
          title="Nhấp để đổi tên sổ làm việc"
        />
        <span className="title-extension">.xlsx</span>
        <span className={`status-badge ${workbook.isModified ? 'modified' : 'saved'}`}>
          {workbook.isModified ? 'Chưa lưu' : 'Đã lưu'}
        </span>
      </div>

      {/* Right: Window Controls */}
      <div className="window-controls">
        <button
          className="win-btn win-minimize"
          onClick={handleMinimize}
          title="Thu nhỏ"
        >
          <Minus size={14} />
        </button>
        <button
          className="win-btn win-maximize"
          onClick={handleMaximize}
          title="Phóng to / Thu nhỏ"
        >
          <Square size={12} />
        </button>
        <button
          className="win-btn win-close"
          onClick={handleClose}
          title="Đóng ứng dụng"
        >
          <X size={15} />
        </button>
      </div>
    </div>
  );
};
