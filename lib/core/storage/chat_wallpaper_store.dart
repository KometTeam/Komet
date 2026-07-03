import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  })  : kind = ChatWallpaperKind.image,
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

class ChatWallpaperStore {
  ChatWallpaperStore._();

  static final ChatWallpaperStore instance = ChatWallpaperStore._();

  static const String _prefsKey = 'chat_wallpapers';
  static const String _dirName = 'chat_wallpapers';

  final Map<String, ChatWallpaper> _wallpapers = {};
  final ValueNotifier<int> revision = ValueNotifier(0);
  bool _loaded = false;

  String _key(int accountId, int chatId) => '$accountId/$chatId';

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        map.forEach((k, v) {
          if (k is! String) return;
          final wp = ChatWallpaper._fromJson(v);
          if (wp != null) _wallpapers[k] = wp;
        });
      }
    } catch (_) {}
  }

  ChatWallpaper? get(int accountId, int chatId) {
    if (accountId == 0) return null;
    return _wallpapers[_key(accountId, chatId)];
  }

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
    await _store(accountId, chatId, wallpaper);
    return wallpaper;
  }

  Future<ChatWallpaper> setTheme(
    int accountId,
    int chatId,
    String themeId,
  ) async {
    final wallpaper = ChatWallpaper.theme(themeId);
    await _store(accountId, chatId, wallpaper);
    return wallpaper;
  }

  Future<void> clear(int accountId, int chatId) => _store(accountId, chatId, null);

  Future<void> _store(
    int accountId,
    int chatId,
    ChatWallpaper? wallpaper,
  ) async {
    if (accountId == 0) return;
    final key = _key(accountId, chatId);
    final previous = _wallpapers[key];
    if (previous != null &&
        previous.isImage &&
        previous.imagePath != wallpaper?.imagePath) {
      unawaited(_deleteImage(previous.imagePath));
    }
    if (wallpaper == null) {
      if (previous == null) return;
      _wallpapers.remove(key);
    } else {
      _wallpapers[key] = wallpaper;
    }
    revision.value++;
    final prefs = await SharedPreferences.getInstance();
    final serializable = <String, dynamic>{};
    _wallpapers.forEach((k, v) => serializable[k] = v._toJson());
    await prefs.setString(_prefsKey, jsonEncode(serializable));
  }

  Future<void> _deleteImage(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
