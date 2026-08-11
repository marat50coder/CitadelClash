// Off-tree generator: turns plaintext gray-flow secrets into the masked
// byte arrays consumed by lib/conduit/cipher/scrambler.dart -> unmask().
//
// This file NEVER ships (it lives under tool/). Run:
//   dart run tool/gate_mask.dart
// then paste the printed arrays into lib/conduit/cipher/masked.dart.
//
// Codec: FNV-1a(salt) seeds an LCG keystream; each byte is XOR'd with the
// keystream then pushed through an additive position ramp. This decode loop
// shape is intentionally distinct from every codec family in the reference
// template (which use XOR-only position masks / RC4 / plain FNV).

import 'dart:convert';

const List<int> _salt = <int>[
  0x5A, 0x13, 0xE7, 0x2C, 0x88, 0x41, 0xBD, 0x0F,
  0x96, 0x74, 0x33, 0xCE, 0xA1, 0x6B, 0x22, 0xDF,
  0x50, 0x9C, 0x07, 0xB4,
];
const int _streamLen = 29;

List<int> _keystream() {
  int seed = 0x811C9DC5;
  for (final int b in _salt) {
    seed = (seed ^ b) & 0xFFFFFFFF;
    seed = (seed * 0x01000193) & 0xFFFFFFFF;
  }
  int state = seed == 0 ? 0x1A2B3C4D : seed;
  final List<int> ks = List<int>.filled(_streamLen, 0);
  for (int i = 0; i < _streamLen; i++) {
    state = (state * 1664525 + 1013904223) & 0xFFFFFFFF;
    ks[i] = (state >> 24) & 0xFF;
  }
  return ks;
}

int _ramp(int i) => (i * 7 + 3) & 0xFF;

List<int> _mask(String plain) {
  if (plain.isEmpty) return const <int>[];
  final List<int> ks = _keystream();
  final List<int> src = utf8.encode(plain);
  final List<int> out = List<int>.filled(src.length, 0);
  for (int i = 0; i < src.length; i++) {
    out[i] = (((src[i] ^ ks[i % _streamLen]) + _ramp(i)) & 0xFF);
  }
  return out;
}

String _unmask(List<int> enc) {
  if (enc.isEmpty) return '';
  final List<int> ks = _keystream();
  final List<int> out = List<int>.filled(enc.length, 0);
  for (int i = 0; i < enc.length; i++) {
    out[i] = ((enc[i] - _ramp(i)) & 0xFF) ^ ks[i % _streamLen];
  }
  return utf8.decode(out);
}

String _fmt(String name, String plain) {
  final List<int> bytes = _mask(plain);
  final bool ok = _unmask(bytes) == plain;
  final StringBuffer buf = StringBuffer();
  buf.writeln('// roundtrip: ${ok ? 'OK' : 'MISMATCH'}  ($name)');
  buf.write('const List<int> $name = <int>[');
  for (int i = 0; i < bytes.length; i++) {
    if (i % 12 == 0) buf.write('\n  ');
    buf.write('0x${bytes[i].toRadixString(16).toUpperCase().padLeft(2, '0')}, ');
  }
  buf.writeln('\n];');
  if (!ok) {
    throw StateError('roundtrip failed for $name');
  }
  return buf.toString();
}

void main() {
  const Map<String, String> secrets = <String, String>{
    '_mConfigUrl': 'https://citadelclash.com/config.php',
    '_mGcdBase': 'https://gcdsdk.appsflyer.com/install_data/v4.0/',
    '_mAttrKey': '2uncHoBtcPaXBtvKvDXRU4',
    '_mFirebaseNo': '596053179548',
    '_mUaProduct': 'Mozilla/5.0',
    '_mUaPlatform': '(Linux; Android',
    '_mUaBuildTag': ' Build/',
    '_mUaClose': ')',
    '_mUaEngine': ' AppleWebKit/',
    '_mUaKhtml': ' (KHTML, like Gecko)',
    '_mUaChrome': ' Chrome/',
    '_mUaSafari': ' Mobile Safari/',
    '_mChromeVer': '149.0.7615.129',
    '_mWebkitVer': '537.36',
    '_mUaAppId': ' appid/',
    '_mUaAppName': ' appname/',
    '_mAppLabel': 'CitadelClash',
    '_mJsSafeArea':
        "(function(){if(window.__ccSafe)return;window.__ccSafe=1;var v=document.documentElement.style;var n=['--safe-area-inset-top','--safe-area-inset-right','--safe-area-inset-bottom','--safe-area-inset-left','--sat','--sar','--sab','--sal','--safe-top','--safe-bottom','--safe-left','--safe-right'];for(var i=0;i<n.length;i++){v.setProperty(n[i],'0px','important');}var css='.app-header,.gameview-mobile-header,.js-safe-top{padding-top:0!important;margin-top:0!important;}';var s=document.createElement('style');s.textContent=css;document.head.appendChild(s);})();",
    '_mJsKeyboard':
        "(function(){if(window.__ccKbd)return;window.__ccKbd=1;document.addEventListener('focusin',function(e){var t=e.target;if(!t)return;var g=(t.tagName||'').toLowerCase();if(g==='input'||g==='textarea'||t.isContentEditable){setTimeout(function(){try{t.scrollIntoView({block:'center',behavior:'smooth'});}catch(_){}} ,320);}},true);})();",
    '_mJsAutoplay':
        "(function(){if(window.__ccPlay)return;window.__ccPlay=1;var kick=function(){var d=document.getElementsByTagName('video');for(var i=0;i<d.length;i++){var el=d[i];el.muted=true;el.setAttribute('playsinline','');el.setAttribute('webkit-playsinline','');var p=el.play();if(p&&p.catch)p.catch(function(){});}};kick();setTimeout(kick,900);})();",
  };

  final StringBuffer out = StringBuffer();
  secrets.forEach((String name, String plain) {
    out.writeln(_fmt(name, plain));
  });
  // ignore: avoid_print
  print(out.toString());
}
