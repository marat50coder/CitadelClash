# Citadel Clash

A construction themed casino crash game for Android, built with Flutter. A
crane stacks blocks on top of a shop; every block that stands lifts your
multiplier, and you decide when to cash out before one slips. All funds are
virtual — the game contains no real money gambling.

- **Application id:** `com.citadelclash.citadelclashgame`
- **Orientation:** the game is portrait only; the loading screen supports both
  portrait and landscape.
- **Connectivity:** gameplay is fully offline. The `INTERNET` permission exists
  solely for the in-app Privacy Policy and Support pages.

## How a round works

1. Set the stake with the stepper, `ALL IN` or `x2`, then press **BUILD**. The
   stake leaves your balance and the crane lowers the first block.
2. Every further **BUILD** adds a block and moves you one rung up the
   multiplier ladder, which starts at `x1.05` and reaches `x746` at the top of
   a forty block tower.
3. **CASHOUT** pays the stake multiplied by the current rung at any time.
4. If a block slips the tower collapses and the stake is lost.

The falling block is drawn once at the start of the round from a distribution
derived from the ladder itself, so cashing out on any rung has the same
expected return of 97%. The first block stands 92% of the time and each further
rung is a little riskier than the last. The maths lives in
`lib/src/game/tower_engine.dart` and is covered by unit tests, including a
200 000 round simulation that checks the return rate.

## Screens

| Screen | File | Notes |
| --- | --- | --- |
| Loading | `lib/src/screens/loading_screen.dart` | Portrait/landscape artwork, animated `Loading...` caption and a left-to-right hazard progress bar that only reaches 100% right before the menu opens |
| Menu | `lib/src/screens/menu_screen.dart` | Play, how to play, Privacy Policy, Support, audio toggles, free top-up |
| Game | `lib/src/screens/tower_screen.dart` | Crane, stacking tower, scrolling camera, stake controls, results strip |
| Web pages | `lib/src/screens/web_page_screen.dart` | In-app WebView with an offline fallback screen |

The play field chrome mirrors a live casino client: a dark top bar with the
player id and balance in `FUN`, the hamburger menu, a results strip of recent
multipliers and the stake row above the primary action button.

## Project layout

```
assets/Citadel_Clash_assets/   original artwork and sounds
lib/src/core/                  assets registry, audio, storage, shared widgets
lib/src/game/                  crash engine and play field geometry/painters
lib/src/screens/               loading, menu, game and web screens
lib/src/widgets/               background, dialogs, in-game menu, rules
tool/make_launcher_icons.dart  builds the full-bleed adaptive icon layers
```

## Building

```bash
flutter pub get
flutter test
flutter build apk --release       # or: flutter build appbundle --release
```

The release build is currently signed with the debug keystore; replace the
`signingConfig` in `android/app/build.gradle.kts` before publishing.

## Launcher icon

`tool/make_launcher_icons.dart` takes `Icon.png` and produces the adaptive
layers. The artwork is placed inside the 72/108 safe zone and the surrounding
border is filled by clamping the edge pixels, so the icon covers the entire
surface with no empty margins under any launcher mask. Regenerate with:

```bash
dart run tool/make_launcher_icons.dart
dart run flutter_launcher_icons
```

## Audio

`bgm_menu.wav` and `bgm_game.wav` loop as background music; the remaining
sounds cover the crane, landings, cashouts and collapses through a small pool
of players. Music and effects can be muted independently and the choice is
persisted.
