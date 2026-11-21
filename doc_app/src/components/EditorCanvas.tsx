import React, { useState } from 'react'
import { Editor, EditorContent } from '@tiptap/react'
import { FileUp } from 'lucide-react'
import { MarginType, OrientationType, ViewModeType } from '../types'

interface EditorCanvasProps {
  editor: Editor | null
  zoom: number
  marginType: MarginType
  orientation: OrientationType
  viewMode: ViewModeType
  onFileDrop: (file: File) => void
}

export const EditorCanvas: React.FC<EditorCanvasProps> = ({
  editor,
  zoom,
  marginType,
  orientation,
  viewMode,
  onFileDrop
}) => {
  const [isDraggingOver, setIsDraggingOver] = useState(false)

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDraggingOver(true)
  }

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDraggingOver(false)
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDraggingOver(false)

    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      const file = e.dataTransfer.files[0]
      if (file.name.endsWith('.docx')) {
        onFileDrop(file)
      } else {
        alert('Vui lòng kéo & thả tệp định dạng Word (.docx)!')
      }
    }
  }

  const scaleRatio = zoom / 100

  return (
    <div
      className={`canvas-wrapper ${viewMode === 'reading' ? 'reading-mode' : ''}`}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      {/* Drag & Drop Visual Indicator */}
      {isDraggingOver && (
        <div className="dropzone-overlay">
          <FileUp size={48} style={{ marginBottom: 12 }} />
          <h2 style={{ margin: 0, fontSize: 20 }}>Thả file .docx vào đây để mở</h2>
          <p style={{ margin: '8px 0 0 0', opacity: 0.9, fontSize: 14 }}>
            Tự động nạp toàn bộ văn bản, hình ảnh và bảng biểu
          </p>
        </div>
      )}

      {/* Simulated A4 Paper */}
      <div
        className={`page-sheet ${orientation} margin-${marginType}`}
        style={{
          transform: viewMode === 'page' ? `scale(${scaleRatio})` : 'none',
          marginBottom: viewMode === 'page' && zoom > 100 ? `${(zoom - 100) * 10}px` : '40px'
        }}
        onClick={() => {
          // Keep editor focused when clicking page margins
          if (editor && !editor.isFocused) {
            editor.commands.focus()
          }
        }}
      >
        <EditorContent editor={editor} />
      </div>
    </div>
  )
}
