import React, { useState, useRef } from 'react'
import { Editor } from '@tiptap/react'
import {
  Bold,
  Italic,
  Underline as UnderlineIcon,
  Strikethrough,
  Subscript as SubscriptIcon,
  Superscript as SuperscriptIcon,
  AlignLeft,
  AlignCenter,
  AlignRight,
  AlignJustify,
  List,
  ListOrdered,
  ListTodo,
  Table as TableIcon,
  Image as ImageIcon,
  Minus,
  Quote,
  Code,
  Link as LinkIcon,
  Unlink,
  Highlighter,
  Palette,
  Maximize2,
  FileText,
  BookOpen,
  ZoomIn,
  ZoomOut,
  RotateCcw,
  PlusSquare,
  Columns,
  Rows,
  Trash2,
  Split,
  Combine
} from 'lucide-react'
import { MarginType, OrientationType, ViewModeType } from '../types'

interface RibbonToolbarProps {
  editor: Editor | null
  marginType: MarginType
  orientation: OrientationType
  viewMode: ViewModeType
  zoom: number
  onMarginChange: (margin: MarginType) => void
  onOrientationChange: (orientation: OrientationType) => void
  onViewModeChange: (mode: ViewModeType) => void
  onZoomChange: (zoom: number) => void
}

export const RibbonToolbar: React.FC<RibbonToolbarProps> = ({
  editor,
  marginType,
  orientation,
  viewMode,
  zoom,
  onMarginChange,
  onOrientationChange,
  onViewModeChange,
  onZoomChange
}) => {
  const [activeTab, setActiveTab] = useState<'home' | 'insert' | 'layout' | 'view'>('home')
  const imageInputRef = useRef<HTMLInputElement>(null)

  if (!editor) {
    return null
  }

  // Formatting helpers
  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      const reader = new FileReader()
      reader.onload = () => {
        if (typeof reader.result === 'string') {
          editor.chain().focus().setImage({ src: reader.result }).run()
        }
      }
      reader.readAsDataURL(file)
    }
    // reset input
    e.target.value = ''
  }

  const setLink = () => {
    const previousUrl = editor.getAttributes('link').href
    const url = window.prompt('Nhập địa chỉ liên kết (URL):', previousUrl || 'https://')

    if (url === null) {
      return
    }

    if (url === '') {
      editor.chain().focus().extendMarkRange('link').unsetLink().run()
      return
    }

    editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run()
  }

  return (
    <div className="ribbon-container">
      {/* Tabs list */}
      <div className="ribbon-tabs">
        <button
          className={`ribbon-tab ${activeTab === 'home' ? 'active' : ''}`}
          onClick={() => setActiveTab('home')}
        >
          Trang đầu
        </button>
        <button
          className={`ribbon-tab ${activeTab === 'insert' ? 'active' : ''}`}
          onClick={() => setActiveTab('insert')}
        >
          Chèn
        </button>
        <button
          className={`ribbon-tab ${activeTab === 'layout' ? 'active' : ''}`}
          onClick={() => setActiveTab('layout')}
        >
          Bố trí
        </button>
        <button
          className={`ribbon-tab ${activeTab === 'view' ? 'active' : ''}`}
          onClick={() => setActiveTab('view')}
        >
          Xem
        </button>
      </div>

      {/* Tab Contents */}
      <div className="ribbon-content">
        {/* ==================== TAB 1: TRANG ĐẦU (HOME) ==================== */}
        {activeTab === 'home' && (
          <>
            {/* Font Family & Size */}
            <div className="ribbon-group">
              <div className="ribbon-group-row">
                <select
                  className="ribbon-select"
                  style={{ width: 135 }}
                  onChange={(e) => {
                    const font = e.target.value
                    if (font) {
                      editor.chain().focus().run()
                      // TipTap style
                      const el = document.querySelector('.page-sheet .ProseMirror') as HTMLElement
                      if (el) el.style.fontFamily = font
                    }
                  }}
                  defaultValue="Segoe UI"
                  title="Phông chữ"
                >
                  <option value="Segoe UI">Segoe UI</option>
                  <option value="Aptos">Aptos</option>
                  <option value="Arial">Arial</option>
                  <option value="Calibri">Calibri</option>
                  <option value="'Times New Roman', Times, serif">Times New Roman</option>
                  <option value="Roboto, sans-serif">Roboto</option>
                  <option value="Georgia, serif">Georgia</option>
                  <option value="'Courier New', monospace">Courier New</option>
                </select>

                <select
                  className="ribbon-select"
                  style={{ width: 55 }}
                  defaultValue="15"
                  onChange={(e) => {
                    const size = e.target.value
                    const el = document.querySelector('.page-sheet .ProseMirror') as HTMLElement
                    if (el) el.style.fontSize = `${size}px`
                  }}
                  title="Cỡ chữ"
                >
                  <option value="11">11</option>
                  <option value="12">12</option>
                  <option value="13">13</option>
                  <option value="14">14</option>
                  <option value="15">15</option>
                  <option value="16">16</option>
                  <option value="18">18</option>
                  <option value="20">20</option>
                  <option value="24">24</option>
                  <option value="28">28</option>
                  <option value="36">36</option>
                  <option value="48">48</option>
                  <option value="72">72</option>
                </select>
              </div>

              {/* Text formatting & colors */}
              <div className="ribbon-group-row">
                <button
                  className={`ribbon-btn ${editor.isActive('bold') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleBold().run()}
                  title="In đậm (Ctrl+B)"
                >
                  <Bold size={15} />
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive('italic') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleItalic().run()}
                  title="In nghiêng (Ctrl+I)"
                >
                  <Italic size={15} />
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive('underline') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleUnderline().run()}
                  title="Gạch chân (Ctrl+U)"
                >
                  <UnderlineIcon size={15} />
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive('strike') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleStrike().run()}
                  title="Gạch ngang chữ"
                >
                  <Strikethrough size={15} />
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive('subscript') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleSubscript().run()}
                  title="Chỉ số dưới (X₂)"
                >
                  <SubscriptIcon size={14} />
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive('superscript') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleSuperscript().run()}
                  title="Chỉ số trên (X²)"
                >
                  <SuperscriptIcon size={14} />
                </button>

                {/* Font Color */}
                <label className="ribbon-btn" title="Màu chữ" style={{ position: 'relative', cursor: 'pointer' }}>
                  <Palette size={15} color={editor.getAttributes('textStyle').color || '#185abd'} />
                  <input
                    type="color"
                    style={{ position: 'absolute', opacity: 0, width: 0, height: 0 }}
                    onChange={(e) => editor.chain().focus().setColor(e.target.value).run()}
                  />
                </label>

                {/* Highlight Color */}
                <label className="ribbon-btn" title="Màu dạ quang đánh dấu" style={{ position: 'relative', cursor: 'pointer' }}>
                  <Highlighter size={15} color="#eab308" />
                  <input
                    type="color"
                    defaultValue="#fef08a"
                    style={{ position: 'absolute', opacity: 0, width: 0, height: 0 }}
                    onChange={(e) => editor.chain().focus().toggleHighlight({ color: e.target.value }).run()}
                  />
                </label>
              </div>
              <span className="ribbon-group-label">Phông chữ</span>
            </div>

            {/* Paragraph & Alignment */}
            <div className="ribbon-group">
              <div className="ribbon-group-row">
                <button
                  className={`ribbon-btn ${editor.isActive({ textAlign: 'left' }) ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().setTextAlign('left').run()}
                  title="Căn trái (Ctrl+L)"
                >
                  <AlignLeft size={15} />
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive({ textAlign: 'center' }) ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().setTextAlign('center').run()}
                  title="Căn giữa (Ctrl+E)"
                >
                  <AlignCenter size={15} />
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive({ textAlign: 'right' }) ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().setTextAlign('right').run()}
                  title="Căn phải (Ctrl+R)"
                >
                  <AlignRight size={15} />
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive({ textAlign: 'justify' }) ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().setTextAlign('justify').run()}
                  title="Căn đều hai bên (Ctrl+J)"
                >
                  <AlignJustify size={15} />
                </button>
              </div>

              <div className="ribbon-group-row">
                <button
                  className={`ribbon-btn ${editor.isActive('bulletList') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleBulletList().run()}
                  title="Danh sách dấu đầu dòng"
                >
                  <List size={15} />
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive('orderedList') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleOrderedList().run()}
                  title="Danh sách đánh số"
                >
                  <ListOrdered size={15} />
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive('taskList') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleTaskList().run()}
                  title="Danh sách công việc (Task list)"
                >
                  <ListTodo size={15} />
                </button>
              </div>
              <span className="ribbon-group-label">Đoạn văn</span>
            </div>

            {/* Styles gallery */}
            <div className="ribbon-group">
              <div className="ribbon-group-row" style={{ gap: 6 }}>
                <button
                  className={`ribbon-btn ${editor.isActive('paragraph') && !editor.isActive('heading') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().setParagraph().run()}
                  title="Văn bản thông thường"
                  style={{ fontSize: 12, fontWeight: 500 }}
                >
                  Normal
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive('heading', { level: 1 }) ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}
                  title="Tiêu đề 1"
                  style={{ fontSize: 13, fontWeight: 'bold', color: '#185abd' }}
                >
                  Heading 1
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive('heading', { level: 2 }) ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}
                  title="Tiêu đề 2"
                  style={{ fontSize: 12, fontWeight: 'bold', color: '#185abd' }}
                >
                  Heading 2
                </button>
                <button
                  className={`ribbon-btn ${editor.isActive('heading', { level: 3 }) ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}
                  title="Tiêu đề 3"
                  style={{ fontSize: 11.5, fontWeight: 'bold', color: '#185abd' }}
                >
                  Heading 3
                </button>
              </div>
              <span className="ribbon-group-label">Kiểu cách (Styles)</span>
            </div>
          </>
        )}

        {/* ==================== TAB 2: CHÈN (INSERT) ==================== */}
        {activeTab === 'insert' && (
          <>
            {/* Tables */}
            <div className="ribbon-group">
              <div className="ribbon-group-row">
                <button
                  className="ribbon-btn-large"
                  onClick={() => editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()}
                  title="Chèn bảng 3x3"
                >
                  <TableIcon size={20} color="#185abd" />
                  <span>Bảng biểu</span>
                </button>

                {editor.isActive('table') && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                    <div className="ribbon-group-row">
                      <button
                        className="ribbon-btn"
                        onClick={() => editor.chain().focus().addRowAfter().run()}
                        title="Thêm hàng dưới"
                      >
                        <Rows size={13} /> +Hàng
                      </button>
                      <button
                        className="ribbon-btn"
                        onClick={() => editor.chain().focus().addColumnAfter().run()}
                        title="Thêm cột phải"
                      >
                        <Columns size={13} /> +Cột
                      </button>
                    </div>
                    <div className="ribbon-group-row">
                      <button
                        className="ribbon-btn"
                        onClick={() => editor.chain().focus().mergeOrSplit().run()}
                        title="Gộp hoặc Tách ô"
                      >
                        <Combine size={13} /> Gộp/Tách
                      </button>
                      <button
                        className="ribbon-btn"
                        onClick={() => editor.chain().focus().deleteTable().run()}
                        title="Xóa toàn bộ bảng"
                        style={{ color: '#dc2626' }}
                      >
                        <Trash2 size={13} /> Xóa
                      </button>
                    </div>
                  </div>
                )}
              </div>
              <span className="ribbon-group-label">Bảng</span>
            </div>

            {/* Media & Illustrations */}
            <div className="ribbon-group">
              <div className="ribbon-group-row">
                <button
                  className="ribbon-btn-large"
                  onClick={() => imageInputRef.current?.click()}
                  title="Chèn ảnh từ máy tính"
                >
                  <ImageIcon size={20} color="#16a34a" />
                  <span>Hình ảnh</span>
                </button>
                <input
                  type="file"
                  ref={imageInputRef}
                  style={{ display: 'none' }}
                  accept="image/*"
                  onChange={handleImageUpload}
                />

                <button
                  className="ribbon-btn-large"
                  onClick={() => editor.chain().focus().setHorizontalRule().run()}
                  title="Chèn đường kẻ ngang"
                >
                  <Minus size={20} color="#6b7280" />
                  <span>Đường kẻ</span>
                </button>
              </div>
              <span className="ribbon-group-label">Minh họa</span>
            </div>

            {/* Blocks & Links */}
            <div className="ribbon-group">
              <div className="ribbon-group-row">
                <button
                  className={`ribbon-btn-large ${editor.isActive('blockquote') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleBlockquote().run()}
                  title="Khối trích dẫn"
                >
                  <Quote size={20} color="#d97706" />
                  <span>Trích dẫn</span>
                </button>

                <button
                  className={`ribbon-btn-large ${editor.isActive('codeBlock') ? 'active' : ''}`}
                  onClick={() => editor.chain().focus().toggleCodeBlock().run()}
                  title="Khối mã nguồn"
                >
                  <Code size={20} color="#7c3aed" />
                  <span>Mã nguồn</span>
                </button>

                <button
                  className={`ribbon-btn-large ${editor.isActive('link') ? 'active' : ''}`}
                  onClick={setLink}
                  title="Chèn hoặc sửa liên kết"
                >
                  <LinkIcon size={20} color="#0284c7" />
                  <span>Liên kết</span>
                </button>
              </div>
              <span className="ribbon-group-label">Nội dung nâng cao</span>
            </div>
          </>
        )}

        {/* ==================== TAB 3: BỐ TRÍ (LAYOUT) ==================== */}
        {activeTab === 'layout' && (
          <>
            {/* Margins */}
            <div className="ribbon-group">
              <div className="ribbon-group-row">
                <button
                  className={`ribbon-btn ${marginType === 'normal' ? 'active' : ''}`}
                  onClick={() => onMarginChange('normal')}
                  title="Lề chuẩn (2.54 cm)"
                >
                  Bình thường (2.54cm)
                </button>
                <button
                  className={`ribbon-btn ${marginType === 'narrow' ? 'active' : ''}`}
                  onClick={() => onMarginChange('narrow')}
                  title="Lề hẹp (1.27 cm)"
                >
                  Thu hẹp (1.27cm)
                </button>
                <button
                  className={`ribbon-btn ${marginType === 'wide' ? 'active' : ''}`}
                  onClick={() => onMarginChange('wide')}
                  title="Lề rộng (3.81 cm)"
                >
                  Rộng (3.81cm)
                </button>
              </div>
              <span className="ribbon-group-label">Căn lề trang (Margins)</span>
            </div>

            {/* Page Orientation */}
            <div className="ribbon-group">
              <div className="ribbon-group-row">
                <button
                  className={`ribbon-btn ${orientation === 'portrait' ? 'active' : ''}`}
                  onClick={() => onOrientationChange('portrait')}
                  title="Khổ giấy đứng A4"
                >
                  <FileText size={16} /> Dọc (Portrait)
                </button>
                <button
                  className={`ribbon-btn ${orientation === 'landscape' ? 'active' : ''}`}
                  onClick={() => onOrientationChange('landscape')}
                  title="Khổ giấy nằm ngang A4"
                >
                  <FileText size={16} style={{ transform: 'rotate(90deg)' }} /> Ngang (Landscape)
                </button>
              </div>
              <span className="ribbon-group-label">Hướng giấy</span>
            </div>

            {/* Clean styling */}
            <div className="ribbon-group">
              <div className="ribbon-group-row">
                <button
                  className="ribbon-btn"
                  onClick={() => editor.chain().focus().unsetAllMarks().clearNodes().run()}
                  title="Xóa sạch định dạng văn bản đã chọn"
                >
                  <RotateCcw size={15} /> Xóa định dạng
                </button>
              </div>
              <span className="ribbon-group-label">Công cụ trang</span>
            </div>
          </>
        )}

        {/* ==================== TAB 4: XEM (VIEW) ==================== */}
        {activeTab === 'view' && (
          <>
            {/* View Modes */}
            <div className="ribbon-group">
              <div className="ribbon-group-row">
                <button
                  className={`ribbon-btn-large ${viewMode === 'page' ? 'active' : ''}`}
                  onClick={() => onViewModeChange('page')}
                  title="Chế độ trang in A4 chuẩn Word"
                >
                  <FileText size={20} color="#185abd" />
                  <span>Trang in A4</span>
                </button>
                <button
                  className={`ribbon-btn-large ${viewMode === 'reading' ? 'active' : ''}`}
                  onClick={() => onViewModeChange('reading')}
                  title="Chế độ đọc tập trung toàn màn hình"
                >
                  <BookOpen size={20} color="#059669" />
                  <span>Chế độ đọc</span>
                </button>
              </div>
              <span className="ribbon-group-label">Chế độ hiển thị</span>
            </div>

            {/* Zoom Controls */}
            <div className="ribbon-group">
              <div className="ribbon-group-row">
                <button
                  className="ribbon-btn"
                  onClick={() => onZoomChange(Math.max(50, zoom - 10))}
                  title="Thu nhỏ"
                >
                  <ZoomOut size={15} /> -10%
                </button>
                <button
                  className={`ribbon-btn ${zoom === 100 ? 'active' : ''}`}
                  onClick={() => onZoomChange(100)}
                  title="Đặt lại 100%"
                >
                  100%
                </button>
                <button
                  className="ribbon-btn"
                  onClick={() => onZoomChange(Math.min(200, zoom + 10))}
                  title="Phóng to"
                >
                  <ZoomIn size={15} /> +10%
                </button>
              </div>
              <span className="ribbon-group-label">Thu phóng (Zoom)</span>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
