import 'anim_command.dart';
import 'crush_command.dart';
import 'epsh_files_command.dart';
import 'fake_video_message_command.dart';
import 'info_command.dart';
import 'send_control_command.dart';
import 'slash_command.dart';
import 'watching_command.dart';

const List<SlashCommand> kSlashCommands = [
  SlashCommand('/test', '12345 test отображение'),
  SlashCommand('/info', 'сводка данных о человеке', run: runInfo),
  SlashCommand('/anim1', 'анимация текста', run: runAnim1),
  SlashCommand('/IAlwaysWatchingYou', '👁️', run: runWatching),
  SlashCommand(
    '/epshFiles',
    'цензура слов чёрными квадратами {шанс 1-100}',
    run: runEpshFiles,
  ),
  SlashCommand(
    '/crush',
    'Тест устойчивости веб клиента макса',
    run: runCrush,
    hidden: true,
  ),
  SlashCommand(
    '/FakeVideoMessage',
    'кружок с подменённой длиной: [13:37 | 10000 (сек)]',
    run: runFakeVideoMessage,
  ),
  SlashCommand(
    '/sendControlPayload',
    'CONTROL в текущий чат: [event | json]',
    run: runSendControl,
  ),
];

SlashCommand? findSlashCommand(String text) {
  final name = text.trimLeft().split(RegExp(r'\s')).first.toLowerCase();
  for (final c in kSlashCommands) {
    if (c.name.toLowerCase() == name) return c;
  }
  return null;
}

String commandArgs(String text) {
  final trimmed = text.trimLeft();
  final idx = trimmed.indexOf(RegExp(r'\s'));
  if (idx == -1) return '';
  return trimmed.substring(idx + 1).trim();
}
