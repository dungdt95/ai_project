import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import 'excel_controller.dart';
import 'xlsx/xlsx_model.dart';

/// Lưới bảng tính: cuộn 2 chiều, ghim hàng tiêu đề (A, B, C…) và cột số dòng,
/// hỗ trợ ô gộp. Hàng/cột 0 của TableView là tiêu đề; dữ liệu bắt đầu từ 1.
class SheetGrid extends StatelessWidget {
  const SheetGrid({
    super.key,
    required this.controller,
    required this.vertical,
    required this.horizontal,
    required this.onTapCell,
    required this.onDoubleTapCell,
  });

  final ExcelController controller;
  final ScrollController vertical;
  final ScrollController horizontal;
  final void Function(int row, int col) onTapCell;
  final void Function(int row, int col) onDoubleTapCell;

  static const headerWidth = 44.0;
  static const headerHeight = 28.0;
  static const extraRows = 30;
  static const extraCols = 6;

  /// Excel đo độ rộng cột theo số ký tự; quy đổi xấp xỉ sang px.
  static double columnPx(Worksheet ws, int c) {
    final w = ws.columnWidth(c);
    return w <= 0 ? 0 : w * 7.2 + 6;
  }

  /// Chiều cao dòng (point) → px, tối thiểu 26 để dễ chạm.
  static double rowPx(Worksheet ws, int r) {
    final h = ws.rowHeight(r);
    if (h <= 0) return 0;
    return (h * 1.5).clamp(26, 400);
  }

  static int rowCount(Worksheet ws) => (ws.maxRow + 1).clamp(20, 1 << 20) + extraRows;
  static int colCount(Worksheet ws) => (ws.maxCol + 1).clamp(8, 16384) + extraCols;

  @override
  Widget build(BuildContext context) {
    final ws = controller.sheet;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gridLine = scheme.outlineVariant.withValues(alpha: 0.6);
    final selected = controller.selected;

    return TableView.builder(
      verticalDetails: ScrollableDetails.vertical(controller: vertical),
      horizontalDetails: ScrollableDetails.horizontal(controller: horizontal),
      diagonalDragBehavior: DiagonalDragBehavior.free,
      pinnedRowCount: 1,
      pinnedColumnCount: 1,
      rowCount: rowCount(ws) + 1,
      columnCount: colCount(ws) + 1,
      columnBuilder: (i) => TableSpan(
        extent: FixedTableSpanExtent(i == 0 ? headerWidth : columnPx(ws, i - 1)),
      ),
      rowBuilder: (i) => TableSpan(
        extent: FixedTableSpanExtent(i == 0 ? headerHeight : rowPx(ws, i - 1)),
      ),
      cellBuilder: (context, vicinity) {
        final vr = vicinity.row;
        final vc = vicinity.column;
        final headerStyle = theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
        final headerBg = scheme.surfaceContainerHigh;
        final headerActiveBg = scheme.primaryContainer;

        // Góc trên trái
        if (vr == 0 && vc == 0) {
          return TableViewCell(
            child: Container(
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(right: BorderSide(color: gridLine), bottom: BorderSide(color: gridLine)),
              ),
            ),
          );
        }
        // Tiêu đề cột
        if (vr == 0) {
          final c = vc - 1;
          return TableViewCell(
            child: GestureDetector(
              onTap: () => onTapCell(selected.row, c),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c == selected.col ? headerActiveBg : headerBg,
                  border: Border(right: BorderSide(color: gridLine), bottom: BorderSide(color: gridLine)),
                ),
                child: Text(columnLetters(c), style: headerStyle, overflow: TextOverflow.clip),
              ),
            ),
          );
        }
        // Số dòng
        if (vc == 0) {
          final r = vr - 1;
          return TableViewCell(
            child: GestureDetector(
              onTap: () => onTapCell(r, selected.col),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: r == selected.row ? headerActiveBg : headerBg,
                  border: Border(right: BorderSide(color: gridLine), bottom: BorderSide(color: gridLine)),
                ),
                child: Text('${r + 1}', style: headerStyle),
              ),
            ),
          );
        }

        final r = vr - 1;
        final c = vc - 1;
        final merge = ws.mergeAt(r, c);
        final anchorR = merge?.r1 ?? r;
        final anchorC = merge?.c1 ?? c;
        final cell = ws.cellAt(anchorR, anchorC);
        final isSelected = selected.row == anchorR && selected.col == anchorC;
        final text = controller.displayFor(anchorR, anchorC);
        final bold = controller.styles.bold(cell?.styleIndex);
        final align = _alignment(controller.styles.align(cell?.styleIndex), cell, controller);

        return TableViewCell(
          rowMergeStart: merge == null ? null : merge.r1 + 1,
          rowMergeSpan: merge?.rowSpan,
          columnMergeStart: merge == null ? null : merge.c1 + 1,
          columnMergeSpan: merge?.colSpan,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTapCell(anchorR, anchorC),
            onDoubleTap: () => onDoubleTapCell(anchorR, anchorC),
            child: Container(
              alignment: align,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary.withValues(alpha: 0.10) : null,
                border: isSelected
                    ? Border.all(color: scheme.primary, width: 2)
                    : Border(right: BorderSide(color: gridLine), bottom: BorderSide(color: gridLine)),
              ),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: cell?.type == CellType.error ? scheme.error : scheme.onSurface,
                  fontStyle: cell?.formula != null && cell?.type == CellType.empty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Alignment _alignment(String? h, XlsxCell? cell, ExcelController controller) {
    switch (h) {
      case 'center':
      case 'centerContinuous':
        return Alignment.center;
      case 'right':
        return Alignment.centerRight;
      case 'left':
        return Alignment.centerLeft;
    }
    // Mặc định như Excel: số/bool căn phải, text căn trái.
    if (cell != null && controller.alignRight(cell)) {
      return Alignment.centerRight;
    }
    return Alignment.centerLeft;
  }
}
