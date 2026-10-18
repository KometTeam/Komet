import 'dart:io';
import 'dart:typed_data';

import 'native_share_account_channel.dart';

class ShareAvatarExport {
  ShareAvatarExport._();

  static const _avatarsDirName = 'avatars';
  static const _partSuffix = '.part';

  static String? _shareDirectory;
  static bool _shareDirectoryResolved = false;

  /// #***! своя аватарка для ячейки «В сторис»: фиксированное имя own.jpg
  static Future<String?> exportOwn({
    required int accountId,
    required Uint8List bytes,
  }) async {
    final root = await _resolveShareDirectory();
    if (root == null) return null;
    try {
      final directory = Directory('$root/$_avatarsDirName/$accountId');
      final target = File('${directory.path}/own.jpg');
      final part = File('${target.path}$_partSuffix');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(target.path);
      return 'own.jpg';
    } catch (_) {
      return null;
    }
  }

  static Future<String?> export({
    required int accountId,
    required int chatId,
    required Uint8List bytes,
    required String key,
  }) async {
    final root = await _resolveShareDirectory();
    if (root == null) return null;
    try {
      final directory = Directory('$root/$_avatarsDirName/$accountId');
      final name = '${chatId}_$key.jpg';
      final target = File('${directory.path}/$name');
      if (await target.exists()) return name;
      final part = File('${target.path}$_partSuffix');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(target.path);
      return name;
    } catch (_) {
      return null;
    }
  }

  static Future<void> prune({
    required int accountId,
    required Set<String> keep,
  }) async {
    final root = await _resolveShareDirectory();
    if (root == null) return;
    try {
      final directory = Directory('$root/$_avatarsDirName/$accountId');
      if (!await directory.exists()) return;
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        if (keep.contains(name)) continue;
        try {
          await entity.delete();
        } on FileSystemException {
          continue;
        }
      }
    } catch (_) {}
  }

  static Future<String?> _resolveShareDirectory() async {
    if (_shareDirectoryResolved) return _shareDirectory;
    final resolved = await NativeShareAccountChannel.instance.shareDirectory();
    if (resolved != null) {
      // #***! неуспешный резолв не кэшируем – повторяем на следующем синке
      _shareDirectory = resolved;
      _shareDirectoryResolved = true;
    }
    return resolved;
  }
}
