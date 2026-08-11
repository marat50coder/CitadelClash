import 'package:flutter/material.dart';

import '../../src/core/app_assets.dart';
import '../push/push_center.dart';
import '../settings/knobs.dart';
import '../store/locker.dart';
import '../web/site_shell.dart';
import 'gate_button.dart';

/// One-shot push opt-in shown before the site (only when
/// `locker.shouldAskPush` is true). Accept triggers the OS prompt;
/// Skip snoozes. Both are real buttons of equal weight.
class PushAskScreen extends StatefulWidget {
  const PushAskScreen({
    super.key,
    required this.locker,
    required this.push,
    required this.destUrl,
  });

  final Locker locker;
  final PushCenter push;
  final String destUrl;

  @override
  State<PushAskScreen> createState() => _PushAskScreenState();
}

class _PushAskScreenState extends State<PushAskScreen> {
  Future<void> _accept() async {
    final bool granted = await widget.push.requestPermission();
    if (!granted) await widget.locker.setPushSnooze(_snoozeUntil());
    if (mounted) _forward();
  }

  Future<void> _skip() async {
    await widget.locker.setPushSnooze(_snoozeUntil());
    if (mounted) _forward();
  }

  int _snoozeUntil() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + Knobs.pushSnoozeSeconds;

  void _forward() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SiteShell(
          url: widget.destUrl,
          locker: widget.locker,
          push: widget.push,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.notifyLandscape
        : AppAssets.notifyPortrait;
    // Landscape rail is 20% narrower than portrait's proportional share, and
    // clamped tighter, so the buttons over Horizontal_Notifications_Screen
    // sit at ~80% of their previous footprint.
    final double rail = size.width * (landscape ? 0.24 : 0.72);
    final double railMin = landscape ? 176.0 : 220.0;
    final double railMax = landscape ? 336.0 : 420.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0C1A2A),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x8A000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.07 : 0.09),
            child: Center(
              child: SizedBox(
                width: rail.clamp(railMin, railMax),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GateButton(
                      label: 'Accept',
                      onTap: _accept,
                      width: double.infinity,
                      height: landscape ? 38 : 56,
                    ),
                    SizedBox(height: landscape ? 8 : 14),
                    GateButton(
                      label: 'Skip',
                      tone: GateTone.ghost,
                      onTap: _skip,
                      width: double.infinity,
                      height: landscape ? 35 : 50,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
