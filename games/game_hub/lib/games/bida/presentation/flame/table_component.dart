import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../domain/table.dart';

class TableComponent extends Component {
  TableComponent({this.hasPockets = true});

  final bool hasPockets;

  @override
  void render(Canvas canvas) {
    const w = BidaTable.widthM;
    const h = BidaTable.heightM;

    // Room background — fills any visible area outside the table
    canvas.drawRect(
      Rect.fromLTWH(-2, -2, w + 4, h + 4),
      Paint()..color = const Color(0xFF1A0A00),
    );

    // Felt
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF1B5E20),
    );

    // Rail border (thick)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.02,
    );

    // Inner rail highlight
    canvas.drawRect(
      Rect.fromLTWH(0.008, 0.008, w - 0.016, h - 0.016),
      Paint()
        ..color = const Color(0xFF4E342E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.006,
    );

    // Head string
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 0.003;
    canvas.drawLine(Offset(w * 0.25, 0), Offset(w * 0.25, h), linePaint);

    // Foot spot & head spot dots
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.45);
    canvas.drawCircle(Offset(BidaTable.footSpot.x, BidaTable.footSpot.y), 0.012, dotPaint);
    canvas.drawCircle(Offset(BidaTable.headSpot.x, BidaTable.headSpot.y), 0.012, dotPaint);

    if (hasPockets) {
      for (final pos in BidaTable.pocketPositions) {
        canvas.drawCircle(
          Offset(pos.x, pos.y),
          BidaTable.pocketRadiusM + 0.006,
          Paint()..color = Colors.black.withOpacity(0.5),
        );
        canvas.drawCircle(
          Offset(pos.x, pos.y),
          BidaTable.pocketRadiusM,
          Paint()..color = Colors.black,
        );
      }
    }
  }
}
