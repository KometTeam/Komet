import '../core/utils/parse.dart';
import 'attachment.dart';

enum StoryOwnerType { user, chat, channel }

int _ownerTypeToInt(StoryOwnerType type) {
  switch (type) {
    case StoryOwnerType.user:
      return 0;
    case StoryOwnerType.chat:
      return 1;
    case StoryOwnerType.channel:
      return 2;
  }
}

StoryOwnerType _ownerTypeFromInt(Object? raw) {
  switch (parseIntOrNull(raw)) {
    case 1:
      return StoryOwnerType.chat;
    case 2:
      return StoryOwnerType.channel;
    default:
      return StoryOwnerType.user;
  }
}

Map<String, dynamic> _asStringMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const {};
}

class StoryOwner {
  final int ownerId;
  final StoryOwnerType type;

  const StoryOwner({required this.ownerId, this.type = StoryOwnerType.user});

  bool get isUser => type == StoryOwnerType.user;

  static StoryOwner? fromMap(Object? raw) {
    final map = _asStringMap(raw);
    final id = parseIntOrNull(map['ownerId']);
    if (id == null || id == 0) return null;
    return StoryOwner(ownerId: id, type: _ownerTypeFromInt(map['type']));
  }

  Map<String, dynamic> toMap() => {
    'ownerId': ownerId,
    'type': _ownerTypeToInt(type),
  };

  @override
  bool operator ==(Object other) =>
      other is StoryOwner &&
      other.ownerId == ownerId &&
      other.type == type;

  @override
  int get hashCode => Object.hash(ownerId, type);
}

class StoryReaction {
  final int reactionType; // 0 = emoji, 1 = sticker
  final String id;

  const StoryReaction({this.reactionType = 0, required this.id});

  bool get isSticker => reactionType == 1;

  static StoryReaction? fromMap(Object? raw) {
    final map = _asStringMap(raw);
    final id = map['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return StoryReaction(
      reactionType: parseIntOrNull(map['reactionType']) ?? 0,
      id: id,
    );
  }

  Map<String, dynamic> toMap() => {'reactionType': reactionType, 'id': id};
}

class StoryMedia {
  final AttachmentType type;
  final String? url;
  final String? thumbnailUrl;
  final String? previewData;
  final int? width;
  final int? height;
  final int? durationMs;

  const StoryMedia({
    required this.type,
    this.url,
    this.thumbnailUrl,
    this.previewData,
    this.width,
    this.height,
    this.durationMs,
  });

  bool get isVideo => type == AttachmentType.video;
  bool get isPhoto => type == AttachmentType.photo;

  double get aspectRatio {
    final w = width ?? 0;
    final h = height ?? 0;
    if (w <= 0 || h <= 0) return 9 / 16;
    return w / h;
  }

  static StoryMedia? fromMap(Object? raw) {
    final map = _asStringMap(raw);
    final typeStr = (map['_type'] as String? ?? '').toUpperCase();
    final previewData = decodeAttachPreview(map['previewData']);
    final width = parseIntOrNull(map['width']);
    final height = parseIntOrNull(map['height']);
    switch (typeStr) {
      case 'PHOTO':
        final url =
            (map['photoUrl'] ?? map['baseUrl'] ?? map['url'])?.toString();
        return StoryMedia(
          type: AttachmentType.photo,
          url: url,
          previewData: previewData,
          width: width,
          height: height,
        );
      case 'VIDEO':
        final url =
            (map['mp4Url'] ??
                    map['videoUrl'] ??
                    map['MP4_1080'] ??
                    map['baseUrl'])
                ?.toString();
        return StoryMedia(
          type: AttachmentType.video,
          url: url,
          thumbnailUrl: map['thumbnail']?.toString(),
          previewData: previewData,
          width: width,
          height: height,
          durationMs: parseIntOrNull(map['duration']),
        );
      default:
        return StoryMedia(
          type: AttachmentType.unknown,
          previewData: previewData,
          width: width,
          height: height,
        );
    }
  }

