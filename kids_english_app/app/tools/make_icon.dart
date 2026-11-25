import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

// Tạo ảnh nguồn icon app từ linh vật Momo (assets/images/common/momo_wave.png).
//
// Cách dùng (trong thư mục app/):
//   dart run tools/make_icon.dart
//   dart run flutter_launcher_icons
//
// Ghi ra tools/icon/:
//   - app_icon.png             1024x1024: nền nắng vàng–cam + vầng sáng + Momo vẫy tay (icon thường)
//   - app_icon_foreground.png  1024x1024 nền trong suốt, Momo nằm trong vùng an toàn của adaptive icon
const _src = 'assets/images/common/momo_wave.png';
const _out = 'tools/icon';
const _size = 1024;

// Vùng Momo trong ảnh 512x512 gốc: từ đỉnh đầu xuống hết ảnh (thân tràn ra mép dưới icon, không lộ vết cắt).
const _cropX = 70, _cropY = 34, _cropW = 376, _cropH = 478;
// Tâm khuôn mặt (y trong ảnh gốc) — dùng để đặt mặt Momo vào giữa icon.
const _faceY = 190;

void main() {
  final src = img.decodePng(File(_src).readAsBytesSync())!;
  final bust = img.copyCrop(src, x: _cropX, y: _cropY, width: _cropW, height: _cropH);

  Directory(_out).createSync(recursive: true);

  // 1) Icon thường (legacy): nền gradient + tia nắng + vầng sáng + Momo.
  final full = img.Image(width: _size, height: _size, numChannels: 4);
  _paintBackground(full);
  _paste(full, bust, scale: 0.86, faceAt: 0.50);
  File('$_out/app_icon.png').writeAsBytesSync(img.encodePng(full));

  // 2) Foreground adaptive icon: launcher cắt theo hình tròn/bo góc, vùng an toàn ~ 66/108 kích thước.
  final fg = img.Image(width: _size, height: _size, numChannels: 4);
  _paste(fg, bust, scale: 0.66, faceAt: 0.50);
  File('$_out/app_icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  // 3) Background adaptive icon: cùng nền nắng với icon thường.
  final bg = img.Image(width: _size, height: _size, numChannels: 4);
  _paintBackground(bg, haloScale: 72 / 108); // chỉ ~2/3 giữa được hiển thị
  File('$_out/app_icon_background.png').writeAsBytesSync(img.encodePng(bg));

  // 4) Ảnh xem trước: foreground + background, cắt tròn như launcher (chỉ để kiểm tra, không dùng trong app).
  final preview = bg.clone();
  img.compositeImage(preview, fg);
  final r = _size * 0.5 * 72 / 108; // phần hiển thị của adaptive icon
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final dx = x - _size / 2, dy = y - _size / 2;
      if (dx * dx + dy * dy > r * r) preview.setPixelRgba(x, y, 255, 255, 255, 0);
    }
  }
  File('$_out/preview_adaptive_round.png').writeAsBytesSync(img.encodePng(preview));

  stdout.writeln('Đã tạo icon trong $_out/');
}

/// Dán Momo rộng [scale] x icon, đặt tâm mặt tại [faceAt] chiều cao; phần thân dưới tràn ra ngoài bị cắt ở mép.
void _paste(img.Image dst, img.Image bust, {required double scale, required double faceAt}) {
  final w = (dst.width * scale).round();
  final h = (w * _cropH / _cropW).round();
  final scaled = img.copyResize(bust, width: w, height: h, interpolation: img.Interpolation.cubic);
  final x = (dst.width - w) ~/ 2;
  final y = (dst.height * faceAt - (_faceY - _cropY) * w / _cropW).round();
  if (y + h < dst.height) throw StateError("Momo không phủ tới mép dưới icon");
  img.compositeImage(dst, scaled, dstX: x, dstY: y);
}

/// Nền: gradient dọc vàng (#FFD23F) → cam (#FF9F1C), tia nắng nhạt, vầng sáng kem phía sau Momo.
void _paintBackground(img.Image im, {double haloScale = 1}) {
  const top = [0xFF, 0xDE, 0x6A];
  const bottom = [0xFF, 0x9F, 0x1C];
  final cx = im.width / 2, cy = im.height * 0.47;
  final haloR = im.width * 0.40 * haloScale;
  for (var y = 0; y < im.height; y++) {
    final t = y / (im.height - 1);
    for (var x = 0; x < im.width; x++) {
      var r = top[0] + (bottom[0] - top[0]) * t;
      var g = top[1] + (bottom[1] - top[1]) * t;
      var b = top[2] + (bottom[2] - top[2]) * t;

      final dx = x - cx, dy = y - cy;
      final d = math.sqrt(dx * dx + dy * dy);

      // 12 tia nắng mờ toả ra từ tâm.
      final ang = math.atan2(dy, dx);
      final ray = (math.cos(ang * 12) + 1) / 2; // 0..1
      if (ray > 0.55) {
        final k = 0.16 * ((ray - 0.55) / 0.45);
        r += (255 - r) * k;
        g += (255 - g) * k;
        b += (255 - b) * k;
      }

      // Vầng sáng kem (#FFF8E7) mềm phía sau Momo.
      final halo = (1 - ((d - haloR * 0.75) / (haloR * 0.35)).clamp(0.0, 1.0));
      if (halo > 0) {
        final k = 0.85 * halo;
        r += (0xFF - r) * k;
        g += (0xF8 - g) * k;
        b += (0xE7 - b) * k;
      }
      im.setPixelRgba(x, y, r.round(), g.round(), b.round(), 255);
    }
  }
}
