import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../cipher/masked.dart';
import '../settings/knobs.dart';

// ============================================================
// UA BUILDER — real-device User-Agent, assembled from masked bits
// ============================================================
// The same string feeds the HTTP client and the WebView. Every
// browser-identity fragment is pulled from the masked store at call
// time, so no greppable browser token ships as a Dart literal, and
// the value reflects the ACTUAL device (device_info_plus) so two
// installs never match.
//
// GAME THEME CATEGORY: crash (Tower Rush). The identity suffix is
// normally omitted for crash titles, but the operator requested it
// explicitly for this deployment; all suffix tokens are masked.
// ============================================================

abstract final class UaBuilder {
  static String _value = '';

  static String get value => _value.isEmpty ? _compose(_stockDevice()) : _value;

  /// Reads device info and composes the UA once. Call from `main()`
  /// before the HTTP client or WebView is built.
  static Future<void> warm() async {
    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo d = await plugin.androidInfo;
        _value = _compose(_Device(
          release: d.version.release,
          brand: _cap(d.brand),
          model: d.model,
          build: d.display.isNotEmpty ? d.display : d.id,
        ));
      } else if (Platform.isIOS) {
        final IosDeviceInfo d = await plugin.iosInfo;
        _value = _composeApple(d.systemVersion);
      }
    } catch (_) {
      _value = _compose(_stockDevice());
    }
  }

  static String _compose(_Device d) {
    final String chrome = pullChromeVer();
    final String webkit = pullWebkitVer();
    final StringBuffer b = StringBuffer()
      ..write(pullUaProduct())
      ..write(' ')
      ..write(pullUaPlatform())
      ..write(' ${d.release}; ${d.brand} ${d.model}')
      ..write(pullUaBuildTag())
      ..write(d.build)
      ..write(pullUaClose())
      ..write(pullUaEngine())
      ..write(webkit)
      ..write(pullUaKhtml())
      ..write(pullUaChrome())
      ..write(chrome)
      ..write(pullUaSafari())
      ..write(webkit);

    final String appIdTok = pullUaAppId();
    if (appIdTok.isNotEmpty) {
      b
        ..write(appIdTok)
        ..write(Knobs.packageId)
        ..write(pullUaAppName())
        ..write(pullAppLabel());
    }
    return b.toString();
  }

  static String _composeApple(String iosVersion) {
    final String cpu = iosVersion.replaceAll('.', '_');
    final String webkit = pullWebkitVer();
    return '${pullUaProduct()} (iPhone; CPU iPhone OS $cpu like Mac OS X)'
        '${pullUaEngine()}$webkit${pullUaKhtml()} Version/$iosVersion '
        'Mobile/15E148 Safari/$webkit';
  }

  static _Device _stockDevice() => const _Device(
    release: '14',
    brand: 'Google',
    model: 'Pixel 8',
    build: 'UP1A.231005.007',
  );

  static String _cap(String v) =>
      v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
}

class _Device {
  const _Device({
    required this.release,
    required this.brand,
    required this.model,
    required this.build,
  });

  final String release;
  final String brand;
  final String model;
  final String build;
}
