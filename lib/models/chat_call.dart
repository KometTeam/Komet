import 'dart:convert';

import '../core/utils/parse.dart';

class ChatCall {
  final String joinLink;
  final bool isVideo;
  final int participantsCount;
  final List<int> participantIds;

  const ChatCall({
    required this.joinLink,
    required this.isVideo,
    required this.participantsCount,
    this.participantIds = const [],
  });

  static ChatCall? fromServer(Object? raw) {
    if (raw is! Map) return null;
    final joinLink = raw['joinLink']?.toString() ?? '';
    if (joinLink.isEmpty) return null;
    final participantIds = parseIntList(raw['previewParticipantIds']);
    final approxCount = parseIntOrNull(raw['approxParticipantsCount']) ?? 0;
    final participantsCount = approxCount > 0
        ? approxCount
        : participantIds.length;
    if (participantsCount <= 0) return null;
    return ChatCall(
      joinLink: joinLink,
      isVideo: raw['callType']?.toString().toUpperCase() == 'VIDEO',
      participantsCount: participantsCount,
      participantIds: participantIds,
    );
  }

  String encode() => jsonEncode({
    'l': joinLink,
    if (isVideo) 'v': true,
    'c': participantsCount,
    if (participantIds.isNotEmpty) 'p': participantIds,
  });

  static ChatCall? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final joinLink = map['l']?.toString() ?? '';
      if (joinLink.isEmpty) return null;
      return ChatCall(
        joinLink: joinLink,
        isVideo: map['v'] == true,
        participantsCount: parseIntOrNull(map['c']) ?? 0,
        participantIds: parseIntList(map['p']),
      );
    } catch (_) {
      return null;
    }
  }
}
