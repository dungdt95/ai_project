import 'dart:typed_data';

import 'package:flutter_quill/quill_delta.dart';

/// Namespace chính của WordprocessingML.
const wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const rNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const aNs = 'http://schemas.openxmlformats.org/drawingml/2006/main';

/// Khóa embed tùy chỉnh trong Delta.
const kEmbedImage = 'docximage'; // run chứa ảnh / đối tượng inline, giữ XML thô
const kEmbedBlock = 'docxblock'; // bảng hoặc phần tử cấp body không hỗ trợ, giữ XML thô

/// Khóa thuộc tính ẩn (scope ignore) lưu phần XML dư không ánh xạ được.
const kAttrPPr = 'docxppr'; // id → phần dư của <w:pPr>
const kAttrRPr = 'docxrpr'; // id → phần dư của <w:rPr>
const kAttrNumId = 'docxnumid'; // numId gốc của đoạn danh sách

/// Một phần tử con của pPr/rPr được giữ nguyên dạng chuỗi XML.
class RawChild {
  const RawChild(this.name, this.xml);
  final String name; // local name, ví dụ "spacing"
  final String xml;
}

/// Run chứa đối tượng không phải văn bản (ảnh, text box, công thức…).
class InlineRaw {
  const InlineRaw({required this.xml, this.imageBytes, required this.label});

  /// XML nguyên bản của `<w:r>` (hoặc phần tử inline khác) để ghi lại.
  final String xml;
  final Uint8List? imageBytes;

  /// Nhãn hiển thị khi không có ảnh ("Hộp văn bản", "Công thức"…).
  final String label;
}

/// Phần tử cấp body không sửa được trong app (bảng, SDT lạ…), giữ nguyên XML.
class BlockRaw {
  const BlockRaw({required this.xml, required this.kind, this.tableRows});

  final String xml;
  final String kind; // 'table' | 'other'

  /// Nội dung text của bảng để hiển thị (chỉ đọc).
  final List<List<String>>? tableRows;
}

/// Kết quả đọc .docx: Delta cho flutter_quill + mọi thứ cần để ghi lại.
class DocxDocument {
  DocxDocument({
    required this.delta,
    required this.parts,
    required this.documentXml,
    required this.pprs,
    required this.rprs,
    required this.inlineRaws,
    required this.blockRaws,
    required this.headingStyleIds,
    required this.numIdIsBullet,
    required this.hasHyperlinkStyle,
    required this.warnings,
  });

  final Delta delta;

  /// Toàn bộ zip (đường dẫn → bytes).
  final Map<String, List<int>> parts;
  final String documentXml;

  final Map<String, List<RawChild>> pprs;
  final Map<String, List<RawChild>> rprs;
  final Map<String, InlineRaw> inlineRaws;
  final Map<String, BlockRaw> blockRaws;

  /// cấp heading (1..6) → styleId trong styles.xml (ví dụ 1 → "Heading1").
  final Map<int, String> headingStyleIds;

  /// numId → true nếu là bullet, false nếu đánh số.
  final Map<int, bool> numIdIsBullet;
  final bool hasHyperlinkStyle;

  /// Thành phần bị bỏ khi đọc (sẽ mất khi lưu): footnote, comment, field…
  final List<String> warnings;
}
