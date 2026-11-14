import 'epub_importer.dart';
import 'parsed_book.dart';
import 'txt_importer.dart';
import 'zip_importer.dart';

/// Chọn bộ phân tích theo phần mở rộng của tệp.
class BookImporter {
  const BookImporter._();

  static const List<String> supportedExtensions = ['zip', 'txt', 'epub'];

  static ParsedBook parse(List<int> bytes, String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.zip')) return ZipImporter.parseBytes(bytes, fileName);
    if (lower.endsWith('.epub')) {
      return EpubImporter.parseBytes(bytes, fileName);
    }
    if (lower.endsWith('.txt') || lower.endsWith('.text')) {
      return TxtImporter.parseBytes(bytes, fileName);
    }
    throw ImportException('Định dạng không được hỗ trợ: $fileName');
  }
}
