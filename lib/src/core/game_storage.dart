import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent player profile. Everything lives on the device, the game never
/// talks to a server.
class GameStorage {
  GameStorage._();

  static final GameStorage instance = GameStorage._();

  static const String currency = 'FUN';
  static const int startingBalance = 10000;
  static const int refillAmount = 5000;
  static const int minBet = 10;
  static const int maxBet = 100000;

  static const String _kBalance = 'balance';
  static const String _kBet = 'bet';
  static const String _kMusic = 'music_on';
  static const String _kSfx = 'sfx_on';
  static const String _kBestMultiplier = 'best_multiplier';
  static const String _kRounds = 'total_rounds';
  static const String _kPlayerId = 'player_id';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_prefs.containsKey(_kBalance)) {
      await _prefs.setInt(_kBalance, startingBalance);
    }
    if (!_prefs.containsKey(_kPlayerId)) {
      final int id = 10000000 + Random().nextInt(89999999);
      await _prefs.setString(_kPlayerId, '$id');
    }
  }

  String get playerId => _prefs.getString(_kPlayerId) ?? '00000000';

  int get balance => _prefs.getInt(_kBalance) ?? startingBalance;
  Future<void> setBalance(int value) =>
      _prefs.setInt(_kBalance, value < 0 ? 0 : value);

  int get bet => _prefs.getInt(_kBet) ?? 100;
  Future<void> setBet(int value) =>
      _prefs.setInt(_kBet, value.clamp(minBet, maxBet));

  bool get musicOn => _prefs.getBool(_kMusic) ?? true;
  Future<void> setMusicOn(bool value) => _prefs.setBool(_kMusic, value);

  bool get sfxOn => _prefs.getBool(_kSfx) ?? true;
  Future<void> setSfxOn(bool value) => _prefs.setBool(_kSfx, value);

  double get bestMultiplier => _prefs.getDouble(_kBestMultiplier) ?? 0;
  Future<void> registerMultiplier(double value) async {
    if (value > bestMultiplier) await _prefs.setDouble(_kBestMultiplier, value);
  }

  int get totalRounds => _prefs.getInt(_kRounds) ?? 0;
  Future<void> registerRound() => _prefs.setInt(_kRounds, totalRounds + 1);
}
