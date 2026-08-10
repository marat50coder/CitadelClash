import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_assets.dart';
import 'audio_manager.dart';

class AppPalette {
  const AppPalette._();

  static const Color gold = Color(0xFFF7C637);
  static const Color goldLight = Color(0xFFFFE88A);
  static const Color goldDark = Color(0xFFB07C12);
  static const Color ink = Color(0xFF1C1206);
  static const Color panel = Color(0xFF2A1A0C);
  static const Color panelLight = Color(0xFF4A2F14);
  static const Color sky = Color(0xFF2FA1EF);
  static const Color skyDeep = Color(0xFF1173C4);
  static const Color win = Color(0xFF6BE04A);
  static const Color danger = Color(0xFFE2543B);

  // Chrome around the play field.
  static const Color barDark = Color(0xFF3B3B3D);
  static const Color panelDark = Color(0xFF2B2B2D);
  static const Color fieldDark = Color(0xFF19191B);
  static const Color blue = Color(0xFF2F86EA);
  static const Color blueDark = Color(0xFF1B60B4);
  static const Color soil = Color(0xFF4B3526);
}

/// Formats coin amounts with thin spaces between thousands.
String formatAmount(num value) {
  final String digits = value.round().abs().toString();
  final StringBuffer out = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return out.toString();
}

String formatMultiplier(double value) {
  if (value >= 100) return 'x${value.round()}';
  return 'x${value.toStringAsFixed(2)}';
}

const List<Shadow> kTextGlow = <Shadow>[
  Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2)),
];

/// Chunky cartoon lettering with an outline, matching the painted assets.
class StrokedText extends StatelessWidget {
  const StrokedText(
    this.text, {
    super.key,
    this.size = 18,
    this.color = Colors.white,
    this.strokeColor = AppPalette.ink,
    this.strokeWidth = 3.5,
    this.letterSpacing = 0.6,
    this.align = TextAlign.center,
    this.maxLines = 1,
    this.height,
  });

  final String text;
  final double size;
  final Color color;
  final Color strokeColor;
  final double strokeWidth;
  final double letterSpacing;
  final TextAlign align;
  final int maxLines;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
      height: height,
      decoration: TextDecoration.none,
    );
    return Stack(
      children: <Widget>[
        Text(
          text,
          textAlign: align,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
          ),
        ),
        Text(
          text,
          textAlign: align,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(color: color, shadows: kTextGlow),
        ),
      ],
    );
  }
}

/// Diagonal construction hazard stripes, used on frames and progress bars.
class HazardStripePainter extends CustomPainter {
  const HazardStripePainter({
    this.stripeWidth = 16,
    this.phase = 0,
    this.base = AppPalette.gold,
    this.stripe = const Color(0xFF17130B),
  });

  final double stripeWidth;
  final double phase;
  final Color base;
  final Color stripe;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final Paint paint = Paint()..color = stripe;
    final double step = stripeWidth * 2;
    final double offset = phase % step;
    for (double x = -size.height - step + offset; x < size.width; x += step) {
      final Path path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + stripeWidth, size.height)
        ..lineTo(x + stripeWidth + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(HazardStripePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.stripeWidth != stripeWidth ||
      oldDelegate.base != base;
}

/// Metal plate with a gold rim; the shared surface for panels and dialogs.
BoxDecoration goldPanelDecoration({double radius = 22, bool dark = true}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const <Color>[Color(0xFF3B2611), Color(0xFF1B1006)]
          : const <Color>[AppPalette.goldLight, AppPalette.goldDark],
    ),
    border: Border.all(color: AppPalette.gold, width: 3),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Color(0x77000000), blurRadius: 14, offset: Offset(0, 6)),
    ],
  );
}

