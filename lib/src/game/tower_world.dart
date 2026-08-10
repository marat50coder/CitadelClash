import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/ui_kit.dart';

/// Artwork used for the stacked blocks together with their aspect ratios, so
/// the tower can be laid out before the images are decoded.
class BlockArt {
  const BlockArt(
    this.asset,
    this.heightRatio, {
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final String asset;

  /// Height as a fraction of the block width.
  final double heightRatio;

  /// Fraction of the bounding-box height that is transparent above the
  /// structural top of the block. Used so the block above rests on the visible
  /// silhouette rather than an invisible edge.
  final double topInset;

  /// Fraction of the bounding-box height that is transparent (or purely
  /// decorative overhang, like hanging plants) below the structural bottom.
  final double bottomInset;

  // Values below are measured from the source artwork (see
  // tool/_measure_blocks used during development).
  static const List<BlockArt> all = <BlockArt>[
    BlockArt(AppAssets.block1, 1157 / 1359),
    BlockArt(AppAssets.block2, 1355 / 1160, bottomInset: 0.033),
    BlockArt(AppAssets.block3, 1371 / 1148, topInset: 0.009, bottomInset: 0.009),
    BlockArt(AppAssets.block4, 1),
  ];

  static const double storeRatio = 976 / 1086;
}

/// A block that already belongs to the tower.
class PlacedBlock {
  const PlacedBlock({
    required this.artIndex,
    required this.offsetX,
    required this.bottom,
    required this.height,
  });

  final int artIndex;

  /// Horizontal jitter so the stack looks hand built.
  final double offsetX;

  /// Distance from the ground line to the bottom edge of the block.
  final double bottom;
  final double height;
}

/// Screen measurements shared by the play field widgets.
class TowerGeometry {
  TowerGeometry(this.size)
    : soilHeight = size.height * 0.13,
      streetHeight = size.width / 2.6,
      blockWidth = size.width * 0.32,
      storeWidth = size.width * 0.44,
      hookHeight = size.height * 0.17;

  final Size size;
  final double soilHeight;
  final double streetHeight;
  final double blockWidth;
  final double storeWidth;
  final double hookHeight;

  double get storeHeight => storeWidth * BlockArt.storeRatio;

  /// Screen y of the pavement the tower stands on, before the camera moves.
  double get groundLine => size.height - soilHeight;

  /// Screen y of the top edge of the hanging block.
  double get hangingTop => hookHeight + size.height * 0.02;

  double blockHeight(int artIndex) =>
      blockWidth * BlockArt.all[artIndex].heightRatio;

  /// Lowest screen y the crane load can occupy, used to keep the tower clear
  /// of the block waiting on the hook.
  double get carryBottom => hangingTop + blockWidth * 1.2;

  /// How far the world scrolls so the top of a tower of [towerHeight] always
  /// stays a comfortable distance below the hanging block.
  double cameraFor(double towerHeight) =>
      math.max(0, towerHeight + carryBottom + size.height * 0.07 - groundLine);
}

/// The soil cross-section drawn underneath the street.
class SoilPainter extends CustomPainter {
  const SoilPainter({required this.band});

  /// Thickness of the soil that stays visible on screen.
  final double band;

  static const List<Offset> _stones = <Offset>[
    Offset(0.08, 0.42),
    Offset(0.21, 0.74),
    Offset(0.36, 0.30),
    Offset(0.47, 0.66),
    Offset(0.61, 0.38),
    Offset(0.74, 0.72),
    Offset(0.88, 0.46),
    Offset(0.95, 0.80),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF6B4B33), Color(0xFF332217)],
          stops: <double>[0, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, band * 0.07),
      Paint()..color = const Color(0xFF2E2116),
    );

    final Paint stone = Paint()..color = const Color(0xFF7A5B41);
    final Paint shade = Paint()..color = const Color(0x33000000);
    for (int i = 0; i < _stones.length; i++) {
      final Offset spot = _stones[i];
      final double radius = band * (0.08 + (i % 3) * 0.025);
      final Offset center = Offset(
        spot.dx * size.width,
        band * (0.2 + spot.dy * 0.75),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2.4,
          height: radius * 1.5,
        ),
        stone,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, radius * 0.32),
          width: radius * 2.0,
          height: radius * 0.9,
        ),
        shade,
      );
    }
  }

  @override
  bool shouldRepaint(SoilPainter oldDelegate) => oldDelegate.band != band;
}

