
import 'package:flutter/foundation.dart';

/// Giao diện chung cho mọi trình sửa (text / xlsx / docx).
///
/// [EditorShell] chỉ làm việc qua interface này: biết khi nào có thay đổi
/// ([isDirty]) và lấy nội dung để ghi ra file ([encode]).
abstract class DocumentEditorController extends ChangeNotifier {
  bool get isDirty;

  /// Mã hóa trạng thái hiện tại thành bytes để ghi ra file.
  Future<Uint8List> encode();

  /// Gọi sau khi lưu thành công để xóa cờ thay đổi.
  void markSaved();

  /// Mime dùng khi "Lưu thành…".
  String get saveMime;
}
