/// Một mục (tệp) trong thư mục Google Drive.
class DriveEntry {
  const DriveEntry({
    required this.id,
    required this.title,
    required this.isDoc,
    this.mime = '',
    this.modified = '',
  });

  /// Id tệp Drive.
  final String id;

  /// Tên hiển thị (Drive không kèm phần mở rộng trong danh sách).
  final String title;

  /// `true` = Google Docs (xuất bằng /export), `false` = tệp tải lên.
  final bool isDoc;

  /// Loại tệp suy ra từ biểu tượng trong danh sách (có thể rỗng).
  final String mime;

  /// Nhãn "sửa lần cuối" như Drive hiển thị ("11:24 am", "Nov 3"...). Chỉ là
  /// nhãn thô, không phải mốc thời gian chính xác.
  final String modified;

  bool get isFolder => mime == 'application/vnd.google-apps.folder';

  /// Có thể là văn bản chương không (bỏ ảnh, bảng tính, PDF, thư mục...).
  bool get isTextual {
    if (isFolder) return false;
    if (isDoc) return true;
    if (mime.isEmpty) return true;
    return mime.startsWith('text/') ||
        mime == 'application/json' ||
        mime == 'application/octet-stream';
  }
}

class DriveListing {
  const DriveListing({required this.folderName, required this.entries});

  final String folderName;
  final List<DriveEntry> entries;
}

/// Nội dung tải về của một chương.
class DriveFile {
  const DriveFile({required this.bytes, this.fileName = ''});

  final List<int> bytes;

  /// Tên tệp thật (từ Content-Disposition) nếu có.
  final String fileName;
}

/// Lỗi khi làm việc với Drive; [message] là tiếng Việt, hiển thị được.
class DriveException implements Exception {
  const DriveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thư mục chưa chia sẻ công khai (Drive trả về trang đăng nhập).
class DriveSignInRequiredException extends DriveException {
  const DriveSignInRequiredException()
    : super(
        'Thư mục chưa được chia sẻ công khai. Hãy mở Google Drive, chọn '
        '"Chia sẻ" và đặt quyền truy cập thành "Bất kỳ ai có đường liên kết".',
      );
}

/// Người dùng hủy giữa chừng.
class DriveCancelledException extends DriveException {
  const DriveCancelledException() : super('Đã hủy.');
}

/// Nguồn dữ liệu Drive; tách khỏi mạng để kiểm thử bằng bản giả.
abstract interface class DriveSource {
  Future<DriveListing> listFolder(String folderId);

  Future<DriveFile> fetchChapter(DriveEntry entry);
}

/// Cờ hủy dùng chung giữa UI và tác vụ tải.
class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const DriveCancelledException();
  }
}
