import 'dart:math';

import 'slash_command.dart';

const int _defaultChance = 65;
const String _square = '⬛';

final Random _rng = Random();

Future<void> runEpshFiles(CommandContext ctx) async {
  var chance = _defaultChance;
  var text = ctx.args;

  if (text.startsWith('{')) {
    final match = RegExp(r'^\{\s*(\d+)\s*\}\s*').firstMatch(text);
    final parsed = match != null ? int.tryParse(match.group(1)!) : null;
    if (match == null || parsed == null || parsed < 1 || parsed > 100) {
      ctx.notify('НЕВЕРНЫЙ СИНТАКСИС🚨🚨🚨');
      return;
    }
    chance = parsed;
    text = text.substring(match.end);
  }

  text = text.trim();
  if (text.isEmpty) {
    ctx.notify('Нет текста');
    return;
  }

  final censored = text.replaceAllMapped(RegExp(r'\S+'), (m) {
    final word = m.group(0)!;
    return _rng.nextInt(100) < chance ? _square * word.runes.length : word;
  });

  await ctx.postMessage(censored);
}
