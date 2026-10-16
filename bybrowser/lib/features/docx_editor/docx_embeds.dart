import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'docx/docx_model.dart';

/// Ảnh / đối tượng inline giữ nguyên từ file (chỉ xem).
class DocxImageEmbedBuilder extends EmbedBuilder {
  const DocxImageEmbedBuilder(this.raws);

  final Map<String, InlineRaw> raws;

  @override
  String get key => kEmbedImage;

  @override
  bool get expanded => false;

  @override
  String toPlainText(Embed node) => '[${raws[node.value.data as String]?.label ?? 'Đối tượng'}]';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final raw = raws[embedContext.node.value.data as String];
    final scheme = Theme.of(context).colorScheme;
    if (raw?.imageBytes != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: Image.memory(
          raw!.imageBytes!,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _chip(context, raw.label, Icons.broken_image_outlined),
        ),
      );
    }
    return _chip(context, raw?.label ?? 'Đối tượng', Icons.widgets_outlined, color: scheme.tertiaryContainer);
  }

  static Widget _chip(BuildContext context, String label, IconData icon, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Bảng hoặc phần tử cấp body không sửa được: hiển thị chỉ đọc, giữ nguyên khi lưu.
class DocxBlockEmbedBuilder extends EmbedBuilder {
  const DocxBlockEmbedBuilder(this.raws);

  final Map<String, BlockRaw> raws;

  @override
  String get key => kEmbedBlock;

  @override
  String toPlainText(Embed node) {
    final raw = raws[node.value.data as String];
    if (raw?.tableRows == null) return '[Đối tượng]';
    return raw!.tableRows!.map((r) => r.join('\t')).join('\n');
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final raw = raws[embedContext.node.value.data as String];
    final scheme = Theme.of(context).colorScheme;
    final rows = raw?.tableRows;
    if (rows == null || rows.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('Thành phần không hỗ trợ sửa (được giữ nguyên khi lưu)',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      );
    }
    final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: scheme.outlineVariant),
              children: [
                for (final r in rows)
                  TableRow(
                    children: [
                      for (var i = 0; i < cols; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Text(i < r.length ? r[i] : '', style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Text('Bảng: chỉ xem, giữ nguyên khi lưu',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
