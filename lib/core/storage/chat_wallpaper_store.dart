import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import 'per_chat_json_store.dart';

// #***! chatId 0 это обои по умолчанию
const int kGlobalWallpaperChatId = 0;

// #***! обои, своя картинка, встроенная тема или свой градиент
enum ChatWallpaperKind { image, theme, gradient }

// #***! правки картинки, затемнение блюр параллакс сдвиг
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

// #***! один объект на все виды, у темы/градиента настройки картинки нулевые
@immutable
class ChatWallpaper {
  final ChatWallpaperKind kind;
  final String? imagePath;
  final String? themeId;
  final List<Color>? gradientColors;
  final bool gradientAnimated;
  final double gradientRotation;
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
       themeId = null,
       gradientColors = null,
       gradientAnimated = true,
       gradientRotation = 0;

  const ChatWallpaper.theme(String id)
    : kind = ChatWallpaperKind.theme,
      imagePath = null,
      themeId = id,
      gradientColors = null,
      gradientAnimated = true,
      gradientRotation = 0,
      dim = 0,
      blur = false,
      motion = false,
      offsetX = 0;

  const ChatWallpaper.gradient(
    List<Color> colors, {
    this.gradientAnimated = false,
    this.gradientRotation = 0,
  }) : kind = ChatWallpaperKind.gradient,
       imagePath = null,
       themeId = null,
       gradientColors = colors,
       dim = 0,
       blur = false,
       motion = false,
       offsetX = 0;

  bool get isImage => kind == ChatWallpaperKind.image;
  bool get isGradient => kind == ChatWallpaperKind.gradient;

  // #***! в джейсон или путь с настройками, или id темы, или свои цвета
  Map<String, dynamic> _toJson() {
    if (isImage) {
      return {
        'path': imagePath,
        'dim': dim,
        'blur': blur,
        'motion': motion,
        'offsetX': offsetX,
      };
    }
    if (isGradient) {
      return {
        'colors': gradientColors!.map((c) => c.toARGB32()).toList(),
        'animated': gradientAnimated,
        'rotation': gradientRotation,
      };
    }
    return {'theme': themeId};
  }

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
    final colors = raw['colors'];
    if (colors is List && colors.isNotEmpty) {
      return ChatWallpaper.gradient(
        colors.whereType<num>().map((v) => Color(v.toInt())).toList(),
        gradientAnimated: raw['animated'] == true,
        gradientRotation: (raw['rotation'] as num?)?.toDouble() ?? 0,
      );
    }
    final theme = raw['theme'];
    if (theme is String && theme.isNotEmpty) return ChatWallpaper.theme(theme);
    return null;
  }
}

// #***! обои по чатам поверх общего хранилища
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

  // #***! картинку копируем к себе, исходник из галереи может исчезнуть
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
    // #***! время в имени файла, иначе флаттер отдаст старую из кэша
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

  Future<ChatWallpaper> setGradient(
    int accountId,
    int chatId,
    List<Color> colors, {
    bool animated = false,
    double rotation = 0,
  }) async {
    final wallpaper = ChatWallpaper.gradient(
      colors,
      gradientAnimated: animated,
      gradientRotation: rotation,
    );
    await write(accountId, chatId, wallpaper);
    return wallpaper;
  }

  Future<void> clear(int accountId, int chatId) =>
      write(accountId, chatId, null);

  // #***! старый файл удаляем иначе обои копятся на диске
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
