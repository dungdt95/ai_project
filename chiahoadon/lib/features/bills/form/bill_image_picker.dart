import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../services/image_service.dart';

/// Đính kèm ảnh hóa đơn (SPEC FR-3.9).
///
/// Ảnh là bằng chứng khi có tranh cãi về con số, nên để ngay ở bước nhập
/// thông tin chứ không giấu trong menu.
class BillImagePicker extends StatelessWidget {
  const BillImagePicker({
    required this.imagePath,
    required this.onChanged,
    super.key,
  });

  /// Đường dẫn **tương đối** đã lưu, `null` nếu chưa có ảnh.
  final String? imagePath;

  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (imagePath == null) {
      return Card(
        child: InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.s16),
            child: Row(
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thêm ảnh hóa đơn', style: theme.textTheme.bodyLarge),
                      Text(
                        'Để đối chiếu khi có ai thắc mắc về số tiền',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FutureBuilder<File?>(
      future: ImageService.resolve(imagePath),
      builder: (context, snapshot) {
        final file = snapshot.data;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (file != null)
                InkWell(
                  onTap: () => BillImageViewer.show(context, file),
                  child: Image.file(
                    file,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(AppTheme.s16),
                  child: Text('Không tìm thấy tệp ảnh'),
                ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _pick(context),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Đổi ảnh'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => onChanged(null),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Bỏ ảnh'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context) async {
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );
    if (fromCamera == null || !context.mounted) return;

    final result = await ImageService.pick(fromCamera: fromCamera);
    if (!context.mounted) return;

    result.when(
      ok: (path) {
        if (path != null) onChanged(path);
      },
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}

/// Xem ảnh hóa đơn toàn màn hình, phóng to được (SPEC FR-3.9).
class BillImageViewer extends StatelessWidget {
  const BillImageViewer({required this.file, super.key});

  final File file;

  static Future<void> show(BuildContext context, File file) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => BillImageViewer(file: file),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Ảnh hóa đơn'),
      ),
      body: Center(
        // Chữ trên hóa đơn giấy thường nhỏ, nên phải phóng to được.
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(file),
        ),
      ),
    );
  }
}
