import 'probe_send.dart';
import 'slash_command.dart';

Future<void> runSend1x1(CommandContext ctx) async {
  try {
    final file = await assetToTempFile(
      'assets/debug/red_1x1.png',
      extension: 'png',
    );
    await sendFileAsPhoto(ctx, file);
  } catch (e) {
    ctx.notify('Не удалось отправить 1×1: $e');
  }
}

Future<void> runSend1x8192(CommandContext ctx) async {
  try {
    final file = await assetToTempFile(
      'assets/debug/red_1x8192.png',
      extension: 'png',
    );
    await sendFileAsPhoto(ctx, file);
  } catch (e) {
    ctx.notify('Не удалось отправить 1×8192: $e');
  }
}
