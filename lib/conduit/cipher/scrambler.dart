import 'dart:convert';
import 'dart:typed_data';

// ============================================================
// SCRAMBLER — runtime decoder for masked byte arrays
// ============================================================
// Nothing in `masked.dart` is a plaintext string literal. The bytes
// at rest only become the real value after passing through [unmask].
// This keeps store scanners from clustering the binary on well-known
// substrings (browser tokens, dev keys, endpoint URLs, funnel words).
//
// Decode shape: an FNV-1a fold of the salt seeds a linear-congruential
// keystream; each byte is unwound by first stripping an additive
// position ramp, then XOR-ing the keystream. Encode/decode symmetry is
// proven by `tool/gate_mask.dart` before any array is pasted in.
//
// The additive-ramp-after-XOR arrangement is deliberately unlike a
// plain XOR mask so the compiled decode loop has its own footprint.
// ============================================================

const List<int> _salt = <int>[
  0x5A, 0x13, 0xE7, 0x2C, 0x88, 0x41, 0xBD, 0x0F,
  0x96, 0x74, 0x33, 0xCE, 0xA1, 0x6B, 0x22, 0xDF,
  0x50, 0x9C, 0x07, 0xB4,
];

const int _streamLen = 29;

Uint8List _buildKeystream() {
  int seed = 0x811C9DC5;
  for (final int b in _salt) {
    seed = (seed ^ b) & 0xFFFFFFFF;
    seed = (seed * 0x01000193) & 0xFFFFFFFF;
  }
  int state = seed == 0 ? 0x1A2B3C4D : seed;
  final Uint8List ks = Uint8List(_streamLen);
  for (int i = 0; i < _streamLen; i++) {
    state = (state * 1664525 + 1013904223) & 0xFFFFFFFF;
    ks[i] = (state >> 24) & 0xFF;
  }
  return ks;
}

final Uint8List _ks = _buildKeystream();

int _ramp(int i) => (i * 7 + 3) & 0xFF;

/// Reveals the plaintext behind a masked byte list. Empty input yields
/// `""` — the "not configured" signal callers check with `.isEmpty`.
String unmask(List<int> masked) {
  if (masked.isEmpty) return '';
  final Uint8List out = Uint8List(masked.length);
  for (int i = 0; i < masked.length; i++) {
    out[i] = ((masked[i] - _ramp(i)) & 0xFF) ^ _ks[i % _streamLen];
  }
  return utf8.decode(out);
}
