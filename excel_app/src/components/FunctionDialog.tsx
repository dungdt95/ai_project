import React, { useState } from 'react';
import { X, Calculator, Search } from 'lucide-react';
import { useExcel } from '../context/ExcelContext';

interface FunctionDialogProps {
  isOpen: boolean;
  onClose: () => void;
}

interface ExcelFuncInfo {
  name: string;
  syntax: string;
  description: string;
  category: string;
}

const EXCEL_FUNCTIONS: ExcelFuncInfo[] = [
  {
    name: 'SUM',
    syntax: '=SUM(number1, [number2], ...)',
    description: 'Tính tổng tất cả các số trong một phạm vi ô được chọn.',
    category: 'Toán học'
  },
  {
    name: 'AVERAGE',
    syntax: '=AVERAGE(number1, [number2], ...)',
    description: 'Trả về giá trị trung bình cộng của các đối số.',
    category: 'Thống kê'
  },
  {
    name: 'COUNT',
    syntax: '=COUNT(value1, [value2], ...)',
    description: 'Đếm số ô có chứa giá trị dạng số trong một vùng.',
    category: 'Thống kê'
  },
  {
    name: 'MAX',
    syntax: '=MAX(number1, [number2], ...)',
    description: 'Trả về giá trị lớn nhất trong một tập hợp các giá trị.',
    category: 'Thống kê'
  },
  {
    name: 'MIN',
    syntax: '=MIN(number1, [number2], ...)',
    description: 'Trả về giá trị nhỏ nhất trong một tập hợp các giá trị.',
    category: 'Thống kê'
  },
  {
    name: 'IF',
    syntax: '=IF(logical_test, [value_if_true], [value_if_false])',
    description: 'Kiểm tra xem điều kiện có được thỏa mãn hay không và trả về một giá trị nếu TRUE, giá trị khác nếu FALSE.',
    category: 'Logic'
  },
  {
    name: 'CONCATENATE',
    syntax: '=CONCATENATE(text1, [text2], ...)',
    description: 'Nối nhiều chuỗi văn bản lại thành một chuỗi duy nhất.',
    category: 'Văn bản'
  },
  {
    name: 'ROUND',
    syntax: '=ROUND(number, num_digits)',
    description: 'Làm tròn một số đến số chữ số thập phân đã chỉ định.',
    category: 'Toán học'
  },
  {
    name: 'PRODUCT',
    syntax: '=PRODUCT(number1, [number2], ...)',
    description: 'Nhân tất cả các số đã cho dưới dạng đối số và trả về tích số.',
    category: 'Toán học'
  },
  {
    name: 'VLOOKUP',
    syntax: '=VLOOKUP(lookup_value, table_array, col_index_num, [range_lookup])',
    description: 'Tìm kiếm một giá trị trong cột ngoài cùng bên trái của bảng và trả về giá trị ở cột tương ứng.',
    category: 'Tìm kiếm & Tham chiếu'
  }
];

export const FunctionDialog: React.FC<FunctionDialogProps> = ({ isOpen, onClose }) => {
  const { onFormulaBarChange, commitEditing } = useExcel();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedFunc, setSelectedFunc] = useState<ExcelFuncInfo>(EXCEL_FUNCTIONS[0]);

  if (!isOpen) return null;

  const filtered = EXCEL_FUNCTIONS.filter(f =>
    f.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    f.description.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleInsert = () => {
    const defaultTemplate = `=${selectedFunc.name}()`;
    onFormulaBarChange(defaultTemplate);
    commitEditing(defaultTemplate);
    onClose();
  };

  return (
    <div className="dialog-overlay">
      <div className="function-dialog">
        <div className="dialog-header">
          <div className="dialog-title">
            <Calculator size={18} color="#107c41" />
            <span>Chèn Hàm Tính Toán (Insert Function)</span>
          </div>
          <button className="dialog-close-btn" onClick={onClose}>
            <X size={16} />
          </button>
        </div>

        <div className="dialog-body">
          {/* Search box */}
          <div className="search-box">
            <Search size={14} className="search-icon" />
            <input
              type="text"
              placeholder="Tìm kiếm tên hàm hoặc mô tả..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              autoFocus
            />
          </div>

          <div className="function-content-layout">
            {/* List */}
            <div className="function-list">
              {filtered.map(fn => (
                <div
                  key={fn.name}
                  className={`function-item ${selectedFunc.name === fn.name ? 'active' : ''}`}
                  onClick={() => setSelectedFunc(fn)}
                >
                  <span className="func-name">{fn.name}</span>
                  <span className="func-cat">{fn.category}</span>
                </div>
              ))}
              {filtered.length === 0 && (
                <div className="no-result">Không tìm thấy hàm phù hợp</div>
              )}
            </div>

            {/* Details */}
            <div className="function-details">
              <h4 className="detail-name">{selectedFunc.name}</h4>
              <div className="detail-syntax">{selectedFunc.syntax}</div>
              <p className="detail-desc">{selectedFunc.description}</p>
            </div>
          </div>
        </div>

        <div className="dialog-footer">
          <button className="dialog-btn secondary" onClick={onClose}>
            Hủy
          </button>
          <button className="dialog-btn primary" onClick={handleInsert}>
            Chèn Hàm
          </button>
        </div>
      </div>
    </div>
  );
};
