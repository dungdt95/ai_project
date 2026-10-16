import 'package:flutter/material.dart';

import '../../core/models/document_ref.dart';
import '../../core/recent/recent_files.dart';
import '../../core/saf/saf_service.dart';
import '../../shared/dialogs.dart';
import 'document_editor.dart';

/// Khung chung cho mọi màn hình sửa file: AppBar với tên file, dấu `*` khi
/// chưa lưu, nút Lưu / Lưu thành…, chặn nút Back khi còn thay đổi.
class EditorShell extends StatefulWidget {
  const EditorShell({
    super.key,
    required this.document,
    required this.controller,
    required this.recents,
    required this.child,
    this.actions = const [],
    this.bottomBar,
    this.menuItems = const [],
    this.onMenuSelected,
    this.switchViewLabel,
    this.onSwitchView,
  });

  final DocumentRef document;
  final DocumentEditorController controller;
  final RecentFilesStore recents;
  final Widget child;

  /// Nút bổ sung cho từng loại editor (tìm kiếm, undo…).
  final List<Widget> actions;
  final Widget? bottomBar;

  /// Mục menu thêm vào menu ⋮ (sau "Lưu thành…"); giá trị trả về qua [onMenuSelected].
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String>? onMenuSelected;

  /// Mục menu mở lại file bằng trình sửa khác (ví dụ CSV: bảng ↔ văn bản).
  /// Hỏi lưu nếu còn thay đổi, rồi gọi [onSwitchView] với file hiện tại
  /// (có thể đã đổi sau "Lưu thành…").
  final String? switchViewLabel;
  final ValueChanged<DocumentRef>? onSwitchView;

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  late DocumentRef _doc = widget.document;
  bool _saving = false;

  Future<bool> _save() async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      final bytes = await widget.controller.encode();
      await SafService.writeBytes(_doc.uri, bytes);
      widget.controller.markSaved();
      _doc = _doc.copyWith(size: bytes.length);
      await widget.recents.touch(_doc);
      if (mounted) showSnack(context, 'Đã lưu "${_doc.name}"');
      return true;
    } on SafException catch (e) {
      if (mounted) await showErrorDialog(context, 'Không lưu được', e.message);
      return false;
    } catch (e) {
      if (mounted) await showErrorDialog(context, 'Không lưu được', '$e');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAs() async {
    DocumentRef? target;
    try {
      target = await SafService.createDocument(
        suggestedName: _doc.name,
        mime: widget.controller.saveMime,
      );
    } on SafException catch (e) {
      if (mounted) await showErrorDialog(context, 'Không tạo được file', e.message);
      return;
    }
    if (target == null) return;
    setState(() => _doc = target!);
    await _save();
  }

  Future<void> _switchView() async {
    if (widget.controller.isDirty) {
      final action = await showUnsavedDialog(context, _doc.name);
      if (action == UnsavedAction.cancel) return;
      if (action == UnsavedAction.save && !await _save()) return;
    }
    if (mounted) widget.onSwitchView?.call(_doc);
  }

  Future<void> _onBack() async {
    if (!widget.controller.isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final action = await showUnsavedDialog(context, _doc.name);
    switch (action) {
      case UnsavedAction.cancel:
        return;
      case UnsavedAction.discard:
        if (mounted) Navigator.of(context).pop();
      case UnsavedAction.save:
        if (await _save() && mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final dirty = widget.controller.isDirty;
        return PopScope(
          canPop: !dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBack();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: _onBack),
              title: Text(
                dirty ? '${_doc.name} *' : _doc.name,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                ...widget.actions,
                IconButton(
                  tooltip: 'Lưu (ghi đè file gốc)',
                  icon: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  onPressed: dirty && !_saving ? _save : null,
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'saveAs') {
                      _saveAs();
                    } else if (v == 'switchView') {
                      _switchView();
                    } else {
                      widget.onMenuSelected?.call(v);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'saveAs',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.save_as_outlined),
                        title: Text('Lưu thành…'),
                      ),
                    ),
                    if (widget.switchViewLabel != null)
                      PopupMenuItem(
                        value: 'switchView',
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.swap_horiz),
                          title: Text(widget.switchViewLabel!),
                        ),
                      ),
                    if (widget.menuItems.isNotEmpty) const PopupMenuDivider(),
                    ...widget.menuItems,
                  ],
                ),
              ],
            ),
            // bottomBar nằm trong body (không dùng bottomNavigationBar) để luôn
            // hiển thị phía trên bàn phím.
            body: widget.bottomBar == null
                ? widget.child
                : Column(
                    children: [
                      Expanded(child: widget.child),
                      widget.bottomBar!,
                    ],
                  ),
          ),
        );
      },
    );
  }
}
