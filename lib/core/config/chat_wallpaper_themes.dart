import 'package:flutter/material.dart';

@immutable
class ChatWallpaperTheme {
  final String id;
  final String name;
  final Gradient gradient;
  final Color bubbleTint;

  const ChatWallpaperTheme({
    required this.id,
    required this.name,
    required this.gradient,
    this.bubbleTint = Colors.transparent,
  });

  Widget buildBackground() => DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: const SizedBox.expand(),
      );

  Widget buildPreview() => DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: const SizedBox.expand(),
      );
}

const List<ChatWallpaperTheme> kChatWallpaperThemes = <ChatWallpaperTheme>[];

ChatWallpaperTheme? chatWallpaperThemeById(String? id) {
  if (id == null) return null;
  for (final theme in kChatWallpaperThemes) {
    if (theme.id == id) return theme;
  }
  return null;
}
