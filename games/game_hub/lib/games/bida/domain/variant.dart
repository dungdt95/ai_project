enum BidaVariant {
  eightBall,
  nineBall,
  vnBall,
  carom;

  String get displayName {
    switch (this) {
      case eightBall: return 'Pool 8-ball';
      case nineBall: return 'Pool 9-ball';
      case vnBall: return 'Bida lỗ VN';
      case carom: return 'Carom 3 băng';
    }
  }

  bool get hasPockets => this != carom;
  int get ballCount {
    switch (this) {
      case eightBall: return 15;
      case nineBall: return 9;
      case vnBall: return 15;
      case carom: return 3;
    }
  }
}

enum AiLevel { easy, medium, hard }
enum BidaMode { vsAi, vsHuman, practice, daily }
