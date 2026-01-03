enum AttachTypes { call, control, inlineKeyboard, share }

abstract class Attachment {
  final AttachTypes type;

  Attachment(this.type);

  factory Attachment.fromJson(Map<String, dynamic> json) {
    final typeString = json['_type'] as String;
    switch (typeString) {
      case 'CALL':
        return CallAttachment.fromJson(json);
      case 'CONTROL':
        return ControlAttachment.fromJson(json);
      case 'INLINE_KEYBOARD':
        return InlineKeyboardAttachment.fromJson(json);
      case 'SHARE':
        return ShareAttachment.fromJson(json);
      default:
        throw ArgumentError('Unknown attachment type: $typeString');
    }
  }
}

class CallAttachment extends Attachment {
  final int duration;
  final String conversationId;
  final String hangupType;
  final String joinLink;
  final String callType;

  CallAttachment({
    required this.duration,
    required this.conversationId,
    required this.hangupType,
    required this.joinLink,
    required this.callType,
  }) : super(AttachTypes.call);

  factory CallAttachment.fromJson(Map<String, dynamic> json) {
    return CallAttachment(
      duration: json['duration'] as int,
      conversationId: json['conversationId'] as String,
      hangupType: json['hangupType'] as String,
      joinLink: json['joinLink'] as String,
      callType: json['callType'] as String,
    );
  }
}

class ControlAttachment extends Attachment {
  final String event;

  ControlAttachment({required this.event}) : super(AttachTypes.control);

  factory ControlAttachment.fromJson(Map<String, dynamic> json) {
    return ControlAttachment(event: json['event'] as String);
  }
}

class InlineKeyboardAttachment extends Attachment {
  final Map<String, dynamic> keyboard;
  final String callbackId;

  InlineKeyboardAttachment({required this.keyboard, required this.callbackId})
    : super(AttachTypes.inlineKeyboard);

  factory InlineKeyboardAttachment.fromJson(Map<String, dynamic> json) {
    return InlineKeyboardAttachment(
      keyboard: json['keyboard'] as Map<String, dynamic>,
      callbackId: json['callbackId'] as String,
    );
  }
}

class ShareAttachment extends Attachment {
  final Map<String, dynamic> image;
  final String description;
  final bool contentLevel;
  final int shareId;
  final String title;
  final String url;

  ShareAttachment({
    required this.image,
    required this.description,
    required this.contentLevel,
    required this.shareId,
    required this.title,
    required this.url,
  }) : super(AttachTypes.share);

  factory ShareAttachment.fromJson(Map<String, dynamic> json) {
    return ShareAttachment(
      image: json['image'] as Map<String, dynamic>,
      description: json['description'] as String,
      contentLevel: json['contentLevel'] as bool,
      shareId: json['shareId'] as int,
      title: json['title'] as String,
      url: json['url'] as String,
    );
  }
}

class AttachmentsParser {
  static List<Attachment> parse(List<dynamic> jsonList) {
    return jsonList.map((jsonItem) {
      if (jsonItem is Map<String, dynamic>) {
        return Attachment.fromJson(jsonItem);
      } else {
        throw ArgumentError('Invalid JSON item in the list: $jsonItem');
      }
    }).toList();
  }
}
