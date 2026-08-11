import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'conduit/net/attribution.dart';
import 'conduit/net/reach.dart';
import 'conduit/net/server_ask.dart';
import 'conduit/net/ua_builder.dart';
import 'conduit/push/push_center.dart';
import 'conduit/screens/warmup_screen.dart';
import 'conduit/store/locker.dart';
import 'conduit/switchboard.dart';
import 'src/core/audio_manager.dart';
import 'src/core/ui_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is best-effort: the app compiles and runs (game path only)
  // even without a wired google-services.json — never block startup.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Build the device UA before any HTTP client or WebView is created.
  await UaBuilder.warm();

  final Locker locker = Locker();
  await locker.warm();

  final Reach reach = Reach();
  final Attribution attribution = Attribution();
  final ServerAsk server = ServerAsk(locker);
  final PushCenter push = PushCenter(locker);
  final Switchboard board = Switchboard(
    locker: locker,
    reach: reach,
    attribution: attribution,
    server: server,
    push: push,
  );

  runApp(CitadelClashApp(board: board, locker: locker, push: push));
}

class CitadelClashApp extends StatefulWidget {
  const CitadelClashApp({
    super.key,
    required this.board,
    required this.locker,
    required this.push,
  });

  final Switchboard board;
  final Locker locker;
  final PushCenter push;

  @override
  State<CitadelClashApp> createState() => _CitadelClashAppState();
}

class _CitadelClashAppState extends State<CitadelClashApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Warm/foreground taps arriving while the user is on game screens
    // (no SiteShell mounted) have already stashed the URL as a cold URL.
    // Bounce back through WarmupScreen so the boot pipeline reads it.
    widget.push.onOrphanTap = _rerouteFromTap;
  }

  @override
  void dispose() {
    widget.push.onOrphanTap = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _rerouteFromTap() {
    widget.board.invalidate();
    _navKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => WarmupScreen(
          board: widget.board,
          locker: widget.locker,
          push: widget.push,
        ),
      ),
      (_) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        AudioManager.instance.resumeFromBackground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        AudioManager.instance.pauseForBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Citadel Clash',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppPalette.gold,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppPalette.skyDeep,
        fontFamily: 'Roboto',
      ),
      home: WarmupScreen(
        board: widget.board,
        locker: widget.locker,
        push: widget.push,
      ),
    );
  }
}
