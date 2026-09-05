import 'dart:convert';

import '../../models/attachment.dart';
import '../../models/chat_preview_media.dart';

// #***! в превью влезает три миниатюры
const int _maxPreviewThumbs = 3;
// #***! длинную base64 превьюшку в базу не кладём, раздувает таблицу
const int _maxThumbLength = 20000;

// #***! подпись чата вместо текста, Изображение Файл и прочее
String? attachPreviewLabel(dynamic attaches) {
  final parts = _attachPreviewParts(attaches);
  if (parts == null) return null;
  final detail = parts.detail;
  return detail == null ? parts.label : '${parts.label}: $detail';
}

// #***! метка и уточнение отдельно, склеит вызывающий
({String label, String? detail})? _attachPreviewParts(dynamic attaches) {
  final first = _firstPreviewAttach(attaches);
  if (first == null) return null;
  final type = (first['_type'] as String? ?? '').toUpperCase();
  switch (type) {
    case 'PHOTO':
      return (
        label: _mediaAttachCount(attaches) > 1 ? 'Изображения' : 'Изображение',
        detail: null,
      );
    case 'VIDEO':
      if (_isVideoNote(first)) return (label: 'Видео-сообщение', detail: null);
      return (label: 'Видео', detail: null);
    case 'AUDIO':
      return (label: 'Голосовое сообщение', detail: null);
    case 'FILE':
      return (label: 'Файл', detail: _nonEmpty(first['name']));
    case 'STICKER':
      return (label: 'Стикер', detail: null);
    case 'SHARE':
      return (label: 'Ссылка', detail: _nonEmpty(first['title']));
    case 'POLL':
      return (label: 'Опрос', detail: _nonEmpty(first['title']));
    case 'LOCATION':
      return (label: 'Геопозиция', detail: null);
    case 'CONTACT':
      return (label: 'Контакт', detail: null);
    case 'CONTROL':
      final label = _controlPreviewLabel(first);
      return label == null ? null : (label: label, detail: null);
    case 'INLINE_KEYBOARD':
      return null;
    case 'CALL':
      return (label: _callPreviewLabel(first), detail: null);
    default:
      return (label: 'Вложение', detail: null);
  }
}

// #***! тот же разбор но для иконки
ChatPreviewKind? _attachPreviewKind(Map attach) {
  switch ((attach['_type'] as String? ?? '').toUpperCase()) {
    case 'PHOTO':
      return ChatPreviewKind.photo;
    case 'VIDEO':
      return _isVideoNote(attach)
          ? ChatPreviewKind.videoNote
          : ChatPreviewKind.video;
    case 'AUDIO':
      return ChatPreviewKind.audio;
    case 'FILE':
      return ChatPreviewKind.file;
    case 'STICKER':
      return ChatPreviewKind.sticker;
    case 'SHARE':
      return ChatPreviewKind.share;
    case 'POLL':
      return ChatPreviewKind.poll;
    case 'LOCATION':
      return ChatPreviewKind.location;
    case 'CONTACT':
      return ChatPreviewKind.contact;
    case 'CONTROL':
      return ChatPreviewKind.control;
    case 'INLINE_KEYBOARD':
      return null;
    case 'CALL':
      final video = attach['callType']?.toString().toUpperCase() == 'VIDEO';
      if (_isFailedCall(attach)) {
        return video
            ? ChatPreviewKind.missedVideoCall
            : ChatPreviewKind.missedCall;
      }
      return video ? ChatPreviewKind.videoCall : ChatPreviewKind.call;
    default:
      return ChatPreviewKind.other;
  }
}

// #***! звонок, групповой пропущенный или обычный
String _callPreviewLabel(Map attach) {
  final video = attach['callType']?.toString().toUpperCase() == 'VIDEO';
  if (attach['joinLink'] != null) {
    return video ? 'Групповой видеозвонок' : 'Групповой звонок';
  }
  if (_isFailedCall(attach)) {
    return video ? 'Пропущенный видеозвонок' : 'Пропущенный звонок';
  }
  return video ? 'Видеозвонок' : 'Звонок';
}

// #***! нулевая длительность или тип сброса значит пропущенный
bool _isFailedCall(Map attach) {
  final duration = (attach['duration'] as num?)?.toInt() ?? 0;
  final hangup = attach['hangupType']?.toString();
  return duration == 0 ||
      hangup == 'CANCELED' ||
      hangup == 'REJECTED' ||
      hangup == 'MISSED';
}

String? _nonEmpty(dynamic raw) {
  final value = raw?.toString();
  return value != null && value.isNotEmpty ? value : null;
}

// #***! инлайн клавиатуру пропускаем, это не вложение
Map? _firstPreviewAttach(dynamic attaches) {
  if (attaches is! List || attaches.isEmpty) return null;
  for (final attach in attaches) {
    if (attach is! Map) continue;
    final type = (attach['_type'] as String? ?? '').toUpperCase();
    if (type == 'INLINE_KEYBOARD') continue;
    return attach;
  }
  return null;
}

// #***! несколько фото значит множественное число
int _mediaAttachCount(dynamic attaches) {
  if (attaches is! List) return 0;
  var count = 0;
  for (final attach in attaches.whereType<Map>()) {
    final type = (attach['_type'] as String? ?? '').toUpperCase();
    if (type == 'PHOTO' || (type == 'VIDEO' && !_isVideoNote(attach))) count++;
  }
  return count;
}

// #***! videoType == 1 это кружок, у него своя подпись
bool _isVideoNote(Map attach) {
  final raw = attach['videoType'];
  if (raw is int) return raw == 1;
  return raw?.toString() == '1';
}

