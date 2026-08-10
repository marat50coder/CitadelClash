import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_assets.dart';
import '../core/audio_manager.dart';
import '../core/game_storage.dart';
import '../core/ui_kit.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/rules_sheet.dart';
import '../widgets/sky_background.dart';
import 'tower_screen.dart';
import 'web_page_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    AudioManager.instance.playMusic(AppAssets.musicMenu);
  }

  Future<void> _openGame() async {
    await AudioManager.instance.playMusic(AppAssets.musicGame);
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => const TowerScreen(),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.06, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    await AudioManager.instance.playMusic(AppAssets.musicMenu);
    if (mounted) setState(() {});
  }

  Future<void> _openWeb(String title, String url) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WebPageScreen(title: title, url: url),
      ),
    );
  }

  Future<void> _topUp() async {
    final GameStorage storage = GameStorage.instance;
    if (storage.balance >= GameStorage.refillAmount) {
      await showMessageDialog(
        context,
        title: 'BUDGET IS FULL',
        message:
            'Free funds are available once your balance drops below '
            '${formatAmount(GameStorage.refillAmount)} '
            '${GameStorage.currency}.',
      );
      return;
    }
    await storage.setBalance(storage.balance + GameStorage.refillAmount);
    AudioManager.instance.playSfx(AppAssets.sfxCashout);
    if (!mounted) return;
    setState(() {});
    await showMessageDialog(
      context,
      title: 'FUNDS ADDED',
      message:
          '+${formatAmount(GameStorage.refillAmount)} '
          '${GameStorage.currency} have been credited to your balance. '
          'Good luck!',
    );
  }

  Future<void> _confirmExit() async {
    final bool leave = await showConfirmDialog(
      context,
      title: 'LEAVE THE SITE?',
      message: 'Do you want to close Citadel Clash?',
      confirmLabel: 'EXIT',
      cancelLabel: 'STAY',
    );
    if (leave) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final EdgeInsets inset = MediaQuery.viewPaddingOf(context);
    final double buttonHeight = (size.width * 0.16).clamp(52.0, 72.0);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppPalette.skyDeep,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const SkyBackground(cityHeightFactor: 0.26),
            _buildSkyline(size),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: inset.top.clamp(6.0, 90.0),
                bottom: inset.bottom.clamp(6.0, 60.0),
              ),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 6),
                  _buildTopBar(),
                  Expanded(flex: 6, child: _buildBanner(size)),
                  Column(
                    children: <Widget>[
                      PlaqueButton(
                        label: 'PLAY',
                        height: buttonHeight,
                        onTap: _openGame,
                      ),
                      const SizedBox(height: 10),
                      PlaqueButton(
                        label: 'HOW TO PLAY',
                        height: buttonHeight,
                        onTap: () => showRules(context),
                      ),
                      const SizedBox(height: 10),
                      PlaqueButton(
                        label: 'PRIVACY POLICY',
                        height: buttonHeight,
                        onTap: () => _openWeb(
                          'PRIVACY POLICY',
                          WebPageScreen.privacyPolicyUrl,
                        ),
                      ),
                      const SizedBox(height: 10),
                      PlaqueButton(
                        label: 'SUPPORT',
                        height: buttonHeight,
                        onTap: () =>
                            _openWeb('SUPPORT', WebPageScreen.supportUrl),
                      ),
                    ],
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0x99120B03),
                        ),
                        child: const Text(
                          'Virtual coins only. No real money gambling.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEAD9BC),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: <Widget>[
        ValuePlate(
          label: GameStorage.currency,
          value: formatAmount(GameStorage.instance.balance),
          icon: Icons.monetization_on_rounded,
          compact: true,
        ),
        const SizedBox(width: 6),
        RoundGoldButton(icon: Icons.add_rounded, size: 38, onTap: _topUp),
        const Spacer(),
        ValueListenableBuilder<bool>(
          valueListenable: AudioManager.instance.musicEnabled,
          builder: (BuildContext context, bool on, _) => RoundGoldButton(
            icon: on ? Icons.music_note_rounded : Icons.music_off_rounded,
            size: 38,
            active: on,
            onTap: () async {
              await AudioManager.instance.toggleMusic();
              if (mounted) setState(() {});
            },
          ),
        ),
        const SizedBox(width: 6),
        ValueListenableBuilder<bool>(
          valueListenable: AudioManager.instance.sfxEnabled,
          builder: (BuildContext context, bool on, _) => RoundGoldButton(
            icon: on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            size: 38,
            active: on,
            onTap: () async {
              await AudioManager.instance.toggleSfx();
              if (mounted) setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBanner(Size size) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double hookHeight = constraints.maxHeight * 0.34;
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            Positioned(
              top: 0,
              child: Image.asset(
                AppAssets.hook,
                height: hookHeight,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: hookHeight * 0.72,
              child: Bobbing(
                amplitude: 5,
                child: Image.asset(
                  AppAssets.logo,
                  width: constraints.maxWidth * 0.88,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0x66000000),
                  border: Border.all(color: AppPalette.goldDark, width: 2),
                ),
                child: StrokedText(
                  'BEST TOWER  '
                  '${formatMultiplier(GameStorage.instance.bestMultiplier)}',
                  size: 13,
                  color: AppPalette.goldLight,
                  strokeWidth: 3,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkyline(Size size) {
    final double houseHeight = size.height * 0.11;
    return Positioned(
      left: 0,
      right: 0,
      bottom: -houseHeight * 0.22,
      height: houseHeight,
      child: Opacity(
        opacity: 0.85,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Image.asset(AppAssets.block3, height: houseHeight * 0.8),
            Image.asset(AppAssets.shop, height: houseHeight),
            Image.asset(AppAssets.block2, height: houseHeight * 0.86),
          ],
        ),
      ),
    );
  }
}
