import 'package:flutter/widgets.dart';

/// Base interface every game must implement.
abstract class GameModule {
  /// Unique identifier used for routing and storage keys.
  String get id;

  /// i18n key for the game's display name.
  String get nameKey;

  /// i18n key for the short description shown on the launcher.
  String get descriptionKey;

  /// Icon widget displayed on the home launcher card.
  Widget buildIcon(BuildContext context);

  /// The entry screen of the game (mode selection, settings, etc.).
  Widget buildEntryScreen(BuildContext context);

  /// Optional: extra settings panels merged into the app settings screen.
  List<Widget> buildSettingsPanels(BuildContext context) => const [];

  /// Optional: called once at app startup to preload assets or warm up AI.
  Future<void> onAppStart() async {}
}
