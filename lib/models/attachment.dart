import 'dart:convert';

import '../core/utils/parse.dart';

enum AttachmentType {
  photo,
  video,
  audio,
  file,
  contact,
  location,
  sticker,
  control,
  poll,
  share,
  call,
  inlineKeyboard,
  forward,
  unknown,
}

String? decodeAttachPreview(dynamic raw) {
  if (raw is String) return raw;
  if (raw is List) {
    try {
      final bytes = List<int>.from(raw);
      return 'data:image/webp;base64,${base64Encode(bytes)}';
    } catch (_) {}
  }
  return null;
}

abstract class MessageAttachment {
  final AttachmentType type;
  final String? previewData;
  final String? baseUrl;
  final String? fileUrl;

  const MessageAttachment({
    required this.type,
    this.previewData,
    this.baseUrl,
    this.fileUrl,
  });

  factory MessageAttachment.fromMap(Map<String, dynamic> map) {
    final type = (map['_type'] as String? ?? '').toUpperCase();
    switch (type) {
      case 'PHOTO':
        return PhotoAttachment.fromMap(map);
      case 'VIDEO':
        return VideoAttachment.fromMap(map);
      case 'AUDIO':
        return AudioAttachment.fromMap(map);
      case 'FILE':
        return FileAttachment.fromMap(map);
      case 'STICKER':
        return StickerAttachment.fromMap(map);
      case 'CONTACT':
        return ContactAttachment.fromMap(map);
      case 'LOCATION':
        return LocationAttachment.fromMap(map);
      case 'CONTROL':
        return ControlAttachment.fromMap(map);
      case 'POLL':
        return PollAttachment.fromMap(map);
      case 'CALL':
        return CallAttachment.fromMap(map);
      case 'SHARE':
        return ShareAttachment.fromMap(map);
      case 'INLINE_KEYBOARD':
        return InlineKeyboardAttachment.fromMap(map);
      default:
        return UnknownAttachment(map);
    }
  }

  Map<String, dynamic> toMap();
}

class PhotoAttachment extends MessageAttachment {
  final int? photoId;
  final String? photoToken;
  final int? width;
  final int? height;
  final int? size;
  final String? localPath;

  const PhotoAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.photoId,
    this.photoToken,
    this.width,
    this.height,
    this.size,
    this.localPath,
  }) : super(type: AttachmentType.photo);

  factory PhotoAttachment.fromMap(Map<String, dynamic> map) {
    return PhotoAttachment(
      previewData: decodeAttachPreview(map['previewData']),
      baseUrl: (map['baseUrl'] ?? map['url']) as String?,
      photoId: map['photoId'] as int?,
      photoToken: map['photoToken'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      size: map['size'] as int?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'PHOTO',
    'previewData': previewData,
    'baseUrl': baseUrl,
    'photoId': photoId,
    'photoToken': photoToken,
    'width': width,
    'height': height,
    'size': size,
  };
}

class VideoAttachment extends MessageAttachment {
  final int? videoId;
  final String? videoToken;
  final String? thumbnail;
  final int? width;
  final int? height;
  final int? duration;
  final int? size;

  final int? videoType;

  bool get isNote => videoType == 1;

  const VideoAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.videoId,
    this.videoToken,
    this.thumbnail,
    this.width,
    this.height,
    this.duration,
    this.size,
    this.videoType,
  }) : super(type: AttachmentType.video);

  factory VideoAttachment.fromMap(Map<String, dynamic> map) {
    return VideoAttachment(
      previewData: decodeAttachPreview(map['previewData']),
      baseUrl: map['baseUrl'] as String?,
      videoId: map['videoId'] as int?,
      videoToken: (map['token'] ?? map['videoToken'])?.toString(),
      thumbnail: map['thumbnail'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      duration: map['duration'] as int?,
      size: map['size'] as int?,
      videoType: map['videoType'] as int?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'VIDEO',
    'previewData': previewData,
    'baseUrl': baseUrl,
    'videoId': videoId,
    'videoToken': videoToken,
    'thumbnail': thumbnail,
    'width': width,
    'height': height,
    'duration': duration,
    'size': size,
    'videoType': videoType,
  };
}

class AudioAttachment extends MessageAttachment {
  final int? audioId;
  final String? audioToken;
  final int? duration;
  final int? size;
  final String? waveform;

  const AudioAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.audioId,
    this.audioToken,
    this.duration,
    this.size,
    this.waveform,
  }) : super(type: AttachmentType.audio);

  factory AudioAttachment.fromMap(Map<String, dynamic> map) {
    String? waveStr;
    final waveRaw = map['wave'];
    if (waveRaw is String) {
      waveStr = waveRaw;
    } else if (waveRaw is List) {
      try {
        final bytes = List<int>.from(waveRaw);
        waveStr = String.fromCharCodes(bytes);
      } catch (_) {}
    }

    return AudioAttachment(
      previewData: decodeAttachPreview(map['previewData']),
      baseUrl: map['baseUrl']?.toString(),
      fileUrl: map['url']?.toString(),
      audioId: map['audioId'] as int?,
      audioToken: map['token']?.toString(),
      duration: map['duration'] as int?,
      size: map['size'] as int?,
      waveform: waveStr,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'AUDIO',
    'previewData': previewData,
    'baseUrl': baseUrl,
    'audioId': audioId,
    'audioToken': audioToken,
    'duration': duration,
    'size': size,
    'waveform': waveform,
  };
}

