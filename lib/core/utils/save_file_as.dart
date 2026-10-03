import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'logger.dart';
import '../security/app_lock.dart';

const _documentExport = MethodChannel('ru.komet.app/media_export');

// #***! итог сохранить как, отмену отличаем от ошибки
class SaveFileAsResult {
  final bool saved;
  final bool cancelled;
  final String? path;
  final String? error;

  const SaveFileAsResult({
    required this.saved,
    this.cancelled = false,
    this.path,
    this.error,
  });
}

// #***! на андроиде системное сохранить файл, на остальных выбор папки и копирование
Future<SaveFileAsResult> saveFileAs({
  required File source,
  required String fileName,
  required String dialogTitle,
}) async {
  final safeName = p.basename(fileName).trim();
  final name = safeName.isEmpty ? p.basename(source.path) : safeName;
  try {
    if (!kIsWeb && Platform.isAndroid) {
      return await _exportDocument(source, name);
    }
    final directory = await AppLock.instance.external(
      () => FilePicker.platform.getDirectoryPath(dialogTitle: dialogTitle),
    );
    if (directory == null) {
      return const SaveFileAsResult(saved: false, cancelled: true);
    }
    final target = await _availableTarget(directory, name);
    if (p.equals(p.absolute(source.path), p.absolute(target.path))) {
      return SaveFileAsResult(saved: true, path: target.path);
    }
    await source.copy(target.path);
    return SaveFileAsResult(saved: true, path: target.path);
  } catch (error) {
    logger.w('[saveAs] $name: $error');
    return SaveFileAsResult(saved: false, error: error.toString());
  }
}

Future<SaveFileAsResult> _exportDocument(File source, String name) async {
  final uri = await _documentExport.invokeMethod<String>('saveAs', {
    'path': source.path,
    'name': name,
  });
  if (uri == null) return const SaveFileAsResult(saved: false, cancelled: true);
  return SaveFileAsResult(saved: true, path: uri);
}

// #***! такой файл уже есть, дописываем (2) как проводник
Future<File> _availableTarget(String directory, String fileName) async {
  var target = File(p.join(directory, fileName));
  if (!await target.exists()) return target;
  final extension = p.extension(fileName);
  final stem = p.basenameWithoutExtension(fileName);
  var suffix = 2;
  while (await target.exists()) {
    target = File(p.join(directory, '$stem ($suffix)$extension'));
    suffix++;
  }
  return target;
}
