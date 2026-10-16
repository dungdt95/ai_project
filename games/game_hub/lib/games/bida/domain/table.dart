import 'package:flame/components.dart';

/// WPA 9-foot pool table dimensions in meters.
class BidaTable {
  BidaTable();

  // Playing surface (inside cushions)
  static const double widthM = 2.54;
  static const double heightM = 1.27;

  // Pocket radius
  static const double pocketRadiusM = 0.057;

  // Cushion thickness
  static const double cushionM = 0.05;

  /// 6 pocket center positions (in table-local meters, origin = top-left inside cushion).
  static final List<Vector2> pocketPositions = [
    Vector2(0, 0),                             // top-left
    Vector2(widthM / 2, -pocketRadiusM * 0.5), // top-mid
    Vector2(widthM, 0),                        // top-right
    Vector2(0, heightM),                       // bottom-left
    Vector2(widthM / 2, heightM + pocketRadiusM * 0.5), // bottom-mid
    Vector2(widthM, heightM),                  // bottom-right
  ];

  /// Rack position (foot spot) for pool.
  static Vector2 get footSpot => Vector2(widthM * 0.75, heightM / 2);

  /// Head spot for cue ball placement.
  static Vector2 get headSpot => Vector2(widthM * 0.25, heightM / 2);
}
