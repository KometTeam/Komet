import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/plugins/plugin_manifest.dart';
import 'package:komet/frontend/commands/commands.dart';
import 'package:komet/frontend/screens/chats/chat/view/command_arguments_form.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  const chance = PluginCommandArgumentManifest(
    name: 'chance',
    description: 'Шанс от 1 до 100',
    required: false,
    rest: false,
  );
  const text = PluginCommandArgumentManifest(
    name: 'text',
    description: 'Текст команды',
    required: true,
    rest: true,
  );
  const command = SlashCommand(
    name: '/synthetic',
    description: 'Синтетическая команда',
    arguments: [chance, text],
  );

  testWidgets('shows command arguments as separate interface fields', (
    tester,
  ) async {
    final controllers = {
      'chance': TextEditingController(),
      'text': TextEditingController(),
    };
    final focusNodes = {'chance': FocusNode(), 'text': FocusNode()};
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandArgumentsForm(
            command: command,
            controllers: controllers,
            focusNodes: focusNodes,
            onCancel: () => cancelled = true,
            onSubmit: () {},
          ),
        ),
      ),
    );

    expect(find.text('/synthetic'), findsOneWidget);
    expect(find.text('Синтетическая команда'), findsOneWidget);
    expect(find.text('chance · необязательно'), findsOneWidget);
    expect(find.text('text'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const ValueKey('command_argument_chance')),
      '80',
    );
    await tester.enterText(
      find.byKey(const ValueKey('command_argument_text')),
      'alpha beta',
    );

    expect(controllers['chance']!.text, '80');
    expect(controllers['text']!.text, 'alpha beta');

    await tester.tap(find.byIcon(Symbols.close));
    expect(cancelled, isTrue);

    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final node in focusNodes.values) {
      node.dispose();
    }
  });

  testWidgets('moves focus to the next argument on submit', (tester) async {
    final controllers = {
      'chance': TextEditingController(),
      'text': TextEditingController(),
    };
    final focusNodes = {'chance': FocusNode(), 'text': FocusNode()};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandArgumentsForm(
            command: command,
            controllers: controllers,
            focusNodes: focusNodes,
            onCancel: () {},
            onSubmit: () {},
          ),
        ),
      ),
    );

    focusNodes['chance']!.requestFocus();
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    expect(focusNodes['text']!.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final node in focusNodes.values) {
      node.dispose();
    }
  });
}