/// The two cables that carry the block below the crane hook. [blockDx] shifts
/// the lower ends so the cables track the block while it swings.
class CablePainter extends CustomPainter {
  const CablePainter({
    required this.hookBottom,
    required this.blockTop,
    required this.blockWidth,
    this.blockDx = 0,
  });

  final double hookBottom;
  final double blockTop;
  final double blockWidth;
  final double blockDx;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final Paint paint = Paint()
      ..color = const Color(0xFF2B2B2B)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final Offset anchor = Offset(centerX, hookBottom);
    canvas.drawLine(
      anchor,
      Offset(centerX + blockDx - blockWidth * 0.42, blockTop + 4),
      paint,
    );
    canvas.drawLine(
      anchor,
      Offset(centerX + blockDx + blockWidth * 0.42, blockTop + 4),
      paint,
    );
  }

  @override
  bool shouldRepaint(CablePainter oldDelegate) =>
      oldDelegate.blockTop != blockTop ||
      oldDelegate.hookBottom != hookBottom ||
      oldDelegate.blockWidth != blockWidth ||
      oldDelegate.blockDx != blockDx;
}

/// Puff of dust kicked up when a block lands. [progress] runs 0..1 with the
/// landing bounce; the puffs expand outwards and fade away.
class DustPainter extends CustomPainter {
  const DustPainter({required this.progress});

  final double progress;

  static const List<Offset> _puffs = <Offset>[
    Offset(0.16, 0.92),
    Offset(0.38, 0.98),
    Offset(0.62, 0.98),
    Offset(0.84, 0.92),
    Offset(0.50, 0.86),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.clamp(0.0, 1.0);
    final double fade = 1 - t;
    if (fade <= 0) return;
    final Paint paint = Paint()
      ..color = const Color(0xFFEFE3CE).withValues(alpha: 0.5 * fade);
    for (int i = 0; i < _puffs.length; i++) {
      final Offset spot = _puffs[i];
      final double radius = size.width * (0.06 + 0.10 * t) * (0.7 + (i % 3) * 0.2);
      final double dx = (spot.dx - 0.5) * size.width * (1 + t * 0.7);
      final double dy = -t * size.height * (0.35 + (i % 2) * 0.25);
      canvas.drawCircle(
        Offset(size.width * 0.5 + dx, size.height * spot.dy + dy),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DustPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Multiplier badge that pops above a block the moment it is placed: it springs
/// in, floats up and fades, the way the reward reads out in the real slot.
class RisingMultiplier extends StatefulWidget {
  const RisingMultiplier({super.key, required this.text});

  final String text;

  @override
  State<RisingMultiplier> createState() => _RisingMultiplierState();
}

class _RisingMultiplierState extends State<RisingMultiplier>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final double t = _controller.value;
        final double pop = Curves.easeOutBack.transform(math.min(t / 0.3, 1));
        final double rise = -Curves.easeOut.transform(t) * 42;
        final double fade = t < 0.65
            ? 1.0
            : (1 - (t - 0.65) / 0.35).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, rise),
          child: Opacity(
            opacity: fade,
            child: Transform.scale(
              scale: 0.5 + 0.5 * pop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xCC17130B),
                  border: Border.all(color: AppPalette.gold, width: 2),
                ),
                child: StrokedText(
                  widget.text,
                  size: 22,
                  color: AppPalette.goldLight,
                  strokeWidth: 4.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Warm halo behind the shop at the base of the tower.
class GroundGlow extends StatelessWidget {
  const GroundGlow({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size * 0.7,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          gradient: RadialGradient(
            colors: <Color>[
              const Color(0xFFFFE9A8).withValues(alpha: 0.85),
              const Color(0xFFFFC65C).withValues(alpha: 0.35),
              const Color(0x00FFC65C),
            ],
            stops: const <double>[0, 0.45, 1],
          ),
        ),
      ),
    );
  }
}

/// Small chip listing a finished round multiplier.
class ResultChip extends StatelessWidget {
  const ResultChip({
    super.key,
    required this.multiplier,
    required this.cashedOut,
  });

  final double multiplier;
  final bool cashedOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xB31A1A1C),
        border: Border.all(
          color: cashedOut ? AppPalette.win : AppPalette.danger,
          width: 1.5,
        ),
      ),
      child: Text(
        formatMultiplier(multiplier),
        style: TextStyle(
          color: cashedOut ? AppPalette.win : const Color(0xFFFF9E8C),
          fontWeight: FontWeight.w800,
          fontSize: 12,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
