export const defaultDocumentHTML = `
<h1>BÁO CÁO DỰ ÁN PC DOC EDITOR (WORD 365)</h1>
<p><strong>Phiên bản:</strong> 1.0.0 Pro | <strong>Ngày cập nhật:</strong> 22/11/2026 | <strong>Trạng thái:</strong> <mark>Hoàn thành kiểm duyệt</mark></p>
<hr/>
<h2>1. Tổng quan Dự án</h2>
<p>PC Doc Editor là bộ công cụ văn phòng máy tính chuyên nghiệp được xây dựng dựa trên giao diện <strong>Microsoft Word 365</strong> hiện đại. Ứng dụng hỗ trợ đầy đủ các thao tác soạn thảo trực quan (WYSIWYG), định dạng kiểu chữ, căn lề văn bản, chèn bảng biểu, chèn hình ảnh và hỗ trợ đọc/ghi định dạng tệp <code>.docx</code> chuẩn <em>OpenXML</em>.</p>

<blockquote>
  <p><em>"Trải nghiệm soạn thảo mượt mà, định dạng văn bản chuẩn mực cùng khả năng tương thích 100% với Microsoft Word trên máy tính cá nhân."</em></p>
</blockquote>

<h2>2. Bảng Tóm tắt Thông số Kỹ thuật</h2>
<table>
  <thead>
    <tr>
      <th>Thành phần</th>
      <th>Công nghệ sử dụng</th>
      <th>Mô tả tính năng</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Lõi soạn thảo</td>
      <td>TipTap / ProseMirror</td>
      <td>Đầy đủ tính năng Headings, Tables, Lists, Colors, Text Align</td>
    </tr>
    <tr>
      <td>Đọc file .docx</td>
      <td>Mammoth Converter</td>
      <td>Phân tích cấu trúc Word và trích xuất hình ảnh, bảng biểu tự động</td>
    </tr>
    <tr>
      <td>Ghi file .docx</td>
      <td>Docx OpenXML Generator</td>
      <td>Xuất tệp .docx chuẩn quốc tế, mở được trên MS Word &amp; Google Docs</td>
    </tr>
    <tr>
      <td>Nền tảng Desktop</td>
      <td>Electron + React + TS</td>
      <td>Hiệu năng cao, bảo mật cách ly, menu Ribbon chuẩn Word 365</td>
    </tr>
  </tbody>
</table>

<h2>3. Danh mục Công việc Đã Hoàn thành</h2>
<ul data-type="taskList">
  <li data-type="taskItem" data-checked="true">Xây dựng thanh tiêu đề xanh lam Word 365 với Quick Access Toolbar</li>
  <li data-type="taskItem" data-checked="true">Phát triển Ribbon Toolbar 4 thẻ: Trang đầu, Chèn, Bố trí, Xem</li>
  <li data-type="taskItem" data-checked="true">Hỗ trợ phím tắt chuẩn: Ctrl+S, Ctrl+O, Ctrl+P, Ctrl+B, Ctrl+I, Ctrl+U</li>
  <li data-type="taskItem" data-checked="true">Xử lý Kéo &amp; Thả trực tiếp file Word .docx vào khung soạn thảo</li>
  <li data-type="taskItem" data-checked="true">Thanh trạng thái thống kê số từ, ký tự, trang và thanh trượt Zoom</li>
</ul>

<h2>4. Hướng dẫn Sử dụng Nhanh</h2>
<ol>
  <li><strong>Mở tệp:</strong> Nhấp vào biểu tượng thư mục trên thanh Quick Access hoặc nhấn <code>Ctrl + O</code>, hoặc kéo thả tệp .docx vào trang giấy.</li>
  <li><strong>Định dạng:</strong> Sử dụng các nút bấm trên thanh <em>Trang đầu</em> để đổi font chữ, màu sắc, cỡ chữ và căn lề.</li>
  <li><strong>Lưu tệp:</strong> Nhấn <code>Ctrl + S</code> hoặc nút Lưu để xuất tệp <code>.docx</code> OpenXML về máy tính.</li>
  <li><strong>In &amp; Xuất PDF:</strong> Nhấn <code>Ctrl + P</code> để in hoặc xuất tài liệu sang định dạng PDF.</li>
</ol>
`
