import 'probe_send.dart';
import 'slash_command.dart';

Future<void> runSendHeic(CommandContext ctx) async {
  try {
    final file = await assetToTempFile(
      'assets/debug/red.heic',
      extension: 'heic',
    );
    await sendFileAsPhoto(ctx, file);
  } catch (e) {
    ctx.notify('Не удалось отправить .heic: $e');
  }
}
