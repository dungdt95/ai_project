import 'package:flutter/material.dart';
import '../../core/game_module.dart';
import 'presentation/bida_menu_screen.dart';

class BidaGame extends GameModule {
  @override
  String get id => 'bida';

  @override
  String get nameKey => 'gameBidaName';

  @override
  String get descriptionKey => 'gameBidaDescription';

  @override
  Widget buildIcon(BuildContext context) => const Icon(
        Icons.circle_outlined,
        size: 48,
        color: Color(0xFF388E3C),
      );

  @override
  Widget buildEntryScreen(BuildContext context) => const BidaMenuScreen();
}
