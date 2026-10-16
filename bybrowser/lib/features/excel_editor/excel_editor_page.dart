import 'package:flutter/material.dart';

import '../../core/models/document_ref.dart';
import '../../core/recent/recent_files.dart';
import '../../shared/dialogs.dart';
import '../editor/editor_shell.dart';
import '../home/open_document.dart';
import 'csv/csv_codec.dart';
import 'csv/csv_controller.dart';
import 'excel_controller.dart';
import 'sheet_grid.dart';
import 'xlsx/xlsx_model.dart';

class ExcelEditorPage extends StatefulWidget {
  const ExcelEditorPage({
    super.key,
    required this.document,
    required this.controller,
    required this.recents,
  });

  final DocumentRef document;

  /// [ExcelController] cho .xlsx, [CsvController] cho .csv/.tsv. Trang sở hữu
  /// và dispose controller.
  final ExcelController controller;
  final RecentFilesStore recents;

  @override
  State<ExcelEditorPage> createState() => _ExcelEditorPageState();
}

class _ExcelEditorPageState extends State<ExcelEditorPage> {
  late final ExcelController _controller = widget.controller;

  /// Khác null khi đang mở file CSV/TSV.
  late final CsvController? _csv =
      _controller is CsvController ? _controller : null;

  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _searchInput = TextEditingController();
  bool _searching = false;

  /// Ô mà thanh công thức đang hiển thị (để commit khi đổi ô).
  CellPos _editing = const CellPos(0, 0);
  int _seenMutation = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _syncInput();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final csv = _csv;
      if (csv == null) {
        showSnack(
          context,
          'Công thức được giữ nguyên nhưng không tính lại trong app; Excel sẽ tính khi mở file.',
        );
      } else if (csv.hadMalformedBytes) {
        showSnack(
          context,
          'File không phải UTF-8 hợp lệ, đang hiển thị theo Latin-1. Lưu có thể làm mất ký tự.',
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    _input.dispose();
    _inputFocus.dispose();
    _searchInput.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.selected != _editing) {
      // Đổi ô: ghi nội dung thanh công thức vào ô cũ trước, rồi nạp ô mới.
      // Cập nhật _editing trước khi setCellInput để tránh gọi lại đệ quy
      // (setCellInput cũng notifyListeners).
      final old = _editing;
      final text = _input.text;
      _editing = _controller.selected;
      _controller.setCellInput(old.row, old.col, text);
      _input.text = _controller.inputFor(_editing.row, _editing.col);
    } else if (_controller.mutation != _seenMutation) {
      // Chèn/xóa dòng cột, undo/redo, đổi sheet: nội dung ô đang chọn có thể
      // đã khác → nạp lại thanh công thức (bỏ nội dung đang gõ dở).
      _input.text = _controller.inputFor(_editing.row, _editing.col);
    }
    _seenMutation = _controller.mutation;
    setState(() {});
  }

  void _syncInput() {
    _editing = _controller.selected;
    _input.text = _controller.inputFor(_editing.row, _editing.col);
  }

  /// Ghi nội dung thanh công thức vào ô đang sửa (nếu có thay đổi).
  void _commitInput({required bool moveDown}) {
    final changed = _controller.setCellInput(
      _editing.row,
      _editing.col,
      _input.text,
    );
    if (moveDown) {
      _controller.select(_editing.row + 1, _editing.col);
      _scrollTo(_controller.selected);
    } else if (changed) {
      setState(() {});
    }
  }

  void _scrollTo(CellPos pos) {
    final ws = _controller.sheet;
    var y = 0.0;
    for (var r = 0; r < pos.row; r++) {
      y += SheetGrid.rowPx(ws, r);
    }
    var x = 0.0;
    for (var c = 0; c < pos.col; c++) {
      x += SheetGrid.columnPx(ws, c);
    }
    if (!_vertical.hasClients || !_horizontal.hasClients) return;
    final vh = _vertical.position.viewportDimension - SheetGrid.headerHeight;
    final vw = _horizontal.position.viewportDimension - SheetGrid.headerWidth;
    final rowH = SheetGrid.rowPx(ws, pos.row);
    final colW = SheetGrid.columnPx(ws, pos.col);
    final vy = _vertical.offset;
    if (y < vy) {
      _vertical.jumpTo(y);
    } else if (y + rowH > vy + vh) {
      _vertical.jumpTo(
        (y + rowH - vh).clamp(0, _vertical.position.maxScrollExtent),
      );
    }
    final vx = _horizontal.offset;
    if (x < vx) {
      _horizontal.jumpTo(x);
    } else if (x + colW > vx + vw) {
      _horizontal.jumpTo(
        (x + colW - vw).clamp(0, _horizontal.position.maxScrollExtent),
      );
    }
  }

  void _find({bool backward = false}) {
    final pos = _controller.findNext(_searchInput.text, backward: backward);
    if (pos == null) {
      showSnack(context, 'Không tìm thấy "${_searchInput.text}"');
      return;
    }
    _controller.select(pos.row, pos.col);
    _scrollTo(pos);
  }

  void _onMenu(String v) {
    final sel = _controller.selected;
    switch (v) {
      case 'rowAbove':
        _controller.insertRow(sel.row);
      case 'rowBelow':
        _controller.insertRow(sel.row + 1);
        _controller.select(sel.row + 1, sel.col);
      case 'rowDelete':
        _controller.deleteRow(sel.row);
      case 'colLeft':
        _controller.insertColumn(sel.col);
      case 'colRight':
        _controller.insertColumn(sel.col + 1);
        _controller.select(sel.row, sel.col + 1);
      case 'colDelete':
        _controller.deleteColumn(sel.col);
      case 'delimiter':
        _pickDelimiter();
    }
  }

