import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../settings/knobs.dart';

// ============================================================
// REACH — connectivity adapter check + DNS reachability
// ============================================================
// `connectivity_plus` alone lies (captive gateways, half-up VPN
// interfaces, dead cells all report "connected"), so a real DNS
// lookup gates the online decision. VPN/bluetooth/ethernet count as
// live adapters — dropping them produced false-offline results on
// real users.
// ============================================================

const Set<ConnectivityResult> _liveAdapters = <ConnectivityResult>{
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

// Neutral, cheap-DNS hosts unrelated to the partner or config domain.
const List<String> _dnsHosts = <String>['google.com', 'github.com'];

class Reach {
  Reach({Connectivity? plugin}) : _plugin = plugin ?? Connectivity();

  final Connectivity _plugin;
  int _cursor = 0;

  Stream<List<ConnectivityResult>> get changes => _plugin.onConnectivityChanged;

  /// True when at least one adapter is up. No DNS lookup.
  Future<bool> hasLink() async {
    try {
      final List<ConnectivityResult> now = await _plugin.checkConnectivity();
      return now.any(_liveAdapters.contains);
    } catch (_) {
      return false;
    }
  }

  /// True when at least one probe host resolves inside the timeout.
  Future<bool> canReach() async {
    if (!await hasLink()) return false;
    final Duration limit = Duration(seconds: Knobs.reachTimeoutSeconds);
    for (int i = 0; i < _dnsHosts.length; i++) {
      final String host = _dnsHosts[(_cursor + i) % _dnsHosts.length];
      try {
        final List<InternetAddress> hit =
            await InternetAddress.lookup(host).timeout(limit);
        if (hit.any((InternetAddress a) => a.rawAddress.isNotEmpty)) {
          _cursor = (_cursor + 1) % _dnsHosts.length;
          return true;
        }
      } catch (_) {
        // fall through to the next host
      }
    }
    return false;
  }
}
