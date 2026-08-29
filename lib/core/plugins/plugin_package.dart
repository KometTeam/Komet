import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'plugin_manifest.dart';
import 'plugin_models.dart';

const int _maxPackageBytes = 5 * 1024 * 1024;
const int _maxExtractedBytes = 10 * 1024 * 1024;
const int _maxFiles = 128;
const int _maxFileBytes = 2 * 1024 * 1024;

class PluginPackage {
  const PluginPackage({required this.manifest, required this.files});

  final PluginManifest manifest;
  final Map<String, Uint8List> files;

  static PluginPackagePreview preview(List<int> bytes) {
    final package = decode(bytes);
    return PluginPackagePreview(manifest: package.manifest, bytes: bytes);
  }

  static PluginPackage decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > _maxPackageBytes) {
      throw const FormatException('Некорректный размер .kinet');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.isEmpty || archive.length > _maxFiles) {
      throw const FormatException('Некорректное количество файлов');
    }
    final files = <String, Uint8List>{};
    var extractedSize = 0;
    for (final entry in archive) {
      if (entry.isSymbolicLink) {
        throw const FormatException('Символические ссылки запрещены');
      }
      if (!entry.isFile) continue;
      final name = _safePath(entry.name);
      if (entry.size > _maxFileBytes) {
        throw FormatException('Файл $name слишком большой');
      }
      final content = entry.content;
      extractedSize += content.length;
      if (extractedSize > _maxExtractedBytes) {
        throw const FormatException('Распакованный плагин слишком большой');
      }
      if (files.containsKey(name)) {
        throw FormatException('Файл $name объявлен дважды');
      }
      files[name] = content;
    }
    final manifestBytes = files['manifest.json'];
    if (manifestBytes == null) {
      throw const FormatException('manifest.json не найден');
    }
    final manifest = PluginManifest.decode(utf8.decode(manifestBytes));
    if (!files.containsKey(manifest.main)) {
      throw FormatException('${manifest.main} не найден');
    }
    for (final path in files.keys) {
      if (path != 'manifest.json' && !path.endsWith('.js')) {
        throw FormatException('Неподдерживаемый файл: $path');
      }
    }
    return PluginPackage(manifest: manifest, files: Map.unmodifiable(files));
  }
}

String _safePath(String raw) {
  final path = raw.replaceAll('\\', '/');
  if (path.startsWith('/') ||
      path.split('/').any((part) => part.isEmpty || part == '..')) {
    throw const FormatException('Опасный путь в архиве');
  }
  return path;
}
