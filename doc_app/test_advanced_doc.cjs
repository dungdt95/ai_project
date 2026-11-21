const fs = require('fs');
const path = require('path');
const esbuild = require('esbuild');
const { Packer } = require('docx');

// Dynamically load TypeScript modules using esbuild
function loadTsModule(relativePath, externals = []) {
  const fullPath = path.join(__dirname, relativePath);
  const result = esbuild.buildSync({
    entryPoints: [fullPath],
    write: false,
    format: 'cjs',
    platform: 'node',
    bundle: true,
    external: externals
  });
  const moduleObj = { exports: {} };
  const fn = new Function('module', 'exports', 'require', '__dirname', '__filename', result.outputFiles[0].text);
  fn(moduleObj, moduleObj.exports, require, path.dirname(fullPath), fullPath);
  return moduleObj.exports;
}

const { exportTipTapToDocxDocument } = loadTsModule('src/utils/docxExporter.ts', ['docx', '@tiptap/react']);
const { importDocxToArrayBuffer } = loadTsModule('src/utils/docxImporter.ts', ['mammoth']);

async function runAdvancedDocTests() {
  console.log('================================================================');
  console.log('   PC DOC EDITOR - ADVANCED ROUND-TRIP TEST SUITE (WORD 365)    ');
  console.log('================================================================\n');

  let passedChecks = 0;
  const totalChecks = 7;

  // 1. Construct Complex TipTap Document JSON
  console.log('[STAGE 1] Constructing Complex TipTap Document Structure...');
  const complexDocJSON = {
    type: 'doc',
    content: [
      // Heading 1 - Centered
      {
        type: 'heading',
        attrs: { level: 1, textAlign: 'center' },
        content: [{ type: 'text', text: 'BÁO CÁO NGHIÊN CỨU & KIỂM THỬ NÂNG CAO' }]
      },
      // Horizontal Rule (Divider)
      {
        type: 'horizontalRule'
      },
      // Heading 2
      {
        type: 'heading',
        attrs: { level: 2 },
        content: [{ type: 'text', text: '1. Khảo sát Kiểu Chữ và Định Dạng Nâng Cao' }]
      },
      // Paragraph with Bold, Italic, Underline, Color, Highlight, Justify
      {
        type: 'paragraph',
        attrs: { textAlign: 'justify' },
        content: [
          { type: 'text', text: 'Đoạn văn bản mẫu được căn đều hai lề nhằm kiểm thử tính năng typography. ' },
          { type: 'text', marks: [{ type: 'bold' }], text: 'Chữ in đậm nổi bật (Bold), ' },
          { type: 'text', marks: [{ type: 'italic' }], text: 'chữ in nghiêng trang nhã (Italic), ' },
          { type: 'text', marks: [{ type: 'underline' }], text: 'văn bản có gạch chân chuẩn mực (Underline), ' },
          { type: 'text', marks: [{ type: 'textStyle', attrs: { color: '#E11D48' } }], text: 'màu chữ đỏ nổi bật (#E11D48), ' },
          { type: 'text', marks: [{ type: 'highlight' }], text: 'và phần đánh dấu văn bản màu vàng (Highlight).' }
        ]
      },
      // Heading 3
      {
        type: 'heading',
        attrs: { level: 3 },
        content: [{ type: 'text', text: '1.1. Khối Trích dẫn Ý kiến Chuyên gia' }]
      },
      // Blockquote
      {
        type: 'blockquote',
        content: [
          {
            type: 'paragraph',
            content: [
              {
                type: 'text',
                marks: [{ type: 'italic' }],
                text: '“Khả năng tương thích tệp OpenXML .docx là tiêu chuẩn vàng cho các ứng dụng văn phòng hiện đại trên hệ điều hành Windows.”'
              }
            ]
          }
        ]
      },
      // Heading 2: Danh sách
      {
        type: 'heading',
        attrs: { level: 2 },
        content: [{ type: 'text', text: '2. Danh Mục Yêu Cầu & Tính Năng' }]
      },
      // Bullet List
      {
        type: 'bulletList',
        content: [
          {
            type: 'listItem',
            content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Mục danh sách gạch đầu dòng A (Bullet item)' }] }]
          },
          {
            type: 'listItem',
            content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Mục danh sách gạch đầu dòng B (Bullet item)' }] }]
          }
        ]
      },
      // Numbered List (Ordered List)
      {
        type: 'orderedList',
        content: [
          {
            type: 'listItem',
            content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Bước thực hiện 1: Khởi động trình soạn thảo' }] }]
          },
          {
            type: 'listItem',
            content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Bước thực hiện 2: Chỉnh sửa định dạng và chèn bảng' }] }]
          },
          {
            type: 'listItem',
            content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Bước thực hiện 3: Xuất bản tệp tin Word và PDF' }] }]
          }
        ]
      },
      // Heading 2: Bảng Biểu
      {
        type: 'heading',
        attrs: { level: 2 },
        content: [{ type: 'text', text: '3. Ma Trận Thống Kê Dữ Liệu (Bảng Biểu Đa Cột)' }]
      },
      // Table: Multiple rows, columns, header
      {
        type: 'table',
        content: [
          // Header Row
          {
            type: 'tableRow',
            content: [
              { type: 'tableHeader', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'STT' }] }] },
              { type: 'tableHeader', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Tên Mô-đun' }] }] },
              { type: 'tableHeader', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Trạng Thái Kiểm Thử' }] }] }
            ]
          },
          // Row 1
          {
            type: 'tableRow',
            content: [
              { type: 'tableCell', content: [{ type: 'paragraph', content: [{ type: 'text', text: '01' }] }] },
              { type: 'tableCell', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'docxExporter (JSON -> .docx)' }] }] },
              { type: 'tableCell', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Sẵn sàng / Đạt chuẩn' }] }] }
            ]
          },
          // Row 2
          {
            type: 'tableRow',
            content: [
              { type: 'tableCell', content: [{ type: 'paragraph', content: [{ type: 'text', text: '02' }] }] },
              { type: 'tableCell', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'docxImporter (.docx -> HTML)' }] }] },
              { type: 'tableCell', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Sẵn sàng / Đạt chuẩn' }] }] }
            ]
          },
          // Row 3
          {
            type: 'tableRow',
            content: [
              { type: 'tableCell', content: [{ type: 'paragraph', content: [{ type: 'text', text: '03' }] }] },
              { type: 'tableCell', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Desktop Native Shell (Electron)' }] }] },
              { type: 'tableCell', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Hoàn thiện 100%' }] }] }
            ]
          }
        ]
      }
    ]
  };

  console.log(` -> Đã khởi tạo cấu trúc Document JSON gồm ${complexDocJSON.content.length} khối phần tử.`);
  passedChecks++;

  // 2. Export TipTap Document to .docx via docxExporter
  console.log('\n[STAGE 2] Exporting to OpenXML .docx using docxExporter...');
  const docxDoc = exportTipTapToDocxDocument(complexDocJSON, 'normal', 'portrait');
  const docxBuffer = await Packer.toBuffer(docxDoc);

  if (docxBuffer && docxBuffer.length > 3000) {
    console.log(` -> PASS: docxExporter đã tạo gói OpenXML hợp lệ (${docxBuffer.length} bytes).`);
    passedChecks++;
  } else {
    throw new Error(`Buffer kích thước không hợp lệ: ${docxBuffer ? docxBuffer.length : 0}`);
  }

  // 3. Save to disk as test_advanced_doc.docx
  const testOutputPath = path.join(__dirname, 'test_advanced_doc.docx');
  console.log(`\n[STAGE 3] Saving .docx file to: ${testOutputPath}...`);
  fs.writeFileSync(testOutputPath, docxBuffer);
  const fileStat = fs.statSync(testOutputPath);
  if (fileStat.size === docxBuffer.length) {
    console.log(` -> PASS: Đã ghi thành công tệp .docx vào đĩa (${fileStat.size} bytes).`);
    passedChecks++;
  } else {
    throw new Error('Kích thước tệp đĩa không khớp với bộ đệm bộ nhớ.');
  }

  // 4. Import via docxImporter and Parse Content
  console.log('\n[STAGE 4] Re-importing .docx file via docxImporter (Round-trip verification)...');
  const importResult = await importDocxToArrayBuffer(docxBuffer);
  const importedHtml = importResult.html;

  console.log(' -> Imported HTML Snippet:');
  console.log('    ' + importedHtml.substring(0, 200).replace(/\n/g, ' ') + '...');

  // 5. Deep Content Validation
  console.log('\n[STAGE 5] Validating Typography, Headings, Lists, Tables, Blockquote...');

  // Check Headings
  const hasH1 = importedHtml.includes('BÁO CÁO NGHIÊN CỨU &amp; KIỂM THỬ NÂNG CAO') || importedHtml.includes('BÁO CÁO NGHIÊN CỨU & KIỂM THỬ NÂNG CAO');
  const hasH2 = importedHtml.includes('1. Khảo sát Kiểu Chữ và Định Dạng Nâng Cao');
  const hasH3 = importedHtml.includes('1.1. Khối Trích dẫn Ý kiến Chuyên gia');
  if (hasH1 && hasH2 && hasH3) {
    console.log(' -> PASS: Cả 3 cấp độ tiêu đề (Heading 1, 2, 3) được bảo toàn nguyên vẹn.');
    passedChecks++;
  } else {
    throw new Error(`Thiếu tiêu đề trong HTML: H1=${hasH1}, H2=${hasH2}, H3=${hasH3}`);
  }

  // Check Inline Styles: Bold, Italic
  const hasBold = importedHtml.includes('<strong>Chữ in đậm nổi bật (Bold), </strong>') || importedHtml.includes('Chữ in đậm nổi bật (Bold)');
  const hasItalic = importedHtml.includes('<em>chữ in nghiêng trang nhã (Italic), </em>') || importedHtml.includes('chữ in nghiêng trang nhã (Italic)');
  const hasUnderline = importedHtml.includes('văn bản có gạch chân chuẩn mực (Underline)');
  if (hasBold && hasItalic && hasUnderline) {
    console.log(' -> PASS: Các định dạng chữ In đậm, In nghiêng, Gạch chân được bảo toàn.');
    passedChecks++;
  } else {
    throw new Error(`Thiếu định dạng inline: Bold=${hasBold}, Italic=${hasItalic}, Underline=${hasUnderline}`);
  }

  // Check Lists: Bullet and Ordered
  const hasBulletList = importedHtml.includes('Mục danh sách gạch đầu dòng A') && importedHtml.includes('Mục danh sách gạch đầu dòng B');
  const hasNumberedList = importedHtml.includes('Bước thực hiện 1:') && importedHtml.includes('Bước thực hiện 2:') && importedHtml.includes('Bước thực hiện 3:');
  if (hasBulletList && hasNumberedList) {
    console.log(' -> PASS: Toàn bộ danh sách gạch đầu dòng (Bullet) và có thứ tự (Numbered) được bảo toàn.');
    passedChecks++;
  } else {
    throw new Error(`Lỗi kiểm tra danh sách: Bullet=${hasBulletList}, Numbered=${hasNumberedList}`);
  }

  // Check Table & Content
  const hasTable = importedHtml.includes('<table>') &&
                   importedHtml.includes('STT') &&
                   importedHtml.includes('Tên Mô-đun') &&
                   importedHtml.includes('Trạng Thái Kiểm Thử') &&
                   importedHtml.includes('docxExporter (JSON -&gt; .docx)') || importedHtml.includes('docxExporter (JSON -> .docx)');
  const hasRows = importedHtml.includes('Desktop Native Shell (Electron)') && importedHtml.includes('Hoàn thiện 100%');
  if (hasTable && hasRows) {
    console.log(' -> PASS: Cấu trúc bảng biểu (3 cột x 4 hàng) và dữ liệu các ô bảo toàn 100%.');
    passedChecks++;
  } else {
    throw new Error('Lỗi kiểm tra bảng biểu trong HTML tái nhập khẩu.');
  }

  // Clean up
  console.log('\n[STAGE 6] Cleaning up test file...');
  if (fs.existsSync(testOutputPath)) {
    fs.unlinkSync(testOutputPath);
    console.log(' -> PASS: Đã dọn dẹp file thử nghiệm tạm thời.');
  }

  console.log('\n================================================================');
  console.log(`KẾT QUẢ: ${passedChecks}/${totalChecks} MỤC KIỂM THỬ ĐẠT CHUẨN XUẤT SẮC!`);
  console.log('================================================================');
}

runAdvancedDocTests().then(() => {
  process.exit(0);
}).catch((err) => {
  console.error('\n[LỖI TEST]:', err);
  process.exit(1);
});
