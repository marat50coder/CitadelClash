import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/exit.dart';
import '../settings/knobs.dart';

// ============================================================
// LOCKER — persisted state
// ============================================================
// Flags and timestamps live in SharedPreferences; URLs live in the
// platform secure store. Key names are opaque and share one short,
// project-unique prefix so a prefs dump never reveals intent.
// ============================================================

const String _p = 'cq9_';

class Locker {
  Locker({FlutterSecureStorage? secure})
    : _secure = secure ?? const FlutterSecureStorage();

  static const String _kLane = '${_p}lane';
  static const String _kDest = '${_p}dst';
  static const String _kDestTtl = '${_p}dst_exp';
  static const String _kPushGrant = '${_p}pg';
  static const String _kPushHardNo = '${_p}phn';
  static const String _kPushSnooze = '${_p}psz';
  static const String _kColdUrl = '${_p}cold';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<void> warm() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Lane memory ─────────────────────────────────────────
  Lane get lane => Lane.read(_prefs.getString(_kLane));

  Future<void> keepLane(Lane value) => _prefs.setString(_kLane, value.token);

  // ── Cached destination (secure) ─────────────────────────
  Future<String?> cachedDest() => _secure.read(key: _kDest);

  Future<void> stashDest(String url, int? expiryUnix) async {
    await _secure.write(key: _kDest, value: url);
    final int ttl = expiryUnix ?? (_now() + Knobs.cacheLifetimeSeconds);
    await _prefs.setInt(_kDestTtl, ttl);
  }

  bool get cachedDestStale {
    final int? ttl = _prefs.getInt(_kDestTtl);
    if (ttl == null) return true;
    return _now() >= ttl;
  }

  // ── Push invite state ───────────────────────────────────
  bool get pushGranted => _prefs.getBool(_kPushGrant) ?? false;

  Future<void> setPushGranted(bool v) => _prefs.setBool(_kPushGrant, v);

  bool get pushHardDenied => _prefs.getBool(_kPushHardNo) ?? false;

  Future<void> setPushHardDenied() => _prefs.setBool(_kPushHardNo, true);

  Future<void> setPushSnooze(int untilUnix) =>
      _prefs.setInt(_kPushSnooze, untilUnix);

  /// Whether the push invite screen should show before the site.
  bool get shouldAskPush {
    if (pushGranted) return false;
    if (pushHardDenied) return false;
    final int? until = _prefs.getInt(_kPushSnooze);
    if (until == null) return true;
    return _now() >= until;
  }

  // ── Cold-boot push URL (secure, one-shot) ───────────────
  Future<void> holdColdUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _secure.delete(key: _kColdUrl);
    } else {
      await _secure.write(key: _kColdUrl, value: url);
    }
  }

  Future<String?> takeColdUrl() async {
    final String? url = await _secure.read(key: _kColdUrl);
    if (url != null) await _secure.delete(key: _kColdUrl);
    return url;
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
