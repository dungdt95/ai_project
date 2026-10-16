import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/result.dart';

/// Lưu và đọc ảnh hóa đơn (SPEC FR-3.9), và dựng ảnh để chia sẻ (SPEC FR-8.2).
///
/// Ảnh nằm trong thư mục tài liệu của app, **không** phải thư viện ảnh chung —
/// hóa đơn là dữ liệu riêng, không nên lẫn vào cuộn ảnh của người dùng.
///
/// Đường dẫn lưu trong DB là **tương đối**, vì thư mục tài liệu của app đổi
/// sau mỗi lần cài lại trên iOS; lưu đường dẫn tuyệt đối là mất ảnh.
class ImageService {
  const ImageService._();

  static const Uuid _uuid = Uuid();

  /// Chụp ảnh mới hoặc chọn từ thư viện, rồi chép vào thư mục của app.
  static Future<Result<String?>> pick({required bool fromCamera}) =>
      Result.guard(() async {
        final picked = await ImagePicker().pickImage(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          // Ảnh hóa đơn chỉ cần đọc được chữ, không cần độ phân giải máy ảnh.
          maxWidth: 1600,
          imageQuality: 80,
        );
        if (picked == null) return null;

        final dir = await _imageDir();
        final name = '${_uuid.v4()}${p.extension(picked.path)}';
        await File(picked.path).copy(p.join(dir.path, name));

        return p.join(AppConstants.billImageDir, name);
      });

  /// Đường dẫn tuyệt đối từ đường dẫn tương đối đã lưu trong DB.
  static Future<File?> resolve(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, relativePath));
    return file.existsSync() ? file : null;
  }

  static Future<Result<void>> delete(String? relativePath) =>
      Result.guard(() async {
        final file = await resolve(relativePath);
        if (file != null) await file.delete();
      });

  /// Chụp một widget thành ảnh PNG (SPEC FR-8.2).
  ///
  /// Dùng cho việc chia sẻ kết quả chia tiền dưới dạng ảnh: nhiều người đọc
  /// ảnh nhanh hơn đọc text dài trong khung chat.
  ///
  /// [pixelRatio] 3 cho ảnh đủ nét trên màn hình mật độ cao mà vẫn nhẹ.
  static Future<Result<File>> captureWidget(
    GlobalKey boundaryKey, {
    double pixelRatio = 3,
    String fileName = 'chia-hoa-don.png',
  }) => Result.guard(() async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw const AppError.validation('Chưa dựng xong khung ảnh để chụp.');
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw AppError.storage('Không tạo được ảnh.');
    }

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(data.buffer.asUint8List());

    return file;
  });

  /// Thư mục chứa ảnh hóa đơn, tạo nếu chưa có.
  static Future<Directory> _imageDir() async {
    final dir = Directory(
      p.join(
        (await getApplicationDocumentsDirectory()).path,
        AppConstants.billImageDir,
      ),
    );
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }
}
