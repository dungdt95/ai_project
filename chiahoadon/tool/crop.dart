import 'dart:io';
import 'package:image/image.dart';

/// Cắt một vùng ảnh chụp màn hình rồi phóng to, để soi từng pixel.
void main(List<String> args) {
  final src = decodePng(File(args[0]).readAsBytesSync())!;
  final x = int.parse(args[1]), y = int.parse(args[2]);
  final w = int.parse(args[3]), h = int.parse(args[4]);
  final out = copyResize(
    copyCrop(src, x: x, y: y, width: w, height: h),
    width: w * 2,
    interpolation: Interpolation.nearest,
  );
  File(args[5]).writeAsBytesSync(encodePng(out));
}
