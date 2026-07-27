import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

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

Future<SaveFileAsResult> saveFileAs({
  required File source,
  required String fileName,
  required String dialogTitle,
}) async {
  try {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: dialogTitle,
    );
    if (directory == null) {
      return const SaveFileAsResult(saved: false, cancelled: true);
    }
    final safeName = p.basename(fileName).trim();
    final target = await _availableTarget(
      directory,
      safeName.isEmpty ? p.basename(source.path) : safeName,
    );
    if (p.equals(p.absolute(source.path), p.absolute(target.path))) {
      return SaveFileAsResult(saved: true, path: target.path);
    }
    await source.copy(target.path);
    return SaveFileAsResult(saved: true, path: target.path);
  } catch (error) {
    return SaveFileAsResult(saved: false, error: error.toString());
  }
}

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
