// Generates full-bleed launcher icon sources from the master artwork.
//
// Android masks an adaptive icon down to the centre 72/108 of each layer, so the
// artwork is placed inside that safe zone and the remaining border is filled by
// clamping the edge pixels. The result covers the whole icon surface with no
// empty margins whatever mask shape the launcher applies.
//
// Run with: dart run tool/make_launcher_icons.dart

import 'dart:io';

import 'package:image/image.dart' as img;

const String _source =
    'assets/Citadel_Clash_assets/Citadel_Clash_additional_assets/Icon.png';
const String _outDir = 'assets/launcher';
const int _canvas = 1024;

void main() {
  final File sourceFile = File(_source);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Master icon not found at $_source');
    exit(1);
  }

  final img.Image master = img.decodeImage(sourceFile.readAsBytesSync())!;
  Directory(_outDir).createSync(recursive: true);

  final img.Image square = img.copyResize(
    master,
    width: _canvas,
    height: _canvas,
    interpolation: img.Interpolation.cubic,
  );
  File('$_outDir/icon_full.png').writeAsBytesSync(img.encodePng(square));

  const int safeZone = (_canvas * 72) ~/ 108;
  const int margin = (_canvas - safeZone) ~/ 2;
  final img.Image inner = img.copyResize(
    master,
    width: safeZone,
    height: safeZone,
    interpolation: img.Interpolation.cubic,
  );

  final img.Image background = img.Image(
    width: _canvas,
    height: _canvas,
    numChannels: 4,
  );
  img.compositeImage(background, inner, dstX: margin, dstY: margin);

  const int last = margin + safeZone - 1;
  for (int y = 0; y < _canvas; y++) {
    for (int x = 0; x < _canvas; x++) {
      if (x >= margin && x <= last && y >= margin && y <= last) continue;
      final int sx = x.clamp(margin, last);
      final int sy = y.clamp(margin, last);
      background.setPixel(x, y, background.getPixel(sx, sy));
    }
  }
  File(
    '$_outDir/icon_adaptive_back.png',
  ).writeAsBytesSync(img.encodePng(background));

  final img.Image foreground = img.Image(
    width: _canvas,
    height: _canvas,
    numChannels: 4,
  );
  img.fill(foreground, color: img.ColorRgba8(0, 0, 0, 0));
  File(
    '$_outDir/icon_adaptive_fore.png',
  ).writeAsBytesSync(img.encodePng(foreground));

  stdout.writeln('Launcher icon sources written to $_outDir');
}
