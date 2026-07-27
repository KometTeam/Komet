import 'dart:convert';

import '../../core/protocol/packet.dart';
import 'slash_command.dart';

Future<void> runSendControl(CommandContext ctx) async {
  final rest = ctx.args.trim();

  Map<String, dynamic> control;
  if (rest.startsWith('{')) {
    try {
      final decoded = jsonDecode(rest);
      if (decoded is! Map) {
        ctx.notify('JSON должен быть объектом');
        return;
      }
      control = Map<String, dynamic>.from(decoded);
    } catch (e) {
      ctx.notify('Кривой JSON: $e');
      return;
    }
  } else {
    control = {'event': rest.isEmpty ? 'test' : rest};
  }
  control['_type'] = 'CONTROL';

  try {
    final Packet packet = await ctx.messages.sendControlMessage(
      ctx.chatId,
      control,
    );
    if (packet.isOk) {
      final data = packet.payload;
      final msg = data is Map ? data['message'] : null;
      final id = msg is Map ? msg['id'] : null;
      ctx.notify('Принято ✅${id != null ? ' · msgId=$id' : ''}');
    } else {
      final p = packet.payload;
      final err = p is Map
          ? (p['localizedMessage'] ?? p['message'] ?? p).toString()
          : p.toString();
      ctx.notify('Отклонено ❌: $err');
    }
  } catch (e) {
    ctx.notify('Ошибка: $e');
  }
}
