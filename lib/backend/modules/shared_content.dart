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

  const SharedMediaItem({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.time,
    required this.attachment,
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

class SharedContentModule {
  final Api _api;

  SharedContentModule(this._api);

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
