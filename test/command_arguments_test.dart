import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/plugins/plugin_manifest.dart';
import 'package:komet/frontend/commands/commands.dart';

void main() {
  const chance = PluginCommandArgumentManifest(
    name: 'chance',
    description: 'Synthetic chance',
    required: false,
    rest: false,
  );
  const text = PluginCommandArgumentManifest(
    name: 'text',
    description: 'Synthetic text',
    required: true,
    rest: true,
  );

  test('parses positional and rest arguments', () {
    expect(parseCommandArguments('80 alpha beta', const [chance, text]), {
      'chance': '80',
      'text': 'alpha beta',
    });
  });

  test('parses a quoted positional argument', () {
    expect(
      parseCommandArguments('"70 percent" alpha beta', const [chance, text]),
      {'chance': '70 percent', 'text': 'alpha beta'},
    );
  });

  test('keeps optional positional argument empty when input is empty', () {
    expect(parseCommandArguments('', const [chance]), {'chance': ''});
  });

  test('builds command usage from argument declarations', () {
    const command = SlashCommand(
      name: '/synthetic',
      description: 'Synthetic command',
      arguments: [chance, text],
    );

    expect(command.usage, '/synthetic [chance] <text...>');
  });

  test('shrug sends a kaomoji', () async {
    final sent = <String>[];
    final command = CommandRegistry.instance.commands.value.single;
    final context = PluginCommandContext(
      args: '',
      arguments: const {},
      replyMessage: null,
      onlineCheck: () => true,
      activeCheck: () => true,
      sendTextCallback: (text) async {
        sent.add(text);
        return 'synthetic-message';
      },
      editTextCallback: (_, _) async {},
      sendPhotoCallback: (_, _, _) async {},
      sendFileCallback: (_, _) async {},
      notifyCallback: (_) async {},
      getPeerCallback: () async => null,
    );

    await command.execute(context);

    expect(command.name, '/shrug');
    expect(sent, [r'¯\_(ツ)_/¯']);
  });
}
