import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/image_utils.dart';

Future<File?> rasterPictureToJpegFile(
  ui.Picture picture,
  int width,
  int height, {
  required String prefix,
  void Function()? onPictureDisposed,
}) async {
  final rendered = await picture.toImage(width, height);
  picture.dispose();
  onPictureDisposed?.call();
  final bd = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
  rendered.dispose();
  if (bd == null) return null;

  final jpeg = await encodeRgbaToJpeg(bd.buffer.asUint8List(), width, height);
  if (jpeg == null) return null;
  final dir = await getTemporaryDirectory();
  final out = File(
    p.join(
      dir.path,
      'komet_${prefix}_${DateTime.now().microsecondsSinceEpoch}.jpg',
    ),
  );
  await out.writeAsBytes(jpeg);
  return out;
}
