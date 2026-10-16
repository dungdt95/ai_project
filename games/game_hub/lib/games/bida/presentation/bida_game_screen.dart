import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/bida_ai_player.dart';
import '../domain/ball.dart';
import '../domain/game_state.dart';
import '../domain/shot.dart';
import '../domain/table.dart';
import '../domain/variant.dart';
import '../services/bida_audio_service.dart';
import 'bida_game_notifier.dart';
import 'flame/bida_flame_game.dart' show BidaFlameGame, kTableScale;
import 'widgets/power_slider.dart';
import 'widgets/spin_widget.dart';

class BidaGameScreen extends ConsumerStatefulWidget {
  const BidaGameScreen({
    super.key,
    required this.variant,
    required this.mode,
    this.aiLevel,
  });

  final BidaVariant variant;
  final BidaMode mode;
  final AiLevel? aiLevel;

  @override
  ConsumerState<BidaGameScreen> createState() => _BidaGameScreenState();
}

class _BidaGameScreenState extends ConsumerState<BidaGameScreen> {
  BidaFlameGame? _flameGame;
  final BidaAudioService _audio = BidaAudioService();

  double _aimAngle = 0;
  double _power = 0.5;
  Offset _spin = Offset.zero;

  Offset? _lastPan;
  Size _canvasSize = Size.zero;

  bool _showingGameOver = false;
  bool _isAiThinking = false;

