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
      _kbShim,
      pullJsAutoplay(),
    ]) {
      if (body.isEmpty) continue;
      try {
        await controller.runJavaScript(body);
      } catch (_) {}
    }
  }
}

// Keyboard shim — same approach we ship in the FlameSurge reference.
// When the IME opens, Chromium's `visualViewport.height` shrinks; ask the
// browser to `scrollIntoView` the focused field. Two triggers cover every
// case:
//   1. `focusin` with a 350 ms delay — waits for the IME open animation
//      to complete before scrolling, so the input lands directly above
//      the keyboard without a visible jump.
//   2. `visualViewport.resize` (shrinking) with a 120 ms delay — catches
//      autofocus / programmatic focus that fires before the field is in
//      the DOM.
// `behavior: 'auto'` — smooth-scroll on Android fights the IME animation.
const String _kbShim = r'''
(function(){
  if (window.__cq_kb_shim) return;
  window.__cq_kb_shim = true;

  function isInput(el){
    return el && (el.tagName === 'INPUT' ||
                  el.tagName === 'TEXTAREA' ||
                  el.isContentEditable);
  }

  function reveal(){
    var el = document.activeElement;
    if(!isInput(el)) return;
    var vp = window.visualViewport;
    if(vp){
      var rect = el.getBoundingClientRect();
      var vpBottom = vp.offsetTop + vp.height;
      if(rect.bottom > vpBottom - 20 || rect.top < vp.offsetTop){
        el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
      }
    } else {
      el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
    }
  }

  document.addEventListener('focusin', function(e){
    if(isInput(e.target)) setTimeout(reveal, 350);
  });

  if(window.visualViewport){
    var prevH = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height;
      if(h < prevH) setTimeout(reveal, 120);
      prevH = h;
    });
  }
})();
''';
