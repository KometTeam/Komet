import 'dart:math';

import 'slash_command.dart';

const double _defaultCooldownSec = 0.15;
const int _minLength = 3;
const List<String> _fillChars = ['#', '@', '%', '&', '*'];

final Random _rng = Random();

String _fill() => _fillChars[_rng.nextInt(_fillChars.length)];

Future<void> runAnim1(CommandContext ctx) async {
  var cooldownSec = _defaultCooldownSec;
  var text = ctx.args;

  if (text.startsWith('{')) {
    final match = RegExp(r'^\{\s*([0-9]*\.?[0-9]+)\s*\}\s*').firstMatch(text);
    final parsed = match != null ? double.tryParse(match.group(1)!) : null;
    if (match == null || parsed == null || parsed < 0) {
      ctx.notify('НЕВЕРНЫЙ СИНТАКСИС🚨🚨🚨');
      return;
    }
    cooldownSec = parsed;
    text = text.substring(match.end);
  }

  final chars = text.runes.map(String.fromCharCode).toList();
  if (chars.length < _minLength) {
    ctx.notify('Минимум $_minLength символа для анимации');
    return;
  }
  if (!ctx.isOnline()) {
    ctx.notify('Нет соединения');
    return;
  }

  final cooldown = Duration(milliseconds: (cooldownSec * 1000).round());

  final frames = _buildFrames(chars);
  if (frames.isEmpty) return;
  final id = await ctx.postMessage(frames.first);
  if (id.isEmpty) return;

  await playFrames(ctx, id, frames, cooldown);
}

List<String> _buildFrames(List<String> chars) {
  final n = chars.length;
  final noise = List.generate(n, (_) => _fill());
  final frames = <String>[chars.join()];

  for (var i = 0; i <= n + 1; i++) {
    final sb = StringBuffer();
    for (var p = 0; p < n; p++) {
      if (p < i - 1) {
        sb.write(noise[p]);
      } else if (p == i - 1) {
        sb.write('\$');
      } else if (p == i) {
        sb.write(chars[p].toUpperCase());
      } else {
        sb.write(chars[p]);
      }
    }
    frames.add(sb.toString());
  }

  for (var w = n; w >= 1; w -= 2) {
    if (w == 1) {
      frames.add('%');
    } else {
      final sb = StringBuffer('>');
      for (var k = 0; k < w - 2; k++) {
        sb.write(noise[k]);
      }
      sb.write('<');
      frames.add(sb.toString());
    }
  }

  for (var w = n.isEven ? 2 : 1; w <= n; w += 2) {
    final start = (n - w) ~/ 2;
    frames.add(chars.sublist(start, start + w).join());
  }

  return frames.where((f) => f.trim().isNotEmpty).toList();
}
