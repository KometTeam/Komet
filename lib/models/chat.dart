import 'package:gwid/models/message.dart';

class Chat {
  final int id;
  final int ownerId;
  final Message lastMessage;
  final List<int> participantIds;
  final int newMessages;
  final String? title; // Название группы
  final String? type; // Тип чата (DIALOG, CHAT)
  final String? baseIconUrl; // URL иконки группы
  final String? description;
  final int? participantsCount;
  final Message? pinnedMessage; // Закрепленное сообщение

  Chat({
    required this.id,
    required this.ownerId,
    required this.lastMessage,
    required this.participantIds,
    required this.newMessages,
    this.title,
    this.type,
    this.baseIconUrl,
    this.description,
    this.participantsCount,
    this.pinnedMessage,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    var participantsMap = json['participants'] as Map<String, dynamic>? ?? {};
    List<int> participantIds = participantsMap.keys
        .map((id) => int.parse(id))
        .toList();

    Message lastMessage;
    if (json['lastMessage'] != null) {
      lastMessage = Message.fromJson(json['lastMessage']);
    } else {
      lastMessage = Message(
        id: 'empty',
        senderId: 0,
        time: DateTime.now().millisecondsSinceEpoch,
        text: '',
        cid: null,
        attaches: [],
      );
    }

    Message? pinnedMessage;
    if (json['pinnedMessage'] != null) {
      pinnedMessage = Message.fromJson(json['pinnedMessage']);
    }

    return Chat(
      id: json['id'] ?? 0,
      ownerId: json['owner'] ?? 0,
      lastMessage: lastMessage,
      participantIds: participantIds,
      newMessages: json['newMessages'] ?? 0,
      title: json['title'],
      type: json['type'],
      baseIconUrl: json['baseIconUrl'],
      description: json['description'],
      participantsCount: json['participantsCount'],
      pinnedMessage: pinnedMessage,
    );
  }

  bool get isGroup => type == 'CHAT' || participantIds.length > 2;

  List<int> get groupParticipantIds => participantIds;

  int get onlineParticipantsCount => participantIds.length; // Упрощенная версия

  String get displayTitle {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    if (isGroup) {
      return 'Группа ${participantIds.length}';
    }
    return 'Чат';
  }

  Chat copyWith({
    Message? lastMessage,
    int? newMessages,
    String? title,
    String? type,
    String? baseIconUrl,
    Message? pinnedMessage,
  }) {
    return Chat(
      id: id,
      ownerId: ownerId,
      lastMessage: lastMessage ?? this.lastMessage,
      participantIds: participantIds,
      newMessages: newMessages ?? this.newMessages,
      title: title ?? this.title,
      type: type ?? this.type,
      baseIconUrl: baseIconUrl ?? this.baseIconUrl,
      description: description ?? description,
      participantsCount: participantsCount,
      pinnedMessage: pinnedMessage ?? this.pinnedMessage,
    );
  }
}