  // Ball-in-hand placement
  Vector2? _placementPos; // world coords

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(bidaGameProvider);
      final needsInit = current.balls.isEmpty ||
          current.variant != widget.variant ||
          current.mode != widget.mode;
      if (needsInit) {
        ref.read(bidaGameProvider.notifier).startGame(
              variant: widget.variant,
              mode: widget.mode,
              aiLevel: widget.aiLevel,
            );
      }
      _buildFlameGame();
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _audio.dispose();
    super.dispose();
  }

  void _buildFlameGame() {
    final state = ref.read(bidaGameProvider);
    setState(() {
      _flameGame = BidaFlameGame(
        state: state,
        onShotResult: (updated, result) async {
          await ref.read(bidaGameProvider.notifier).onShotSettled(updated, result);

          // Sync evaluated state (currentPlayer, playerGroups, isGroupAssigned…)
          // back to FlameGame — it holds a stale snapshot otherwise.
          _flameGame?.state = ref.read(bidaGameProvider);

          // Scratch: hide aim, enter placing mode (player places manually)
          final s = ref.read(bidaGameProvider);
          if (result.cueBallScratched && s.phase == TurnPhase.placing) {
            _flameGame?.aimComponent.visible = false;
            final isAiTurn = s.mode == BidaMode.vsAi && s.currentPlayer == 1;
            if (isAiTurn) {
              // AI gets ball-in-hand — auto-place and auto-shoot
              _scheduleAiCueBallPlacement();
            } else if (mounted) {
              setState(() => _placementPos = BidaTable.headSpot.clone());
            }
          } else if (result.cueBallScratched) {
            // Non-placing rules (carom etc.) — restore immediately
            final cueBall = s.balls.firstWhere((b) => b.isCue);
            _flameGame?.restoreCueBall(cueBall);
          }

          _audio.playForResult(result);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final gs = ref.read(bidaGameProvider);
            if (gs.phase == TurnPhase.over && gs.winner != null && !_showingGameOver) {
              _showGameOverDialog(gs);
            } else if (gs.phase != TurnPhase.placing) {
              _maybeScheduleAiShot();
            }
          });
        },
      );
    });
  }

  // ── AI turn handling ────────────────────────────────────────────────────────

  void _maybeScheduleAiShot() {
    final s = ref.read(bidaGameProvider);
    if (s.mode != BidaMode.vsAi) return;
    if (s.currentPlayer != 1) return; // player 0 = human, player 1 = AI
    if (s.phase != TurnPhase.aiming) return;
    if (s.winner != null) return;
    _scheduleAiShot(s.aiLevel ?? AiLevel.medium);
  }

  Future<void> _scheduleAiShot(AiLevel level) async {
    if (!mounted) return;
    setState(() => _isAiThinking = true);

    // Thinking delay (longer for harder AI)
    final thinkMs = switch (level) {
      AiLevel.easy => 600,
      AiLevel.medium => 1000,
      AiLevel.hard => 1500,
    };
    await Future.delayed(Duration(milliseconds: thinkMs));
    if (!mounted) return;

    final state = ref.read(bidaGameProvider);
    // Guard: check turn didn't change while waiting
    if (state.currentPlayer != 1 || state.phase != TurnPhase.aiming || state.winner != null) {
      setState(() => _isAiThinking = false);
      return;
    }

    final shot = BidaAiPlayer.computeShot(state, level);

    // Show AI aim briefly on the table
    final angle = atan2(shot.direction.y, shot.direction.x);
    setState(() {
      _aimAngle = angle;
      _power = shot.power;
    });
    final game = _flameGame;
    if (game != null && game.isLoaded) game.aimComponent.aimAngle = angle;

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    setState(() => _isAiThinking = false);
    _applyAiShot(shot);
  }

  void _applyAiShot(Shot shot) {
    final game = _flameGame;
    if (game == null || !game.isLoaded) return;
    final notifier = ref.read(bidaGameProvider.notifier);
    notifier.confirmShot();
    game.applyShot(shot);
  }

  // ── Human aim / shot ────────────────────────────────────────────────────────

  void _updateAngle(double angle) {
    _aimAngle = angle % (2 * pi);
    final game = _flameGame;
    if (game != null && game.isLoaded) game.aimComponent.aimAngle = _aimAngle;
    ref.read(bidaGameProvider.notifier).setAimAngle(_aimAngle);
    if (mounted) setState(() {});
  }

  void _onTapUp(TapUpDetails d) {
    final game = _flameGame;
    if (game == null || !game.isLoaded || _canvasSize == Size.zero) return;
    final worldTap = game.widgetPosToWorld(d.localPosition, _canvasSize);
    final cue = game.state.balls.firstWhere((b) => b.isCue,
        orElse: () => game.state.balls.first);
    final dx = worldTap.x - cue.position.x;
    final dy = worldTap.y - cue.position.y;
    if (dx * dx + dy * dy < 0.01) return;
    _updateAngle(atan2(dy, dx));
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_lastPan != null) {
      final delta = d.localPosition.dx - _lastPan!.dx;
      _updateAngle(_aimAngle + delta * 0.008);
    }
    _lastPan = d.localPosition;
  }

  void _fireShot() {
    final game = _flameGame;
    if (game == null || !game.isLoaded) return;
    final notifier = ref.read(bidaGameProvider.notifier);
    final shot = notifier.buildShot();
    notifier.confirmShot();
    game.applyShot(shot);
  }

  // ── Ball-in-hand placement ────────────────────────────────────────────────

  void _onPlacementTap(TapUpDetails d) => _movePlacementTo(d.localPosition);

  void _onPlacementPanUpdate(DragUpdateDetails d) => _movePlacementTo(d.localPosition);

  void _movePlacementTo(Offset localPos) {
    final game = _flameGame;
    if (game == null || _canvasSize == Size.zero) return;
    final wp = game.widgetPosToWorld(localPos, _canvasSize);
    const r = Ball.radiusM;
    setState(() {
      _placementPos = Vector2(
        wp.x.clamp(r, BidaTable.widthM - r),
        wp.y.clamp(r, BidaTable.heightM - r),
      );
    });
  }

  void _confirmCueBallPlacement() {
    final pos = _placementPos;
    if (pos == null) return;
    ref.read(bidaGameProvider.notifier).confirmCueBallPlacement(pos);
    // Sync phase=aiming back to FlameGame immediately; without this, the stale
    // phase=placing bleeds into the next shot's evaluate() and re-triggers placement.
    _flameGame?.state = ref.read(bidaGameProvider);
    final cueBall = ref.read(bidaGameProvider).cueBall;
    _flameGame?.restoreCueBall(cueBall);
    _flameGame?.aimComponent.visible = true;
    setState(() => _placementPos = null);
    // If somehow it became AI's turn after placement, let AI shoot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeScheduleAiShot();
    });
  }

  /// AI gets ball-in-hand: wait briefly, then auto-place at head spot and shoot.
  Future<void> _scheduleAiCueBallPlacement() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final pos = BidaTable.headSpot.clone();
    ref.read(bidaGameProvider.notifier).confirmCueBallPlacement(pos);
    _flameGame?.state = ref.read(bidaGameProvider);
    final cueBall = ref.read(bidaGameProvider).cueBall;
    _flameGame?.restoreCueBall(cueBall);
    _flameGame?.aimComponent.visible = true;
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _maybeScheduleAiShot();
  }

  void _onHintPressed() {
    final state = ref.read(bidaGameProvider);
    if (state.phase != TurnPhase.aiming) return;
    final shot = BidaAiPlayer.computeShot(state, AiLevel.hard);
    final angle = atan2(shot.direction.y, shot.direction.x);
    setState(() {
      _aimAngle = angle;
      _power = shot.power;
    });
    _flameGame?.aimComponent.aimAngle = angle;
    ref.read(bidaGameProvider.notifier).setAimAngle(angle);
    ref.read(bidaGameProvider.notifier).setPower(shot.power);
  }

  void _showGameOverDialog(BidaGameState state) {
    if (!mounted) return;
    _showingGameOver = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GameOverDialog(
        winner: state.winner!,
        shotCount: state.shotCount,
        fouls: state.fouls,
        isVsAi: widget.mode == BidaMode.vsAi,
        isDaily: widget.mode == BidaMode.daily,
        scores: widget.variant == BidaVariant.carom ? state.scores : null,
        onRematch: widget.mode == BidaMode.daily ? null : () {
          Navigator.of(ctx).pop();
          _showingGameOver = false;
          ref.read(bidaGameProvider.notifier).newGame();
          _buildFlameGame();
        },
        onExit: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bidaGameProvider);
    final isAiTurn = state.mode == BidaMode.vsAi && state.currentPlayer == 1;
    final humanCanAim = state.phase == TurnPhase.aiming && !isAiTurn && !_isAiThinking;
    final isCarom = widget.variant == BidaVariant.carom;
    final isPlacing = state.phase == TurnPhase.placing;

    // Sync highlight rings to Flame game
    if (_flameGame != null) {
      _flameGame!.highlightGroup =
          widget.variant == BidaVariant.eightBall && state.isGroupAssigned
              ? state.playerGroups[state.currentPlayer]
              : PlayerGroup.none;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              // ── 1. Full-screen game (no space lost) ──────────────────────
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: isPlacing ? _onPlacementTap : (humanCanAim ? _onTapUp : null),
                  onPanStart: isPlacing
                      ? (d) => _movePlacementTo(d.localPosition)
                      : (humanCanAim ? (d) => _lastPan = d.localPosition : null),
                  onPanUpdate: isPlacing ? _onPlacementPanUpdate : (humanCanAim ? _onPanUpdate : null),
                  onPanEnd: (_) => _lastPan = null,
                  child: _flameGame == null
                      ? const Center(child: CircularProgressIndicator())
                      : GameWidget(game: _flameGame!),
                ),
              ),

              // ── 2. Top HUD — gradient fade, status + buttons in one bar ─
              Positioned(
                top: 0, left: 0, right: 0,
                child: _TopHud(
                  state: state,
                  isVsAi: widget.mode == BidaMode.vsAi,
                  isCarom: isCarom,
                  mode: widget.mode,
                  onBack: () => Navigator.of(context).pop(),
                  onRerack: widget.mode == BidaMode.practice
                      ? () {
                          ref.read(bidaGameProvider.notifier).newGame();
                          _buildFlameGame();
                        }
                      : null,
                  onNewGame: () {
                    _isAiThinking = false;
                    _showingGameOver = false;
                    ref.read(bidaGameProvider.notifier).newGame();
                    _buildFlameGame();
                  },
                ),
              ),

              // ── 3. Message chip (floating, bottom-centre) ────────────────
              if (state.message != null && !isPlacing)
                Positioned(
                  bottom: 72, left: 0, right: 0,
                  child: Center(child: _MessageChip(message: state.message!)),
                ),

              // ── 3b. Ghost ball — shows where cue ball will land ───────────
              if (isPlacing && _placementPos != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _GhostBallPainter(
                        worldPos: _placementPos!,
                        canvasSize: _canvasSize,
                      ),
                    ),
                  ),
                ),

              // ── 4. AI thinking badge (floats centre-bottom) ───────────────
              if (_isAiThinking)
                Positioned(
                  bottom: 16, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade900.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                          SizedBox(width: 10),
                          Text('AI đang suy nghĩ...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── 4b. Ball-in-hand confirm bar ──────────────────────────────
              if (isPlacing)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _PlacementBar(onConfirm: _confirmCueBallPlacement),
                ),

              // ── 5. Controls LEFT — spin + hint (bottom-left) ─────────────
              Positioned(
                left: 8, bottom: 8,
                child: Visibility(
                  visible: humanCanAim,
                  child: _LeftPanel(
                    spin: _spin,
                    onSpinChanged: (s) => setState(() => _spin = s),
                    isPractice: widget.mode == BidaMode.practice,
                    onHint: _onHintPressed,
                  ),
                ),
              ),

              // ── 6. Controls RIGHT — power + fire (right side) ─────────────
              Positioned(
                right: 8, top: 42, bottom: 8,
                child: Visibility(
                  visible: humanCanAim,
                  child: Center(
                    child: _RightPanel(
                      aimAngle: _aimAngle,
                      power: _power,
                      onPowerChanged: (p) {
                        setState(() => _power = p);
                        ref.read(bidaGameProvider.notifier).setPower(p);
                      },
                      onFire: _fireShot,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Top HUD — gradient bar merging navigation + status ───────────────────────

class _TopHud extends StatelessWidget {
  const _TopHud({
    required this.state,
    required this.isVsAi,
    required this.isCarom,
    required this.mode,
    required this.onBack,
    required this.onNewGame,
    this.onRerack,
  });

  final BidaGameState state;
  final bool isVsAi;
  final bool isCarom;
  final BidaMode mode;
  final VoidCallback onBack;
  final VoidCallback onNewGame;
  final VoidCallback? onRerack;

  @override
  Widget build(BuildContext context) {
    final isOver = state.winner != null;
    final p1Label = isVsAi ? 'Bạn' : 'P1';
    final p2Label = isVsAi ? 'AI' : 'P2';

    return Container(
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.72), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          // Back
          SizedBox(
            width: 36, height: 36,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
              padding: EdgeInsets.zero,
              onPressed: onBack,
            ),
          ),
          // P1 chip
          _HudChip(
            label: p1Label,
            group: state.playerGroups[0],
            score: isCarom ? state.scores[0] : null,
            active: state.currentPlayer == 0 && !isOver,
            isWinner: state.winner == 0,
          ),
          const SizedBox(width: 4),
          // Centre info
          Expanded(
            child: Text(
              isOver
                  ? 'Ván kết thúc!'
                  : 'Cú ${state.shotCount}${state.fouls > 0 ? '  ⚠${state.fouls}' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isOver ? Colors.amber : Colors.white60,
                fontSize: 11,
                fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // P2 chip
          _HudChip(
            label: p2Label,
            group: state.playerGroups[1],
            score: isCarom ? state.scores[1] : null,
            active: state.currentPlayer == 1 && !isOver,
            isWinner: state.winner == 1,
          ),
          // Action buttons
          if (onRerack != null)
            SizedBox(
              width: 34, height: 34,
              child: IconButton(
                icon: const Icon(Icons.restart_alt, color: Colors.white54, size: 17),
                padding: EdgeInsets.zero,
                onPressed: onRerack,
              ),
            ),
          SizedBox(
            width: 34, height: 34,
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 17),
              padding: EdgeInsets.zero,
              onPressed: onNewGame,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.label,
    required this.group,
    required this.active,
    required this.isWinner,
    this.score,
  });

  final String label;
  final PlayerGroup group;
  final int? score;
  final bool active;
  final bool isWinner;

  String get _groupText {
    switch (group) {
      case PlayerGroup.solid:  return 'Đặc';
      case PlayerGroup.stripe: return 'Sọc';
      case PlayerGroup.none:   return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = isWinner ? Colors.amber : active ? Colors.greenAccent : Colors.white38;
    final groupLabel = _groupText;
    final text = score != null
        ? '$label $score'
        : groupLabel.isEmpty ? label : '$label · $groupLabel';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(active || isWinner ? 0.18 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: active || isWinner ? 1.2 : 0.4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: active || isWinner ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// ── Message chip ──────────────────────────────────────────────────────────────

class _MessageChip extends StatelessWidget {
  const _MessageChip({required this.message});
  final String message;

  static const _foulKeywords = ['Phạm quy', 'Không chạm', 'Phải chạm', '3 băng:', 'ra ngoài bàn'];

  @override
  Widget build(BuildContext context) {
    final isFoul = _foulKeywords.any((k) => message.contains(k));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: (isFoul ? Colors.red.shade800 : Colors.green.shade800).withOpacity(0.88),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Game over dialog ──────────────────────────────────────────────────────────

class _GameOverDialog extends StatelessWidget {
  const _GameOverDialog({
    required this.winner,
    required this.shotCount,
    required this.fouls,
    required this.isVsAi,
    required this.isDaily,
    required this.onExit,
    this.onRematch,
    this.scores,
  });

  final int winner;
  final int shotCount;
  final int fouls;
  final bool isVsAi;
  final bool isDaily;
  final List<int>? scores;
  final VoidCallback? onRematch;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final String winnerLabel;
    if (isDaily) {
      winnerLabel = winner == 0 ? 'Daily hoàn thành!' : 'Ván kết thúc';
    } else if (isVsAi) {
      winnerLabel = winner == 0 ? 'Bạn thắng!' : 'AI thắng!';
    } else {
      winnerLabel = 'Người chơi ${winner + 1} thắng!';
    }

    return Dialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isDaily ? '📅' : '🎱', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              winnerLabel,
              style: const TextStyle(
                  color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (scores != null)
              Text('${scores![0]} – ${scores![1]} điểm',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
            Text(
              '$shotCount cú  •  $fouls phạm quy',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: onExit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('Thoát'),
                ),
                if (onRematch != null)
                  ElevatedButton(
                    onPressed: onRematch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Ván mới'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Left panel — spin widget + optional hint ─────────────────────────────────

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({
    required this.spin,
    required this.onSpinChanged,
    this.isPractice = false,
    this.onHint,
  });

  final Offset spin;
  final ValueChanged<Offset> onSpinChanged;
  final bool isPractice;
  final VoidCallback? onHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.60),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SpinWidget(spin: spin, onChanged: onSpinChanged),
          if (isPractice && onHint != null) ...[
            const SizedBox(height: 8),
            _HintButton(onPressed: onHint!),
          ],
        ],
      ),
    );
  }
}

// ── Right panel — power slider + fire button ──────────────────────────────────

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.aimAngle,
    required this.power,
    required this.onPowerChanged,
    required this.onFire,
  });

  final double aimAngle;
  final double power;
  final ValueChanged<double> onPowerChanged;
  final VoidCallback onFire;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.60),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PowerSlider(power: power, onChanged: onPowerChanged),
          const SizedBox(height: 4),
          Text(
            '${(aimAngle * 180 / pi).round()}°',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 10),
          _FireButton(onPressed: onFire),
        ],
      ),
    );
  }
}

class _FireButton extends StatelessWidget {
  const _FireButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green.shade700,
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 12)],
        ),
        child: const Icon(Icons.sports_cricket, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Hint button ───────────────────────────────────────────────────────────────

class _HintButton extends StatelessWidget {
  const _HintButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Gợi ý góc đánh',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.amber.shade800.withOpacity(0.85),
            boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 8)],
          ),
          child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ── Ghost ball painter — shows cue ball placement position ───────────────────

