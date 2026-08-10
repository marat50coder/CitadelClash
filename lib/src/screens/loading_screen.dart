import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_assets.dart';
import '../core/audio_manager.dart';
import '../core/game_storage.dart';
import '../core/ui_kit.dart';
import 'menu_screen.dart';

/// First screen of the app. It works in both orientations, warms up every
/// asset and only lets the bar reach 100% at the very moment the game starts.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final AnimationController _stripes = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_boot());
  }

  @override
  void dispose() {
    _progress.dispose();
    _stripes.dispose();
    _dots.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final Stopwatch clock = Stopwatch()..start();

    unawaited(
      _progress.animateTo(
        0.28,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      ),
    );

    await _precacheScreens();
    if (!mounted) return;
    await _progress.animateTo(
      0.52,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOut,
    );

    await GameStorage.instance.init();
    await AudioManager.instance.init();
    if (!mounted) return;
    await _progress.animateTo(
      0.74,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );

    await _precacheGameArt();
    if (!mounted) return;
    await _progress.animateTo(
      0.93,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
    );

    // Keep the splash on screen long enough to be read, never shorter.
    const Duration minimum = Duration(milliseconds: 3400);
    final Duration remaining = minimum - clock.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (!mounted) return;

    // The bar completes only immediately before the game opens.
    await _progress.animateTo(
      1.0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;

    unawaited(AudioManager.instance.playMusic(AppAssets.musicMenu));
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, _, _) => const MenuScreen(),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _precacheScreens() async {
    await Future.wait<void>(<Future<void>>[
      precacheImage(const AssetImage(AppAssets.loadingPortrait), context),
      precacheImage(const AssetImage(AppAssets.loadingLandscape), context),
    ]);
  }

  Future<void> _precacheGameArt() async {
    for (final String asset in AppAssets.preloadImages) {
      if (!mounted) return;
      await precacheImage(AssetImage(asset), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.skyDeep,
      body: OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
          final bool portrait = orientation == Orientation.portrait;
          final Size size = MediaQuery.sizeOf(context);
          final double barWidth = portrait
              ? size.width * 0.80
              : size.width * 0.56;
          final double bottomInset = portrait
              ? size.height * 0.10
              : size.height * 0.09;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(
                portrait
                    ? AppAssets.loadingPortrait
                    : AppAssets.loadingLandscape,
                fit: BoxFit.cover,
                alignment: Alignment.center,
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
                      animation: Listenable.merge(<Listenable>[
                        _progress,
                        _stripes,
                        _dots,
                      ]),
                      builder: (BuildContext context, _) {
                        final int percent = (_progress.value * 100).round();
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
                              progress: _progress.value,
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
