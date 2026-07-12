import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

const int _avatarMaxDimension = 1024;
const int _avatarTargetBytes = 900 * 1024;

/// Maximum accepted size for a user-picked avatar before compression.
const int kMaxAvatarBytes = 8 * 1024 * 1024;

Future<Uint8List?> compressAvatar(Uint8List input) => compute(_encodeAvatar, input);

Future<Uint8List?> encodeRgbaToJpeg(Uint8List rgba, int width, int height) =>
    compute(_encodeRgba, (rgba, width, height));

Uint8List? _encodeRgba((Uint8List, int, int) args) {
  final (rgba, width, height) = args;
  if (width <= 0 || height <= 0) return null;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: 90);
}

Uint8List? _encodeAvatar(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final image = oriented.width > _avatarMaxDimension || oriented.height > _avatarMaxDimension
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? _avatarMaxDimension : null,
          height: oriented.height > oriented.width ? _avatarMaxDimension : null,
          interpolation: img.Interpolation.average,
        )
      : oriented;
  var quality = 88;
  var out = img.encodeJpg(image, quality: quality);
  while (out.lengthInBytes > _avatarTargetBytes && quality > 35) {
    quality -= 12;
    out = img.encodeJpg(image, quality: quality);
  }
  return out;
}
