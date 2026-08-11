import 'dart:async';
import 'dart:io';

import 'model/exit.dart';
import 'net/attribution.dart';
import 'net/reach.dart';
import 'net/server_ask.dart';
import 'push/push_center.dart';
import 'settings/knobs.dart';
import 'store/locker.dart';

// ============================================================
// SWITCHBOARD — the single boot decision
// ============================================================
// `route(onStep)` returns an [Exit]; the warmup screen switches on it
// and pushes exactly one route. No routing logic lives anywhere else.
//
// Branches on the persisted [Lane]:
//   fresh → no link: DarkExit · dns fail: DarkExit · granted: SiteExit
//           · denied: PlayExit
//   site  → no link: DarkExit · cold-tap url: SiteExit · fresh cache:
//           SiteExit · granted: SiteExit · denied+cache: SiteExit(cache)
//           · else DarkExit
//   play  → no link: PlayExit (never blocks) · granted: SiteExit ·
//           denied: PlayExit
//
// Concurrent calls share one in-flight future so a double build does
// not fire two config POSTs; it clears on completion so a retry re-runs
// the whole pipeline.
// ============================================================

class Switchboard {
  Switchboard({
    required this.locker,
    required this.reach,
    required this.attribution,
    required this.server,
    required this.push,
  });

  final Locker locker;
  final Reach reach;
  final Attribution attribution;
  final ServerAsk server;
  final PushCenter push;

  Future<Exit>? _pending;

  Future<Exit> route({void Function(double)? onStep}) {
    return _pending ??=
        _route(onStep ?? (_) {}).whenComplete(() => _pending = null);
  }

  /// Drop the in-flight route so the next [route] call starts over.
  /// Used when a push tap arrives during (or after) a running route:
  /// the old decision was made before the new URL was stashed, so a
  /// fresh evaluation is required. The old future keeps running to
  /// completion; its result is simply discarded.
  void invalidate() {
    _pending = null;
  }

  Future<Exit> _route(void Function(double) step) async {
    if (!Knobs.gateArmed) {
      step(1);
      return const PlayExit();
    }

    push.onToken = _reAskOnToken;

    final String? cold = await locker.takeColdUrl();
    if (cold != null && cold.isNotEmpty) {
      await locker.keepLane(Lane.site);
      unawaited(_backgroundRefresh());
      step(1);
      return SiteExit(cold, pushedIn: true);
    }

    step(0.18);
    return switch (locker.lane) {
      Lane.fresh => _fromFresh(step),
      Lane.site => _fromSite(step),
      Lane.play => _fromPlay(step),
    };
  }

  Future<Exit> _fromFresh(void Function(double) step) async {
    if (!await reach.hasLink()) return const DarkExit();
    step(0.34);
    try {
      await push.boot();
    } catch (_) {}
    final Exit? tapped = await _pickTappedUrl(step);
    if (tapped != null) return tapped;
    if (!await reach.canReach()) return const DarkExit();
    step(0.52);
    await attribution.boot();
    await attribution.settle(installSeconds: Knobs.firstWaitSeconds);
    step(0.78);
    final ServerReply reply = await _query();
    step(1);
    if (reply.pointsSomewhere) {
      await locker.keepLane(Lane.site);
      return SiteExit(reply.url!);
    }
    await locker.keepLane(Lane.play);
    return const PlayExit();
  }

  Future<Exit> _fromSite(void Function(double) step) async {
    if (!await reach.hasLink()) return const DarkExit();

    final String? cached = await locker.cachedDest();
    if (cached != null && !locker.cachedDestStale) {
      step(1);
      return SiteExit(cached);
    }

    await Future.wait<void>(<Future<void>>[push.boot(), attribution.boot()]);
    final Exit? tapped = await _pickTappedUrl(step);
    if (tapped != null) return tapped;
    if (!await reach.canReach()) {
      if (cached != null) return SiteExit(cached);
      return const DarkExit();
    }
    step(0.62);
    await attribution.settle(installSeconds: Knobs.returnWaitSeconds);
    final ServerReply reply = await _query();
    step(1);
    if (reply.pointsSomewhere) return SiteExit(reply.url!);
    if (cached != null) return SiteExit(cached);
    return const DarkExit();
  }

  Future<Exit> _fromPlay(void Function(double) step) async {
    if (!await reach.hasLink()) {
      step(1);
      return const PlayExit();
    }
    await Future.wait<void>(<Future<void>>[push.boot(), attribution.boot()]);
    final Exit? tapped = await _pickTappedUrl(step);
    if (tapped != null) return tapped;
    if (!await reach.canReach()) {
      step(1);
      return const PlayExit();
    }
    step(0.58);
    await attribution.settle(installSeconds: Knobs.returnWaitSeconds);
    final ServerReply reply = await _query();
    step(1);
    if (!reply.pointsSomewhere) return const PlayExit();
    await locker.keepLane(Lane.site);
    return SiteExit(reply.url!);
  }

  /// After [push.boot] resolved `getInitialMessage()` (the cold-tap that
  /// woke the app), the URL is now in the locker. Consume it here so the
  /// tap always trumps the cached/server destination.
  Future<Exit?> _pickTappedUrl(void Function(double) step) async {
    final String? url = await locker.takeColdUrl();
    if (url == null || url.isEmpty) return null;
    await locker.keepLane(Lane.site);
    step(1);
    return SiteExit(url, pushedIn: true);
  }

  Future<ServerReply> _query({String? token}) async {
    final Map<String, dynamic> body = await attribution.assemble(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? push.token,
    );
    return server.ask(body);
  }

  Future<void> _backgroundRefresh() async {
    try {
      await Future.wait<void>(<Future<void>>[push.boot(), attribution.boot()]);
      await attribution.settle(installSeconds: Knobs.returnWaitSeconds);
      await _query();
    } catch (_) {}
  }

  Future<void> _reAskOnToken(String token) async {
    try {
      await _query(token: token);
    } catch (_) {}
  }
}
