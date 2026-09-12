import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/plugins/plugin_manifest.dart';
import '../../../../commands/commands.dart';

class CommandArgumentsForm extends StatelessWidget {
  const CommandArgumentsForm({
    super.key,
    required this.command,
    required this.controllers,
    required this.focusNodes,
    required this.onCancel,
    required this.onSubmit,
  });

  final SlashCommand command;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        command.name,
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        command.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Отменить команду',
                      onPressed: onCancel,
                      icon: const Icon(Symbols.close, size: 20),
                    ),
                  ],
                ),
                if (command.arguments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (var index = 0; index < command.arguments.length; index++)
                    Padding(
                      padding: EdgeInsets.only(
                        right: 6,
                        bottom: index == command.arguments.length - 1 ? 0 : 10,
                      ),
                      child: _ArgumentField(
                        argument: command.arguments[index],
                        controller: controllers[command.arguments[index].name]!,
                        focusNode: focusNodes[command.arguments[index].name]!,
                        onSubmit: index == command.arguments.length - 1
                            ? onSubmit
                            : () =>
                                  focusNodes[command.arguments[index + 1].name]
                                      ?.requestFocus(),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArgumentField extends StatelessWidget {
  const _ArgumentField({
    required this.argument,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final PluginCommandArgumentManifest argument;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final optional = argument.required ? '' : ' · необязательно';
    return TextField(
      key: ValueKey('command_argument_${argument.name}'),
      controller: controller,
      focusNode: focusNode,
      minLines: 1,
      maxLines: argument.rest ? 3 : 1,
      textInputAction: argument.rest
          ? TextInputAction.newline
          : TextInputAction.next,
      onSubmitted: argument.rest ? null : (_) => onSubmit(),
      decoration: InputDecoration(
        labelText: '${argument.name}$optional',
        hintText: argument.description.isEmpty ? null : argument.description,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}
