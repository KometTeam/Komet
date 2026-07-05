import 'package:flutter/material.dart';

import 'package:komet/frontend/commands/slash_command.dart';
import 'package:komet/frontend/screens/chats/chat/command_panel_controller.dart';
import 'package:komet/frontend/widgets/command_suggestions_panel.dart';

class CommandPanelView extends StatelessWidget {
  const CommandPanelView({super.key, required this.commandPanel});

  final CommandPanelController commandPanel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: commandPanel.anim,
      child: ValueListenableBuilder<List<SlashCommand>>(
        valueListenable: commandPanel.matches,
        builder: (context, matches, _) => CommandSuggestionsPanel(
          commands: matches,
          onSelected: commandPanel.select,
        ),
      ),
      builder: (context, child) {
        final t = commandPanel.anim.value;
        if (t == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: IgnorePointer(
            ignoring: t < 1,
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
    );
  }
}
