import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/tlottie/tlottie_atlas.dart';
import 'package:komet/core/media/tlottie/tlottie_codec.dart';

Uint8List _frames(int px, int count) {
  final size = px * px * 4;
  final all = Uint8List(size * count);
  for (var i = 0; i < all.length; i++) {
    all[i] = (i ~/ size * 37 + i) & 0xff;
  }
  return all;
}

void main() {
  test('codec round-trips rendered frames', () {
    const px = 32;
    const count = 5;
    final frames = _frames(px, count);
    const header = EncodedClipHeader(
      px: px,
      frameCount: count,
      frameRate: 30,
      durationMs: 166,
    );

    final encoded = TlottieCodec.encode(header, frames);
    final decoded = TlottieCodec.decode(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.header.px, px);
    expect(decoded.header.frameCount, count);
    expect(decoded.header.frameRate, 30);
    expect(decoded.header.durationMs, 166);
    expect(decoded.frames, orderedEquals(frames));
    expect(
      frames,
      orderedEquals(_frames(px, count)),
      reason: 'input untouched',
    );
  });

  test('codec rejects foreign and truncated files', () {
    expect(TlottieCodec.decode(Uint8List(10)), isNull);
    final encoded = TlottieCodec.encode(
      const EncodedClipHeader(
        px: 8,
        frameCount: 2,
        frameRate: 30,
        durationMs: 66,
      ),
      _frames(8, 2),
    );
    final foreign = Uint8List.fromList(encoded)..[0] ^= 0xff;
    expect(TlottieCodec.decode(foreign), isNull);
  });

  test('atlas pages hold sixteen frames in a four column grid with gaps', () {
    const layout = AtlasLayout(px: 10, frameCount: 37);

    expect(layout.pageCount, 3);
    expect([for (var p = 0; p < 3; p++) layout.framesOn(p)], [16, 16, 5]);
    expect(layout.widthOf(0), 46);
    expect(layout.heightOf(0), 46);
    expect(layout.widthOf(2), 46);
    expect(layout.heightOf(2), 22);
    expect(layout.pageOf(16), 1);
    expect((layout.leftOf(21), layout.topOf(21)), (12, 12));
  });

  test('a short clip gets a page as narrow as its frames', () {
    const layout = AtlasLayout(px: 10, frameCount: 3);

    expect(layout.pageCount, 1);
    expect(layout.widthOf(0), 34);
    expect(layout.heightOf(0), 10);
  });

  test('blit puts every frame row into its own cell', () {
    const px = 4;
    const layout = AtlasLayout(px: px, frameCount: 6);
    final page = layout.allocate(0);
    final frames = _frames(px, 6);
    final size = px * px * 4;
    for (var f = 0; f < 6; f++) {
      layout.blit(
        page,
        f,
        Uint8List.sublistView(frames, f * size, (f + 1) * size),
      );
    }

    final stride = layout.widthOf(0) * 4;
    for (var f = 0; f < 6; f++) {
      for (var y = 0; y < px; y++) {
        final start = (layout.topOf(f) + y) * stride + layout.leftOf(f) * 4;
        expect(
          page.sublist(start, start + px * 4),
          orderedEquals(
            frames.sublist(f * size + y * px * 4, f * size + (y + 1) * px * 4),
          ),
          reason: 'frame $f row $y',
        );
      }
    }
  });

  test('the gap between cells stays transparent', () {
    const px = 4;
    const layout = AtlasLayout(px: px, frameCount: 6);
    final page = layout.allocate(0);
    final opaque = Uint8List(px * px * 4)..fillRange(0, px * px * 4, 0xff);
    for (var f = 0; f < 6; f++) {
      layout.blit(page, f, opaque);
    }

    final width = layout.widthOf(0);
    bool inCell(int x, int y) {
      for (var f = 0; f < 6; f++) {
        final left = layout.leftOf(f);
        final top = layout.topOf(f);
        if (x >= left && x < left + px && y >= top && y < top + px) return true;
      }
      return false;
    }

    for (var y = 0; y < layout.heightOf(0); y++) {
      for (var x = 0; x < width; x++) {
        final alpha = page[(y * width + x) * 4 + 3];
        expect(alpha, inCell(x, y) ? 0xff : 0, reason: 'pixel $x,$y');
      }
    }
  });
}