/// Small readout used for balance / bet / win.
class ValuePlate extends StatelessWidget {
  const ValuePlate({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppPalette.goldLight,
    this.icon,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xCC160E05),
        border: Border.all(color: AppPalette.goldDark, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StrokedText(
            label,
            size: compact ? 9 : 11,
            color: const Color(0xFFE9C88A),
            strokeWidth: 2,
            letterSpacing: 1.4,
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: compact ? 13 : 16, color: valueColor),
                const SizedBox(width: 4),
              ],
              StrokedText(
                value,
                size: compact ? 15 : 19,
                color: valueColor,
                strokeWidth: 3,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Golden sign board button built on top of the painted plaque asset.
class PlaqueButton extends StatefulWidget {
  const PlaqueButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 62,
    this.fontSize = 22,
    this.enabled = true,
    this.useBuildArt = false,
    this.color = Colors.white,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final bool enabled;

  /// Uses the pre-lettered `BUILD` plaque instead of the blank one.
  final bool useBuildArt;
  final Color color;

  static const double aspect = 2132 / 737;

  @override
  State<PlaqueButton> createState() => _PlaqueButtonState();
}

class _PlaqueButtonState extends State<PlaqueButton> {
  bool _down = false;

  void _handleTap() {
    if (!widget.enabled || widget.onTap == null) return;
    AudioManager.instance.click();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: active ? 1 : 0.55,
          child: SizedBox(
            height: widget.height,
            width: widget.height * PlaqueButton.aspect,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Image.asset(
                  widget.useBuildArt
                      ? AppAssets.buttonBuild
                      : AppAssets.buttonBlank,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
                if (!widget.useBuildArt)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.height * 0.55,
                    ),
                    child: FittedBox(
                      child: StrokedText(
                        widget.label,
                        size: widget.fontSize,
                        color: widget.color,
                        strokeWidth: widget.fontSize * 0.22,
                        letterSpacing: 1.6,
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

/// Flat control button used by the play field chrome (ALL IN, x2, CASHOUT).
class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.onTap,
    required this.child,
    this.color = AppPalette.blue,
    this.shadowColor = AppPalette.blueDark,
    this.height = 48,
    this.radius = 12,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color color;
  final Color shadowColor;
  final double height;
  final double radius;
  final bool enabled;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: active
          ? () {
              AudioManager.instance.click();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: active ? 1 : 0.45,
          child: Container(
            height: widget.height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[widget.color, widget.shadowColor],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: widget.shadowColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Full-width construction plaque used for the primary BUILD action. It is
/// painted (not a stretched bitmap) so the label stays crisp and correctly
/// proportioned at any width: a gold body with hazard-striped ends, rivets and
/// centred stroked lettering, matching the reference art.
class GoldBarButton extends StatefulWidget {
  const GoldBarButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.height = 62,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final double height;

  @override
  State<GoldBarButton> createState() => _GoldBarButtonState();
}

class _GoldBarButtonState extends State<GoldBarButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled;
    final double endWidth = (widget.height * 0.75).clamp(38.0, 56.0);
    final double fontSize = widget.height * 0.62;

    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: active
          ? () {
              AudioManager.instance.click();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: active ? 1 : 0.5,
          child: Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppPalette.ink, width: 2.5),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11.5),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          AppPalette.goldLight,
                          AppPalette.gold,
                          AppPalette.goldDark,
                        ],
                        stops: <double>[0, 0.5, 1],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: endWidth,
                      child: CustomPaint(
                        painter: HazardStripePainter(
                          stripeWidth: widget.height * 0.26,
                          base: AppPalette.gold,
                          stripe: AppPalette.ink,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: endWidth,
                      child: CustomPaint(
                        painter: HazardStripePainter(
                          stripeWidth: widget.height * 0.26,
                          base: AppPalette.gold,
                          stripe: AppPalette.ink,
                        ),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color(0x55FFFFFF),
                          Color(0x00FFFFFF),
                          Color(0x22000000),
                        ],
                        stops: <double>[0, 0.45, 1],
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      child: FittedBox(
                        child: StrokedText(
                          widget.label,
                          size: fontSize,
                          strokeWidth: fontSize * 0.2,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin band of construction stripes used to separate the chrome panels.
class HazardStrip extends StatelessWidget {
  const HazardStrip({
    super.key,
    this.height = 7,
    this.base = AppPalette.gold,
    this.stripe = const Color(0xFF17130B),
  });

  final double height;
  final Color base;
  final Color stripe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: HazardStripePainter(
          stripeWidth: height * 1.1,
          base: base,
          stripe: stripe,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Round gold button for icon-only actions.
class RoundGoldButton extends StatelessWidget {
  const RoundGoldButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 46,
    this.tooltip,
    this.active = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Widget button = GestureDetector(
      onTap: () {
        AudioManager.instance.click();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[AppPalette.goldLight, AppPalette.goldDark],
          ),
          border: Border.all(color: AppPalette.ink, width: 2.5),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: size * 0.52,
          color: active ? AppPalette.ink : const Color(0x77140C03),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Hazard striped frame drawn around the reels.
class HazardFrame extends StatelessWidget {
  const HazardFrame({
    super.key,
    required this.child,
    this.borderWidth = 12,
    this.radius = 20,
  });

  final Widget child;
  final double borderWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius + borderWidth * 0.4),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius + borderWidth * 0.4),
        child: CustomPaint(
          painter: const HazardStripePainter(stripeWidth: 14),
          child: Padding(
            padding: EdgeInsets.all(borderWidth),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Left-to-right progress bar with a moving hazard pattern and a glossy sheen.
class HazardProgressBar extends StatelessWidget {
  const HazardProgressBar({
    super.key,
    required this.progress,
    required this.phase,
    this.height = 26,
  });

  final double progress;
  final double phase;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        color: const Color(0xB3100B04),
        border: Border.all(color: AppPalette.ink, width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CustomPaint(
                  painter: HazardStripePainter(
                    stripeWidth: height * 0.42,
                    phase: phase,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.45),
                        Colors.white.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.22),
                      ],
                      stops: const <double>[0, 0.5, 1],
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

/// "Loading" caption whose dots cycle while work is in flight.
class LoadingDotsText extends StatelessWidget {
  const LoadingDotsText({
    super.key,
    required this.tick,
    this.size = 22,
    this.label = 'Loading',
  });

  final int tick;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final int dots = tick % 4;
    return SizedBox(
      width: size * (label.length * 0.62 + 2.2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: StrokedText(
          '$label${'.' * dots}',
          size: size,
          color: Colors.white,
          strokeWidth: size * 0.2,
          align: TextAlign.left,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Gentle floating motion reused by menu decorations.
class Bobbing extends StatefulWidget {
  const Bobbing({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.duration = const Duration(milliseconds: 2600),
    this.phase = 0,
  });

  final Widget child;
  final double amplitude;
  final Duration duration;
  final double phase;

  @override
  State<Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = (_controller.value + widget.phase) * 2 * math.pi;
        return Transform.translate(
          offset: Offset(0, math.sin(t) * widget.amplitude),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
