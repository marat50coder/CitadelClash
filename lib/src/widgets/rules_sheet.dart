import 'package:flutter/material.dart';

import '../core/game_storage.dart';
import '../core/ui_kit.dart';
import '../game/tower_engine.dart';

Future<void> showRules(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xCC000000),
    builder: (BuildContext context) => const _RulesDialog(),
  );
}

class _RulesDialog extends StatelessWidget {
  const _RulesDialog();

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
          child: Container(
            constraints: BoxConstraints(maxHeight: size.height * 0.82),
            decoration: goldPanelDecoration(radius: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                        child: StrokedText(
                          'HOW TO PLAY',
                          size: 22,
                          color: AppPalette.goldLight,
                          strokeWidth: 4.5,
                          letterSpacing: 1.6,
                          align: TextAlign.left,
                        ),
                      ),
                      RoundGoldButton(
                        icon: Icons.close_rounded,
                        size: 38,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const _Step(
                          number: '1',
                          text:
                              'Set your stake with the stepper, ALL IN or x2, '
                              'then press BUILD to start the round.',
                        ),
                        const _Step(
                          number: '2',
                          text:
                              'Every BUILD lowers one more block onto the '
                              'tower and lifts your multiplier to the next '
                              'rung.',
                        ),
                        const _Step(
                          number: '3',
                          text:
                              'Press CASHOUT at any time to collect your '
                              'stake multiplied by the current rung.',
                        ),
                        const _Step(
                          number: '4',
                          text:
                              'If a block slips off, the tower collapses and '
                              'the stake is lost. The higher you build, the '
                              'riskier the next block.',
                        ),
                        const SizedBox(height: 14),
                        const _SectionTitle('MULTIPLIER LADDER'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            for (
                              int i = 1;
                              i <= 14 && i <= TowerEngine.ladder.length;
                              i++
                            )
                              _Rung(
                                blocks: i,
                                multiplier: TowerEngine.multiplierFor(i),
                              ),
                            const _Rung.more(),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const _SectionTitle('THE ODDS'),
                        const SizedBox(height: 6),
                        _Hint(
                          'Each block has its own chance of slipping, derived '
                          'from the ladder itself: cashing out at any rung has '
                          'the same expected return of '
                          '${((1 - TowerEngine.houseEdge) * 100).round()}%. '
                          'The first block stands '
                          '${(TowerEngine.reachChance(1) * 100).round()}% of '
                          'the time, and a full tower of '
                          '${TowerEngine.ladder.length} blocks pays '
                          '${formatMultiplier(TowerEngine.multiplierFor(TowerEngine.ladder.length))}.',
                        ),
                        const SizedBox(height: 14),
                        const _SectionTitle('YOUR BUDGET'),
                        const SizedBox(height: 6),
                        _Hint(
                          'Balance is shown in ${GameStorage.currency}, a '
                          'virtual currency with no real world value. Running '
                          'out simply lets you claim '
                          '${formatAmount(GameStorage.refillAmount)} more for '
                          'free. This game is for entertainment only and '
                          'offers no real money gambling.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        StrokedText(
          text,
          size: 14,
          color: AppPalette.gold,
          strokeWidth: 3,
          letterSpacing: 1.6,
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Divider(color: AppPalette.goldDark, thickness: 2),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD9BE93),
        fontSize: 12.5,
        height: 1.4,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.none,
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[AppPalette.goldLight, AppPalette.goldDark],
              ),
              border: Border.all(color: AppPalette.ink, width: 1.5),
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppPalette.ink,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _Hint(text)),
        ],
      ),
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({required this.blocks, required this.multiplier})
    : isMore = false;

  const _Rung.more() : blocks = 0, multiplier = 0, isMore = true;

  final int blocks;
  final double multiplier;
  final bool isMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0x55000000),
        border: Border.all(color: AppPalette.goldDark, width: 1.5),
      ),
      child: isMore
          ? const StrokedText(
              '...',
              size: 12,
              color: Color(0xFFD9BE93),
              strokeWidth: 2.5,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                StrokedText(
                  formatMultiplier(multiplier),
                  size: 12,
                  color: AppPalette.goldLight,
                  strokeWidth: 2.5,
                ),
                StrokedText(
                  blocks == 1 ? '1 block' : '$blocks blocks',
                  size: 9,
                  color: const Color(0xFFBFA37A),
                  strokeWidth: 2,
                ),
              ],
            ),
    );
  }
}
