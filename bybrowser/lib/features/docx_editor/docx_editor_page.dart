import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../core/models/document_ref.dart';
import '../../core/recent/recent_files.dart';
import '../../shared/dialogs.dart';
import '../editor/document_editor.dart';
import '../editor/editor_shell.dart';
import 'docx/docx_model.dart';
import 'docx/docx_writer.dart';
import 'docx_embeds.dart';

class DocxController extends DocumentEditorController {
  DocxController(this.doc)
      : quill = QuillController(
          document: Document.fromDelta(doc.delta),
          selection: const TextSelection.collapsed(offset: 0),
        ) {
    _sub = quill.document.changes.listen((change) {
      if (change.source == ChangeSource.local && !_dirty) {
        _dirty = true;
        notifyListeners();
      }
    });
  }

  final DocxDocument doc;
  final QuillController quill;
  late final StreamSubscription<DocChange> _sub;
  bool _dirty = false;

  @override
  bool get isDirty => _dirty;

  @override
  String get saveMime =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  @override
  Future<Uint8List> encode() async => DocxWriter.write(doc, quill.document.toDelta());

  @override
  void markSaved() {
    _dirty = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    quill.dispose();
    super.dispose();
  }
}

class DocxEditorPage extends StatefulWidget {
  const DocxEditorPage({
    super.key,
    required this.document,
    required this.doc,
    required this.recents,
  });

  final DocumentRef document;
  final DocxDocument doc;
  final RecentFilesStore recents;

  @override
  State<DocxEditorPage> createState() => _DocxEditorPageState();
}

class _DocxEditorPageState extends State<DocxEditorPage> {
  late final DocxController _controller = DocxController(widget.doc);
  final _focus = FocusNode();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.doc.warnings.isNotEmpty) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Lưu ý khi sửa file này'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Nếu bạn lưu, các thành phần sau sẽ bị mất hoặc đổi:'),
                  const SizedBox(height: 8),
                  for (final w in widget.doc.warnings) Text('• $w'),
                ],
              ),
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
            ],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EditorShell(
      document: widget.document,
      controller: _controller,
      recents: widget.recents,
      menuItems: const [
        PopupMenuItem(
          value: 'limits',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.info_outline),
            title: Text('Giới hạn hỗ trợ Word'),
          ),
        ),
      ],
      onMenuSelected: (v) {
        if (v == 'limits') {
          showErrorDialog(
            context,
            'Giới hạn hỗ trợ Word',
            'Sửa được: văn bản, đậm/nghiêng/gạch chân/gạch ngang, màu chữ, nền, cỡ chữ, '
                'heading 1-6, danh sách, căn lề, thụt lề, liên kết.\n\n'
                'Giữ nguyên nhưng chỉ xem: bảng, ảnh, hộp văn bản, biểu đồ, công thức toán, '
                'header/footer, khổ giấy.\n\n'
                'Sẽ mất khi lưu: chú thích cuối trang, bình luận, trường (field) tự động, '
                'theo dõi thay đổi.',
          );
        }
      },
      bottomBar: _Toolbar(controller: _controller.quill),
      child: Container(
        color: theme.colorScheme.surface,
        child: QuillEditor.basic(
          controller: _controller.quill,
          focusNode: _focus,
          scrollController: _scroll,
          config: QuillEditorConfig(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 200),
            autoFocus: false,
            expands: true,
            placeholder: 'Tài liệu trống',
            embedBuilders: [
              DocxImageEmbedBuilder(widget.doc.inlineRaws),
              DocxBlockEmbedBuilder(widget.doc.blockRaws),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh định dạng rút gọn cho mobile: một hàng cuộn ngang, nằm sát bàn phím.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});
  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: QuillSimpleToolbar(
          controller: controller,
          config: const QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            toolbarSize: 44,
            showFontFamily: false,
            showFontSize: true,
            showBoldButton: true,
            showItalicButton: true,
            showUnderLineButton: true,
            showStrikeThrough: true,
            showInlineCode: false,
            showColorButton: true,
            showBackgroundColorButton: true,
            showClearFormat: true,
            showAlignmentButtons: true,
            showJustifyAlignment: true,
            showHeaderStyle: true,
            showListNumbers: true,
            showListBullets: true,
            showListCheck: false,
            showCodeBlock: false,
            showQuote: false,
            showIndent: true,
            showLink: true,
            showUndo: true,
            showRedo: true,
            showDirection: false,
            showSearchButton: true,
            showSubscript: false,
            showSuperscript: false,
            showSmallButton: false,
            showLineHeightButton: false,
            showDividers: false,
          ),
        ),
      ),
    );
  }
}
