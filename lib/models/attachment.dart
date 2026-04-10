enum AttachmentType {
  photo,
  video,
  audio,
  file,
  contact,
  location,
  sticker,
  control,
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
      case 'SHARE':
        return FileAttachment.fromMap(map);
      case 'INLINE_KEYBOARD':
        return UnknownAttachment(map);
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

  const PhotoAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.photoId,
    this.photoToken,
    this.width,
    this.height,
    this.size,
  }) : super(type: AttachmentType.photo);

  factory PhotoAttachment.fromMap(Map<String, dynamic> map) {
    String? previewStr;
    final previewRaw = map['previewData'];
    if (previewRaw is String) {
      previewStr = previewRaw;
    } else if (previewRaw is List) {
      try {
        final bytes = List<int>.from(previewRaw);
        final base64 = String.fromCharCodes(bytes);
        previewStr = 'data:image/webp;base64,$base64';
      } catch (_) {}
    }

    return PhotoAttachment(
      previewData: previewStr,
      baseUrl: map['baseUrl'] as String?,
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
  final int? width;
  final int? height;
  final int? duration;
  final int? size;

  const VideoAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.videoId,
    this.videoToken,
    this.width,
    this.height,
    this.duration,
    this.size,
  }) : super(type: AttachmentType.video);

  factory VideoAttachment.fromMap(Map<String, dynamic> map) {
    String? previewStr;
    final previewRaw = map['previewData'];
    if (previewRaw is String) {
      previewStr = previewRaw;
    } else if (previewRaw is List) {
      try {
        final bytes = List<int>.from(previewRaw);
        previewStr = String.fromCharCodes(bytes);
      } catch (_) {}
    }

    return VideoAttachment(
      previewData: previewStr,
      baseUrl: map['baseUrl'] as String?,
      videoId: map['videoId'] as int?,
      videoToken: map['videoToken'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      duration: map['duration'] as int?,
      size: map['size'] as int?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'VIDEO',
    'previewData': previewData,
    'baseUrl': baseUrl,
    'videoId': videoId,
    'videoToken': videoToken,
    'width': width,
    'height': height,
    'duration': duration,
    'size': size,
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
    String? previewStr;
    final previewRaw = map['previewData'];
    if (previewRaw is String) {
      previewStr = previewRaw;
    } else if (previewRaw is List) {
      try {
        final bytes = List<int>.from(previewRaw);
        previewStr = String.fromCharCodes(bytes);
      } catch (_) {}
    }

    return AudioAttachment(
      previewData: previewStr,
      baseUrl: map['baseUrl'] as String?,
      audioId: map['audioId'] as int?,
      audioToken: map['audioToken'] as String?,
      duration: map['duration'] as int?,
      size: map['size'] as int?,
      waveform: map['waveform'] as String?,
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

  const FileAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.fileId,
    this.fileToken,
    this.name,
    this.size,
  }) : super(type: AttachmentType.file);

  factory FileAttachment.fromMap(Map<String, dynamic> map) {
    String? previewStr;
    final previewRaw = map['previewData'];
    if (previewRaw is String) {
      previewStr = previewRaw;
    } else if (previewRaw is List) {
      try {
        final bytes = List<int>.from(previewRaw);
        previewStr = String.fromCharCodes(bytes);
      } catch (_) {}
    }

    return FileAttachment(
      previewData: previewStr,
      baseUrl: map['baseUrl'] as String?,
      fileId: map['fileId'] as int?,
      fileToken: map['fileToken'] as String?,
      name: map['name'] as String?,
      size: map['size'] as int?,
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
  };
}

class StickerAttachment extends MessageAttachment {
  final String? stickerId;
  final String? stickerPackId;
  final int? width;
  final int? height;

  const StickerAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.stickerId,
    this.stickerPackId,
    this.width,
    this.height,
  }) : super(type: AttachmentType.sticker);

  factory StickerAttachment.fromMap(Map<String, dynamic> map) {
    String? previewStr;
    final previewRaw = map['previewData'];
    if (previewRaw is String) {
      previewStr = previewRaw;
    } else if (previewRaw is List) {
      try {
        final bytes = List<int>.from(previewRaw);
        previewStr = String.fromCharCodes(bytes);
      } catch (_) {}
    }

    return StickerAttachment(
      previewData: previewStr,
      baseUrl: map['baseUrl'] as String?,
      stickerId: map['stickerId'] as String?,
      stickerPackId: map['stickerPackId'] as String?,
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
    'width': width,
    'height': height,
  };
}

class ContactAttachment extends MessageAttachment {
  final String? userId;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;

  const ContactAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.userId,
    this.firstName,
    this.lastName,
    this.phoneNumber,
  }) : super(type: AttachmentType.contact);

  factory ContactAttachment.fromMap(Map<String, dynamic> map) {
    return ContactAttachment(
      previewData: map['previewData'] as String?,
      baseUrl: map['baseUrl'] as String?,
      userId: map['userId'] as String?,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
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
  };
}

class LocationAttachment extends MessageAttachment {
  final double? latitude;
  final double? longitude;
  final String? title;
  final String? address;

  const LocationAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.latitude,
    this.longitude,
    this.title,
    this.address,
  }) : super(type: AttachmentType.location);

  factory LocationAttachment.fromMap(Map<String, dynamic> map) {
    return LocationAttachment(
      previewData: map['previewData'] as String?,
      baseUrl: map['baseUrl'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
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
    'title': title,
    'address': address,
  };
}

class ControlAttachment extends MessageAttachment {
  final String? event;
  final String? title;
  final List<int>? userIds;

  const ControlAttachment({
    super.previewData,
    super.baseUrl,
    super.fileUrl,
    this.event,
    this.title,
    this.userIds,
  }) : super(type: AttachmentType.control);

  factory ControlAttachment.fromMap(Map<String, dynamic> map) {
    return ControlAttachment(
      previewData: map['previewData'] as String?,
      baseUrl: map['baseUrl'] as String?,
      event: map['event'] as String?,
      title: map['title'] as String?,
      userIds: (map['userIds'] as List?)?.cast<int>(),
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
  };
}

class ForwardedMessageAttachment extends MessageAttachment {
  final int originalSenderId;
  final String? originalSenderName;
  final String? originalMessageId;
  final int? originalTime;
  final String? originalText;
  final int? originalChatId;
  final List<MessageAttachment>? originalAttachments;

  const ForwardedMessageAttachment({
    required this.originalSenderId,
    this.originalSenderName,
    this.originalMessageId,
    this.originalTime,
    this.originalText,
    this.originalChatId,
    this.originalAttachments,
  }) : super(type: AttachmentType.photo);

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
    if (message != null) {
      final attaches = message['attaches'] as List?;
      if (attaches != null) {
        originalAttaches = attaches
            .whereType<Map>()
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
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    '_type': 'FORWARD',
    'originalSenderId': originalSenderId,
    'originalSenderName': originalSenderName,
    'originalMessageId': originalMessageId,
    'originalTime': originalTime,
    'originalText': originalText,
    'originalChatId': originalChatId,
  };
}

class UnknownAttachment extends MessageAttachment {
  final Map<String, dynamic> rawData;

  const UnknownAttachment(this.rawData) : super(type: AttachmentType.photo);

  @override
  Map<String, dynamic> toMap() => rawData;
}
