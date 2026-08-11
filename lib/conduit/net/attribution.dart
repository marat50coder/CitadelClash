import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../cipher/masked.dart';
import '../settings/knobs.dart';
import 'tagged_client.dart';

// ============================================================
// ATTRIBUTION — AppsFlyer install + deep-link collector
// ============================================================
// Gathers install-conversion, deep-link and app-open payloads and
// folds them into the config request body.
//
// Organic rescue: AppsFlyer sometimes reports `af_status: Organic` on
// the first callback for genuinely paid installs. When that happens we
// wait, re-query GCD, and prefer the rescued payload. If GCD fails we
// keep Organic (which routes to the safe native game).
//
// With no dev key packed the SDK never boots and the futures resolve
// empty so QA can still reach the game path.
// ============================================================

class Attribution {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _install;
  Map<String, dynamic>? _deepLink;
  Map<String, dynamic>? _appOpen;

  final Completer<void> _installDone = Completer<void>();
  final Completer<void> _deepLinkDone = Completer<void>();
  bool _booted = false;

  Future<void> boot() async {
    if (_booted) return;
    _booted = true;

    final String key = Knobs.attributionKey;
    if (key.isEmpty) {
      _finishInstall();
      _finishDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: key,
      appId: Knobs.appleStoreId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 8,
    );
    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic raw) async {
      final Map<String, dynamic> data = _flatten(raw);
      if (data['af_status']?.toString() == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: Knobs.organicRescueSeconds),
        );
        _install = await _gcdRescue() ?? data;
      } else {
        _install = data;
      }
      _finishInstall();
    });

    sdk.onAppOpenAttribution((dynamic raw) => _appOpen = _flatten(raw));

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? ev = result.deepLink?.clickEvent;
      if (ev != null) _deepLink = Map<String, dynamic>.from(ev);
      _finishDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _finishInstall();
      _finishDeepLink();
    }
  }

  Future<void> settle({required int installSeconds}) async {
    await Future.wait<void>(<Future<void>>[
      _installDone.future.timeout(
        Duration(seconds: installSeconds),
        onTimeout: () {},
      ),
      _deepLinkDone.future.timeout(
        Duration(seconds: Knobs.deepLinkWaitSeconds),
        onTimeout: () {},
      ),
    ]);
  }

  Future<String?> uid() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> assemble({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (_install != null) body.addAll(_install!);
    _deepLink?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpen?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await uid() ?? '';
    body['bundle_id'] = Knobs.packageId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = Knobs.storeRef;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    if (Knobs.firebaseNumber.isNotEmpty) {
      body['firebase_project_id'] = Knobs.firebaseNumber;
    }

    assert(() {
      // ignore: avoid_print
      print('[conduit.attr] ${jsonEncode(body)}');
      return true;
    }());
    return body;
  }

  Future<Map<String, dynamic>?> _gcdRescue() async {
    try {
      final String? device = await uid();
      if (device == null) return null;
      final String ref =
          Platform.isIOS ? Knobs.appleStoreId : Knobs.packageId;
      final String url = pullGcdCallUrl(ref, device);
      if (url.isEmpty) return null;
      final dynamic res = await taggedClient.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${Knobs.attributionKey}',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _finishInstall() {
    if (!_installDone.isCompleted) _installDone.complete();
  }

  void _finishDeepLink() {
    if (!_deepLinkDone.isCompleted) _deepLinkDone.complete();
  }

  static Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final dynamic inner = raw['payload'] ?? raw['data'] ?? raw;
    if (inner is Map) {
      return inner.map(
        (dynamic k, dynamic v) => MapEntry<String, dynamic>(k.toString(), v),
      );
    }
    return <String, dynamic>{};
  }
}
