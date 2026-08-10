import 'package:flutter/material.dart';

import '../core/audio_manager.dart';
import '../core/ui_kit.dart';

/// What the player picked in the in-game menu. The sheet only reports the
/// choice; the caller performs it once the sheet has closed, so no navigation
/// ever runs against a disposed context.
enum GameMenuAction { rules, privacy, support, mainMenu }

/// Slide-in menu opened from the hamburger button on the play field.
Future<GameMenuAction?> showGameMenu(BuildContext context) {
  return showGeneralDialog<GameMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'menu',
    barrierColor: const Color(0xAA000000),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (BuildContext context, _, _) => const _GameMenu(),
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
  );
}

class _GameMenu extends StatefulWidget {
  const _GameMenu();

  @override
  State<_GameMenu> createState() => _GameMenuState();
}

class _GameMenuState extends State<_GameMenu> {
  @override
  Widget build(BuildContext context) {
    final EdgeInsets inset = MediaQuery.viewPaddingOf(context);
    void close(GameMenuAction action) =>
        Navigator.of(context).pop<GameMenuAction>(action);

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: (MediaQuery.sizeOf(context).width * 0.78).clamp(240.0, 340.0),
          height: double.infinity,
          padding: EdgeInsets.only(
            top: inset.top + 18,
            bottom: inset.bottom + 18,
            left: 16,
            right: 16,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF3B3B3D), Color(0xFF1F1F21)],
            ),
            border: Border(right: BorderSide(color: AppPalette.gold, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: StrokedText(
                      'MENU',
                      size: 22,
                      color: AppPalette.goldLight,
                      strokeWidth: 4,
                      letterSpacing: 2,
                      align: TextAlign.left,
                    ),
                  ),
                  RoundGoldButton(
                    icon: Icons.close_rounded,
                    size: 36,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MenuRow(
                icon: Icons.menu_book_rounded,
                label: 'HOW TO PLAY',
                onTap: () => close(GameMenuAction.rules),
              ),
              _MenuRow(
                icon: Icons.privacy_tip_rounded,
                label: 'PRIVACY POLICY',
                onTap: () => close(GameMenuAction.privacy),
              ),
              _MenuRow(
                icon: Icons.support_agent_rounded,
                label: 'SUPPORT',
                onTap: () => close(GameMenuAction.support),
              ),
              const SizedBox(height: 10),
              const Divider(color: Color(0xFF56565A), thickness: 1.5),
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: AudioManager.instance.musicEnabled,
                builder: (BuildContext context, bool on, _) => _MenuRow(
                  icon: on ? Icons.music_note_rounded : Icons.music_off_rounded,
                  label: on ? 'MUSIC: ON' : 'MUSIC: OFF',
                  onTap: () => AudioManager.instance.toggleMusic(),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: AudioManager.instance.sfxEnabled,
                builder: (BuildContext context, bool on, _) => _MenuRow(
                  icon: on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  label: on ? 'SOUND: ON' : 'SOUND: OFF',
                  onTap: () => AudioManager.instance.toggleSfx(),
                ),
              ),
              const Spacer(),
              _MenuRow(
                icon: Icons.home_rounded,
                label: 'MAIN MENU',
                onTap: () => close(GameMenuAction.mainMenu),
              ),
              const SizedBox(height: 10),
              const Text(
                'Virtual funds only. No real money gambling.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9C9CA2),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AudioManager.instance.click();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF2A2A2C),
            border: Border.all(color: const Color(0xFF4A4A4E), width: 1.5),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: AppPalette.gold, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8A8A90),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