class FileAttachment extends MessageAttachment {
  final int? fileId;
  final String? fileToken;
  final String? name;
  final int? size;
  final PhotoAttachment? preview;

  const FileAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.fileId,
    this.fileToken,
    this.name,
    this.size,
    this.preview,
  }) : super(type: AttachmentType.file);

  factory FileAttachment.fromMap(Map<String, dynamic> map) {
    PhotoAttachment? preview;
    final previewRaw = map['preview'];
    if (previewRaw is Map) {
      preview = PhotoAttachment.fromMap(Map<String, dynamic>.from(previewRaw));
    }

    return FileAttachment(
      previewData: decodeAttachPreview(map['previewData']),
      baseUrl: map['baseUrl'] as String?,
      fileId: map['fileId'] as int?,
      fileToken: (map['fileToken'] ?? map['token'])?.toString(),
      name: map['name'] as String?,
      size: map['size'] as int?,
      preview: preview,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'FILE',
    'previewData': previewData,
    'baseUrl': baseUrl,
    'fileId': fileId,
    'fileToken': fileToken,
    'name': name,
    'size': size,
    if (preview != null) 'preview': preview!.toMap(),
  };
}

class StickerAttachment extends MessageAttachment {
  final String? stickerId;
  final String? stickerPackId;
  final String? lottieUrl;
  final int? width;
  final int? height;

  const StickerAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.stickerId,
    this.stickerPackId,
    this.lottieUrl,
    this.width,
    this.height,
  }) : super(type: AttachmentType.sticker);

  bool get isAnimated => lottieUrl != null && lottieUrl!.isNotEmpty;

  factory StickerAttachment.fromMap(Map<String, dynamic> map) {
    return StickerAttachment(
      previewData: decodeAttachPreview(map['previewData']),
      baseUrl: (map['url'] ?? map['baseUrl'])?.toString(),
      stickerId: map['stickerId']?.toString(),
      stickerPackId:
          map['setId']?.toString() ?? map['stickerPackId']?.toString(),
      lottieUrl: map['lottieUrl']?.toString(),
      width: map['width'] as int?,
      height: map['height'] as int?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'STICKER',
    'previewData': previewData,
    'baseUrl': baseUrl,
    'stickerId': stickerId,
    'stickerPackId': stickerPackId,
    'lottieUrl': lottieUrl,
    'width': width,
    'height': height,
  };
}

class ContactAttachment extends MessageAttachment {
  final String? userId;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? photoUrl;
  final int? contactId;
  final String? name;

  const ContactAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.userId,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.photoUrl,
    this.contactId,
    this.name,
  }) : super(type: AttachmentType.contact);

  factory ContactAttachment.fromMap(Map<String, dynamic> map) {
    return ContactAttachment(
      previewData: map['previewData']?.toString(),
      baseUrl: map['baseUrl']?.toString(),
      userId: map['userId']?.toString(),
      firstName: map['firstName']?.toString(),
      lastName: map['lastName']?.toString(),
      phoneNumber: map['phoneNumber']?.toString(),
      photoUrl: map['photoUrl']?.toString(),
      contactId: map['contactId'] is int
          ? map['contactId'] as int
          : int.tryParse(map['contactId']?.toString() ?? ''),
      name: map['name']?.toString(),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'CONTACT',
    'previewData': previewData,
    'baseUrl': baseUrl,
    'userId': userId,
    'firstName': firstName,
    'lastName': lastName,
    'phoneNumber': phoneNumber,
    'photoUrl': photoUrl,
    'contactId': contactId,
    'name': name,
  };
}

class LocationAttachment extends MessageAttachment {
  final double? latitude;
  final double? longitude;
  final double? zoom;
  final String? title;
  final String? address;

