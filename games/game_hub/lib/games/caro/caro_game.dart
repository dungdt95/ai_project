import 'package:flutter/material.dart';
import '../../core/game_module.dart';
import 'presentation/caro_menu_screen.dart';

/// GameModule implementation for Cờ Caro.
class CaroGame extends GameModule {
  @override
  String get id => 'caro';

  @override
  String get nameKey => 'gameCaroName';

  @override
  String get descriptionKey => 'gameCaroDescription';

  @override
  Widget buildIcon(BuildContext context) => const Icon(
        Icons.grid_on,
        size: 48,
        color: Color(0xFF1976D2),
      );

  @override
  Widget buildEntryScreen(BuildContext context) => const CaroMenuScreen();
}
