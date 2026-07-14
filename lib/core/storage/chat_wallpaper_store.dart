import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import 'per_chat_json_store.dart';

const int kGlobalWallpaperChatId = 0;

enum ChatWallpaperKind { image, theme }

@immutable
class WallpaperImageSettings {
  final double dim;
  final bool blur;
  final bool motion;
  final double offsetX;

  const WallpaperImageSettings({
    this.dim = 0,
    this.blur = false,
    this.motion = false,
    this.offsetX = 0,
  });
}

@immutable
class ChatWallpaper {
  final ChatWallpaperKind kind;
  final String? imagePath;
  final String? themeId;
  final double dim;
  final bool blur;
  final bool motion;
  final double offsetX;

  const ChatWallpaper.image(
    String path, {
    this.dim = 0,
    this.blur = false,
    this.motion = false,
    this.offsetX = 0,
  }) : kind = ChatWallpaperKind.image,
       imagePath = path,
       themeId = null;

  const ChatWallpaper.theme(String id)
    : kind = ChatWallpaperKind.theme,
      imagePath = null,
      themeId = id,
      dim = 0,
      blur = false,
      motion = false,
      offsetX = 0;

  bool get isImage => kind == ChatWallpaperKind.image;

  Map<String, dynamic> _toJson() => isImage
      ? {
          'path': imagePath,
          'dim': dim,
          'blur': blur,
          'motion': motion,
          'offsetX': offsetX,
        }
      : {'theme': themeId};

  static ChatWallpaper? _fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'];
    if (path is String && path.isNotEmpty) {
      return ChatWallpaper.image(
        path,
        dim: (raw['dim'] as num?)?.toDouble() ?? 0,
        blur: raw['blur'] == true,
        motion: raw['motion'] == true,
        offsetX: (raw['offsetX'] as num?)?.toDouble() ?? 0,
      );
    }
    final theme = raw['theme'];
    if (theme is String && theme.isNotEmpty) return ChatWallpaper.theme(theme);
    return null;
  }
}

class ChatWallpaperStore extends PerChatJsonStore<ChatWallpaper> {
  ChatWallpaperStore._()
    : super(
        prefsKey: 'chat_wallpapers',
        fromJson: ChatWallpaper._fromJson,
        toJson: (value) => value._toJson(),
      );

  static final ChatWallpaperStore instance = ChatWallpaperStore._();

  static const String _dirName = 'chat_wallpapers';

  ChatWallpaper? get(int accountId, int chatId) => read(accountId, chatId);

  Future<ChatWallpaper?> setImage(
    int accountId,
    int chatId,
    Uint8List bytes, {
    WallpaperImageSettings settings = const WallpaperImageSettings(),
  }) async {
    if (accountId == 0) return null;
    final dir = await getApplicationDocumentsDirectory();
    final wpDir = Directory('${dir.path}/$_dirName');
    if (!await wpDir.exists()) await wpDir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${wpDir.path}/${accountId}_${chatId}_$stamp.img');
    await file.writeAsBytes(bytes, flush: true);
    final wallpaper = ChatWallpaper.image(
      file.path,
      dim: settings.dim,
      blur: settings.blur,
      motion: settings.motion,
      offsetX: settings.offsetX,
    );
    await write(accountId, chatId, wallpaper);
    return wallpaper;
  }

  Future<ChatWallpaper> setTheme(
    int accountId,
    int chatId,
    String themeId,
  ) async {
    final wallpaper = ChatWallpaper.theme(themeId);
    await write(accountId, chatId, wallpaper);
    return wallpaper;
  }

  Future<void> clear(int accountId, int chatId) =>
      write(accountId, chatId, null);

  @override
  void onBeforeWrite(String key, ChatWallpaper? previous, ChatWallpaper? next) {
    if (previous != null &&
        previous.isImage &&
        previous.imagePath != next?.imagePath) {
      unawaited(_deleteImage(previous.imagePath));
    }
  }

  Future<void> _deleteImage(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      logger.w('wallpaper image delete failed: $e');
    }
  }
}
