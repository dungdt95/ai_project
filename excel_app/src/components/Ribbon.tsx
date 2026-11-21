import React, { useState } from 'react';
import {
  Scissors,
  Copy,
  Clipboard,
  Bold,
  Italic,
  Underline,
  Strikethrough,
  AlignLeft,
  AlignCenter,
  AlignRight,
  AlignVerticalJustifyStart,
  AlignVerticalJustifyCenter,
  AlignVerticalSpaceAround,
  Grid,
  Combine,
  Sigma,
  ArrowDownAZ,
  ArrowUpZA,
  Trash2,
  Table,
  PlusSquare,
  MinusSquare,
  ZoomIn,
  ZoomOut,
  Sparkles,
  FunctionSquare
} from 'lucide-react';
import { useExcel } from '../context/ExcelContext';
import { RibbonTab, CellFormatType } from '../types/excel';

interface RibbonProps {
  onOpenFunctionDialog: () => void;
}

export const Ribbon: React.FC<RibbonProps> = ({ onOpenFunctionDialog }) => {
  const {
    activeTab,
    setActiveTab,
    applyFormat,
    toggleMerge,
    clearSelection,
    autoSum,
    sortSelection,
    copy,
    cut,
    paste,
    insertRow,
    deleteRow,
    insertCol,
    deleteCol,
    showGridlines,
    setShowGridlines,
    showFormulaBar,
    setShowFormulaBar,
    showHeaders,
    setShowHeaders,
    zoom,
    setZoom
  } = useExcel();

  const [borderMenuOpen, setBorderMenuOpen] = useState(false);
  const [sumMenuOpen, setSumMenuOpen] = useState(false);

  return (
    <div className="ribbon-container">
      {/* Ribbon Tabs Header */}
      <div className="ribbon-tabs">
        <button
          className={`ribbon-tab-btn ${activeTab === 'home' ? 'active' : ''}`}
          onClick={() => setActiveTab('home')}
        >
          Trang đầu (Home)
        </button>
        <button
          className={`ribbon-tab-btn ${activeTab === 'insert' ? 'active' : ''}`}
          onClick={() => setActiveTab('insert')}
        >
          Chèn (Insert)
        </button>
        <button
          className={`ribbon-tab-btn ${activeTab === 'data' ? 'active' : ''}`}
          onClick={() => setActiveTab('data')}
        >
          Dữ liệu (Data)
        </button>
        <button
          className={`ribbon-tab-btn ${activeTab === 'view' ? 'active' : ''}`}
          onClick={() => setActiveTab('view')}
        >
          Xem (View)
        </button>
      </div>

      {/* Ribbon Content Panel */}
      <div className="ribbon-toolbar">
        {activeTab === 'home' && (
          <div className="ribbon-tab-content">
            {/* Group: Clipboard */}
            <div className="ribbon-group">
              <div className="group-content clipboard-group">
                <button className="ribbon-large-btn" onClick={paste} title="Dán (Ctrl+V)">
                  <Clipboard size={20} />
                  <span>Dán</span>
                </button>
                <div className="small-btn-col">
                  <button className="ribbon-small-btn" onClick={cut} title="Cắt (Ctrl+X)">
                    <Scissors size={14} />
                    <span>Cắt</span>
                  </button>
                  <button className="ribbon-small-btn" onClick={copy} title="Sao chép (Ctrl+C)">
                    <Copy size={14} />
                    <span>Sao chép</span>
                  </button>
                </div>
              </div>
              <div className="group-label">Bảng tạm</div>
            </div>

            {/* Group: Font */}
            <div className="ribbon-group">
              <div className="group-content font-group">
                {/* Row 1: Font Family & Size */}
                <div className="toolbar-row">
                  <select
                    className="font-select"
                    defaultValue="Segoe UI"
                    onChange={e => applyFormat({ fontFamily: e.target.value })}
                    title="Phông chữ"
                  >
                    <option value="Segoe UI">Segoe UI</option>
                    <option value="Arial">Arial</option>
                    <option value="Calibri">Calibri</option>
                    <option value="Times New Roman">Times New Roman</option>
                    <option value="Tahoma">Tahoma</option>
                    <option value="Consolas">Consolas</option>
                  </select>

                  <select
                    className="size-select"
                    defaultValue="11"
                    onChange={e => applyFormat({ fontSize: Number(e.target.value) })}
                    title="Cỡ chữ"
                  >
                    {[9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 36].map(s => (
                      <option key={s} value={s}>
                        {s}
                      </option>
                    ))}
                  </select>
                </div>

                {/* Row 2: B, I, U, Strike, Borders, Fill, Text Color */}
                <div className="toolbar-row font-tools">
                  <button
                    className="tool-btn"
                    onClick={() => applyFormat({ bold: true })}
                    title="In đậm (Bold)"
                  >
                    <Bold size={14} />
                  </button>
                  <button
                    className="tool-btn"
                    onClick={() => applyFormat({ italic: true })}
                    title="In nghiêng (Italic)"
                  >
                    <Italic size={14} />
                  </button>
                  <button
                    className="tool-btn"
                    onClick={() => applyFormat({ underline: true })}
                    title="Gạch chân (Underline)"
                  >
                    <Underline size={14} />
                  </button>
                  <button
                    className="tool-btn"
                    onClick={() => applyFormat({ strike: true })}
                    title="Gạch ngang chữ"
                  >
                    <Strikethrough size={14} />
                  </button>

                  <div className="divider-vert" />

                  {/* Border dropdown */}
                  <div className="dropdown-wrapper">
                    <button
                      className="tool-btn"
                      onClick={() => setBorderMenuOpen(!borderMenuOpen)}
                      title="Kẻ viền bảng"
                    >
                      <Grid size={14} />
                    </button>
                    {borderMenuOpen && (
                      <div className="dropdown-menu border-menu" onMouseLeave={() => setBorderMenuOpen(false)}>
                        <button
                          onClick={() => {
                            applyFormat({ border: { top: true, bottom: true, left: true, right: true } });
                            setBorderMenuOpen(false);
                          }}
                        >
                          Tất cả đường viền (All Borders)
                        </button>
                        <button
                          onClick={() => {
                            applyFormat({ border: { top: true, bottom: true, left: true, right: true, style: 'thick' } });
                            setBorderMenuOpen(false);
                          }}
                        >
                          Viền ngoài đậm (Thick Box Border)
                        </button>
                        <button
                          onClick={() => {
                            applyFormat({ border: { bottom: true, style: 'double' } });
                            setBorderMenuOpen(false);
                          }}
                        >
                          Viền dưới đôi (Double Bottom)
                        </button>
                        <button
                          onClick={() => {
                            applyFormat({ border: { top: false, bottom: false, left: false, right: false } });
                            setBorderMenuOpen(false);
                          }}
                        >
                          Không viền (No Border)
                        </button>
                      </div>
                    )}
                  </div>

                  {/* Fill Color */}
                  <div className="color-picker-btn" title="Màu nền ô (Fill Color)">
                    <span className="color-label">Màu nền:</span>
                    <input
                      type="color"
                      defaultValue="#ffffff"
                      onChange={e => applyFormat({ bgColor: e.target.value })}
                    />
                  </div>

                  {/* Text Color */}
                  <div className="color-picker-btn" title="Màu chữ (Font Color)">
                    <span className="color-label">Màu chữ:</span>
                    <input
                      type="color"
                      defaultValue="#000000"
                      onChange={e => applyFormat({ color: e.target.value })}
                    />
                  </div>
                </div>
              </div>
              <div className="group-label">Phông chữ</div>
            </div>

            {/* Group: Alignment */}
            <div className="ribbon-group">
              <div className="group-content align-group">
                <div className="toolbar-row">
                  <button
                    className="tool-btn"
                    onClick={() => applyFormat({ verticalAlign: 'top' })}
                    title="Căn trên"
                  >
                    <AlignVerticalJustifyStart size={14} />
                  </button>
                  <button
                    className="tool-btn"
                    onClick={() => applyFormat({ verticalAlign: 'middle' })}
                    title="Căn giữa theo chiều dọc"
                  >
                    <AlignVerticalJustifyCenter size={14} />
                  </button>
                  <button
                    className="tool-btn"
                    onClick={() => applyFormat({ verticalAlign: 'bottom' })}
                    title="Căn dưới"
                  >
                    <AlignVerticalSpaceAround size={14} />
                  </button>
                </div>
                <div className="toolbar-row">
                  <button
                    className="tool-btn"
                    onClick={() => applyFormat({ align: 'left' })}
                    title="Căn trái"
                  >
                    <AlignLeft size={14} />
                  </button>
                  <button
                    className="tool-btn"
                    onClick={() => applyFormat({ align: 'center' })}
                    title="Căn giữa"
                  >
                    <AlignCenter size={14} />
                  </button>
                  <button
                    className="tool-btn"
                    onClick={() => applyFormat({ align: 'right' })}
                    title="Căn phải"
                  >
                    <AlignRight size={14} />
                  </button>
                  <button
                    className="tool-btn merge-btn"
                    onClick={toggleMerge}
                    title="Gộp & Căn giữa các ô (Merge & Center)"
                  >
                    <Combine size={14} />
                    <span style={{ fontSize: '11px', marginLeft: '3px' }}>Gộp ô</span>
                  </button>
                </div>
              </div>
              <div className="group-label">Căn chỉnh</div>
            </div>

            {/* Group: Number Format */}
            <div className="ribbon-group">
              <div className="group-content number-group">
                <select
                  className="number-format-select"
                  onChange={e => applyFormat({ numFmt: e.target.value as CellFormatType })}
                  title="Định dạng số"
                >
                  <option value="general">Chung (General)</option>
                  <option value="number">Số (Number)</option>
                  <option value="currency_vnd">Tiền tệ (VNĐ)</option>
                  <option value="currency_usd">Tiền tệ (USD $)</option>
                  <option value="percent">Phần trăm (%)</option>
                  <option value="date">Ngày tháng (Date)</option>
                </select>

                <div className="toolbar-row number-quick-btns">
                  <button
                    className="quick-num-btn"
                    onClick={() => applyFormat({ numFmt: 'currency_vnd' })}
                    title="Định dạng tiền tệ VNĐ"
                  >
                    ₫
                  </button>
                  <button
                    className="quick-num-btn"
                    onClick={() => applyFormat({ numFmt: 'currency_usd' })}
                    title="Định dạng tiền tệ USD"
                  >
                    $
                  </button>
                  <button
                    className="quick-num-btn"
                    onClick={() => applyFormat({ numFmt: 'percent' })}
                    title="Định dạng phần trăm"
                  >
                    %
                  </button>
                  <button
                    className="quick-num-btn"
                    onClick={() => applyFormat({ numFmt: 'number' })}
                    title="Dấu phân cách hàng nghìn"
                  >
                    ,
                  </button>
                </div>
              </div>
              <div className="group-label">Số</div>
            </div>

            {/* Group: Cells (Insert / Delete) */}
            <div className="ribbon-group">
              <div className="group-content cells-group">
                <div className="small-btn-col">
                  <button
                    className="ribbon-small-btn"
                    onClick={() => insertRow()}
                    title="Chèn thêm 1 hàng phía trên ô chọn"
                  >
                    <PlusSquare size={13} color="#107c41" />
                    <span>Chèn hàng</span>
                  </button>
                  <button
                    className="ribbon-small-btn"
                    onClick={() => insertCol()}
                    title="Chèn thêm 1 cột bên trái ô chọn"
                  >
                    <PlusSquare size={13} color="#107c41" />
                    <span>Chèn cột</span>
                  </button>
                </div>
                <div className="small-btn-col">
                  <button
                    className="ribbon-small-btn"
                    onClick={() => deleteRow()}
                    title="Xóa hàng đang chọn"
                  >
                    <MinusSquare size={13} color="#d9381e" />
                    <span>Xóa hàng</span>
                  </button>
                  <button
                    className="ribbon-small-btn"
                    onClick={() => deleteCol()}
                    title="Xóa cột đang chọn"
                  >
                    <MinusSquare size={13} color="#d9381e" />
                    <span>Xóa cột</span>
                  </button>
                </div>
              </div>
              <div className="group-label">Ô tính</div>
            </div>

            {/* Group: Editing (AutoSum, Sort, Clear) */}
            <div className="ribbon-group">
              <div className="group-content editing-group">
                {/* AutoSum dropdown */}
                <div className="dropdown-wrapper">
                  <button
                    className="ribbon-large-btn autosum-btn"
                    onClick={() => setSumMenuOpen(!sumMenuOpen)}
                    title="Tự động tính tổng / thống kê (AutoSum)"
                  >
                    <Sigma size={18} color="#107c41" />
                    <span>Tự tính Σ</span>
                  </button>
                  {sumMenuOpen && (
                    <div className="dropdown-menu autosum-menu" onMouseLeave={() => setSumMenuOpen(false)}>
                      <button
                        onClick={() => {
                          autoSum('SUM');
                          setSumMenuOpen(false);
                        }}
                      >
                        SUM (Tính tổng)
                      </button>
                      <button
                        onClick={() => {
                          autoSum('AVERAGE');
                          setSumMenuOpen(false);
                        }}
                      >
                        AVERAGE (Trung bình)
                      </button>
                      <button
                        onClick={() => {
                          autoSum('COUNT');
                          setSumMenuOpen(false);
                        }}
                      >
                        COUNT (Đếm số)
                      </button>
                      <button
                        onClick={() => {
                          autoSum('MAX');
                          setSumMenuOpen(false);
                        }}
                      >
                        MAX (Lớn nhất)
                      </button>
                      <button
                        onClick={() => {
                          autoSum('MIN');
                          setSumMenuOpen(false);
                        }}
                      >
                        MIN (Nhỏ nhất)
                      </button>
                    </div>
                  )}
                </div>

                <div className="small-btn-col">
                  <button
                    className="ribbon-small-btn"
                    onClick={() => sortSelection('asc')}
                    title="Sắp xếp tăng dần A-Z"
                  >
                    <ArrowDownAZ size={13} />
                    <span>Tăng dần</span>
                  </button>
                  <button
                    className="ribbon-small-btn"
                    onClick={() => sortSelection('desc')}
                    title="Sắp xếp giảm dần Z-A"
                  >
                    <ArrowUpZA size={13} />
                    <span>Giảm dần</span>
                  </button>
                </div>

                <button
                  className="ribbon-large-btn clear-btn"
                  onClick={clearSelection}
                  title="Xóa nội dung ô đang chọn"
                >
                  <Trash2 size={16} />
                  <span>Xóa</span>
                </button>
              </div>
              <div className="group-label">Chỉnh sửa</div>
            </div>
          </div>
        )}

        {activeTab === 'insert' && (
          <div className="ribbon-tab-content">
            <div className="ribbon-group">
              <div className="group-content">
                <button
                  className="ribbon-large-btn"
                  onClick={() => {
                    applyFormat({
                      border: { top: true, bottom: true, left: true, right: true },
                      bgColor: '#f9f9f9'
                    });
                  }}
                  title="Tạo khung bảng"
                >
                  <Table size={20} color="#107c41" />
                  <span>Kẻ Bảng</span>
                </button>

                <button
                  className="ribbon-large-btn"
                  onClick={onOpenFunctionDialog}
                  title="Chèn hàm tính toán chuẩn Excel"
                >
                  <FunctionSquare size={20} color="#107c41" />
                  <span>Chèn Hàm</span>
                </button>
              </div>
              <div className="group-label">Bảng & Công thức</div>
            </div>
          </div>
        )}

        {activeTab === 'data' && (
          <div className="ribbon-tab-content">
            <div className="ribbon-group">
              <div className="group-content">
                <button
                  className="ribbon-large-btn"
                  onClick={() => sortSelection('asc')}
                  title="Sắp xếp từ A đến Z"
                >
                  <ArrowDownAZ size={20} color="#107c41" />
                  <span>A-Z Tăng</span>
                </button>

                <button
                  className="ribbon-large-btn"
                  onClick={() => sortSelection('desc')}
                  title="Sắp xếp từ Z đến A"
                >
                  <ArrowUpZA size={20} color="#107c41" />
                  <span>Z-A Giảm</span>
                </button>
              </div>
              <div className="group-label">Sắp xếp dữ liệu</div>
            </div>
          </div>
        )}

        {activeTab === 'view' && (
          <div className="ribbon-tab-content">
            {/* Show / Hide */}
            <div className="ribbon-group">
              <div className="group-content show-hide-group">
                <label className="checkbox-item">
                  <input
                    type="checkbox"
                    checked={showGridlines}
                    onChange={e => setShowGridlines(e.target.checked)}
                  />
                  <span>Đường lưới (Gridlines)</span>
                </label>
                <label className="checkbox-item">
                  <input
                    type="checkbox"
                    checked={showFormulaBar}
                    onChange={e => setShowFormulaBar(e.target.checked)}
                  />
                  <span>Thanh công thức (Formula Bar)</span>
                </label>
                <label className="checkbox-item">
                  <input
                    type="checkbox"
                    checked={showHeaders}
                    onChange={e => setShowHeaders(e.target.checked)}
                  />
                  <span>Tiêu đề hàng/cột (Headers)</span>
                </label>
              </div>
              <div className="group-label">Hiển thị</div>
            </div>

            {/* Zoom */}
            <div className="ribbon-group">
              <div className="group-content zoom-group">
                <button
                  className="ribbon-small-btn"
                  onClick={() => setZoom(Math.max(50, zoom - 25))}
                  title="Thu nhỏ"
                >
                  <ZoomOut size={14} />
                  <span>Thu nhỏ</span>
                </button>
                <button
                  className="ribbon-small-btn"
                  onClick={() => setZoom(100)}
                  title="100% chuẩn"
                >
                  <span>100%</span>
                </button>
                <button
                  className="ribbon-small-btn"
                  onClick={() => setZoom(Math.min(200, zoom + 25))}
                  title="Phóng to"
                >
                  <ZoomIn size={14} />
                  <span>Phóng to</span>
                </button>
              </div>
              <div className="group-label">Thu phóng ({zoom}%)</div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
