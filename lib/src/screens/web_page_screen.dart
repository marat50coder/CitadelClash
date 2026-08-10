import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_assets.dart';
import '../core/ui_kit.dart';

/// In-app browser used for the Privacy Policy and Support pages. The rest of
/// the game never touches the network, so a failure here only affects this
/// screen and is reported with the offline artwork.
class WebPageScreen extends StatefulWidget {
  const WebPageScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  static const String privacyPolicyUrl =
      'https://citadelclash.com/privacy-policy.html';
  static const String supportUrl = 'https://citadelclash.com/support.html';

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted || error.isForMainFrame == false) return;
            setState(() {
              _loading = false;
              _failed = true;
            });
          },
        ),
      );
    _load();
  }

  void _load() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The game runs fullscreen, so the display cutout is read from viewPadding
    // rather than SafeArea, which reports zero while the bars are hidden.
    final EdgeInsets inset = MediaQuery.viewPaddingOf(context);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppPalette.panel,
        body: Padding(
          padding: EdgeInsets.only(top: inset.top, bottom: inset.bottom),
          child: Column(
            children: <Widget>[
              _buildBar(),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (!_failed) WebViewWidget(controller: _controller),
                    if (_failed) _buildOffline(),
                    if (_loading && !_failed)
                      const ColoredBox(
                        color: Colors.white,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppPalette.goldDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF3B2611), Color(0xFF1B1006)],
        ),
        border: Border(bottom: BorderSide(color: AppPalette.gold, width: 3)),
      ),
      child: Row(
        children: <Widget>[
          RoundGoldButton(
            icon: Icons.arrow_back_rounded,
            size: 40,
            onTap: _handleBack,
          ),
          Expanded(
            child: Center(
              child: StrokedText(
                widget.title,
                size: 18,
                color: AppPalette.goldLight,
                strokeWidth: 3.5,
              ),
            ),
          ),
          RoundGoldButton(icon: Icons.refresh_rounded, size: 40, onTap: _load),
        ],
      ),
    );
  }

  Widget _buildOffline() {
    final bool portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          portrait ? AppAssets.offlinePortrait : AppAssets.offlineLandscape,
          fit: BoxFit.cover,
        ),
        const DecoratedBox(decoration: BoxDecoration(color: Color(0x66000000))),
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              const StrokedText(
                'This page needs a connection',
                size: 22,
                strokeWidth: 4,
              ),
              const SizedBox(height: 8),
              const StrokedText(
                'The game itself works fully offline.',
                size: 15,
                color: Color(0xFFE9C88A),
                strokeWidth: 3,
              ),
              const SizedBox(height: 22),
              PlaqueButton(label: 'TRY AGAIN', height: 58, onTap: _load),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}
