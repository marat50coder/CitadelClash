import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../src/core/app_assets.dart';
import '../../src/core/audio_manager.dart';
import '../../src/core/game_storage.dart';
import '../../src/core/ui_kit.dart';
import '../../src/screens/menu_screen.dart';
import '../model/exit.dart';
import '../push/push_center.dart';
import '../store/locker.dart';
import '../switchboard.dart';
import '../web/site_shell.dart';
import 'no_net_screen.dart';
import 'push_ask_screen.dart';

/// The only startup surface. Shows the loading art + hazard bar while
/// the [Switchboard] resolves, then switches on the [Exit] and pushes
/// exactly one route. Game warmup (storage/audio/art) happens only on
/// the [PlayExit] branch so the gray surfaces stay independent of the
/// game's runtime.
class WarmupScreen extends StatefulWidget {
  const WarmupScreen({
    super.key,
    required this.board,
    required this.locker,
    required this.push,
  });

  final Switchboard board;
  final Locker locker;
  final PushCenter push;

  @override
  State<WarmupScreen> createState() => _WarmupScreenState();
}

class _WarmupScreenState extends State<WarmupScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final AnimationController _stripes = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  bool _handled = false;
  bool _screensReady = false;

  @override
  void initState() {
    super.initState();
    _bar.animateTo(0.08, duration: const Duration(milliseconds: 400));
    // precacheImage() inside _drive() reads MediaQuery.of(context); that
    // is illegal until after the first frame, so defer the whole boot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _drive();
    });
  }

  @override
  void dispose() {
    _bar.dispose();
    _stripes.dispose();
    _dots.dispose();
    super.dispose();
  }

  Future<void> _drive() async {
    final Stopwatch clock = Stopwatch()..start();
    await _precacheScreens();

    final Exit exit = await widget.board.route(onStep: _lift);
    if (!mounted || _handled) return;
    _handled = true;

    // Give the bar a beat to finish and the art a moment to be read.
    await _bar.animateTo(1, duration: const Duration(milliseconds: 360));
    const Duration floor = Duration(milliseconds: 1600);
    final Duration left = floor - clock.elapsed;
    if (left > Duration.zero) await Future<void>.delayed(left);
    if (!mounted) return;

    final Widget next = switch (exit) {
      PlayExit() => await _openGame(),
      SiteExit(url: final String url) => _openSite(url),
      DarkExit() => _openDark(),
    };
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, Animation<double> a, _, Widget child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Future<Widget> _openGame() async {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await GameStorage.instance.init();
    await AudioManager.instance.init();
    await _precacheGameArt();
    unawaited(AudioManager.instance.playMusic(AppAssets.musicMenu));
    return const MenuScreen();
  }

  Widget _openSite(String url) {
    if (widget.locker.shouldAskPush) {
      return PushAskScreen(
        locker: widget.locker,
        push: widget.push,
        destUrl: url,
      );
    }
    return SiteShell(url: url, locker: widget.locker, push: widget.push);
  }

  Widget _openDark() => NoNetScreen(
        rebuild: (_) => WarmupScreen(
          board: widget.board,
          locker: widget.locker,
          push: widget.push,
        ),
      );

  Future<void> _precacheScreens() async {
    if (_screensReady) return;
    _screensReady = true;
    await Future.wait<void>(<Future<void>>[
      precacheImage(const AssetImage(AppAssets.loadingPortrait), context),
      precacheImage(const AssetImage(AppAssets.loadingLandscape), context),
    ]);
  }

  Future<void> _precacheGameArt() async {
    for (final String asset in AppAssets.preloadImages) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(asset), context);
      } catch (_) {}
    }
  }

  void _lift(double value) {
    if (!mounted) return;
    _bar.animateTo(
      value.clamp(0.0, 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.skyDeep,
      body: OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
          final bool portrait = orientation == Orientation.portrait;
          final Size size = MediaQuery.sizeOf(context);
          final double barWidth =
              portrait ? size.width * 0.80 : size.width * 0.56;
          final double bottomInset =
              portrait ? size.height * 0.10 : size.height * 0.09;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(
                portrait
                    ? AppAssets.loadingPortrait
                    : AppAssets.loadingLandscape,
                fit: BoxFit.cover,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: size.height * 0.34,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Colors.transparent, Color(0x8C000000)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomInset,
                child: Center(
                  child: SizedBox(
                    width: barWidth,
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                        <Listenable>[_bar, _stripes, _dots],
                      ),
                      builder: (BuildContext context, _) {
                        final int percent = (_bar.value * 100).round();
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                LoadingDotsText(
                                  tick: (_dots.value * 4).floor(),
                                  size: portrait ? 22 : 19,
                                ),
                                StrokedText(
                                  '$percent%',
                                  size: portrait ? 22 : 19,
                                  color: AppPalette.goldLight,
                                  strokeWidth: 4,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            HazardProgressBar(
                              progress: _bar.value,
                              phase: _stripes.value * 60,
                              height: portrait ? 26 : 22,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
