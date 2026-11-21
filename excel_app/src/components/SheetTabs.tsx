import React, { useState } from 'react';
import { Plus, X, Edit2, ChevronLeft, ChevronRight } from 'lucide-react';
import { useExcel } from '../context/ExcelContext';

export const SheetTabs: React.FC = () => {
  const {
    workbook,
    activeSheet,
    setActiveSheet,
    addSheet,
    renameSheet,
    deleteSheet
  } = useExcel();

  const [editingSheetId, setEditingSheetId] = useState<string | null>(null);
  const [editingSheetName, setEditingSheetName] = useState<string>('');

  const handleStartRename = (id: string, currentName: string) => {
    setEditingSheetId(id);
    setEditingSheetName(currentName);
  };

  const handleFinishRename = (id: string) => {
    if (editingSheetName.trim()) {
      renameSheet(id, editingSheetName.trim());
    }
    setEditingSheetId(null);
  };

  const handleKeyDown = (id: string, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleFinishRename(id);
    } else if (e.key === 'Escape') {
      setEditingSheetId(null);
    }
  };

  return (
    <div className="sheet-tabs-container">
      {/* Navigation Arrows for many tabs */}
      <div className="sheet-nav-controls">
        <button className="sheet-nav-btn" title="Cuộn sang trái">
          <ChevronLeft size={14} />
        </button>
        <button className="sheet-nav-btn" title="Cuộn sang phải">
          <ChevronRight size={14} />
        </button>
      </div>

      {/* Tabs List */}
      <div className="sheet-tabs-list">
        {workbook.sheets.map(sheet => {
          const isActive = sheet.id === activeSheet.id;
          const isEditing = editingSheetId === sheet.id;

          return (
            <div
              key={sheet.id}
              className={`sheet-tab-item ${isActive ? 'active' : ''}`}
              onClick={() => setActiveSheet(sheet.id)}
              onDoubleClick={() => handleStartRename(sheet.id, sheet.name)}
            >
              {isEditing ? (
                <input
                  type="text"
                  className="sheet-rename-input"
                  value={editingSheetName}
                  onChange={e => setEditingSheetName(e.target.value)}
                  onBlur={() => handleFinishRename(sheet.id)}
                  onKeyDown={e => handleKeyDown(sheet.id, e)}
                  autoFocus
                />
              ) : (
                <span className="sheet-tab-label">{sheet.name}</span>
              )}

              {/* Action buttons on active tab */}
              {isActive && !isEditing && (
                <div className="sheet-tab-actions">
                  <button
                    className="sheet-action-icon"
                    onClick={e => {
                      e.stopPropagation();
                      handleStartRename(sheet.id, sheet.name);
                    }}
                    title="Đổi tên sheet"
                  >
                    <Edit2 size={11} />
                  </button>

                  {workbook.sheets.length > 1 && (
                    <button
                      className="sheet-action-icon delete-icon"
                      onClick={e => {
                        e.stopPropagation();
                        deleteSheet(sheet.id);
                      }}
                      title="Xóa sheet"
                    >
                      <X size={12} />
                    </button>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Add Sheet Button */}
      <button
        className="add-sheet-btn"
        onClick={addSheet}
        title="Thêm trang tính mới (+)"
      >
        <Plus size={16} />
      </button>
    </div>
  );
};
