import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

/// Thanh tìm kiếm / thay thế hiển thị phía trên editor, thiết kế cho màn hình
/// hẹp: hai hàng (tìm, thay thế), nút gọn, không cuộn ngang.
class FindPanel extends StatelessWidget implements PreferredSizeWidget {
  const FindPanel({super.key, required this.controller, required this.readOnly});

  final CodeFindController controller;
  final bool readOnly;

  static const _rowHeight = 44.0;

  @override
  Size get preferredSize {
    final v = controller.value;
    if (v == null) return Size.zero;
    return Size(double.infinity, v.replaceMode && !readOnly ? _rowHeight * 2 : _rowHeight);
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    if (value == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final result = value.result;
    final resultText = result == null
        ? '0'
        : '${result.index + 1}/${result.matches.length}';

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _rowHeight,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: _input(
                    controller: controller.findInputController,
                    focusNode: controller.findInputFocusNode,
                    hint: 'Tìm',
                    onSubmitted: (_) => controller.nextMatch(),
                  ),
                ),
                _toggle(context, 'Aa', value.option.caseSensitive, controller.toggleCaseSensitive,
                    tooltip: 'Phân biệt hoa/thường'),
                _toggle(context, '.*', value.option.regex, controller.toggleRegex,
                    tooltip: 'Biểu thức chính quy'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(resultText, style: theme.textTheme.labelMedium),
                ),
                _icon(Icons.keyboard_arrow_up, 'Trước',
                    result == null ? null : controller.previousMatch),
                _icon(Icons.keyboard_arrow_down, 'Sau',
                    result == null ? null : controller.nextMatch),
                if (!readOnly)
                  _icon(
                    value.replaceMode ? Icons.unfold_less : Icons.find_replace,
                    value.replaceMode ? 'Ẩn thay thế' : 'Thay thế',
                    controller.toggleMode,
                  ),
                _icon(Icons.close, 'Đóng', controller.close),
              ],
            ),
          ),
          if (value.replaceMode && !readOnly)
            SizedBox(
              height: _rowHeight,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: _input(
                      controller: controller.replaceInputController,
                      focusNode: controller.replaceInputFocusNode,
                      hint: 'Thay bằng',
                      onSubmitted: (_) => controller.replaceMatch(),
                    ),
                  ),
                  TextButton(
                    onPressed: result == null ? null : controller.replaceMatch,
                    child: const Text('Thay'),
                  ),
                  TextButton(
                    onPressed: result == null ? null : controller.replaceAllMatches,
                    child: const Text('Thay tất cả'),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required ValueChanged<String> onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: 1,
      style: const TextStyle(fontSize: 14),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: const OutlineInputBorder(borderSide: BorderSide.none),
      ),
    );
  }

  Widget _toggle(BuildContext context, String label, bool checked, VoidCallback onTap,
      {required String tooltip}) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: checked ? scheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: checked ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon(IconData icon, String tooltip, VoidCallback? onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }
}
