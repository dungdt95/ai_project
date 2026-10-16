/// Kết quả của một thao tác có thể thất bại.
///
/// Repository trả về [Result] thay vì ném ngoại lệ, để lỗi trở thành một phần
/// của kiểu trả về và trình phân tích bắt được chỗ nào quên xử lý lỗi.
sealed class Result<T> {
  const Result();

  /// Bọc một hàm có thể ném ngoại lệ thành [Result].
  static Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on AppError catch (e) {
      return Err(e);
    } catch (e, stack) {
      return Err(AppError.unexpected(e, stack));
    }
  }

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  /// Giá trị nếu thành công, `null` nếu thất bại.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// Lỗi nếu thất bại, `null` nếu thành công.
  AppError? get errorOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final error) => error,
  };

  /// Giá trị nếu thành công, [fallback] nếu thất bại.
  T valueOr(T fallback) => valueOrNull ?? fallback;

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppError error) err,
  }) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final error) => err(error),
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok(transform(value)),
    Err<T>(:final error) => Err(error),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.error);

  final AppError error;

  @override
  String toString() => 'Err($error)';
}

/// Loại lỗi, dùng để UI quyết định hiện thông báo gì.
enum AppErrorKind {
  /// Dữ liệu người dùng nhập không hợp lệ.
  validation,

  /// Không tìm thấy bản ghi.
  notFound,

  /// Thao tác bị chặn bởi quy tắc nghiệp vụ (vd xóa thành viên đang có hóa đơn).
  conflict,

  /// Lỗi đọc/ghi cơ sở dữ liệu.
  database,

  /// Lỗi đọc/ghi tệp (ảnh hóa đơn, tệp sao lưu).
  storage,

  /// Lỗi chưa phân loại — luôn kèm ngoại lệ gốc để ghi log.
  unexpected,
}

/// Lỗi có thông điệp tiếng Việt hiển thị được trực tiếp cho người dùng.
class AppError implements Exception {
  const AppError({
    required this.kind,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  const AppError.validation(String message)
    : this(kind: AppErrorKind.validation, message: message);

  const AppError.notFound(String message)
    : this(kind: AppErrorKind.notFound, message: message);

  const AppError.conflict(String message)
    : this(kind: AppErrorKind.conflict, message: message);

  AppError.database(Object cause, [StackTrace? stackTrace])
    : this(
        kind: AppErrorKind.database,
        message: 'Không đọc được dữ liệu. Vui lòng thử lại.',
        cause: cause,
        stackTrace: stackTrace,
      );

  AppError.storage(String message, [Object? cause])
    : this(kind: AppErrorKind.storage, message: message, cause: cause);

  AppError.unexpected(Object cause, [StackTrace? stackTrace])
    : this(
        kind: AppErrorKind.unexpected,
        message: 'Đã xảy ra lỗi không mong muốn.',
        cause: cause,
        stackTrace: stackTrace,
      );

  final AppErrorKind kind;

  /// Thông điệp tiếng Việt, đã sẵn sàng hiển thị lên UI.
  final String message;

  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() =>
      'AppError(${kind.name}): $message${cause == null ? '' : ' <- $cause'}';
}
