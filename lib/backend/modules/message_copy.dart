import 'dart:typed_data';

import '../../core/utils/parse.dart';
import '../../models/attachment.dart';
import 'messages.dart';

class MessageCopy {
  final String text;
  final List<Map<String, dynamic>> elements;
  final List<Map<String, dynamic>> attaches;
  final List<Map<String, dynamic>> wireAttaches;

  const MessageCopy._({
    required this.text,
    required this.elements,
    required this.attaches,
    required this.wireAttaches,
  });

  static const _strippedTypes = {'INLINE_KEYBOARD', 'SHARE'};

  static MessageCopy? of(CachedMessage message) {
    if (message.isControl || message.e2ee != CachedMessage.e2eeNone) {
      return null;
    }
    final source = _contentOf(message);
    final text = source['text']?.toString() ?? '';
    final attaches = <Map<String, dynamic>>[];
    final wireAttaches = <Map<String, dynamic>>[];
    for (final attach in _maps(source['attaches'])) {
      final type = attach['_type']?.toString().toUpperCase();
      if (_strippedTypes.contains(type)) continue;
      final wire = _wireAttach(type, attach);
      if (wire == null) return null;
      attaches.add(attach);
      wireAttaches.add(wire);
    }
    if (text.trim().isEmpty && wireAttaches.isEmpty) return null;
    return MessageCopy._(
      text: text,
      elements: _maps(source['elements']),
      attaches: attaches,
      wireAttaches: wireAttaches,
    );
  }

  CachedMessage toOutgoing({
    required int accountId,
    required int chatId,
    required String tempId,
    required int time,
  }) {
    final payload = <String, dynamic>{
      'text': text,
      'elements': elements,
      'attaches': attaches,
    };
    final (attachments, isControl) = CachedMessage.parseAttachments(payload);
    return CachedMessage(
      id: tempId,
      accountId: accountId,
      chatId: chatId,
      senderId: accountId,
      text: text,
      time: time,
      status: 'sending',
      payload: payload,
      attachments: attachments,
      isControl: isControl,
    );
  }

  static Map<String, dynamic> _contentOf(CachedMessage message) {
    final payload = message.payload;
    final link = payload?['link'];
    if (link is Map && link['type']?.toString().toUpperCase() == 'FORWARD') {
      final original = link['message'];
      return original is Map ? Map<String, dynamic>.from(original) : const {};
    }
    return {
      'text': message.text,
      'elements': payload?['elements'],
      'attaches':
          payload?['attaches'] ??
          [
            for (final attachment
                in message.attachments ?? const <MessageAttachment>[])
              attachment.toMap(),
          ],
    };
  }

  static List<Map<String, dynamic>> _maps(Object? raw) => raw is List
      ? [
          for (final item in raw.whereType<Map>())
            Map<String, dynamic>.from(item),
        ]
      : const [];

  static Map<String, dynamic>? _wireAttach(
    String? type,
    Map<String, dynamic> attach,
  ) {
    switch (type) {
      case 'PHOTO':
        final token = attach['photoToken'];
        if (token == null) return null;
        return {'_type': 'PHOTO', 'photoToken': token};
      case 'VIDEO':
        final token = attach['token'] ?? attach['videoToken'];
        if (token == null) return null;
        if (parseIntOrNull(attach['videoType']) != 1) {
          return {'videoType': 0, '_type': 'VIDEO', 'token': token};
        }
        final thumbhash = attach['thumbhash'];
        return {
          'duration': ?parseIntOrNull(attach['duration']),
          'videoType': 1,
          '_type': 'VIDEO',
          'wave': _wave(attach['wave']),
          'token': token,
          'thumbhash': ?thumbhash,
        };
      case 'AUDIO':
        final token = attach['token'] ?? attach['audioToken'];
        if (token == null) return null;
        return {
          'duration': ?parseIntOrNull(attach['duration']),
          '_type': 'AUDIO',
          'wave': _wave(attach['wave']),
          'token': token,
        };
      case 'FILE':
        final fileId = parseIntOrNull(attach['fileId']);
        if (fileId != null) return {'_type': 'FILE', 'fileId': fileId};
        final token = attach['token'] ?? attach['fileToken'];
        if (token == null) return null;
        return {'_type': 'FILE', 'token': token};
      case 'STICKER':
        final stickerId = parseIntOrNull(attach['stickerId']);
        if (stickerId == null) return null;
        return {'_type': 'STICKER', 'stickerId': stickerId};
      case 'CONTACT':
        final contactId = parseIntOrNull(attach['contactId']);
        if (contactId == null) return null;
        return {'_type': 'CONTACT', 'contactId': contactId};
      case 'LOCATION':
        final latitude = attach['latitude'];
        final longitude = attach['longitude'];
        if (latitude is! num || longitude is! num) return null;
        final zoom = attach['zoom'];
        return {
          '_type': 'LOCATION',
          'latitude': latitude.toDouble(),
          'longitude': longitude.toDouble(),
          'zoom': zoom is num ? zoom.toDouble() : 15.0,
        };
      default:
        return null;
    }
  }

  static Uint8List _wave(Object? raw) {
    final samples = parseIntList(raw);
    return samples.isEmpty ? Uint8List(80) : Uint8List.fromList(samples);
  }
}
