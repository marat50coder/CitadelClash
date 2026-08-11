import 'package:webview_flutter/webview_flutter.dart';

import '../cipher/masked.dart';

// ============================================================
// INJECTIONS — JavaScript enhancers run on every page finish
// ============================================================
// Each body lives masked in the cipher store and is assembled at
// runtime, so no normalized JS body hashes ship in the binary. Each
// enhancer is idempotent (guarded by its own window flag) so running
// them on every onPageFinished is safe.
//
// Safe-area rule: the body only zeroes the site's own safe-area CSS
// variables and top spacers on known header classes — it never touches
// html/body/#app/#root horizontal padding, so the partner layout keeps
// its designed gutters.
// ============================================================

abstract final class Injections {
  static Future<void> run(WebViewController controller) async {
    for (final String body in <String>[
      pullJsSafeArea(),
      pullJsKeyboard(),
      pullJsAutoplay(),
    ]) {
      if (body.isEmpty) continue;
      try {
        await controller.runJavaScript(body);
      } catch (_) {}
    }
  }
}
