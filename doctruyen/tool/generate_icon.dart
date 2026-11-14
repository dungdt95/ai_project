import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Sinh bộ ảnh icon và splash: quyển sách mở + sóng âm (đọc to).
///
///     dart run tool/generate_icon.dart
///
/// Sau đó chạy `dart run flutter_launcher_icons` và
/// `dart run flutter_native_splash:create`.

/// Màu seed của theme (teal) và sắc sáng hơn để làm nền chuyển.
const seed = (r: 0x0D, g: 0x94, b: 0x88);
const seedLight = (r: 0x14, g: 0xB8, b: 0xA6);

/// Vẽ ở kích thước gấp [ss] lần rồi thu nhỏ để biên mượt.
const ss = 4;

void main() {
  final out = Directory('assets/icon')..createSync(recursive: true);
  _write('${out.path}/app_icon.png', _legacyIcon());
  _write(
    '${out.path}/app_icon_foreground.png',
    _mark(canvas: 1024, radius: 0.27),
  );
  _write('${out.path}/splash_logo.png', _mark(canvas: 512, radius: 0.40));
  _write(
    '${out.path}/splash_logo_android12.png',
    _mark(canvas: 1152, radius: 0.27),
  );
  stdout.writeln('Đã sinh 4 tệp trong ${out.path}');
}

void _write(String path, img.Image image) {
  File(path).writeAsBytesSync(img.encodePng(image));
  stdout.writeln('  $path  ${image.width}x${image.height}');
}

img.Image _legacyIcon() {
  const size = 1024;
  final big = img.Image(width: size * ss, height: size * ss, numChannels: 4);
  const radius = (size * ss) * 0.22;
  for (var y = 0; y < big.height; y++) {
    for (var x = 0; x < big.width; x++) {
      if (!_insideRoundedRect(x, y, big.width, big.height, radius)) continue;
      final t = (x + y) / (big.width + big.height);
      big.setPixelRgba(
        x,
        y,
        _lerp(seedLight.r, seed.r, t),
        _lerp(seedLight.g, seed.g, t),
        _lerp(seedLight.b, seed.b, t),
        255,
      );
    }
  }
  _drawMark(big, radius: 0.27);
  return img.copyResize(
    big,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
}

img.Image _mark({required int canvas, required double radius}) {
  final big = img.Image(
    width: canvas * ss,
    height: canvas * ss,
    numChannels: 4,
  );
  _drawMark(big, radius: radius);
  return img.copyResize(
    big,
    width: canvas,
    height: canvas,
    interpolation: img.Interpolation.average,
  );
}

/// Sách mở (hai trang) ở dưới, chấm + hai vòng cung sóng âm phía trên.
/// Toạ độ theo đơn vị `u`: sách rộng 0,54u; gốc ở giữa khung.
void _drawMark(img.Image image, {required double radius}) {
  final white = img.ColorRgba8(255, 255, 255, 255);
  final u = image.width * radius * 2 / 0.54;
  final cx = image.width / 2;
  final cy = image.height / 2 + 0.03 * u; // bù để cả hình nằm giữa khung

  img.Point p(double x, double y) => img.Point(cx + x * u, cy + y * u);

  // Hai trang sách.
  for (final s in [-1.0, 1.0]) {
    img.fillPolygon(
      image,
      vertices: [
        p(s * 0.27, 0.04),
        p(s * 0.02, 0.12),
        p(s * 0.02, 0.30),
        p(s * 0.27, 0.22),
      ],
      color: white,
    );
  }

  // Chấm và các vòng cung sóng âm quanh (0, -0.02).
  _disc(image, cx, cy - 0.02 * u, 0.04 * u, white);
  _arc(image, cx, cy - 0.02 * u, 0.10 * u, 0.034 * u, white);
  _arc(image, cx, cy - 0.02 * u, 0.18 * u, 0.034 * u, white);
}

void _disc(img.Image image, double cx, double cy, double r, img.Color c) {
  img.fillCircle(
    image,
    x: cx.round(),
    y: cy.round(),
    radius: r.round(),
    color: c,
  );
}

/// Cung tròn dày quanh hướng lên trên, ±55 độ.
void _arc(
  img.Image image,
  double cx,
  double cy,
  double r,
  double thick,
  img.Color c,
) {
  const half = 55.0;
  final inner = r - thick / 2;
  final outer = r + thick / 2;
  const steps = 55;
  final pts = <img.Point>[];
  for (var i = 0; i <= steps; i++) {
    final a = _radians(-90 - half + 2 * half * i / steps);
    pts.add(img.Point(cx + math.cos(a) * outer, cy + math.sin(a) * outer));
  }
  for (var i = steps; i >= 0; i--) {
    final a = _radians(-90 - half + 2 * half * i / steps);
    pts.add(img.Point(cx + math.cos(a) * inner, cy + math.sin(a) * inner));
  }
  img.fillPolygon(image, vertices: pts, color: c);
  // Đầu tròn.
  for (final sgn in [-1.0, 1.0]) {
    final a = _radians(-90 + sgn * half);
    _disc(image, cx + math.cos(a) * r, cy + math.sin(a) * r, thick / 2, c);
  }
}

bool _insideRoundedRect(int x, int y, int w, int h, double radius) {
  final dx = math.max(radius - x, x - (w - 1 - radius));
  final dy = math.max(radius - y, y - (h - 1 - radius));
  if (dx <= 0 || dy <= 0) return true;
  return dx * dx + dy * dy <= radius * radius;
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

double _radians(double degrees) => degrees * math.pi / 180;
