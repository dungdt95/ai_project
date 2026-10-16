import 'ball.dart';
import 'variant.dart';

enum TurnPhase { aiming, placing, running, evaluating, over }
enum PlayerGroup { none, solid, stripe }

class BidaGameState {
  BidaGameState({
    required this.variant,
    required this.mode,
    required this.balls,
    required this.currentPlayer,
    this.aiLevel,
    this.phase = TurnPhase.aiming,
    this.playerGroups = const [PlayerGroup.none, PlayerGroup.none],
    this.scores = const [0, 0],
    this.shotCount = 0,
    this.fouls = 0,
    this.winner,
    this.isGroupAssigned = false,
    this.message,
  });

  final BidaVariant variant;
  final BidaMode mode;
  final AiLevel? aiLevel;
  List<Ball> balls;
  int currentPlayer;
  TurnPhase phase;
  List<PlayerGroup> playerGroups;
  List<int> scores;
  int shotCount;
  int fouls;
  int? winner;
  bool isGroupAssigned;
  String? message;

  Ball get cueBall => balls.firstWhere((b) => b.isCue);
  List<Ball> get activeBalls => balls.where((b) => !b.isPocketed).toList();

  BidaGameState copyWith({
    List<Ball>? balls,
    int? currentPlayer,
    TurnPhase? phase,
    List<PlayerGroup>? playerGroups,
    List<int>? scores,
    int? shotCount,
    int? fouls,
    int? winner,
    bool? isGroupAssigned,
    String? message,
    bool clearMessage = false,
  }) {
    return BidaGameState(
      variant: variant,
      mode: mode,
      aiLevel: aiLevel,
      balls: balls ?? this.balls,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      phase: phase ?? this.phase,
      playerGroups: playerGroups ?? this.playerGroups,
      scores: scores ?? this.scores,
      shotCount: shotCount ?? this.shotCount,
      fouls: fouls ?? this.fouls,
      winner: winner ?? this.winner,
      isGroupAssigned: isGroupAssigned ?? this.isGroupAssigned,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
