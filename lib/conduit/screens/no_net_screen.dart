import 'package:flutter/material.dart';

import '../../src/core/app_assets.dart';
import 'gate_button.dart';

/// Shown when the conduit concludes "no usable connection". Retry
/// re-runs the caller-supplied route through `pushReplacement`, so the
/// whole boot pipeline runs again fresh.
class NoNetScreen extends StatefulWidget {
  const NoNetScreen({super.key, required this.rebuild});

  final WidgetBuilder rebuild;

  @override
  State<NoNetScreen> createState() => _NoNetScreenState();
}

class _NoNetScreenState extends State<NoNetScreen> {
  bool _working = false;

  Future<void> _retry() async {
    if (_working) return;
    setState(() => _working = true);
    await Future<void>.delayed(const Duration(milliseconds: 560));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.rebuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.offlineLandscape
        : AppAssets.offlinePortrait;

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
                colors: <Color>[Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.09 : 0.08),
            child: Center(
              child: _working
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFF7C637)),
                      ),
                    )
                  : GateButton(
                      label: 'Retry',
                      onTap: _retry,
                      width: landscape
                          ? size.width * 0.34
                          : (size.width * 0.66).clamp(220.0, 360.0),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
