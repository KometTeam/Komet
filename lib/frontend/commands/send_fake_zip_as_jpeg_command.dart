import 'probe_send.dart';
import 'slash_command.dart';

const List<int> _jpegMagic = [
  0xFF, 0xD8, 0xFF, 0xE0, // SOI + APP0 marker
  0x00, 0x10, // APP0 length (16)
  0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
  0x01, 0x01, // version 1.1
  0x00, // density units
  0x00, 0x01, 0x00, 0x01, // X/Y density
  0x00, 0x00, // thumbnail 0x0
];

Future<void> runSendFakeZipAsJpeg(CommandContext ctx) async {
  try {
    final file = await buildProbeZipFile(extension: 'jpeg', prefix: _jpegMagic);
    await sendFileAsPhoto(ctx, file);
  } catch (e) {
    ctx.notify('Не удалось отправить fake jpeg: $e');
  }
}
