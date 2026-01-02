import 'color_utils.dart';

abstract final class StringUtils {
  static String hexFromArgb(int argb, {bool leadingHashSign = true}) =>
      "${leadingHashSign ? "#" : ""}"
      "${ColorUtils.redFromArgb(argb).toRadixString(16).toUpperCase().padLeft(2, "0")}"
      "${ColorUtils.greenFromArgb(argb).toRadixString(16).toUpperCase().padLeft(2, "0")}"
      "${ColorUtils.blueFromArgb(argb).toRadixString(16).toUpperCase().padLeft(2, "0")}";

  static int? argbFromHex(String hex) =>
      int.tryParse(hex.replaceAll("#", ""), radix: 16);
}
