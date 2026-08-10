import 'dart:math';

/// Maths behind the tower.
///
/// Every successfully placed block moves the player one rung up a multiplier
/// ladder and the round can be cashed out at that rung. The chance of a block
/// falling is derived from the ladder itself, so cashing out at any rung has
/// the same expected return of `1 - houseEdge`.
class TowerEngine {
  TowerEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const double houseEdge = 0.025;
  static const int maxBlocks = 40;

  static final List<double> ladder = _buildLadder();

  static List<double> _buildLadder() {
    final List<double> out = <double>[];
    double value = 1.03;
    double growth = 1.075;
    while (out.length < maxBlocks) {
      final double rung = double.parse(value.toStringAsFixed(2));
      if (rung > 1000) break;
      out.add(rung);
      value = rung * growth;
      growth += 0.004;
    }
    return out;
  }

  /// Multiplier unlocked once [blocks] blocks are standing.
  static double multiplierFor(int blocks) {
    if (blocks <= 0) return 1;
    return ladder[min(blocks, ladder.length) - 1];
  }

  /// Chance of reaching [blocks] standing blocks in a round.
  static double reachChance(int blocks) {
    if (blocks <= 0) return 1;
    return (1 - houseEdge) / multiplierFor(blocks);
  }

  /// Chance that the next block survives, given [standing] blocks are placed.
  static double survivalChance(int standing) {
    final double now = reachChance(standing);
    final double next = reachChance(standing + 1);
    return now <= 0 ? 0 : (next / now).clamp(0.0, 1.0);
  }

  /// Index of the block that will fall, decided before the round starts.
  /// A value above [maxBlocks] means the tower can be completed.
  int rollFallingBlock() {
    final double roll = _random.nextDouble();
    for (int block = 1; block <= ladder.length; block++) {
      if (roll > reachChance(block)) return block;
    }
    return ladder.length + 1;
  }

  int payout(int bet, int standingBlocks) =>
      (bet * multiplierFor(standingBlocks)).round();
}

/// One finished round, kept for the results strip.
class RoundResult {
  const RoundResult({required this.multiplier, required this.cashedOut});

  final double multiplier;
  final bool cashedOut;
}
