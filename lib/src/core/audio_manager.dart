import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'app_assets.dart';
import 'game_storage.dart';

/// Owns the background music player and a small pool of one-shot players so
/// overlapping effects never cut each other off.
class AudioManager {
  AudioManager._();

  static final AudioManager instance = AudioManager._();

  static const int _poolSize = 5;

  final AudioPlayer _music = AudioPlayer(playerId: 'citadel_music');
  final List<AudioPlayer> _pool = <AudioPlayer>[];
  int _next = 0;

  final ValueNotifier<bool> musicEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> sfxEnabled = ValueNotifier<bool>(true);

  String? _currentTrack;
  bool _ready = false;

  Future<void> init() async {
    musicEnabled.value = GameStorage.instance.musicOn;
    sfxEnabled.value = GameStorage.instance.sfxOn;

    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.42);
    for (int i = 0; i < _poolSize; i++) {
      final AudioPlayer player = AudioPlayer(playerId: 'citadel_sfx_$i');
      await player.setReleaseMode(ReleaseMode.stop);
      _pool.add(player);
    }
    _ready = true;
  }

  Future<void> playMusic(String asset) async {
    if (!_ready) return;
    _currentTrack = asset;
    if (!musicEnabled.value) return;
    try {
      await _music.stop();
      await _music.play(AssetSource(asset), volume: 0.42);
    } catch (_) {
      // Audio is cosmetic; a device that refuses to play must not break the game.
    }
  }

  Future<void> stopMusic() async {
    try {
      await _music.stop();
    } catch (_) {}
  }

  Future<void> playSfx(String asset, {double volume = 1.0}) async {
    if (!_ready || !sfxEnabled.value) return;
    final AudioPlayer player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await player.stop();
      await player.play(AssetSource(asset), volume: volume);
    } catch (_) {}
  }

  Future<void> click() => playSfx(AppAssets.sfxClick, volume: 0.9);

  Future<void> toggleMusic() async {
    final bool value = !musicEnabled.value;
    musicEnabled.value = value;
    await GameStorage.instance.setMusicOn(value);
    if (value) {
      if (_currentTrack != null) await playMusic(_currentTrack!);
    } else {
      await stopMusic();
    }
  }

  Future<void> toggleSfx() async {
    final bool value = !sfxEnabled.value;
    sfxEnabled.value = value;
    await GameStorage.instance.setSfxOn(value);
    if (value) click();
  }

  Future<void> pauseForBackground() async {
    try {
      await _music.pause();
    } catch (_) {}
  }

  Future<void> resumeFromBackground() async {
    if (!musicEnabled.value) return;
    try {
      await _music.resume();
    } catch (_) {}
  }
}
