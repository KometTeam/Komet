import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class DominantColorCache {
  DominantColorCache._();

  static final DominantColorCache instance = DominantColorCache._();

  static const int _sampleExtent = 8;
  static const int _maxEntries = 256;
  static const int _minAlpha = 8;
  static const double _achromaticFloor = 0.15;
  static const Duration _missingFileCooldown = Duration(seconds: 3);

  final Map<String, Color> _resolved = <String, Color>{};
  final Set<String> _inFlight = <String>{};
  final Set<String> _rejected = <String>{};
  final Map<String, DateTime> _retryAfter = <String, DateTime>{};

  Color? lookup(String url) => _resolved[url];

  void request(String url, VoidCallback onResolved) {
    if (_resolved.containsKey(url) ||
        _inFlight.contains(url) ||
        _rejected.contains(url)) {
      return;
    }
    final retryAt = _retryAfter[url];
    if (retryAt != null && DateTime.now().isBefore(retryAt)) return;

    _inFlight.add(url);
    _extract(url).then((outcome) {
      _inFlight.remove(url);
      switch (outcome) {
        case _ExtractionMissing():
          _retryAfter[url] = DateTime.now().add(_missingFileCooldown);
        case _ExtractionRejected():
          _rejected.add(url);
          _retryAfter.remove(url);
        case _ExtractionResolved(color: final color):
          _retryAfter.remove(url);
          _store(url, color);
          onResolved();
      }
    });
  }

  void _store(String url, Color color) {
    if (_resolved.length >= _maxEntries) {
      _resolved.remove(_resolved.keys.first);
    }
    _resolved[url] = color;
  }

  Future<_ExtractionOutcome> _extract(String url) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      final cached = await DefaultCacheManager().getFileFromCache(url);
      if (cached == null) return const _ExtractionMissing();

      final bytes = await cached.file.readAsBytes();
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _sampleExtent,
        targetHeight: _sampleExtent,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null) return const _ExtractionRejected();

      final color = _average(raw.buffer.asUint8List());
      if (color == null) return const _ExtractionRejected();
      return _ExtractionResolved(color);
    } catch (_) {
      return const _ExtractionRejected();
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  Color? _average(Uint8List pixels) {
    var accumulatedRed = 0.0;
    var accumulatedGreen = 0.0;
    var accumulatedBlue = 0.0;
    var accumulatedWeight = 0.0;

    for (var offset = 0; offset + 3 < pixels.length; offset += 4) {
      final alpha = pixels[offset + 3];
      if (alpha < _minAlpha) continue;

      final red = pixels[offset].toDouble();
      final green = pixels[offset + 1].toDouble();
      final blue = pixels[offset + 2].toDouble();

      final brightest = red > green
          ? (red > blue ? red : blue)
          : (green > blue ? green : blue);
      final darkest = red < green
          ? (red < blue ? red : blue)
          : (green < blue ? green : blue);
      final saturation = brightest <= 0 ? 0.0 : (brightest - darkest) / brightest;

      final weight = (alpha / 255) * (_achromaticFloor + saturation);
      accumulatedRed += red * weight;
      accumulatedGreen += green * weight;
      accumulatedBlue += blue * weight;
      accumulatedWeight += weight;
    }

    if (accumulatedWeight <= 0) return null;
    return Color.fromARGB(
      255,
      (accumulatedRed / accumulatedWeight).round().clamp(0, 255),
      (accumulatedGreen / accumulatedWeight).round().clamp(0, 255),
      (accumulatedBlue / accumulatedWeight).round().clamp(0, 255),
    );
  }
}

sealed class _ExtractionOutcome {
  const _ExtractionOutcome();
}

class _ExtractionMissing extends _ExtractionOutcome {
  const _ExtractionMissing();
}

class _ExtractionRejected extends _ExtractionOutcome {
  const _ExtractionRejected();
}

class _ExtractionResolved extends _ExtractionOutcome {
  const _ExtractionResolved(this.color);

  final Color color;
}
