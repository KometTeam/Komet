import 'package:flutter/material.dart';

import '../utils/tiled_svg.dart';

@immutable
class ChatWallpaperTheme {
  final String id;
  final String name;
  final List<Color> colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final String? pattern;
  final Color patternColor;
  final double patternOpacity;
  final double tileSize;
  final bool dark;

  const ChatWallpaperTheme({
    required this.id,
    required this.name,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.pattern,
    this.patternColor = Colors.white,
    this.patternOpacity = 0.1,
    this.tileSize = 130,
    this.dark = true,
  });

  Gradient get gradient =>
      LinearGradient(colors: colors, begin: begin, end: end);

  Color get bubbleTint => colors.first;

  Widget buildBackground() => _ChatWallpaperThemeView(theme: this);

  Widget buildPreview() =>
      _ChatWallpaperThemeView(theme: this, tileScale: 0.42);
}

class _ChatWallpaperThemeView extends StatelessWidget {
  final ChatWallpaperTheme theme;
  final double tileScale;

  const _ChatWallpaperThemeView({required this.theme, this.tileScale = 1});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: theme.gradient)),
        if (theme.pattern != null)
          TiledSvgPattern(
            asset: theme.pattern!,
            color: theme.patternColor,
            opacity: theme.patternOpacity,
            tileSize: theme.tileSize * tileScale,
          ),
      ],
    );
  }
}

const String _kPatternDir = 'assets/wallpapers/patterns';

const List<ChatWallpaperTheme> kChatWallpaperThemes = <ChatWallpaperTheme>[
  ChatWallpaperTheme(
    id: 'ocean',
    name: 'Океан',
    colors: [Color(0xFF2A7B9B), Color(0xFF57C1EB), Color(0xFF246FA8)],
    pattern: '$_kPatternDir/bubbles.svg',
    patternOpacity: 0.1,
  ),
  ChatWallpaperTheme(
    id: 'sunset',
    name: 'Закат',
    colors: [Color(0xFFFF7E5F), Color(0xFFFEB47B)],
    pattern: '$_kPatternDir/hearts.svg',
    patternOpacity: 0.12,
  ),
  ChatWallpaperTheme(
    id: 'lavender',
    name: 'Лаванда',
    colors: [Color(0xFF9D50BB), Color(0xFF6E48AA)],
    pattern: '$_kPatternDir/stars.svg',
    patternOpacity: 0.11,
  ),
  ChatWallpaperTheme(
    id: 'mint',
    name: 'Мята',
    colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
    pattern: '$_kPatternDir/plus.svg',
    patternColor: Colors.black,
    patternOpacity: 0.06,
    tileSize: 66,
    dark: false,
  ),
  ChatWallpaperTheme(
    id: 'graphite',
    name: 'Графит',
    colors: [Color(0xFF232526), Color(0xFF414345)],
    pattern: '$_kPatternDir/plus.svg',
    patternOpacity: 0.06,
    tileSize: 66,
  ),
  ChatWallpaperTheme(
    id: 'sky',
    name: 'Небо',
    colors: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
    pattern: '$_kPatternDir/planes.svg',
    patternOpacity: 0.11,
  ),
  ChatWallpaperTheme(
    id: 'peach',
    name: 'Персик',
    colors: [Color(0xFFFFD3A5), Color(0xFFFD6585)],
    pattern: '$_kPatternDir/rings.svg',
    patternColor: Colors.black,
    patternOpacity: 0.05,
    dark: false,
  ),
  ChatWallpaperTheme(
    id: 'forest',
    name: 'Лес',
    colors: [Color(0xFF134E5E), Color(0xFF71B280)],
    pattern: '$_kPatternDir/rings.svg',
    patternOpacity: 0.09,
  ),
  ChatWallpaperTheme(
    id: 'grape',
    name: 'Виноград',
    colors: [Color(0xFF4776E6), Color(0xFF8E54E9)],
    pattern: '$_kPatternDir/stars.svg',
    patternOpacity: 0.11,
  ),
  ChatWallpaperTheme(
    id: 'night',
    name: 'Ночь',
    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    pattern: '$_kPatternDir/stars.svg',
    patternOpacity: 0.08,
  ),
  ChatWallpaperTheme(
    id: 'rose',
    name: 'Роза',
    colors: [Color(0xFFF4C4F3), Color(0xFFFC67FA)],
    pattern: '$_kPatternDir/hearts.svg',
    patternOpacity: 0.14,
  ),
  ChatWallpaperTheme(
    id: 'amber',
    name: 'Янтарь',
    colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
    pattern: '$_kPatternDir/bubbles.svg',
    patternColor: Colors.black,
    patternOpacity: 0.05,
    dark: false,
  ),
];

ChatWallpaperTheme? chatWallpaperThemeById(String? id) {
  if (id == null) return null;
  for (final theme in kChatWallpaperThemes) {
    if (theme.id == id) return theme;
  }
  return null;
}
