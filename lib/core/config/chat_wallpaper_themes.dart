import 'package:flutter/material.dart';

@immutable
class WallpaperPattern {
  final String asset;
  final Color inkStart;
  final Color inkEnd;
  final Color glow;

  const WallpaperPattern({
    required this.asset,
    required this.inkStart,
    required this.inkEnd,
    required this.glow,
  });
}

@immutable
class ChatWallpaperTheme {
  final String id;
  final Color top;
  final Color bottom;
  final Alignment begin;
  final Alignment end;
  final Color accent;
  final bool dark;
  final WallpaperPattern? pattern;

  const ChatWallpaperTheme({
    required this.id,
    required this.top,
    required this.bottom,
    required this.accent,
    required this.dark,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
    this.pattern,
  });

  Gradient get gradient =>
      LinearGradient(begin: begin, end: end, colors: [top, bottom]);
}

const List<ChatWallpaperTheme> kChatWallpaperThemes = <ChatWallpaperTheme>[
  ChatWallpaperTheme(
    id: 'komet',
    top: Color(0xFF111214),
    bottom: Color(0xFF222326),
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    accent: Color(0xFF767676),
    dark: true,
    pattern: WallpaperPattern(
      asset: 'assets/wallpapers/patterns/komet.svg',
      inkStart: Color(0xFF33363B),
      inkEnd: Color(0xFF44474D),
      glow: Color(0xFF6A6F78),
    ),
  ),
  ChatWallpaperTheme(
    id: 'graphite',
    top: Color(0xFF262626),
    bottom: Color(0xFF1B1B1B),
    accent: Color(0xFF767676),
    dark: true,
  ),
  ChatWallpaperTheme(
    id: 'ink',
    top: Color(0xFF1B2335),
    bottom: Color(0xFF121827),
    accent: Color(0xFF4A6FA5),
    dark: true,
  ),
  ChatWallpaperTheme(
    id: 'pine',
    top: Color(0xFF19241F),
    bottom: Color(0xFF111915),
    accent: Color(0xFF4E8A6C),
    dark: true,
  ),
  ChatWallpaperTheme(
    id: 'plum',
    top: Color(0xFF241D2A),
    bottom: Color(0xFF18131D),
    accent: Color(0xFF7D5D96),
    dark: true,
  ),
  ChatWallpaperTheme(
    id: 'umber',
    top: Color(0xFF2A221D),
    bottom: Color(0xFF1D1714),
    accent: Color(0xFF9C6B47),
    dark: true,
  ),
  ChatWallpaperTheme(
    id: 'paper',
    top: Color(0xFFF3F1EC),
    bottom: Color(0xFFE7E3DB),
    accent: Color(0xFF7A7A7A),
    dark: false,
  ),
  ChatWallpaperTheme(
    id: 'fog',
    top: Color(0xFFE8EBEF),
    bottom: Color(0xFFDBE0E6),
    accent: Color(0xFF56708F),
    dark: false,
  ),
  ChatWallpaperTheme(
    id: 'sage',
    top: Color(0xFFE5E9E2),
    bottom: Color(0xFFD6DDD3),
    accent: Color(0xFF5B7F5C),
    dark: false,
  ),
  ChatWallpaperTheme(
    id: 'sand',
    top: Color(0xFFF0E8DD),
    bottom: Color(0xFFE3D8C8),
    accent: Color(0xFF9A7650),
    dark: false,
  ),
  ChatWallpaperTheme(
    id: 'powder',
    top: Color(0xFFF1E6E6),
    bottom: Color(0xFFE4D5D6),
    accent: Color(0xFF9C5E68),
    dark: false,
  ),
];

const Map<String, String> _retiredThemes = {
  'ocean': 'ink',
  'night': 'ink',
  'sky': 'fog',
  'sunset': 'sand',
  'peach': 'sand',
  'amber': 'sand',
  'lavender': 'plum',
  'grape': 'plum',
  'mint': 'sage',
  'forest': 'pine',
  'rose': 'powder',
};

ChatWallpaperTheme? chatWallpaperThemeById(String? id) {
  if (id == null) return null;
  final current = _retiredThemes[id] ?? id;
  for (final theme in kChatWallpaperThemes) {
    if (theme.id == current) return theme;
  }
  return null;
}
