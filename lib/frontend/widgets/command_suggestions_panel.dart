import 'package:flutter/material.dart';

import '../commands/command_registry.dart';
import '../commands/slash_command.dart';

class CommandSuggestionsPanel extends StatelessWidget {
  final List<SlashCommand> commands;
  final double maxHeight;
  final ValueChanged<SlashCommand>? onSelected;

  const CommandSuggestionsPanel({
    super.key,
    this.commands = kSlashCommands,
    this.maxHeight = 220,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = commands.where((c) => !c.hidden).toList(growable: false);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: visible.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            thickness: 1,
            indent: 14,
            endIndent: 14,
            color: cs.outlineVariant.withValues(alpha: 0.18),
          ),
          itemBuilder: (context, i) {
            final c = visible[i];
            return InkWell(
              onTap: onSelected == null ? null : () => onSelected!(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        c.name,
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c.description,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
