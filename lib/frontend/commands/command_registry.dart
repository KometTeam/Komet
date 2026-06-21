import 'crush_command.dart';
import 'info_command.dart';
import 'slash_command.dart';

const List<SlashCommand> kSlashCommands = [
  SlashCommand('/test', '12345 test отображение'),
  SlashCommand('/info', 'сводка данных о человеке', run: runInfo),
  SlashCommand(
    '/crush',
    'Тест устойчивости веб клиента макса',
    run: runCrush,
    hidden: true,
  ),
];

SlashCommand? findSlashCommand(String text) {
  for (final c in kSlashCommands) {
    if (c.name == text) return c;
  }
  return null;
}
