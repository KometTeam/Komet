import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/config/app_commands.dart';
import '../../../commands/command_registry.dart';
import '../../../commands/slash_command.dart';

class CommandPanelController {
  CommandPanelController({
    required TickerProvider vsync,
    required this.textOf,
    required this.onSelected,
  }) {
    anim = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 200),
    );
    AppCommands.current.addListener(update);
  }

  final String Function() textOf;
  final void Function(SlashCommand) onSelected;

  late final AnimationController anim;
  final ValueNotifier<List<SlashCommand>> matches = ValueNotifier(const []);
  bool _visible = false;

  List<SlashCommand> _matching(String raw) {
    if (!AppCommands.current.value) return const [];
    final text = raw.trimLeft();
    if (!text.startsWith('/')) return const [];
    if (text.contains(RegExp(r'\s'))) return const [];
    final query = text.toLowerCase();
    for (final c in kSlashCommands) {
      if (!c.hidden && c.name.toLowerCase() == query) return const [];
    }
    return kSlashCommands
        .where((c) => !c.hidden && c.name.toLowerCase().startsWith(query))
        .toList(growable: false);
  }

  void update() {
    final found = _matching(textOf());
    final show = found.isNotEmpty;
    if (show && !listEquals(matches.value, found)) {
      matches.value = found;
    }
    if (show == _visible) return;
    _visible = show;
    if (show) {
      anim.forward();
    } else {
      anim.reverse();
    }
  }

  void select(SlashCommand c) => onSelected(c);

  void dispose() {
    AppCommands.current.removeListener(update);
    anim.dispose();
    matches.dispose();
  }
}
