import '../../core/protocol/opcode_map.dart';
import '../../core/utils/logger.dart';
import '../../models/attachment.dart';
import '../api.dart';

const Map<String, AttachmentType> _attachTypeByName = {
  'PHOTO': AttachmentType.photo,
  'VIDEO': AttachmentType.video,
  'AUDIO': AttachmentType.audio,
  'FILE': AttachmentType.file,
  'SHARE': AttachmentType.share,
};

class SharedMediaItem {
  final String messageId;
  final int chatId;
  final int senderId;
  final int time;
  final MessageAttachment attachment;
  final String? text;

  const SharedMediaItem({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.time,
    required this.attachment,
    this.text,
  });

  String get dedupKey {
    final a = attachment;
    final String tail;
    if (a is PhotoAttachment) {
      tail = 'p${a.photoId ?? a.baseUrl}';
    } else if (a is VideoAttachment) {
      tail = 'v${a.videoId ?? a.baseUrl}';
    } else if (a is FileAttachment) {
      tail = 'f${a.fileId ?? a.name}';
    } else if (a is AudioAttachment) {
      tail = 'a${a.audioId ?? a.fileUrl}';
    } else if (a is ShareAttachment) {
      tail = 's${a.shareId ?? a.url}';
    } else {
      tail = a.hashCode.toString();
    }
    return '$messageId:$tail';
  }
}

class SharedMediaPage {
  final List<SharedMediaItem> items;
  final int total;

  const SharedMediaPage({required this.items, required this.total});

  static const empty = SharedMediaPage(items: [], total: 0);
}

class CommonChatEntry {
  final int id;
  final String type;
  final String title;
  final String? iconUrl;
  final int participantsCount;
  final List<int> participantIds;

  const CommonChatEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.iconUrl,
    required this.participantsCount,
    required this.participantIds,
  });

  factory CommonChatEntry.fromMap(Map<String, dynamic> map) {
    final participants = map['participants'];
    final ids = <int>[];
    if (participants is Map) {
      for (final key in participants.keys) {
        final id = key is int ? key : int.tryParse(key.toString());
        if (id != null) ids.add(id);
      }
    }
    return CommonChatEntry(
      id: (map['id'] as num?)?.toInt() ?? 0,
      type: map['type']?.toString() ?? 'CHAT',
      title: map['title']?.toString() ?? '',
      iconUrl: map['baseIconUrl'] as String?,
      participantsCount:
          (map['participantsCount'] as num?)?.toInt() ?? ids.length,
      participantIds: ids,
    );
  }
}

class ChatPhotoFeed {
  final List<SharedMediaItem> items;
  final int total;
  final bool reachedEnd;

  const ChatPhotoFeed({
    required this.items,
    required this.total,
    required this.reachedEnd,
  });
}

class _ChatPhotoIndex {
  final List<SharedMediaItem> items = [];
  final Set<String> seen = {};
  int total = 0;
  bool reachedEnd = false;
  bool started = false;
  Future<void>? inFlight;
}

String photoDedupKey(String messageId, PhotoAttachment photo) =>
    '$messageId:p${photo.photoId ?? photo.baseUrl}';

class SharedContentModule {
  static const int _photoIndexPageSize = 60;
  static const int _photoIndexMaxPages = 40;

  static final Map<int, _ChatPhotoIndex> _photoIndexes = {};

  final Api _api;

  SharedContentModule(this._api);

  static void clearPhotoIndex() => _photoIndexes.clear();

  Future<ChatPhotoFeed?> photoFeedFor({
    required int chatId,
    required String photoKey,
    required Future<String?> Function() resolveAnchor,
  }) async {
    final index = _photoIndexes.putIfAbsent(chatId, _ChatPhotoIndex.new);

    for (var page = 0; page < _photoIndexMaxPages; page++) {
      if (index.seen.contains(photoKey)) return _snapshot(index);
      if (index.reachedEnd) return null;
      await _nextPhotoPage(chatId, index, resolveAnchor);
    }
    return null;
  }

  Future<ChatPhotoFeed> loadMorePhotos({
    required int chatId,
    required Future<String?> Function() resolveAnchor,
  }) async {
    final index = _photoIndexes.putIfAbsent(chatId, _ChatPhotoIndex.new);
    if (!index.reachedEnd) {
      await _nextPhotoPage(chatId, index, resolveAnchor);
    }
    return _snapshot(index);
  }

