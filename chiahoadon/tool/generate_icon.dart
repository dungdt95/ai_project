import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Sinh bộ ảnh icon và splash từ đúng màu seed của theme.
///
/// Vẽ bằng mã thay vì dùng tệp ảnh có sẵn vì hai lẽ: màu lấy trực tiếp từ
/// `AppColors.seed` nên icon không bao giờ lệch khỏi theme, và khi cần đổi
/// hình thì chỉ sửa vài con số rồi chạy lại — không phải mở trình thiết kế.
///
///     dart run tool/generate_icon.dart
///
/// Chạy lại khi đổi màu hoặc hình, rồi chạy `flutter_launcher_icons` và
/// `flutter_native_splash` để cắt ra các kích thước cho từng mật độ màn hình.

/// Màu seed của theme (`AppColors.seed`) và một sắc sáng hơn để làm nền chuyển.
const seed = (r: 0x0D, g: 0x94, b: 0x88);
const seedLight = (r: 0x14, g: 0xB8, b: 0xA6);

/// Vẽ ở kích thước gấp [ss] lần rồi thu nhỏ lại.
///
/// `fillPolygon` không làm mượt biên, nên cạnh của các múi sẽ răng cưa nếu vẽ
/// trực tiếp ở kích thước cuối. Vẽ lớn rồi thu nhỏ bằng nội suy trung bình cho
/// biên mượt mà không cần tự cài thuật toán khử răng cưa.
const ss = 4;

void main() {
  final out = Directory('assets/icon')..createSync(recursive: true);

  _write('${out.path}/app_icon.png', _legacyIcon());
  // Bán kính 0,27 thay vì lớn hơn: adaptive icon chỉ bảo đảm hiển thị phần
  // trong vòng tròn 66% ở giữa, phần ngoài có thể bị mặt nạ của launcher cắt.
  _write('${out.path}/app_icon_foreground.png', _mark(canvas: 1024, radius: 0.27));
  _write('${out.path}/splash_logo.png', _mark(canvas: 512, radius: 0.40));

  // Android 12+ đặt ảnh chờ trong một mặt nạ tròn chỉ chiếm hai phần ba khung,
  // nên cần bản riêng có lề rộng — dùng chung ảnh với màn chờ cũ thì bị cắt mất
  // rìa hình.
  _write(
    '${out.path}/splash_logo_android12.png',
    _mark(canvas: 1152, radius: 0.27),
  );

  stdout.writeln('Đã sinh 4 tệp trong ${out.path}');
}

void _write(String path, img.Image image) {
  File(path).writeAsBytesSync(img.encodePng(image));
  stdout.writeln('  $path  ${image.width}×${image.height}');
}

/// Icon vuông truyền thống: nền teal bo góc, dấu hiệu màu trắng ở giữa.
///
/// Dùng cho các launcher cũ không hỗ trợ adaptive icon; bản adaptive lấy
/// [_mark] làm lớp trước và màu seed làm lớp nền.
img.Image _legacyIcon() {
  const size = 1024;
  final big = img.Image(width: size * ss, height: size * ss, numChannels: 4);
  const radius = (size * ss) * 0.22;

  // Nền chuyển màu chéo, bo bốn góc; ngoài vùng bo thì để trong suốt để
  // launcher nào tự bo thì không bị viền vuông lộ ra.
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

/// Chỉ dấu hiệu trắng trên nền trong suốt.
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

/// Hình tròn chia thành ba múi, một múi tách ra ngoài.
///
/// Ba múi bằng nhau nói "chia đều"; múi tách ra nói "phần của một người" —
/// đúng hai việc app làm. Hình khối đơn giản nên vẫn đọc được ở 48dp, nơi mọi
/// chi tiết nhỏ hơn đều biến thành vệt mờ.
void _drawMark(img.Image image, {required double radius}) {
  final white = img.ColorRgba8(255, 255, 255, 255);
  final cx = image.width / 2;
  final cy = image.height / 2;
  final r = image.width * radius;

  const gapDegrees = 5.0;
  const explodeDegrees = 60.0; // tâm của múi được tách ra
  final explode = r * 0.22;

  for (var i = 0; i < 3; i++) {
    final start = -90.0 + i * 120.0 + gapDegrees;
    final end = -90.0 + (i + 1) * 120.0 - gapDegrees;

    // Múi đầu tiên nhích ra xa tâm theo hướng phân giác của chính nó; cả ba
    // múi lùi lại một phần ba khoảng đó để trọng tâm hình vẫn nằm giữa khung —
    // icon lệch tâm trông như vẽ hỏng, dù lệch rất ít.
    final offset = (i == 0 ? explode : 0.0) - explode / 3;
    final direction = _radians(explodeDegrees - 90.0);

    img.fillPolygon(
      image,
      vertices: _wedge(
        cx: cx + math.cos(direction) * offset,
        cy: cy + math.sin(direction) * offset,
        r: r,
        startDegrees: start,
        endDegrees: end,
      ),
      color: white,
    );
  }
}

/// Các đỉnh xấp xỉ một múi tròn: tâm, rồi các điểm trên cung.
List<img.Point> _wedge({
  required double cx,
  required double cy,
  required double r,
  required double startDegrees,
  required double endDegrees,
}) {
  // Mỗi bậc một điểm: ở kích thước đã nhân 4 thì sai số còn dưới một pixel
  // của ảnh cuối.
  final steps = (endDegrees - startDegrees).abs().ceil();

  return [
    img.Point(cx, cy),
    for (var i = 0; i <= steps; i++)
      () {
        final a = _radians(
          startDegrees + (endDegrees - startDegrees) * i / steps,
        );
        return img.Point(cx + math.cos(a) * r, cy + math.sin(a) * r);
      }(),
  ];
}

bool _insideRoundedRect(int x, int y, int w, int h, double radius) {
  final dx = math.max(radius - x, x - (w - 1 - radius));
  final dy = math.max(radius - y, y - (h - 1 - radius));
  if (dx <= 0 || dy <= 0) return true;
  return dx * dx + dy * dy <= radius * radius;
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

double _radians(double degrees) => degrees * math.pi / 180;
