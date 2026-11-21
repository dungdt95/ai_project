import React, { useEffect, useRef } from 'react';
import {
  Scissors,
  Copy,
  Clipboard,
  PlusSquare,
  MinusSquare,
  Combine,
  Trash2
} from 'lucide-react';
import { useExcel } from '../context/ExcelContext';

interface ContextMenuProps {
  x: number;
  y: number;
  onClose: () => void;
}

export const ContextMenu: React.FC<ContextMenuProps> = ({ x, y, onClose }) => {
  const {
    copy,
    cut,
    paste,
    insertRow,
    deleteRow,
    insertCol,
    deleteCol,
    toggleMerge,
    clearSelection
  } = useExcel();

  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        onClose();
      }
    };
    window.addEventListener('mousedown', handleClickOutside);
    return () => window.removeEventListener('mousedown', handleClickOutside);
  }, [onClose]);

  return (
    <div
      ref={menuRef}
      className="context-menu"
      style={{ top: `${y}px`, left: `${x}px` }}
    >
      <button
        className="context-menu-item"
        onClick={() => {
          cut();
          onClose();
        }}
      >
        <Scissors size={14} />
        <span>Cắt</span>
        <span className="shortcut">Ctrl+X</span>
      </button>

      <button
        className="context-menu-item"
        onClick={() => {
          copy();
          onClose();
        }}
      >
        <Copy size={14} />
        <span>Sao chép</span>
        <span className="shortcut">Ctrl+C</span>
      </button>

      <button
        className="context-menu-item"
        onClick={() => {
          paste();
          onClose();
        }}
      >
        <Clipboard size={14} />
        <span>Dán</span>
        <span className="shortcut">Ctrl+V</span>
      </button>

      <div className="context-menu-divider" />

      <button
        className="context-menu-item"
        onClick={() => {
          insertRow();
          onClose();
        }}
      >
        <PlusSquare size={14} color="#107c41" />
        <span>Chèn hàng</span>
      </button>

      <button
        className="context-menu-item"
        onClick={() => {
          insertCol();
          onClose();
        }}
      >
        <PlusSquare size={14} color="#107c41" />
        <span>Chèn cột</span>
      </button>

      <button
        className="context-menu-item"
        onClick={() => {
          deleteRow();
          onClose();
        }}
      >
        <MinusSquare size={14} color="#d9381e" />
        <span>Xóa hàng</span>
      </button>

      <button
        className="context-menu-item"
        onClick={() => {
          deleteCol();
          onClose();
        }}
      >
        <MinusSquare size={14} color="#d9381e" />
        <span>Xóa cột</span>
      </button>

      <div className="context-menu-divider" />

      <button
        className="context-menu-item"
        onClick={() => {
          toggleMerge();
          onClose();
        }}
      >
        <Combine size={14} />
        <span>Gộp / Bỏ gộp ô</span>
      </button>

      <button
        className="context-menu-item text-danger"
        onClick={() => {
          clearSelection();
          onClose();
        }}
      >
        <Trash2 size={14} />
        <span>Xóa nội dung</span>
        <span className="shortcut">Del</span>
      </button>
    </div>
  );
};
