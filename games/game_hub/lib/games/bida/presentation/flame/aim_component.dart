import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../domain/ball.dart';
import '../../domain/table.dart';

/// Renders aim line, ghost ball, cue stick, and trajectory prediction.
class AimComponent extends Component {
  AimComponent({required this.balls});

  List<Ball> balls;
  double aimAngle = 0;
  bool visible = true;

  static const double _r = Ball.radiusM;
  static const double _w = BidaTable.widthM;
  static const double _h = BidaTable.heightM;

  Ball get _cue => balls.firstWhere((b) => b.isCue);

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final cue = _cue;
    if (cue.isPocketed) return;

    final cuePos = Offset(cue.position.x, cue.position.y);
    final dir = Offset(cos(aimAngle), sin(aimAngle));

    final hit = _castRay(cuePos, dir);

    // ── Cue stick behind cue ball ──────────────────────────────────────────
    _drawCueStick(canvas, cuePos, dir);

    // ── Aim line to first contact ──────────────────────────────────────────
    _drawDashedLine(canvas, cuePos, hit.contact, Colors.white.withOpacity(0.7), 0.005);

    // ── Ghost ball at contact point ────────────────────────────────────────
    canvas.drawCircle(
      hit.contact,
      _r,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _r * 0.12,
    );

    if (hit.isCushionHit) {
      // ── Cushion bounce reflection path ──────────────────────────────────
      final reflDir = _reflect(dir, hit.normal!);
      final bounceEnd = _tableClamp(hit.contact, reflDir, 0.8);
      _drawDashedLine(canvas, hit.contact, bounceEnd,
          Colors.cyanAccent.withOpacity(0.45), 0.004);
    } else if (hit.targetBallPos != null) {
      // ── Target ball deflection ───────────────────────────────────────────
      // Direction the target ball travels: from ghost-ball center to target center
      final tbPos = Offset(hit.targetBallPos!.x, hit.targetBallPos!.y);
      final tbDir = _normalize(tbPos - hit.contact);
      final tbEnd = _tableClamp(tbPos, tbDir, 0.6);
      _drawDashedLine(canvas, tbPos, tbEnd,
          Colors.orangeAccent.withOpacity(0.5), 0.004);

      // Small dot on target ball
      canvas.drawCircle(tbPos, _r * 0.15,
          Paint()..color = Colors.orangeAccent.withOpacity(0.8));
    }
  }

  // ── Drawing helpers ────────────────────────────────────────────────────────

  void _drawCueStick(Canvas canvas, Offset cuePos, Offset dir) {
    const stickLen = 0.35;
    const gap = _r * 1.1; // small gap between tip and cue ball
    final tipX = cuePos.dx - dir.dx * gap;
    final tipY = cuePos.dy - dir.dy * gap;
    final butt = Offset(tipX - dir.dx * stickLen, tipY - dir.dy * stickLen);

    // Stick body (gradient-width: thinner at tip, thicker at butt)
    final path = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(butt.dx, butt.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD4A056)
        ..strokeWidth = 0.018
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    // Tip highlight
    canvas.drawCircle(
      Offset(tipX, tipY),
      0.008,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }

  void _drawDashedLine(
      Canvas canvas, Offset start, Offset end, Color color, double width) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final total = sqrt(dx * dx + dy * dy);
    if (total < 0.001) return;

    final nx = dx / total;
    final ny = dy / total;
    const dashLen = 0.032;
    const gapLen = 0.022;

    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    double d = 0;
    bool drawing = true;
    while (d < total) {
      final segLen = drawing ? dashLen : gapLen;
      final d2 = min(d + segLen, total);
      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + nx * d, start.dy + ny * d),
          Offset(start.dx + nx * d2, start.dy + ny * d2),
          paint,
        );
      }
      d = d2;
      drawing = !drawing;
    }
  }

  // ── Ray casting ────────────────────────────────────────────────────────────

  _AimRayHit _castRay(Offset start, Offset dir) {
    double t = 10.0; // max distance
    Offset? normal;
    Vector2? targetBallPos;

    // Cushion: find closest wall hit (accounting for ball radius)
    double tCushion = t;
    Offset? cushionNormal;

    if (dir.dx > 0) {
      final tc = (_w - start.dx - _r) / dir.dx;
      if (tc > 0.001 && tc < tCushion) { tCushion = tc; cushionNormal = const Offset(-1, 0); }
    } else if (dir.dx < 0) {
      final tc = (_r - start.dx) / dir.dx;
      if (tc > 0.001 && tc < tCushion) { tCushion = tc; cushionNormal = const Offset(1, 0); }
    }
    if (dir.dy > 0) {
      final tc = (_h - start.dy - _r) / dir.dy;
      if (tc > 0.001 && tc < tCushion) { tCushion = tc; cushionNormal = const Offset(0, -1); }
    } else if (dir.dy < 0) {
      final tc = (_r - start.dy) / dir.dy;
      if (tc > 0.001 && tc < tCushion) { tCushion = tc; cushionNormal = const Offset(0, 1); }
    }
    t = tCushion;
    normal = cushionNormal;

    // Ball intersections (ghost-ball method)
    for (final ball in balls) {
      if (ball.isCue || ball.isPocketed) continue;
      final bx = ball.position.x - start.dx;
      final by = ball.position.y - start.dy;
      final a = dir.dx * dir.dx + dir.dy * dir.dy;
      final b2 = -(bx * dir.dx + by * dir.dy); // -b/2
      final c = bx * bx + by * by - (_r * 2) * (_r * 2);
      final disc = b2 * b2 - a * c;
      if (disc < 0) continue;
      final tHit = (-b2 - sqrt(disc)) / a;
      if (tHit > 0.001 && tHit < t) {
        t = tHit;
        targetBallPos = ball.position.clone();
        normal = null; // ball hit, not cushion
      }
    }

    final contact = start + dir * t;
    return _AimRayHit(
      contact: contact,
      isCushionHit: targetBallPos == null,
      normal: targetBallPos == null ? normal : null,
      targetBallPos: targetBallPos,
    );
  }

  // ── Math helpers ────────────────────────────────────────────────────────────

  Offset _reflect(Offset dir, Offset normal) {
    final dot = dir.dx * normal.dx + dir.dy * normal.dy;
    return Offset(dir.dx - 2 * dot * normal.dx, dir.dy - 2 * dot * normal.dy);
  }

  Offset _normalize(Offset v) {
    final len = sqrt(v.dx * v.dx + v.dy * v.dy);
    return len > 0 ? Offset(v.dx / len, v.dy / len) : Offset.zero;
  }

  /// Walk distance `dist` from `start` in `dir`, clamped to table bounds.
  Offset _tableClamp(Offset start, Offset dir, double dist) {
    double t = dist;
    if (dir.dx > 0) t = min(t, (_w - start.dx) / dir.dx);
    if (dir.dx < 0) t = min(t, (0 - start.dx) / dir.dx);
    if (dir.dy > 0) t = min(t, (_h - start.dy) / dir.dy);
    if (dir.dy < 0) t = min(t, (0 - start.dy) / dir.dy);
    return start + dir * t.clamp(0, dist);
  }
}

class _AimRayHit {
  const _AimRayHit({
    required this.contact,
    required this.isCushionHit,
    this.normal,
    this.targetBallPos,
  });
  final Offset contact;
  final bool isCushionHit;
  final Offset? normal;
  final Vector2? targetBallPos;
}