  const LocationAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.latitude,
    this.longitude,
    this.zoom,
    this.title,
    this.address,
  }) : super(type: AttachmentType.location);

  factory LocationAttachment.fromMap(Map<String, dynamic> map) {
    return LocationAttachment(
      previewData: map['previewData'] as String?,
      baseUrl: map['baseUrl'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      zoom: (map['zoom'] as num?)?.toDouble(),
      title: map['title'] as String?,
      address: map['address'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'LOCATION',
    'previewData': previewData,
    'baseUrl': baseUrl,
    'latitude': latitude,
    'longitude': longitude,
    'zoom': zoom,
    'title': title,
    'address': address,
  };
}

class ControlAttachment extends MessageAttachment {
  final String? event;
  final String? title;
  final List<int>? userIds;
  final int? userId;

  const ControlAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.event,
    this.title,
    this.userIds,
    this.userId,
  }) : super(type: AttachmentType.control);

  factory ControlAttachment.fromMap(Map<String, dynamic> map) {
    String? title = map['title']?.toString();
    if ((title == null || title.isEmpty) && map['shortMessage'] != null) {
      title = map['shortMessage'].toString();
    }

    return ControlAttachment(
      previewData: map['previewData']?.toString(),
      baseUrl: map['baseUrl']?.toString(),
      event: map['event']?.toString(),
      title: title,
      userIds: map['userIds'] is List ? parseIntList(map['userIds']) : null,
      userId: map['userId'] is int
          ? map['userId'] as int
          : int.tryParse(map['userId']?.toString() ?? ''),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'CONTROL',
    'previewData': previewData,
    'baseUrl': baseUrl,
    'event': event,
    'title': title,
    'userIds': userIds,
    'userId': userId,
  };
}

class PollAttachment extends MessageAttachment {
  final int pollId;
  final String? title;

  const PollAttachment({required this.pollId, this.title})
    : super(type: AttachmentType.poll);

  factory PollAttachment.fromMap(Map<String, dynamic> map) {
    final id = map['pollId'] ?? map['id'];
    return PollAttachment(
      pollId: id is int ? id : int.tryParse(id?.toString() ?? '') ?? 0,
      title: (map['title'] ?? map['question'])?.toString(),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'POLL',
    'pollId': pollId,
    'title': title,
  };
}

class CallAttachment extends MessageAttachment {
  final bool isVideo;
  final int durationMs;
  final String? hangupType;
  final String? conversationId;
  final String? joinLink;
  final List<int> contactIds;

  const CallAttachment({
    required this.isVideo,
    this.durationMs = 0,
    this.hangupType,
    this.conversationId,
    this.joinLink,
    this.contactIds = const [],
  }) : super(type: AttachmentType.call);

  bool get isGroup => joinLink != null;

  bool get isMissedOrFailed =>
      durationMs == 0 ||
      hangupType == 'CANCELED' ||
      hangupType == 'REJECTED' ||
      hangupType == 'MISSED';

  factory CallAttachment.fromMap(Map<String, dynamic> map) {
    return CallAttachment(
      isVideo: (map['callType']?.toString().toUpperCase() == 'VIDEO'),
      durationMs: (map['duration'] as num?)?.toInt() ?? 0,
      hangupType: map['hangupType']?.toString(),
      conversationId: map['conversationId']?.toString(),
      joinLink: map['joinLink']?.toString(),
      contactIds: parseIntList(map['contactIds']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'CALL',
    'callType': isVideo ? 'VIDEO' : 'AUDIO',
    'duration': durationMs,
    'hangupType': hangupType,
    'conversationId': conversationId,
    if (joinLink != null) 'joinLink': joinLink,
    if (contactIds.isNotEmpty) 'contactIds': contactIds,
  };
}

class ShareAttachment extends MessageAttachment {
  final int? shareId;
  final String? title;
  final String? description;
  final String? url;
  final String? host;
  final PhotoAttachment? image;

  const ShareAttachment({
    this.shareId,
    this.title,
    this.description,
    this.url,
    this.host,
    this.image,
  }) : super(type: AttachmentType.share);

  factory ShareAttachment.fromMap(Map<String, dynamic> map) {
    PhotoAttachment? image;
    final imageRaw = map['image'];
    if (imageRaw is Map) {
      image = PhotoAttachment.fromMap(Map<String, dynamic>.from(imageRaw));
    }

    return ShareAttachment(
      shareId: map['shareId'] as int?,
      title: map['title']?.toString(),
      description: map['description']?.toString(),
      url: map['url']?.toString(),
      host: map['host']?.toString(),
      image: image,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'SHARE',
    'shareId': shareId,
    'title': title,
    'description': description,
    'url': url,
    'host': host,
    if (image != null) 'image': image!.toMap(),
  };
}

class InlineKeyboardButton {
  final String type;
  final String text;
  final String? url;
  final String? webApp;
  final int? contactId;
  final String? payload;

  const InlineKeyboardButton({
    required this.type,
    required this.text,
    this.url,
    this.webApp,
    this.contactId,
    this.payload,
  });

  factory InlineKeyboardButton.fromMap(Map<String, dynamic> map) {
    return InlineKeyboardButton(
      type: (map['type'] as String? ?? '').toUpperCase(),
      text: map['text']?.toString() ?? '',
      url: map['url']?.toString(),
      webApp: map['webApp']?.toString(),
      contactId: map['contactId'] is int
          ? map['contactId'] as int
          : int.tryParse(map['contactId']?.toString() ?? ''),
      payload: map['payload']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    'text': text,
    if (url != null) 'url': url,
    if (webApp != null) 'webApp': webApp,
    if (contactId != null) 'contactId': contactId,
    if (payload != null) 'payload': payload,
  };
}

class InlineKeyboardAttachment extends MessageAttachment {
  final String? callbackId;
  final List<List<InlineKeyboardButton>> rows;

  const InlineKeyboardAttachment({this.callbackId, required this.rows})
    : super(type: AttachmentType.inlineKeyboard);

  bool get isEmpty => rows.every((row) => row.isEmpty);

  factory InlineKeyboardAttachment.fromMap(Map<String, dynamic> map) {
    final keyboard = map['keyboard'];
    final rawRows = keyboard is Map ? keyboard['buttons'] as List? : null;
    final rows = <List<InlineKeyboardButton>>[];
    if (rawRows != null) {
      for (final row in rawRows) {
        if (row is! List) continue;
        rows.add(
          row
              .whereType<Map>()
              .map(
                (b) =>
                    InlineKeyboardButton.fromMap(Map<String, dynamic>.from(b)),
              )
              .toList(),
        );
      }
    }
    return InlineKeyboardAttachment(
      callbackId: map['callbackId']?.toString(),
      rows: rows,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'INLINE_KEYBOARD',
    if (callbackId != null) 'callbackId': callbackId,
    'keyboard': {
      'buttons': rows.map((row) => row.map((b) => b.toMap()).toList()).toList(),
    },
  };
}

class ForwardedMessageAttachment extends MessageAttachment {
  final int originalSenderId;
  final String? originalSenderName;
  final String? originalSenderAvatar;
  final String? originalMessageId;
  final int? originalTime;
  final String? originalText;
  final int? originalChatId;
  final List<MessageAttachment>? originalAttachments;
  final ContactAttachment? originalContact;

  const ForwardedMessageAttachment({
    required this.originalSenderId,
    this.originalSenderName,
    this.originalSenderAvatar,
    this.originalMessageId,
    this.originalTime,
    this.originalText,
    this.originalChatId,
    this.originalAttachments,
    this.originalContact,
  }) : super(type: AttachmentType.forward);

  factory ForwardedMessageAttachment.fromMap(Map<String, dynamic> map) {
    final linkRaw = map['link'];
    Map<String, dynamic>? link;
    if (linkRaw is Map) {
      link = Map<String, dynamic>.from(linkRaw);
    }

    Map<String, dynamic>? message;
    if (link != null) {
      final msgRaw = link['message'];
      if (msgRaw is Map) {
        message = Map<String, dynamic>.from(msgRaw);
      }
    }

    List<MessageAttachment>? originalAttaches;
    ContactAttachment? originalContact;
    if (message != null) {
      final attaches = message['attaches'] as List?;
      if (attaches != null) {
        final contactAttaches = attaches
            .whereType<Map>()
            .where((a) => (a['_type'] as String?)?.toUpperCase() == 'CONTACT')
            .toList();
        if (contactAttaches.isNotEmpty) {
          originalContact = ContactAttachment.fromMap(
            Map<String, dynamic>.from(contactAttaches.first),
          );
        }
        originalAttaches = attaches
            .whereType<Map>()
            .where((a) {
              final type = (a['_type'] as String?)?.toUpperCase();
              return type != 'CONTACT';
            })
            .map((a) => MessageAttachment.fromMap(Map<String, dynamic>.from(a)))
            .toList();
      }
    }

    return ForwardedMessageAttachment(
      originalSenderId: (message?['sender'] as int?) ?? 0,
      originalMessageId: message?['id']?.toString(),
      originalTime: message?['time'] as int?,
      originalText: message?['text'] as String?,
      originalChatId: link?['chatId'] as int?,
      originalAttachments: originalAttaches,
      originalContact: originalContact,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'FORWARD',
    'originalSenderId': originalSenderId,
    'originalSenderName': originalSenderName,
    'originalSenderAvatar': originalSenderAvatar,
    'originalMessageId': originalMessageId,
    'originalTime': originalTime,
    'originalText': originalText,
    'originalChatId': originalChatId,
  };
}

class UnknownAttachment extends MessageAttachment {
  final Map<String, dynamic> rawData;

  const UnknownAttachment(this.rawData) : super(type: AttachmentType.unknown);

  @override
  Map<String, dynamic> toMap() => rawData;
}
