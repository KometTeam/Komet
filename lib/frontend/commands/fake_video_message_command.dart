import 'probe_send.dart';
import 'slash_command.dart';

const String _noteAsset = 'assets/debug/fake_video_note.mp4';
const String _usage =
    'Формат: /FakeVideoMessage 13:37 (мм:сс) или /FakeVideoMessage 10000 (секунды)';

int? parseFakeDurationMs(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return null;

  final negative = input.startsWith('-');
  final body = negative ? input.substring(1).trim() : input;
  if (body.isEmpty) return null;

  int? seconds;
  if (body.contains(':')) {
    final parts = body.split(':');
    if (parts.length > 3) return null;
    var total = 0;
    for (var i = 0; i < parts.length; i++) {
      final value = int.tryParse(parts[i]);
      if (value == null || value < 0) return null;
      if (i > 0 && value > 59) return null;
      total = total * 60 + value;
    }
    seconds = total;
  } else {
    final value = int.tryParse(body);
    if (value == null || value < 0) return null;
    seconds = value;
  }

  final ms = seconds * 1000;
  return negative ? -ms : ms;
}

String formatDurationMs(int ms) {
  final sign = ms < 0 ? '-' : '';
  final totalSeconds = (ms.abs() / 1000).round();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$sign$hours:$mm:$ss' : '$sign$minutes:$ss';
}

Future<void> runFakeVideoMessage(CommandContext ctx) async {
  final durationMs = parseFakeDurationMs(ctx.args);
  if (durationMs == null) {
    ctx.notify(_usage);
    return;
  }

  ctx.notify(
    'Кружок с подменой: ${formatDurationMs(durationMs)} '
    '(duration=$durationMs мс)',
  );

  try {
    final file = await assetToTempFile(_noteAsset, extension: 'mp4');
    await ctx.sendVideoNote(file, durationMs);
  } catch (e) {
    ctx.notify('Не удалось подготовить кружок: $e');
  }
}
