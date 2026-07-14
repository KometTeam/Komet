import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../config/chat_wallpaper_themes.dart';
import '../storage/chat_wallpaper_store.dart';

Future<Color?> computeWallpaperSeed(ChatWallpaper? wallpaper) async {
  if (wallpaper == null) return null;
  if (!wallpaper.isImage) {
    final theme = chatWallpaperThemeById(wallpaper.themeId);
    if (theme == null) return null;
    return _mostVivid(theme.colors);
  }
  final path = wallpaper.imagePath;
  if (path == null) return null;
  try {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final small = img.copyResize(decoded, width: 8, height: 8);
    var r = 0, g = 0, b = 0, n = 0;
    for (final pixel in small) {
      r += pixel.r.toInt();
      g += pixel.g.toInt();
      b += pixel.b.toInt();
      n++;
    }
    if (n == 0) return null;
    return Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
  } catch (_) {
    return null;
  }
}

Color _mostVivid(List<Color> colors) {
  var best = colors.first;
  var bestScore = -1.0;
  for (final color in colors) {
    final hsl = HSLColor.fromColor(color);
    final score = hsl.saturation * (1 - (hsl.lightness - 0.5).abs());
    if (score > bestScore) {
      bestScore = score;
      best = color;
    }
  }
  return best;
}
