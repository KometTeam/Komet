class BotCommand {
  final int botId;
  final String name;
  final String description;

  const BotCommand({
    required this.botId,
    required this.name,
    required this.description,
  });

  factory BotCommand.fromJson(Map<String, dynamic> json) {
    return BotCommand(
      botId: (json['botId'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
    );
  }

  String get slashCommand => '/$name';
}