// #***! системное событие, берём текст сервера иначе пишем сами
String? _controlPreviewLabel(Map c) {
  final title = c['title']?.toString();
  if (title != null && title.isNotEmpty) return title;
  final short = c['shortMessage']?.toString();
  if (short != null && short.isNotEmpty) return short;
  switch (c['event']?.toString()) {
    case 'new':
      return 'Чат создан';
    case 'add':
    case 'joinByLink':
      return 'Новый участник';
    case 'leave':
      return 'Участник вышел';
    case 'remove':
      return 'Участник удалён';
    case 'pin':
      return 'Закреплённое сообщение';
    case 'changeTitle':
      return 'Название чата изменено';
    case 'changeIcon':
      return 'Фото чата обновлено';
    default:
      return 'Системное сообщение';
  }
}

// #***! итоговая подпись чата, пересланное со стрелкой
String? messagePreviewText(Map msg) {
  final original = _forwardOrigin(msg);
  if (original != null) {
    final inner = original is Map ? _bodyPreviewText(original) : null;
    return inner != null && inner.isNotEmpty
        ? '↪ $inner'
        : '↪ Пересланное сообщение';
  }
  return _bodyPreviewText(msg);
}

// #***! компактное превью для строки чата
String? messagePreviewMedia(Map msg) {
  final origin = _forwardOrigin(msg);
  final body = origin ?? msg;
  if (body is! Map) return null;
  final first = _firstPreviewAttach(body['attaches']);
  if (first == null) return null;
  final kind = _attachPreviewKind(first);
  if (kind == null) return null;

  // #***! есть подпись к медиа, метку типа не дублируем
  final text = body['text']?.toString();
  final captioned = text != null && text.isNotEmpty;
  final parts = captioned ? null : _attachPreviewParts(body['attaches']);
  final label = parts == null
      ? null
      : (origin == null ? parts.label : '↪ ${parts.label}');

  return ChatPreviewMedia(
    kind: kind,
    thumbs: _previewThumbs(body['attaches']),
    label: label,
    detail: parts?.detail,
  ).encode();
}

// #***! достаём оригинал из пересланного
dynamic _forwardOrigin(Map msg) {
  final link = msg['link'];
  if (link is! Map) return null;
  if (link['type']?.toString().toUpperCase() != 'FORWARD') return null;
  return link['message'];
}

// #***! миниатюры только у фото и видео, максимум три
List<ChatPreviewThumb> _previewThumbs(dynamic attaches) {
  if (attaches is! List) return const [];
  final thumbs = <ChatPreviewThumb>[];
  for (final attach in attaches.whereType<Map>()) {
    if (thumbs.length >= _maxPreviewThumbs) break;
    final type = (attach['_type'] as String? ?? '').toUpperCase();
    final isVideo = type == 'VIDEO';
    if (type != 'PHOTO' && !isVideo) continue;
    final source = _thumbSource(attach, isVideo);
    if (source == null) continue;
    thumbs.add(ChatPreviewThumb(source: source, video: isVideo));
  }
  return thumbs;
}

// #***! берём base64 превьюшку если не гигантская, иначе url
String? _thumbSource(Map attach, bool isVideo) {
  final data = decodeAttachPreview(attach['previewData']);
  if (data != null && data.length <= _maxThumbLength) return data;
  final url = isVideo
      ? _nonEmpty(attach['thumbnail'])
      : _nonEmpty(attach['baseUrl']);
  if (url != null && url.startsWith('http')) return url;
  return null;
}

// #***! подписи покороче для закреплённого
({String? text, bool isPreview}) pinnedMessagePreview(Map msg) {
  final link = msg['link'];
  if (link is Map && link['type']?.toString().toUpperCase() == 'FORWARD') {
    final original = link['message'];
    if (original is Map) {
      final inner = pinnedMessagePreview(original);
      return inner.text != null && inner.text!.isNotEmpty
          ? (text: '↪ ${inner.text}', isPreview: inner.isPreview)
          : (text: '↪ пересланное сообщение', isPreview: true);
    }
    return (text: '↪ пересланное сообщение', isPreview: true);
  }
  return _pinnedBodyPreview(msg);
}

({String? text, bool isPreview}) _pinnedBodyPreview(Map msg) {
  final text = msg['text']?.toString();
  if (text != null && text.isNotEmpty) return (text: text, isPreview: false);
  final label = _pinnedAttachPreviewLabel(msg['attaches']);
  return (text: label, isPreview: label != null);
}

String? _pinnedAttachPreviewLabel(dynamic attaches) {
  final first = _firstPreviewAttach(attaches);
  if (first == null) return null;
  final type = (first['_type'] as String? ?? '').toUpperCase();
  switch (type) {
    case 'PHOTO':
      return 'фото';
    case 'VIDEO':
      return _isVideoNote(first) ? 'кружок' : 'видео';
    case 'AUDIO':
      return 'голосовое сообщение';
    case 'FILE':
      return 'файл';
    case 'STICKER':
      return 'стикер';
    case 'SHARE':
      return 'ссылка';
    case 'POLL':
      return 'голосование';
    case 'LOCATION':
      return 'геопозиция';
    case 'CONTACT':
      return 'контакт';
    case 'CALL':
      return 'звонок';
    case 'CONTROL':
      return _controlPreviewLabel(first)?.toLowerCase();
    default:
      return 'вложение';
  }
}

String? _bodyPreviewText(Map msg) {
  final text = msg['text']?.toString();
  if (text != null && text.isNotEmpty) return text;
  return attachPreviewLabel(msg['attaches']);
}

// #***! форматирование тоже в подпись чтоб жирный и ссылки не терялись
String? messagePreviewElements(Map msg) {
  final text = msg['text'];
  if (text is! String || text.isEmpty) return null;
  final elements = msg['elements'];
  if (elements is List && elements.isNotEmpty) return jsonEncode(elements);
  return null;
}
