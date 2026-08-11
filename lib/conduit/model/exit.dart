// ============================================================
// EXIT — the outcome of the boot decision (sealed hierarchy)
// ============================================================
// The warmup screen switches over this and only then picks a route.
// Nothing else in the app decides gray-vs-game routing. Adding a new
// destination means a new subtype here, which forces every switch to
// handle it.
// ============================================================

/// Persisted lane the last session ended in.
enum Lane {
  fresh,
  site,
  play;

  String get token => switch (this) {
    Lane.fresh => 'fresh',
    Lane.site => 'site',
    Lane.play => 'play',
  };

  static Lane read(String? raw) => switch (raw) {
    'site' => Lane.site,
    'play' => Lane.play,
    _ => Lane.fresh,
  };
}

/// Parsed body from the config endpoint. Wire keys `{ok,url,expires,message}`
/// are consumed verbatim.
class ServerReply {
  const ServerReply({required this.granted, this.url, this.expiry, this.note});

  factory ServerReply.fromMap(Map<String, dynamic> map) {
    final dynamic rawExpiry = map['expires'];
    return ServerReply(
      granted: map['ok'] == true,
      url: map['url'] is String ? map['url'] as String : null,
      expiry: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      note: map['message']?.toString(),
    );
  }

  const ServerReply.denied(this.note) : granted = false, url = null, expiry = null;

  final bool granted;
  final String? url;
  final int? expiry;
  final String? note;

  bool get pointsSomewhere => granted && url != null && url!.isNotEmpty;
}

/// Boot outcome.
sealed class Exit {
  const Exit();
}

/// Run the native game.
final class PlayExit extends Exit {
  const PlayExit();
}

/// Open the WebView at [url]. [pushedIn] marks a cold push-tap launch.
final class SiteExit extends Exit {
  const SiteExit(this.url, {this.pushedIn = false});

  final String url;
  final bool pushedIn;
}

/// No usable connection. Retry re-runs the boot.
final class DarkExit extends Exit {
  const DarkExit();
}
