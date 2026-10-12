import '../core/utils/text_format.dart';
import 'contact_info.dart';

// #***! одна команда бота из меню /
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

  // #***! как команда выглядит в поле ввода
  String get slash => '/$name';
}

// #***! данные бота плюс карточка контакта
class BotStartMessage {
  final String text;
  final List<FormatRange> ranges;

  const BotStartMessage({required this.text, this.ranges = const []});

  static BotStartMessage? fromPayload(Object? raw) {
    if (raw is! Map) return null;
    final body = raw['text'];
    if (body is! Map) return null;
    final text = body['text'];
    if (text is! String || text.trim().isEmpty) return null;
    return BotStartMessage(
      text: text,
      ranges: parseFormatElements(body['elements']),
    );
  }

  ({String heading, String body, List<FormatRange> bodyRanges}) get sections {
    var split = 0;
    for (final range in ranges) {
      if (range.format == TextFormat.heading && range.start == 0) {
        split = range.end.clamp(0, text.length);
        break;
      }
    }
    final rest = text.substring(split);
    final bodyStart = split + rest.length - rest.trimLeft().length;
    final body = text.substring(bodyStart).trimRight();
    return (
      heading: text.substring(0, split).trim(),
      body: body,
      bodyRanges: [
        for (final range in ranges)
          if (range.format != TextFormat.heading &&
              range.start >= bodyStart &&
              range.start - bodyStart < body.length)
            FormatRange(
              format: range.format,
              start: range.start - bodyStart,
              length: range.end - bodyStart > body.length
                  ? body.length - (range.start - bodyStart)
                  : range.length,
              entityId: range.entityId,
              entityName: range.entityName,
              attributes: range.attributes,
            ),
      ],
    );
  }
}

class BotInfo {
  final int botId;
  final List<BotCommand> commands;
  final ContactInfo? contact;
  final BotStartMessage? startMessage;

  const BotInfo({
    required this.botId,
    required this.commands,
    this.contact,
    this.startMessage,
  });

  // #***! склеиваем ответ, пустые имена выкидываем
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
      startMessage: BotStartMessage.fromPayload(payload['startMessage']),
    );
  }

  // #***! описание и ссылка в сыром контакте
  String? get description => contact?.raw['description'] as String?;

  String? get link => contact?.raw['link'] as String?;
}
