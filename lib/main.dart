import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/core/audio_manager.dart';
import 'src/core/ui_kit.dart';
import 'src/screens/loading_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // The loading screen supports both orientations; the game locks to portrait
  // as soon as the splash hands over.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const CitadelClashApp());
}

class CitadelClashApp extends StatefulWidget {
  const CitadelClashApp({super.key});

  @override
  State<CitadelClashApp> createState() => _CitadelClashAppState();
}

class _CitadelClashAppState extends State<CitadelClashApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppPalette.gold,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppPalette.skyDeep,
        fontFamily: 'Roboto',
      ),
      home: const LoadingScreen(),
    );
  }
}