class _GhostBallPainter extends CustomPainter {
  const _GhostBallPainter({required this.worldPos, required this.canvasSize});

  final Vector2 worldPos;
  final Size canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Match camera: table at 80% of screen, centred
    const scale = kTableScale;
    const visW = BidaTable.widthM / scale;
    const visH = BidaTable.heightM / scale;
    const leftWorld = BidaTable.widthM / 2 - visW / 2;
    const topWorld  = BidaTable.heightM / 2 - visH / 2;
    final sx = size.width  / visW;
    final sy = size.height / visH;

    final cx = (worldPos.x - leftWorld) * sx;
    final cy = (worldPos.y - topWorld)  * sy;
    final r = Ball.radiusM * sx;

    // Drop shadow
    canvas.drawCircle(
      Offset(cx + 2, cy + 2),
      r,
      Paint()..color = Colors.black38,
    );
    // Ghost fill
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white.withOpacity(0.55),
    );
    // Border
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Cross-hair
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx - r * 0.6, cy), Offset(cx + r * 0.6, cy), paint);
    canvas.drawLine(Offset(cx, cy - r * 0.6), Offset(cx, cy + r * 0.6), paint);
  }

  @override
  bool shouldRepaint(_GhostBallPainter old) =>
      worldPos.x != old.worldPos.x || worldPos.y != old.worldPos.y;
}

// ── Placement confirm bar ─────────────────────────────────────────────────────

class _PlacementBar extends StatelessWidget {
  const _PlacementBar({required this.onConfirm});
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.82),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.touch_app, color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Chạm để đặt bi cái, vuốt để di chuyển',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Xác nhận'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

