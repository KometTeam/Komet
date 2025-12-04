import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadPathHelper {
  static const String _downloadPathKey = 'custom_download_path';

  /// Получить папку для загрузки файлов
  /// Сначала проверяет сохраненный путь, если его нет - использует дефолтный
  static Future<io.Directory?> getDownloadDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(_downloadPathKey);

    if (customPath != null && customPath.isNotEmpty) {
      final dir = io.Directory(customPath);
      if (await dir.exists()) {
        return dir;
      }
    }

    // Используем дефолтную папку
    return _getDefaultDownloadDirectory();
  }

  /// Получить дефолтную папку для загрузки
  static Future<io.Directory?> _getDefaultDownloadDirectory() async {
    if (io.Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        // Пробуем найти папку Download/Downloads
        var downloadDir = io.Directory(
          '${directory.path.split('Android')[0]}Download',
        );
        if (!await downloadDir.exists()) {
          downloadDir = io.Directory(
            '${directory.path.split('Android')[0]}Downloads',
          );
        }
        if (await downloadDir.exists()) {
          return downloadDir;
        }
        return directory;
      }
    } else if (io.Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    } else if (io.Platform.isWindows || io.Platform.isLinux) {
      final homeDir =
          io.Platform.environment['HOME'] ??
          io.Platform.environment['USERPROFILE'] ??
          '';
      if (homeDir.isNotEmpty) {
        final downloadDir = io.Directory('$homeDir/Downloads');
        if (await downloadDir.exists()) {
          return downloadDir;
        }
        return io.Directory(homeDir);
      }
    }

    // Fallback
    return await getApplicationDocumentsDirectory();
  }

  /// Сохранить выбранную пользователем папку
  static Future<void> setDownloadDirectory(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path != null && path.isNotEmpty) {
      await prefs.setString(_downloadPathKey, path);
    } else {
      await prefs.remove(_downloadPathKey);
    }
  }

  /// Получить текущий сохраненный путь (может быть null)
  static Future<String?> getSavedDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_downloadPathKey);
  }

  /// Получить путь для отображения (сохраненный или дефолтный)
  static Future<String> getDisplayPath() async {
    final savedPath = await getSavedDownloadPath();
    if (savedPath != null && savedPath.isNotEmpty) {
      return savedPath;
    }

    final defaultDir = await _getDefaultDownloadDirectory();
    return defaultDir?.path ?? 'Не указано';
  }
}