  /// Đọc lại CSV với dấu phân cách khác (khi tự nhận diện sai).
  Future<void> _pickDelimiter() async {
    final csv = _csv!;
    if (csv.isDirty) {
      showSnack(
        context,
        'Hãy lưu hoặc hoàn tác các thay đổi trước khi đổi dấu phân cách.',
      );
      return;
    }
    final current = csv.format.delimiter;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Dấu phân cách'),
        children: [
          for (final d in kCsvDelimiters)
            ListTile(
              leading: Icon(
                d == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(delimiterLabel(d)),
              onTap: () => Navigator.pop(context, d),
            ),
        ],
      ),
    );
    if (picked == null || picked == current || !mounted) return;
    csv.changeDelimiter(picked);
    showSnack(
      context,
      'Đã đọc lại với ${delimiterLabel(picked).toLowerCase()}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sel = _controller.selected;
    final ref = cellRef(sel.row, sel.col);
    return EditorShell(
      document: widget.document,
      controller: _controller,
      recents: widget.recents,
      actions: [
        IconButton(
          tooltip: 'Tìm trong sheet',
          icon: Icon(_searching ? Icons.search_off : Icons.search),
          onPressed: () => setState(() => _searching = !_searching),
        ),
      ],
      menuItems: [
        _item(
          'rowAbove',
          Icons.arrow_upward,
          'Chèn dòng phía trên (${sel.row + 1})',
        ),
        _item('rowBelow', Icons.arrow_downward, 'Chèn dòng phía dưới'),
        _item(
          'rowDelete',
          Icons.delete_sweep_outlined,
          'Xóa dòng ${sel.row + 1}',
        ),
        const PopupMenuDivider(),
        _item(
          'colLeft',
          Icons.arrow_back,
          'Chèn cột bên trái (${columnLetters(sel.col)})',
        ),
        _item('colRight', Icons.arrow_forward, 'Chèn cột bên phải'),
        _item(
          'colDelete',
          Icons.delete_outline,
          'Xóa cột ${columnLetters(sel.col)}',
        ),
        if (_csv != null) ...[
          const PopupMenuDivider(),
          _item('delimiter', Icons.view_column_outlined, 'Đổi dấu phân cách…'),
        ],
      ],
      onMenuSelected: _onMenu,
      switchViewLabel: _csv == null ? null : 'Mở dạng văn bản',
      onSwitchView: (doc) => openDocument(
        context,
        doc,
        widget.recents,
        as: DocumentKind.text,
        replace: true,
      ),
      bottomBar: _SheetTabs(controller: _controller),
      child: Column(
        children: [
          _formulaBar(ref),
          if (_searching) _searchBar(),
          Expanded(
            child: SheetGrid(
              controller: _controller,
              vertical: _vertical,
              horizontal: _horizontal,
              onTapCell: (r, c) {
                _controller.select(r, c);
              },
              onDoubleTapCell: (r, c) {
                _controller.select(r, c);
                _inputFocus.requestFocus();
                _input.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _input.text.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: ListTile(dense: true, leading: Icon(icon), title: Text(label)),
      );

  Widget _formulaBar(String ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 52),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ref,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _inputFocus,
                style: const TextStyle(fontSize: 14),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _commitInput(moveDown: true),
                decoration: InputDecoration(
                  hintText: _csv == null
                      ? 'Nhập giá trị hoặc =công thức'
                      : 'Nhập giá trị',
                  isDense: true,
                  filled: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Xác nhận',
              icon: const Icon(Icons.check),
              onPressed: () {
                _commitInput(moveDown: false);
                _inputFocus.unfocus();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchInput,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                onSubmitted: (_) => _find(),
                decoration: const InputDecoration(
                  hintText: 'Tìm trong sheet',
                  isDense: true,
                  filled: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              tooltip: 'Trước',
              visualDensity: VisualDensity.compact,
              onPressed: () => _find(backward: true),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              tooltip: 'Sau',
              visualDensity: VisualDensity.compact,
              onPressed: _find,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Đóng',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _searching = false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thanh dưới: tab chọn sheet + undo/redo.
class _SheetTabs extends StatelessWidget {
  const _SheetTabs({required this.controller});
  final ExcelController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              if (controller case final CsvController csv)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      [
                        csv.format.delimiter == '\t' ? 'TSV' : 'CSV',
                        delimiterLabel(csv.format.delimiter),
                        csv.format.encoding.label,
                        csv.format.lineEnding.label,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    itemCount: controller.workbook.sheets.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final ws = controller.workbook.sheets[i];
                      final active = i == controller.sheetIndex;
                      return ChoiceChip(
                        label: Text(ws.unsaved ? '${ws.name} *' : ws.name),
                        selected: active,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => controller.selectSheet(i),
                      );
                    },
                  ),
                ),
              IconButton(
                tooltip: 'Hoàn tác',
                icon: const Icon(Icons.undo, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: controller.canUndo ? controller.undo : null,
              ),
              IconButton(
                tooltip: 'Làm lại',
                icon: const Icon(Icons.redo, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: controller.canRedo ? controller.redo : null,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
