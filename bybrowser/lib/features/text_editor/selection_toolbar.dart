import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

/// Menu ngữ cảnh (chạm giữ / chọn văn bản) cho re_editor, dùng
/// [AdaptiveTextSelectionToolbar] để có giao diện giống TextField chuẩn.
class EditorSelectionToolbar implements SelectionToolbarController {
  EditorSelectionToolbar({required this.readOnly});

  final bool readOnly;
  OverlayEntry? _entry;
  VoidCallback? _detach;

  @override
  void hide(BuildContext context) {
    _entry?.remove();
    _entry = null;
    _detach?.call();
    _detach = null;
  }

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    hide(context);
    final hasSelection = !controller.selection.isCollapsed;

    void run(VoidCallback action) {
      hide(context);
      action();
    }

    final items = <ContextMenuButtonItem>[
      if (hasSelection && !readOnly)
        ContextMenuButtonItem(
          label: 'Cắt',
          onPressed: () => run(controller.cut),
        ),
      if (hasSelection)
        ContextMenuButtonItem(
          label: 'Sao chép',
          onPressed: () => run(controller.copy),
        ),
      if (!readOnly)
        ContextMenuButtonItem(
          label: 'Dán',
          onPressed: () => run(controller.paste),
        ),
      if (!controller.isAllSelected)
        ContextMenuButtonItem(
          label: 'Chọn tất cả',
          onPressed: () => run(controller.selectAll),
        ),
    ];
    if (items.isEmpty) return;

    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Chạm ra ngoài menu → đóng.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => hide(context),
            ),
          ),
          AdaptiveTextSelectionToolbar.buttonItems(
            anchors: anchors,
            buttonItems: items,
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);

    // Gỡ menu khi editor báo ẩn (cuộn, gõ phím…) hoặc vùng chọn / nội dung đổi.
    void onVisibility() {
      if (!visibility.value) hide(context);
    }

    // Chỉ ẩn khi vùng chọn bị bỏ hoặc nội dung đổi — kéo handle mở rộng
    // vùng chọn thì giữ menu.
    final initialLines = controller.codeLines;
    void onControllerChanged() {
      if (controller.selection.isCollapsed && hasSelection ||
          !identical(controller.codeLines, initialLines)) {
        hide(context);
      }
    }
    visibility.addListener(onVisibility);
    controller.addListener(onControllerChanged);
    _detach = () {
      visibility.removeListener(onVisibility);
      controller.removeListener(onControllerChanged);
    };
  }
}
