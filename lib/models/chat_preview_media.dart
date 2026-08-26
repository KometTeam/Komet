import 'dart:convert';

enum ChatPreviewKind {
  photo,
  video,
  videoNote,
  audio,
  file,
  sticker,
  contact,
  location,
  poll,
  share,
  call,
  missedCall,
  videoCall,
  missedVideoCall,
  control,
  other,
}

const Map<ChatPreviewKind, String> _kindToCode = {
  ChatPreviewKind.photo: 'photo',
  ChatPreviewKind.video: 'video',
  ChatPreviewKind.videoNote: 'videoNote',
  ChatPreviewKind.audio: 'audio',
  ChatPreviewKind.file: 'file',
  ChatPreviewKind.sticker: 'sticker',
  ChatPreviewKind.contact: 'contact',
  ChatPreviewKind.location: 'location',
  ChatPreviewKind.poll: 'poll',
  ChatPreviewKind.share: 'share',
  ChatPreviewKind.call: 'call',
  ChatPreviewKind.missedCall: 'missedCall',
  ChatPreviewKind.videoCall: 'videoCall',
  ChatPreviewKind.missedVideoCall: 'missedVideoCall',
  ChatPreviewKind.control: 'control',
  ChatPreviewKind.other: 'other',
};

final Map<String, ChatPreviewKind> _codeToKind = {
  for (final e in _kindToCode.entries) e.value: e.key,
};

class ChatPreviewThumb {
  final String source;
  final bool video;

  const ChatPreviewThumb({required this.source, this.video = false});

  Map<String, dynamic> toMap() => {'s': source, if (video) 'v': true};

  static ChatPreviewThumb? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final source = raw['s']?.toString();
    if (source == null || source.isEmpty) return null;
    return ChatPreviewThumb(source: source, video: raw['v'] == true);
  }
}

class ChatPreviewMedia {
  final ChatPreviewKind kind;
  final List<ChatPreviewThumb> thumbs;
  final String? label;
  final String? detail;

  const ChatPreviewMedia({
    required this.kind,
    this.thumbs = const [],
    this.label,
    this.detail,
  });

  bool get captioned => label == null && detail == null;

  Map<String, dynamic> toMap() => {
    'k': _kindToCode[kind],
    if (thumbs.isNotEmpty) 't': [for (final thumb in thumbs) thumb.toMap()],
    if (label != null) 'l': label,
    if (detail != null) 'd': detail,
  };

  String encode() => jsonEncode(toMap());

  static ChatPreviewMedia? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromMap(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static ChatPreviewMedia? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final kind = _codeToKind[raw['k']?.toString()];
    if (kind == null) return null;
    final thumbsRaw = raw['t'];
    return ChatPreviewMedia(
      kind: kind,
      thumbs: thumbsRaw is List
          ? [for (final item in thumbsRaw) ?ChatPreviewThumb.fromMap(item)]
          : const [],
      label: raw['l']?.toString(),
      detail: raw['d']?.toString(),
    );
  }
}
