import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/media/gallery_source.dart';
import 'slash_command.dart';

Future<void> sendFileAsPhoto(CommandContext ctx, File file) =>
    ctx.sendPhotos([PickedPhoto(item: GalleryItem.fromFile(file))], '');

Future<File> _tempFile(String extension) async {
  final dir = await getTemporaryDirectory();
  return File(
    p.join(
      dir.path,
      'komet_probe_${DateTime.now().microsecondsSinceEpoch}.$extension',
    ),
  );
}

Future<File> assetToTempFile(
  String assetPath, {
  required String extension,
}) async {
  final data = await rootBundle.load(assetPath);
  final file = await _tempFile(extension);
  await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  return file;
}

Future<File> buildProbeZipFile({
  required String extension,
  List<int>? prefix,
}) async {
  final archive = Archive();
  final data = utf8.encode('This is a zip, not a photo. Komet probe.');
  archive.addFile(ArchiveFile('not_a_photo.txt', data.length, data));
  final zip = ZipEncoder().encodeBytes(archive);
  final bytes = prefix == null ? zip : <int>[...prefix, ...zip];

  final file = await _tempFile(extension);
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
