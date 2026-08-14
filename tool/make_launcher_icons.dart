// Bakes every launcher-icon and splash asset from the master artwork so the
// adaptive icon (Android 8+), the Android 12+ SplashScreen and the legacy
// pre-8 launcher/splash all stay in sync.
//
// Strategy: full-bleed art. The master `Icon.png` is scaled to 68% of the
// canvas and centred over a two-stop vertical gradient sampled straight from
// the top/bottom rows of the master. That gives every bucket a self-contained
// PNG that a launcher can display without any mask surprises — the corners
// carry the gradient tone, so a circle/squircle/teardrop trims only gradient
// pixels, never the composition.
//
// Outputs:
//   * mipmap-{mdpi=108, hdpi=162, xhdpi=216, xxhdpi=324, xxxhdpi=432}/
//         ic_launcher.png                       — adaptive-icon canvas sized
//                                                 per dpi bucket. Also serves
//                                                 as the flat icon on Android
//                                                 <8 launchers.
//   * drawable-nodpi/ic_launcher_art.png (432)  — background drawable that
//                                                 mipmap-anydpi-v26/
//                                                 ic_launcher{,_round}.xml
//                                                 and drawable-anydpi-v26/
//                                                 ic_splash_logo.xml point at.
//   * drawable-nodpi/ic_splash_legacy.png (384) — pre-composited splash art
//                                                 for the Android <12
//                                                 layer-list splashes.
//
// It also prints the sampled top/bottom/midpoint hex codes; drop the midpoint
// into values/colors.xml → @color/launch_bg so the Android 12+ splash
// background lines up perfectly with the icon gradient (no visible seam when
// the launcher paints the splash on top of the running window background).
//
// Run with: dart run tool/make_launcher_icons.dart

import 'dart:io';

import 'package:image/image.dart' as img;

const String _source =
    'assets/Citadel_Clash_assets/Citadel_Clash_additional_assets/Icon.png';
const String _resDir = 'android/app/src/main/res';

// Adaptive-icon canvas sizes per dpi bucket (108dp scaled by the bucket dpi).
// These are the sizes the platform expects to blit for the raw mipmap PNGs.
const Map<String, int> _densityCanvasPx = <String, int>{
  'mipmap-mdpi': 108,
  'mipmap-hdpi': 162,
  'mipmap-xhdpi': 216,
  'mipmap-xxhdpi': 324,
  'mipmap-xxxhdpi': 432,
};

const int _launcherArtSize = 432;
const int _splashLegacySize = 384;

// Fraction of each canvas the master art occupies (68% → ~16% padding per
// side). Bump toward 0.70 if the composition already has generous transparent
// margins, drop toward 0.65 if the art is tight to the frame.
const double _scaleFactor = 0.68;

// How many rows from the top/bottom edge to average when sampling the
// gradient stops. Sampling more than a single row smooths out anti-aliasing
// artefacts on the very edge.
const int _sampleBand = 4;

void main() {
  final File sourceFile = File(_source);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Master icon not found at $_source');
    exit(1);
  }

  final img.Image master = img.decodeImage(sourceFile.readAsBytesSync())!;
  final _Rgb top = _averageBand(master, 0, _sampleBand);
  final _Rgb bottom = _averageBand(
    master,
    master.height - _sampleBand,
    _sampleBand,
  );
  final _Rgb mid = _Rgb(
    (top.r + bottom.r) ~/ 2,
    (top.g + bottom.g) ~/ 2,
    (top.b + bottom.b) ~/ 2,
  );

  _densityCanvasPx.forEach((String bucket, int size) {
    final File out = File('$_resDir/$bucket/ic_launcher.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(img.encodePng(_composite(master, size, top, bottom)));
  });

  final File art = File('$_resDir/drawable-nodpi/ic_launcher_art.png');
  art.parent.createSync(recursive: true);
  art.writeAsBytesSync(
    img.encodePng(_composite(master, _launcherArtSize, top, bottom)),
  );

  final File legacy = File('$_resDir/drawable-nodpi/ic_splash_legacy.png');
  legacy.writeAsBytesSync(
    img.encodePng(_composite(master, _splashLegacySize, top, bottom)),
  );

  stdout
    ..writeln('Launcher icons written under $_resDir')
    ..writeln('Gradient stops sampled from $_source:')
    ..writeln('  top    = ${top.hex}')
    ..writeln('  bottom = ${bottom.hex}')
    ..writeln('  midpoint (use as @color/launch_bg) = ${mid.hex}');
}

img.Image _composite(img.Image master, int size, _Rgb top, _Rgb bottom) {
  final img.Image canvas = img.Image(
    width: size,
    height: size,
    numChannels: 4,
  );

  for (int y = 0; y < size; y++) {
    final double t = size > 1 ? y / (size - 1) : 0.0;
    final img.ColorRgba8 row = img.ColorRgba8(
      (top.r + (bottom.r - top.r) * t).round(),
      (top.g + (bottom.g - top.g) * t).round(),
      (top.b + (bottom.b - top.b) * t).round(),
      255,
    );
    for (int x = 0; x < size; x++) {
      canvas.setPixel(x, y, row);
    }
  }

  final int inner = (size * _scaleFactor).round();
  final int offset = ((size - inner) / 2).round();
  final img.Image resized = img.copyResize(
    master,
    width: inner,
    height: inner,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(canvas, resized, dstX: offset, dstY: offset);
  return canvas;
}

_Rgb _averageBand(img.Image image, int y0, int rows) {
  int r = 0;
  int g = 0;
  int b = 0;
  int count = 0;
  final int yEnd = (y0 + rows).clamp(0, image.height);
  for (int y = y0.clamp(0, image.height - 1); y < yEnd; y++) {
    for (int x = 0; x < image.width; x++) {
      final img.Pixel px = image.getPixel(x, y);
      r += px.r.toInt();
      g += px.g.toInt();
      b += px.b.toInt();
      count++;
    }
  }
  return _Rgb(r ~/ count, g ~/ count, b ~/ count);
}

class _Rgb {
  const _Rgb(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;

  String get hex =>
      '#${_two(r)}${_two(g)}${_two(b)}'.toUpperCase();

  static String _two(int v) => v.clamp(0, 255).toRadixString(16).padLeft(2, '0');
}