  ChatPhotoFeed _snapshot(_ChatPhotoIndex index) {
    final counted = index.items.length;
    final total = index.reachedEnd
        ? counted
        : (index.total > counted ? index.total : counted);
    return ChatPhotoFeed(
      items: List.unmodifiable(index.items),
      total: total,
      reachedEnd: index.reachedEnd,
    );
  }

  Future<void> _nextPhotoPage(
    int chatId,
    _ChatPhotoIndex index,
    Future<String?> Function() resolveAnchor,
  ) async {
    final pending = index.inFlight;
    if (pending != null) {
      await pending;
      return;
    }
    final task = _loadPhotoPage(chatId, index, resolveAnchor);
    index.inFlight = task;
    try {
      await task;
    } finally {
      index.inFlight = null;
    }
  }

  Future<void> _loadPhotoPage(
    int chatId,
    _ChatPhotoIndex index,
    Future<String?> Function() resolveAnchor,
  ) async {
    final initial = !index.started;
    final anchor = initial
        ? await resolveAnchor()
        : index.items.last.messageId;
    if (anchor == null || anchor.isEmpty) {
      index.reachedEnd = true;
      return;
    }

    final page = await fetchMedia(
      chatId: chatId,
      anchorMessageId: anchor,
      attachTypes: const ['PHOTO'],
      forward: initial ? _photoIndexPageSize : 0,
      backward: _photoIndexPageSize,
    );
    index.started = true;
    if (page.total > index.total) index.total = page.total;

    final fresh = <SharedMediaItem>[];
    for (final item in page.items) {
      if (index.seen.add(item.dedupKey)) fresh.add(item);
    }
    if (fresh.isEmpty) {
      index.reachedEnd = true;
      return;
    }

    final oldest = index.items.isEmpty ? null : index.items.last;
    index.items.addAll(fresh);
    if (oldest != null && fresh.first.time > oldest.time) {
      index.items.sort((a, b) => b.time.compareTo(a.time));
    }
  }

  Future<SharedMediaPage> fetchMedia({
    required int chatId,
    required String anchorMessageId,
    required List<String> attachTypes,
    int forward = 0,
    int backward = 60,
  }) async {
    try {
      final response = await _api.sendRequest(Opcode.chatMedia, {
        'chatId': chatId,
        'messageId': int.tryParse(anchorMessageId) ?? 0,
        'attachTypes': attachTypes,
        'forward': forward,
        'backward': backward,
      });
      if (!response.isOk) return SharedMediaPage.empty;

      final data = response.payload;
      if (data is! Map) return SharedMediaPage.empty;

      final messages = data['messages'];
      if (messages is! List) return SharedMediaPage.empty;

      final wanted = attachTypes
          .map((t) => _attachTypeByName[t])
          .whereType<AttachmentType>()
          .toSet();

      final out = <SharedMediaItem>[];
      for (final m in messages) {
        if (m is! Map) continue;
        final map = Map<String, dynamic>.from(m);
        final id = map['id']?.toString();
        if (id == null) continue;
        final sender = (map['sender'] as num?)?.toInt() ?? 0;
        final time = (map['time'] as num?)?.toInt() ?? 0;
        final text = map['text'] as String?;
        final attaches = map['attaches'];
        if (attaches is! List) continue;
        for (final a in attaches) {
          if (a is! Map) continue;
          final att = MessageAttachment.fromMap(Map<String, dynamic>.from(a));
          if (!wanted.contains(att.type)) continue;
          out.add(
            SharedMediaItem(
              messageId: id,
              chatId: chatId,
              senderId: sender,
              time: time,
              attachment: att,
              text: text,
            ),
          );
        }
      }

      out.sort((a, b) => b.time.compareTo(a.time));
      final total = (data['total'] as num?)?.toInt() ?? out.length;
      return SharedMediaPage(items: out, total: total);
    } catch (e) {
      logger.w('SharedContent.fetchMedia failed: $e');
      return SharedMediaPage.empty;
    }
  }

  Future<List<CommonChatEntry>> fetchCommonChats(int userId) async {
    try {
      final response = await _api.sendRequest(
        Opcode.chatSearchCommonParticipants,
        {
          'userIds': [userId],
        },
      );
      if (!response.isOk) return const [];

      final data = response.payload;
      if (data is! Map) return const [];

      final chats = data['commonChats'];
      if (chats is! List) return const [];

      final out = <CommonChatEntry>[];
      for (final c in chats) {
        if (c is Map) {
          out.add(CommonChatEntry.fromMap(Map<String, dynamic>.from(c)));
        }
      }
      return out;
    } catch (e) {
      logger.w('SharedContent.fetchCommonChats failed: $e');
      return const [];
    }
  }
}
