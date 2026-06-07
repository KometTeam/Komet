import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

const int _avatarMaxDimension = 1024;
const int _avatarTargetBytes = 900 * 1024;

/// Maximum accepted size for a user-picked avatar before compression.
const int kMaxAvatarBytes = 8 * 1024 * 1024;

Future<Uint8List?> compressAvatar(Uint8List input) => compute(_encodeAvatar, input);

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
