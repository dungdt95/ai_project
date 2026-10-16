class CushionHit {
  const CushionHit({required this.ballId, required this.timeMs});
  final int ballId;
  final double timeMs;
}

class ShotResult {
  const ShotResult({
    required this.pocketedIds,
    required this.firstBallHitId,
    required this.cushionHits,
    required this.cueBallScratched,
    required this.ballsLeftTableIds,
    this.secondBallHitId,
    this.cueCushionCountBeforeSecondBall = 0,
  });

  final List<int> pocketedIds;
  final int? firstBallHitId;
  final int? secondBallHitId;        // id of 2nd different ball cue hits (carom)
  final int cueCushionCountBeforeSecondBall; // cue cushion hits before 2nd ball (carom rule)
  final List<CushionHit> cushionHits;
  final bool cueBallScratched;
  final List<int> ballsLeftTableIds;

  bool get hasFoul => cueBallScratched || ballsLeftTableIds.isNotEmpty;
  bool get noBallHit => firstBallHitId == null;

  int cushionHitsForBall(int ballId) =>
      cushionHits.where((h) => h.ballId == ballId).length;
}
