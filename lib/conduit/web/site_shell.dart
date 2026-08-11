import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../net/reach.dart';
import '../net/ua_builder.dart';
import '../push/push_center.dart';
import '../screens/no_net_screen.dart';
import '../settings/knobs.dart';
import '../store/locker.dart';
import 'injections.dart';

// ============================================================
// SITE SHELL — the WebView host (gray content)
// ============================================================
// Loads the destination URL with the device UA (same as the HTTP
// client), both orientations, immersive chrome, external-scheme
// hand-off, bounded redirect-loop recovery, a debounced connectivity
// guard, warm push-URL delivery, and a native file chooser bridge.
// There is NO client-side classification of the site — the shell is
// a dumb container; any funnel logic lives on the backend.
// ============================================================

class SiteShell extends StatefulWidget {
  const SiteShell({
    super.key,
    required this.url,
    required this.locker,
    required this.push,
  });

  final String url;
  final Locker locker;
  final PushCenter push;

  @override
  State<SiteShell> createState() => _SiteShellState();
}

class _SiteShellState extends State<SiteShell> with WidgetsBindingObserver {
  static const MethodChannel _files = MethodChannel('citadel/files');

  late final WebViewController _web;
  bool _busy = true;
  bool _leftForOffline = false;
  String? _lastTop;
  int _loopHits = 0;
  Timer? _dropTimer;
  StreamSubscription<List<ConnectivityResult>>? _netSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _immersive();
    _createController();

    widget.push.onUrl = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    _netSub = Reach().changes.listen((List<ConnectivityResult> r) {
      final bool allDown = r.isNotEmpty &&
          r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allDown) {
        _dropTimer?.cancel();
        return;
      }
      _dropTimer?.cancel();
      _dropTimer = Timer(
        Duration(milliseconds: Knobs.dropDebounceMs),
        _gotoOffline,
      );
    });
  }

  void _immersive() {
    // Hide the system navigation bar entirely; a swipe from the edge
    // temporarily reveals it (immersiveSticky) so the user can still get
    // out, but the WebView renders edge-to-edge with no chrome.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _immersive();
  }

  void _createController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(UaBuilder.value)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _busy = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _busy = false);
          _loopHits = 0;
          Injections.run(_web);
        },
        onWebResourceError: _onError,
        onNavigationRequest: _onNavigate,
      ));

    _wireAndroid();
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _onError(WebResourceError err) {
    if (err.isForMainFrame != true) return;
    final String blurb = err.description.toLowerCase();

    final bool loop = blurb.contains('too_many_redirects') ||
        blurb.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;
    if (loop && _lastTop != null && _loopHits < Knobs.loopRetries) {
      _loopHits++;
      _web.loadRequest(Uri.parse(_lastTop!));
      return;
    }

    // Hide the native error page immediately.
    if (mounted) setState(() => _busy = true);

    final bool dnsOrDrop = blurb.contains('name_not_resolved') ||
        blurb.contains('address_unreachable') ||
        blurb.contains('internet_disconnected') ||
        blurb.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21 ||
        err.errorCode == -2 ||
        err.errorCode == -6;

    if (dnsOrDrop) {
      _gotoOffline();
    } else {
      _gotoOfflineIfDown();
    }
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final Uri? uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    const Set<String> inApp = <String>{'http', 'https', 'about', 'data', 'blob'};
    if (inApp.contains(uri.scheme)) {
      if (req.isMainFrame) _lastTop = req.url;
      return NavigationDecision.navigate;
    }
    _openOutside(uri);
    return NavigationDecision.prevent;
  }

  void _wireAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController c = _web.platform as AndroidWebViewController;
    c.setMediaPlaybackRequiresUserGesture(false);
    c.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest r) => r.grant(),
    );
    c.setOnShowFileSelector(_chooseFiles);

    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(c, true);
  }

  Future<List<String>> _chooseFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked =
          await _files.invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openOutside(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _gotoOfflineIfDown() async {
    if (_leftForOffline) return;
    if (await Reach().canReach()) return;
    _gotoOffline();
  }

  void _gotoOffline() {
    if (_leftForOffline || !mounted) return;
    _leftForOffline = true;
    final String here = _lastTop ?? widget.url;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoNetScreen(
          rebuild: (_) => SiteShell(
            url: here,
            locker: widget.locker,
            push: widget.push,
          ),
        ),
      ),
    );
  }

  Future<void> _back() async {
    if (await _web.canGoBack()) await _web.goBack();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dropTimer?.cancel();
    _netSub?.cancel();
    widget.push.onUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: MediaQuery.viewPaddingOf(context),
              child: WebViewWidget(controller: _web),
            ),
            if (_busy && !landscape)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFF7C637)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
