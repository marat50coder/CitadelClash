import 'package:flutter/material.dart';

/// Button styling for the conduit (gray) screens. A flat, slightly
/// bevelled rounded rectangle with a solid drop "lip" that sinks on
/// press — deliberately unlike the game's painted gold plaques and
/// unlike a plain pill. Two tones: [GateTone.primary] (amber) for the
/// main action and [GateTone.ghost] (slate) for the secondary — both
/// are real buttons with an equal tap target (never a faint text link).
enum GateTone { primary, ghost }

class GateButton extends StatefulWidget {
  const GateButton({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = GateTone.primary,
    this.width,
    this.height = 54,
  });

  final String label;
  final VoidCallback onTap;
  final GateTone tone;
  final double? width;
  final double height;

  @override
  State<GateButton> createState() => _GateButtonState();
}

class _GateButtonState extends State<GateButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool primary = widget.tone == GateTone.primary;
    final List<Color> face = primary
        ? const <Color>[Color(0xFFFFD34E), Color(0xFFF3A417)]
        : const <Color>[Color(0xFF46586B), Color(0xFF2C3A49)];
    final Color lip = primary ? const Color(0xFFB4720C) : const Color(0xFF17222D);
    final Color text = primary ? const Color(0xFF2A1A03) : Colors.white;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: widget.width,
        height: widget.height,
        transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: face,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
          boxShadow: <BoxShadow>[
            BoxShadow(color: lip, offset: Offset(0, _down ? 1 : 4), blurRadius: 0),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              offset: const Offset(0, 5),
              blurRadius: 12,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
