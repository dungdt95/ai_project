import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/github.dart';

import '../../core/encoding/text_codec.dart';
import '../../core/models/document_ref.dart';
import '../../core/recent/recent_files.dart';
import '../../shared/dialogs.dart';
import '../editor/document_editor.dart';
import '../editor/editor_shell.dart';
import '../home/open_document.dart';
import 'find_panel.dart';
import 'languages.dart';
import 'selection_toolbar.dart';

/// Trên ngưỡng này file chỉ mở để xem (re_editor vẫn hiển thị được nhưng
/// việc so sánh nội dung mỗi lần gõ và lưu lại sẽ chậm).
const kMaxEditableTextBytes = 5 * 1024 * 1024;

/// Trên ngưỡng này tắt highlight cú pháp (re_highlight xử lý cả file một lần,
/// file lớn mất rất lâu và tốn CPU).
const kMaxHighlightBytes = 512 * 1024;

class TextEditorController extends DocumentEditorController {
  TextEditorController(Uint8List bytes)
    : decoded = TextCodec.decode(bytes),
      readOnly = bytes.length > kMaxEditableTextBytes {
    code = CodeLineEditingController.fromText(decoded.text);
    _savedText = decoded.text;
    code.addListener(_onChanged);
  }

  final DecodedText decoded;
  final bool readOnly;
  late final CodeLineEditingController code;
  late String _savedText;
  bool _dirty = false;

  void _onChanged() {
    // Chỉ tính lại khi nội dung đổi (không phải khi chỉ di chuyển con trỏ).
    final d = code.text != _savedText;
    if (d != _dirty) {
      _dirty = d;
    }
    // Luôn notify để status bar cập nhật dòng:cột.
    notifyListeners();
  }

  @override
  bool get isDirty => _dirty;

  @override
  Future<Uint8List> encode() async =>
      TextCodec.encode(code.text, decoded.encoding, decoded.lineEnding);

  @override
  void markSaved() {
    _savedText = code.text;
    _dirty = false;
    notifyListeners();
  }

  @override
  String get saveMime => 'text/plain';

  @override
  void dispose() {
    code.removeListener(_onChanged);
    code.dispose();
    super.dispose();
  }
}

class TextEditorPage extends StatefulWidget {
  const TextEditorPage({
    super.key,
    required this.document,
    required this.bytes,
    required this.recents,
  });

  final DocumentRef document;
  final Uint8List bytes;
  final RecentFilesStore recents;

  @override
  State<TextEditorPage> createState() => _TextEditorPageState();
}

class _TextEditorPageState extends State<TextEditorPage> {
  late final TextEditorController _controller = TextEditorController(
    widget.bytes,
  );
  late final CodeFindController _find = CodeFindController(_controller.code);
  late final EditorSelectionToolbar _toolbar = EditorSelectionToolbar(
    readOnly: _controller.readOnly,
  );
  bool _wordWrap = true;

  /// re_editor tự xin focus khi khởi tạo (kéo bàn phím lên). Khóa focus cho
  /// tới khi người dùng chạm vào vùng soạn thảo.
  final FocusNode _focusNode = FocusNode(canRequestFocus: false);

  @override
  void initState() {
    super.initState();
    // Mã nguồn thường muốn xem không wrap; văn bản thường thì wrap.
    _wordWrap = languageForExtension(widget.document.extension) == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.readOnly) {
        showSnack(
          context,
          'File lớn hơn ${formatFileSize(kMaxEditableTextBytes)} — chỉ xem, không sửa.',
        );
      } else if (_controller.decoded.hadMalformedBytes) {
        showSnack(
          context,
          'File không phải UTF-8 hợp lệ, đang hiển thị theo Latin-1. Lưu có thể làm mất ký tự.',
        );
      }
    });
  }

  @override
  void dispose() {
    _find.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = widget.bytes.length > kMaxHighlightBytes
        ? null
        : languageForExtension(widget.document.extension);
    final codeTheme = CodeHighlightTheme(
      languages: lang == null
          ? {}
          : {lang.id: CodeHighlightThemeMode(mode: lang.mode)},
      theme: isDark ? githubDarkTheme : githubTheme,
    );

    return EditorShell(
      document: widget.document,
      controller: _controller,
      recents: widget.recents,
      actions: [
        IconButton(
          tooltip: 'Tìm kiếm',
          icon: const Icon(Icons.search),
          onPressed: () {
            if (_find.value == null) {
              _find.findMode();
            } else {
              _find.close();
            }
          },
        ),
      ],
      menuItems: [
        CheckedPopupMenuItem(
          value: 'wrap',
          checked: _wordWrap,
          child: const Text('Tự xuống dòng'),
        ),
        if (!_controller.readOnly)
          const PopupMenuItem(
            value: 'replace',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.find_replace),
              title: Text('Tìm và thay thế'),
            ),
          ),
      ],
      switchViewLabel:
          widget.document.kind == DocumentKind.csv ? 'Mở dạng bảng tính' : null,
      onSwitchView: (doc) => openDocument(context, doc, widget.recents,
          as: DocumentKind.csv, replace: true),
      onMenuSelected: (v) {
        switch (v) {
          case 'wrap':
            setState(() => _wordWrap = !_wordWrap);
          case 'replace':
            _find.replaceMode();
        }
      },
      bottomBar: _StatusBar(controller: _controller, lang: lang?.id),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (!_focusNode.canRequestFocus) _focusNode.canRequestFocus = true;
        },
        child: CodeEditor(
          focusNode: _focusNode,
          controller: _controller.code,
          findController: _find,
          toolbarController: _toolbar,
          readOnly: _controller.readOnly,
          autofocus: false,
          wordWrap: _wordWrap,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 200),
          style: CodeEditorStyle(
            fontSize: 14,
            fontFamily: 'monospace',
            fontHeight: 1.4,
            codeTheme: codeTheme,
            textColor: theme.colorScheme.onSurface,
            backgroundColor: theme.colorScheme.surface,
            cursorColor: theme.colorScheme.primary,
            selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
            cursorLineColor: theme.colorScheme.primary.withValues(alpha: 0.06),
          ),
          indicatorBuilder:
              (context, editingController, chunkController, notifier) {
                return DefaultCodeLineNumber(
                  controller: editingController,
                  notifier: notifier,
                  textStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  focusedTextStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                );
              },
          findBuilder: (context, controller, readOnly) =>
              FindPanel(controller: controller, readOnly: readOnly),
        ),
      ),
    );
  }
}

/// Thanh dưới: trạng thái (encoding · xuống dòng · ngôn ngữ · dòng:cột)
/// bên trái, nút hoàn tác / làm lại bên phải.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller, this.lang});

  final TextEditorController controller;
  final String? lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: controller.code,
          builder: (context, _) {
            final code = controller.code;
            final sel = code.selection;
            final parts = [
              controller.decoded.encoding.label,
              controller.decoded.lineEnding.label,
              ?lang,
              '${code.lineCount} dòng',
              'Dòng ${sel.extentIndex + 1}, Cột ${sel.extentOffset + 1}',
              if (controller.readOnly) 'Chỉ đọc',
            ];
            return SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        parts.join(' · '),
                        style: style,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (!controller.readOnly) ...[
                    IconButton(
                      tooltip: 'Hoàn tác',
                      icon: const Icon(Icons.undo, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: code.canUndo ? code.undo : null,
                    ),
                    IconButton(
                      tooltip: 'Làm lại',
                      icon: const Icon(Icons.redo, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: code.canRedo ? code.redo : null,
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
