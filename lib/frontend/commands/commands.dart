import 'package:flutter/foundation.dart';

import '../../core/plugins/plugin_host.dart';
import '../../core/plugins/plugin_manifest.dart';
import '../../core/plugins/plugin_models.dart';
import '../../core/plugins/plugin_runtime.dart';
import '../../core/plugins/plugin_store.dart';

class PluginCommandContext implements PluginHost {
  const PluginCommandContext({
    required this.args,
    required this.arguments,
    required this.replyMessage,
    required this.onlineCheck,
    required this.activeCheck,
    required this.sendTextCallback,
    required this.editTextCallback,
    required this.sendPhotoCallback,
    required this.sendFileCallback,
    required this.notifyCallback,
    required this.getPeerCallback,
  });

  @override
  final String args;

  @override
  final Map<String, dynamic> arguments;

  @override
  final Map<String, dynamic>? replyMessage;

  final bool Function() onlineCheck;
  final bool Function() activeCheck;
  final Future<String> Function(String text) sendTextCallback;
  final Future<void> Function(String messageId, String text) editTextCallback;
  final Future<void> Function(Uint8List bytes, String filename, String caption)
  sendPhotoCallback;
  final Future<void> Function(Uint8List bytes, String filename)
  sendFileCallback;
  final Future<void> Function(String message) notifyCallback;
  final Future<Map<String, dynamic>?> Function() getPeerCallback;

  @override
  bool get isOnline => onlineCheck();

  @override
  bool get isActive => activeCheck();

  @override
  Future<String> sendText(String text) => sendTextCallback(text);

  @override
  Future<void> editText(String messageId, String text) =>
      editTextCallback(messageId, text);

  @override
  Future<void> sendPhoto(
    Uint8List bytes, {
    required String filename,
    required String caption,
  }) => sendPhotoCallback(bytes, filename, caption);

  @override
  Future<void> sendFile(Uint8List bytes, {required String filename}) =>
      sendFileCallback(bytes, filename);

  @override
  Future<void> notify(String message) => notifyCallback(message);

  @override
  Future<Map<String, dynamic>?> getPeer() => getPeerCallback();
}

typedef CommandRunner = Future<void> Function(PluginCommandContext context);

class SlashCommand {
  const SlashCommand({
    required this.name,
    required this.description,
    this.arguments = const [],
    this.run,
    this.hidden = false,
    this.pluginCommand,
  });

  final String name;
  final String description;
  final List<PluginCommandArgumentManifest> arguments;
  final CommandRunner? run;
  final bool hidden;
  final PluginCommandDescriptor? pluginCommand;

  String get usage {
    if (arguments.isEmpty) return name;
    final suffix = arguments
        .map((argument) {
          final value = argument.rest ? '${argument.name}...' : argument.name;
          return argument.required ? '<$value>' : '[$value]';
        })
        .join(' ');
    return '$name $suffix';
  }

  Future<void> execute(PluginCommandContext context) {
    final plugin = pluginCommand;
    if (plugin != null) return PluginRuntime.run(plugin, context);
    return run?.call(context) ?? Future.value();
  }

  PluginCommandArgumentManifest? missingArgument(Map<String, dynamic> values) {
    for (final argument in arguments) {
      if (argument.required && (values[argument.name] as String).isEmpty) {
        return argument;
      }
    }
    return null;
  }
}

const SlashCommand _shrug = SlashCommand(
  name: '/shrug',
  description: 'отправить каомодзи',
  run: _runShrug,
);

Future<void> _runShrug(PluginCommandContext context) async {
  await context.sendText(r'¯\_(ツ)_/¯');
}

class CommandRegistry {
  CommandRegistry._();

  static final CommandRegistry instance = CommandRegistry._();
  final ValueNotifier<List<SlashCommand>> commands = ValueNotifier(const [
    _shrug,
  ]);
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    PluginStore.instance.plugins.addListener(_rebuild);
    _rebuild();
  }

  void _rebuild() {
    final all = <SlashCommand>[_shrug];
    final names = <String>{_shrug.name};
    for (final plugin in PluginStore.instance.plugins.value) {
      if (!plugin.enabled) continue;
      for (final command in plugin.manifest.commands) {
        if (!names.add(command.name.toLowerCase())) continue;
        all.add(
          SlashCommand(
            name: command.name,
            description: command.description,
            arguments: command.arguments,
            hidden: command.hidden,
            pluginCommand: PluginCommandDescriptor(
              plugin: plugin,
              command: command,
            ),
          ),
        );
      }
    }
    commands.value = List.unmodifiable(all);
  }

  SlashCommand? find(String text) {
    final name = text.trimLeft().split(RegExp(r'\s')).first.toLowerCase();
    for (final command in commands.value) {
      if (command.name.toLowerCase() == name) return command;
    }
    return null;
  }
}

String commandArgs(String text) {
  final trimmed = text.trimLeft();
  final index = trimmed.indexOf(RegExp(r'\s'));
  return index == -1 ? '' : trimmed.substring(index + 1).trim();
}

Map<String, dynamic> parseCommandArguments(
  String raw,
  List<PluginCommandArgumentManifest> specs,
) {
  if (specs.isEmpty) return const {};
  final values = <String, dynamic>{};
  final tokens = _tokenizeArguments(raw);
  for (final spec in specs) {
    if (spec.rest) {
      values[spec.name] = tokens.join(' ');
      tokens.clear();
      continue;
    }
    values[spec.name] = tokens.isEmpty ? '' : tokens.removeAt(0);
  }
  return Map.unmodifiable(values);
}

String serializeCommandArguments(
  List<PluginCommandArgumentManifest> specs,
  Map<String, dynamic> values,
) {
  final parts = <String>[];
  for (final spec in specs) {
    final value = values[spec.name]?.toString().trim() ?? '';
    if (value.isEmpty) continue;
    if (spec.rest) {
      parts.add(value);
    } else {
      parts.add(_quoteArgument(value));
    }
  }
  return parts.join(' ');
}

String _quoteArgument(String value) {
  if (!value.contains(RegExp(r'''[\s"']'''))) return value;
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

List<String> _tokenizeArguments(String source) {
  final values = <String>[];
  var remaining = source.trim();
  while (remaining.isNotEmpty) {
    final parsed = _takeArgument(remaining);
    values.add(parsed.value);
    if (parsed.remaining == remaining) break;
    remaining = parsed.remaining;
  }
  return values;
}

({String value, String remaining}) _takeArgument(String source) {
  final input = source.trimLeft();
  if (input.isEmpty) return (value: '', remaining: '');
  final quote = input[0];
  if (quote == '"' || quote == "'") {
    final buffer = StringBuffer();
    var escaped = false;
    for (var index = 1; index < input.length; index++) {
      final char = input[index];
      if (escaped) {
        buffer.write(char);
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == quote) {
        return (
          value: buffer.toString(),
          remaining: input.substring(index + 1).trimLeft(),
        );
      } else {
        buffer.write(char);
      }
    }
    return (value: buffer.toString(), remaining: '');
  }
  final separator = input.indexOf(RegExp(r'\s'));
  if (separator == -1) return (value: input, remaining: '');
  return (
    value: input.substring(0, separator),
    remaining: input.substring(separator + 1).trimLeft(),
  );
}
