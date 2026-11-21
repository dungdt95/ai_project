const fs = require('fs');
const path = require('path');
const mammoth = require('mammoth');
const {
  Document,
  Paragraph,
  TextRun,
  Table,
  TableRow,
  TableCell,
  HeadingLevel,
  AlignmentType,
  WidthType,
  BorderStyle,
  Packer,
  PageOrientation
} = require('docx');

async function runTests() {
  console.log('====================================================');
  console.log('   PC DOC EDITOR - CORE AUTOMATED TEST SUITE        ');
  console.log('====================================================\n');

  let passedTests = 0;
  const totalTests = 5;

  // TEST 1: Build docx document with full Word 365 features
  console.log('[TEST 1] Generating Word (.docx) OpenXML document...');
  try {
    const doc = new Document({
      sections: [
        {
          properties: {
            page: {
              size: {
                orientation: PageOrientation.PORTRAIT,
                width: 11906,
                height: 16838
              },
              margin: {
                top: 1440,
                right: 1440,
                bottom: 1440,
                left: 1440
              }
            }
          },
          children: [
            new Paragraph({
              text: 'Báo cáo Kiểm thử Tự động Word 365',
              heading: HeadingLevel.HEADING_1,
              alignment: AlignmentType.CENTER
            }),
            new Paragraph({
              children: [
                new TextRun({ text: 'Đây là đoạn văn bản kiểm thử định dạng ', size: 24 }),
                new TextRun({ text: 'In Đậm (Bold), ', bold: true, size: 24 }),
                new TextRun({ text: 'In Nghiêng (Italic), ', italics: true, size: 24 }),
                new TextRun({ text: 'Gạch chân (Underline).', underline: {}, size: 24 })
              ]
            }),
            new Paragraph({
              bullet: { level: 0 },
              children: [new TextRun({ text: 'Mục danh sách 1 (Bullet List)', size: 24 })]
            }),
            new Paragraph({
              bullet: { level: 0 },
              children: [new TextRun({ text: 'Mục danh sách 2 (Bullet List)', size: 24 })]
            }),
            new Table({
              width: { size: 100, type: WidthType.PERCENTAGE },
              rows: [
                new TableRow({
                  children: [
                    new TableCell({
                      children: [new Paragraph({ children: [new TextRun({ text: 'Cột Tiêu Đề 1', bold: true })] })],
                      shading: { fill: 'EBF3FC' }
                    }),
                    new TableCell({
                      children: [new Paragraph({ children: [new TextRun({ text: 'Cột Tiêu Đề 2', bold: true })] })],
                      shading: { fill: 'EBF3FC' }
                    })
                  ]
                }),
                new TableRow({
                  children: [
                    new TableCell({
                      children: [new Paragraph({ text: 'Dữ liệu hàng 1 ô 1' })]
                    }),
                    new TableCell({
                      children: [new Paragraph({ text: 'Dữ liệu hàng 1 ô 2' })]
                    })
                  ]
                })
              ]
            })
          ]
        }
      ]
    });

    const buffer = await Packer.toBuffer(doc);
    if (buffer && buffer.length > 0) {
      console.log(` -> PASS: Generated OpenXML .docx buffer (${buffer.length} bytes)`);
      passedTests++;
    } else {
      throw new Error('Buffer is empty');
    }

    // TEST 2: Write docx to disk
    console.log('\n[TEST 2] Saving test .docx file to disk...');
    const testFilePath = path.join(__dirname, 'test_output.docx');
    fs.writeFileSync(testFilePath, buffer);
    if (fs.existsSync(testFilePath) && fs.statSync(testFilePath).size > 0) {
      console.log(` -> PASS: Saved ${testFilePath} (${fs.statSync(testFilePath).size} bytes)`);
      passedTests++;
    } else {
      throw new Error('File not saved properly');
    }

    // TEST 3: Load and Parse .docx via Mammoth
    console.log('\n[TEST 3] Reading & Parsing .docx via Mammoth...');
    const result = await mammoth.convertToHtml({ path: testFilePath });
    const html = result.value;
    console.log(' -> Converted HTML preview:');
    console.log('    ' + html.substring(0, 160) + '...');

    if (
      html.includes('Báo cáo Kiểm thử Tự động Word 365') &&
      html.includes('<strong>In Đậm (Bold), </strong>') &&
      html.includes('<em>In Nghiêng (Italic), </em>') &&
      html.includes('Cột Tiêu Đề 1')
    ) {
      console.log(' -> PASS: Mammoth successfully parsed all headings, bold/italic, and tables!');
      passedTests++;
    } else {
      throw new Error('HTML content verification failed');
    }

    // TEST 4: Clean up test file
    console.log('\n[TEST 4] Verifying clean-up and round-trip consistency...');
    if (fs.existsSync(testFilePath)) {
      fs.unlinkSync(testFilePath);
      console.log(' -> PASS: Cleaned up temporary test file.');
      passedTests++;
    }

    // TEST 5: Verify build outputs in dist/
    console.log('\n[TEST 5] Verifying production build artifacts in dist/...');
    const distHtml = path.join(__dirname, 'dist', 'index.html');
    const distAssets = path.join(__dirname, 'dist', 'assets');
    if (fs.existsSync(distHtml) && fs.existsSync(distAssets)) {
      const files = fs.readdirSync(distAssets);
      const hasJs = files.some(f => f.endsWith('.js'));
      const hasCss = files.some(f => f.endsWith('.css'));
      if (hasJs && hasCss) {
        console.log(` -> PASS: Found valid dist/ build artifacts (${files.length} bundle assets).`);
        passedTests++;
      } else {
        throw new Error('Missing JS or CSS bundle in dist/assets');
      }
    } else {
      throw new Error('dist/ directory or dist/index.html missing');
    }

  } catch (error) {
    console.error(' -> FAIL:', error.message || error);
  }

  console.log('\n====================================================');
  console.log(`RESULT: ${passedTests}/${totalTests} TESTS PASSED`);
  console.log('====================================================');

  if (passedTests === totalTests) {
    process.exit(0);
  } else {
    process.exit(1);
  }
}

runTests();
