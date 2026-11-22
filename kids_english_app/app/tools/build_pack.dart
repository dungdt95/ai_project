import 'dart:io';
import 'package:archive/archive.dart';

/// Script tiện ích đóng gói một thư mục chủ đề thành file .bvpack (chuẩn Zip)
/// Sử dụng: dart run tools/build_pack.dart `thư_mục_chủ_đề` `file_đầu_ra.bvpack`
void main(List<String> args) {
  if (args.length < 2) {
    stdout.writeln("Cách dùng: dart run tools/build_pack.dart <thư_mục_chủ_đề> <file_đầu_ra.bvpack>");
    return;
  }

  final sourceDir = Directory(args[0]);
  final outputFile = File(args[1]);

  if (!sourceDir.existsSync()) {
    stderr.writeln("Lỗi: Không tìm thấy thư mục nguồn: ${sourceDir.path}");
    return;
  }

  stdout.writeln("Đang đóng gói thư mục: ${sourceDir.path} -> ${outputFile.path}...");
  final archive = Archive();

  for (final entity in sourceDir.listSync(recursive: true)) {
    if (entity is File) {
      final relativePath = entity.path.substring(sourceDir.path.length + 1).replaceAll(r'\', '/');
      final bytes = entity.readAsBytesSync();
      archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      stdout.writeln(" + Đã thêm: $relativePath");
    }
  }

  final zipData = ZipEncoder().encode(archive);
  outputFile.writeAsBytesSync(zipData);
  stdout.writeln("Thành công! Đã tạo file gói: ${outputFile.path} (${outputFile.lengthSync()} bytes)");
}
