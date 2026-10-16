import 'game_module.dart';

/// Singleton registry that holds all registered game modules.
class GameRegistry {
  GameRegistry._();
  static final GameRegistry instance = GameRegistry._();

  final List<GameModule> _games = [];

  List<GameModule> get games => List.unmodifiable(_games);

  void register(GameModule game) {
    assert(
      _games.every((g) => g.id != game.id),
      'A game with id "${game.id}" is already registered.',
    );
    _games.add(game);
  }

  GameModule? findById(String id) {
    try {
      return _games.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }
}
