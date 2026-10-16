import 'package:flutter/material.dart';

/// Mini cue-ball widget for selecting spin offset.
class SpinWidget extends StatefulWidget {
  const SpinWidget({
    super.key,
    required this.spin,
    required this.onChanged,
  });

  final Offset spin; // x,y in -1..1
  final ValueChanged<Offset> onChanged;

  @override
  State<SpinWidget> createState() => _SpinWidgetState();
}

class _SpinWidgetState extends State<SpinWidget> {
  static const double _size = 64;
  static const double _radius = _size / 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Spin', style: TextStyle(color: Colors.white, fontSize: 11)),
        const SizedBox(height: 4),
        GestureDetector(
          onPanUpdate: (d) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = box.globalToLocal(d.globalPosition);
            // Find the circle within the widget
            final cx = _radius;
            final cy = _radius + 18; // offset for label
            final dx = (local.dx - cx) / _radius;
            final dy = (local.dy - cy) / _radius;
            widget.onChanged(Offset(
              dx.clamp(-1, 1),
              dy.clamp(-1, 1),
            ));
          },
          onTapUp: (d) {
            // Reset to center on tap outside
            widget.onChanged(Offset.zero);
          },
          child: SizedBox(
            width: _size,
            height: _size,
            child: CustomPaint(
              painter: _SpinPainter(spin: widget.spin),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpinPainter extends CustomPainter {
  const _SpinPainter({required this.spin});
  final Offset spin;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);

    // Ball background
    canvas.drawCircle(center, r - 2, Paint()..color = Colors.white);

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, r), Offset(size.width, r), gridPaint);
    canvas.drawLine(Offset(r, 0), Offset(r, size.height), gridPaint);

    // Spin dot
    final dotX = center.dx + spin.dx * (r - 8);
    final dotY = center.dy + spin.dy * (r - 8);
    canvas.drawCircle(
      Offset(dotX, dotY),
      6,
      Paint()..color = Colors.red,
    );

    // Ball outline
    canvas.drawCircle(
      center, r - 2,
      Paint()
        ..color = Colors.black38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SpinPainter old) => old.spin != spin;
}
