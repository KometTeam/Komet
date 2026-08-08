import 'contact_info.dart';

class BotCommand {
  final String name;
  final String? description;

  const BotCommand({required this.name, this.description});

  factory BotCommand.fromMap(Map map) => BotCommand(
    name: map['name']?.toString() ?? '',
    description: (map['description'] as String?)?.trim().isNotEmpty == true
        ? (map['description'] as String).trim()
        : null,
  );

  String get slash => '/$name';
}

class BotInfo {
  final int botId;
  final List<BotCommand> commands;
  final ContactInfo? contact;

  const BotInfo({required this.botId, required this.commands, this.contact});

  factory BotInfo.fromPayload(int botId, Map<String, dynamic> payload) {
    final rawCommands = payload['commands'];
    final commands = <BotCommand>[];
    if (rawCommands is List) {
      for (final c in rawCommands.whereType<Map>()) {
        final command = BotCommand.fromMap(c);
        if (command.name.isNotEmpty) commands.add(command);
      }
    }
    final rawContact = payload['contact'];
    return BotInfo(
      botId: botId,
      commands: commands,
      contact: rawContact is Map
          ? ContactInfo.fromMap(Map<String, dynamic>.from(rawContact))
          : null,
    );
  }

  String? get description => contact?.raw['description'] as String?;

  String? get link => contact?.raw['link'] as String?;
}
