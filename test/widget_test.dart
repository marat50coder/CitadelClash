import 'dart:math';

import 'package:citadelclashgame/src/game/tower_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the ladder climbs and never repeats a rung', () {
    expect(TowerEngine.ladder, isNotEmpty);
    for (int i = 1; i < TowerEngine.ladder.length; i++) {
      expect(TowerEngine.ladder[i], greaterThan(TowerEngine.ladder[i - 1]));
    }
    expect(TowerEngine.multiplierFor(0), 1);
    expect(TowerEngine.multiplierFor(1), TowerEngine.ladder.first);
  });

  test('cashing out on any rung returns the same expected value', () {
    for (int blocks = 1; blocks <= TowerEngine.ladder.length; blocks++) {
      final double expected =
          TowerEngine.reachChance(blocks) * TowerEngine.multiplierFor(blocks);
      expect(expected, closeTo(1 - TowerEngine.houseEdge, 0.02));
    }
  });

  test('survival chance drops as the tower grows', () {
    final double early = TowerEngine.survivalChance(1);
    final double late = TowerEngine.survivalChance(20);
    expect(early, greaterThan(late));
    expect(early, lessThan(1));
    expect(late, greaterThan(0));
  });

  test('payout follows the stake and the rung reached', () {
    final TowerEngine engine = TowerEngine(random: Random(3));
    expect(engine.payout(100, 0), 100);
    expect(engine.payout(200, 4), (200 * TowerEngine.multiplierFor(4)).round());
  });

  test('the falling block is always a valid round length', () {
    final TowerEngine engine = TowerEngine(random: Random(11));
    for (int i = 0; i < 2000; i++) {
      final int block = engine.rollFallingBlock();
      expect(block, greaterThanOrEqualTo(1));
      expect(block, lessThanOrEqualTo(TowerEngine.ladder.length + 1));
    }
  });

  test('simulated play returns close to the advertised RTP', () {
    final TowerEngine engine = TowerEngine(random: Random(2024));
    const int rounds = 200000;
    const int stake = 100;
    const int cashOutAt = 3;

    int wagered = 0;
    int returned = 0;
    for (int i = 0; i < rounds; i++) {
      wagered += stake;
      final int falls = engine.rollFallingBlock();
      if (falls > cashOutAt) returned += engine.payout(stake, cashOutAt);
    }

    final double rtp = returned / wagered;
    expect(rtp, closeTo(1 - TowerEngine.houseEdge, 0.02));
  });
}
