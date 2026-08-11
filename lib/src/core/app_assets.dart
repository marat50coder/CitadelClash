/// Central registry of every bundled asset path.
class AppAssets {
  const AppAssets._();

  static const String _root = 'assets/Citadel_Clash_assets';
  static const String _extra = '$_root/Citadel_Clash_additional_assets';
  static const String _game = '$_root/Citadel_Clash_gameplay_assets';

  // Screens and branding.
  static const String logo = '$_extra/Game_Name.webp';
  static const String loadingPortrait = '$_extra/Vertical_Loading_Screen.webp';
  static const String loadingLandscape =
      '$_extra/Horizontal_Loading_Screen.webp';
  static const String offlinePortrait = '$_extra/Vertical_Nowifi_Screen.webp';
  static const String offlineLandscape =
      '$_extra/Horizontal_Nowifi_Screen.webp';
  static const String notifyPortrait =
      '$_extra/Vertical_Notifications_Screen.webp';
  static const String notifyLandscape =
      '$_extra/Horizontal_Notifications_Screen.webp';

  // Gameplay art.
  static const String sky = '$_game/bg_sky_asset.webp';
  static const String city = '$_game/start_bg_asset.webp';
  static const String cloudSmall = '$_game/cloud_asset_01.webp';
  static const String cloudLarge = '$_game/cloud_asset_02.webp';
  static const String hook = '$_game/hook_asset.webp';
  static const String buttonBuild = '$_game/button_asset.webp';
  static const String buttonBlank = '$_game/button_blank.webp';
  static const String shop = '$_game/start_block_asset.webp';
  static const String block1 = '$_game/block_asset_01.webp';
  static const String block2 = '$_game/block_asset_02.webp';
  static const String block3 = '$_game/block_asset_03.webp';
  static const String block4 = '$_game/block_asset_04.webp';

  /// Everything that should be warmed up while the loading screen is visible.
  static const List<String> preloadImages = <String>[
    logo,
    sky,
    city,
    cloudSmall,
    cloudLarge,
    hook,
    buttonBuild,
    buttonBlank,
    shop,
    block1,
    block2,
    block3,
    block4,
  ];

  // Sounds. audioplayers resolves these relative to the `assets/` folder.
  static const String _sfx = 'Citadel_Clash_assets/Citadel_Clash_sounds_assets';
  static const String musicMenu = '$_sfx/bgm_menu.wav';
  static const String musicGame = '$_sfx/bgm_game.wav';
  static const String sfxClick = '$_sfx/button_click.wav';
  static const String sfxSpin = '$_sfx/drop.wav';
  static const String sfxReelStop = '$_sfx/block_place.wav';
  static const String sfxCoin = '$_sfx/coin.wav';
  static const String sfxWin = '$_sfx/win.wav';
  static const String sfxSmallWin = '$_sfx/success.wav';
  static const String sfxBigWin = '$_sfx/level_up.wav';
  static const String sfxCashout = '$_sfx/cashout.wav';
  static const String sfxLose = '$_sfx/fail.wav';
}
