import 'probe_send.dart';
import 'slash_command.dart';

Future<void> runSendZipAsImage(CommandContext ctx) async {
  try {
    await sendFileAsPhoto(ctx, await buildProbeZipFile(extension: 'zip'));
  } catch (e) {
    ctx.notify('Не удалось отправить zip: $e');
  }
}