  String get _typeName {
    switch (type) {
      case AttachmentType.photo:
        return 'PHOTO';
      case AttachmentType.video:
        return 'VIDEO';
      default:
        return 'UNKNOWN';
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      '_type': _typeName,
      if (previewData != null) 'previewData': previewData,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    };
    if (isVideo) {
      if (url != null) map['mp4Url'] = url;
      if (thumbnailUrl != null) map['thumbnail'] = thumbnailUrl;
      if (durationMs != null) map['duration'] = durationMs;
    } else {
      if (url != null) map['photoUrl'] = url;
    }
    return map;
  }
}

class Story {
  final int id;
  final int cid;
  final StoryOwner owner;
  final int settings;
  final int time;
  final int updateTime;
  final int expiration;
  final StoryMedia? media;
  final StoryReaction? reaction;

  const Story({
    required this.id,
    required this.owner,
    this.cid = 0,
    this.settings = 0,
    this.time = 0,
    this.updateTime = 0,
    this.expiration = 0,
    this.media,
    this.reaction,
  });

  Story copyWith({StoryReaction? reaction, bool clearReaction = false}) {
    return Story(
      id: id,
      cid: cid,
      owner: owner,
      settings: settings,
      time: time,
      updateTime: updateTime,
      expiration: expiration,
      media: media,
      reaction: clearReaction ? null : (reaction ?? this.reaction),
    );
  }

  static Story? fromMap(Object? raw) {
    final map = _asStringMap(raw);
    final owner = StoryOwner.fromMap(map['owner']);
    if (owner == null) return null;
    return Story(
      id: parseIntOrNull(map['id']) ?? 0,
      cid: parseIntOrNull(map['cid']) ?? 0,
      owner: owner,
      settings: parseIntOrNull(map['settings']) ?? 0,
      time: parseIntOrNull(map['time']) ?? 0,
      updateTime: parseIntOrNull(map['updateTime']) ?? 0,
      expiration: parseIntOrNull(map['expiration']) ?? 0,
      media: StoryMedia.fromMap(map['media']),
      reaction: StoryReaction.fromMap(map['reaction']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'cid': cid,
    'owner': owner.toMap(),
    'settings': settings,
    'time': time,
    'updateTime': updateTime,
    'expiration': expiration,
    if (media != null) 'media': media!.toJson(),
    if (reaction != null) 'reaction': reaction!.toMap(),
  };
}

class StoryPreview {
  final StoryOwner owner;
  final int updateTime;
  final int totalCount;
  final int readCount;
  final int lastStoryExpirationTime;

  const StoryPreview({
    required this.owner,
    this.updateTime = 0,
    this.totalCount = 0,
    this.readCount = 0,
    this.lastStoryExpirationTime = 0,
  });

  int get unreadCount {
    final diff = totalCount - readCount;
    return diff < 0 ? 0 : diff;
  }

  bool get hasUnread => unreadCount > 0;

  bool get isEmpty => totalCount <= 0;

  StoryPreview copyWith({int? readCount}) => StoryPreview(
    owner: owner,
    updateTime: updateTime,
    totalCount: totalCount,
    readCount: readCount ?? this.readCount,
    lastStoryExpirationTime: lastStoryExpirationTime,
  );

  static StoryPreview? fromMap(Object? raw) {
    final map = _asStringMap(raw);
    final owner = StoryOwner.fromMap(map['owner']);
    if (owner == null) return null;
    return StoryPreview(
      owner: owner,
      updateTime: parseIntOrNull(map['updateTime']) ?? 0,
      totalCount: parseIntOrNull(map['totalCount']) ?? 0,
      readCount: parseIntOrNull(map['readCount']) ?? 0,
      lastStoryExpirationTime:
          parseIntOrNull(map['lastStoryExpirationTime']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'owner': owner.toMap(),
    'updateTime': updateTime,
    'totalCount': totalCount,
    'readCount': readCount,
    'lastStoryExpirationTime': lastStoryExpirationTime,
  };
}

class PeerStories {
  final StoryOwner owner;
  final List<Story> stories;

  const PeerStories({required this.owner, this.stories = const []});

  static PeerStories? fromMap(Object? raw) {
    final map = _asStringMap(raw);
    final owner = StoryOwner.fromMap(map['owner']);
    if (owner == null) return null;
    final rawStories = map['stories'];
    final stories = <Story>[];
    if (rawStories is List) {
      for (final s in rawStories) {
        final story = Story.fromMap(s);
        if (story != null) stories.add(story);
      }
    }
    return PeerStories(owner: owner, stories: stories);
  }
}
