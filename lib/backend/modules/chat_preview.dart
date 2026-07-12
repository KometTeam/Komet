import 'dart:convert';

String? attachPreviewLabel(dynamic attaches) {
  final first = _firstPreviewAttach(attaches);
  if (first == null) return null;
  final type = (first['_type'] as String? ?? '').toUpperCase();
  switch (type) {
    case 'PHOTO':
      return 'Фото';
    case 'VIDEO':
      return _isVideoNote(first) ? 'Видео-сообщение' : 'Видео';
    case 'AUDIO':
      return 'Голосовое сообщение';
    case 'FILE':
      final name = first['name']?.toString();
      return name != null && name.isNotEmpty ? 'Файл: $name' : 'Файл';
    case 'STICKER':
      return 'Стикер';
    case 'SHARE':
      final title = first['title']?.toString();
      return title != null && title.isNotEmpty ? 'Ссылка: $title' : 'Ссылка';
    case 'POLL':
      final title = first['title']?.toString();
      return title != null && title.isNotEmpty ? 'Опрос: $title' : 'Опрос';
    case 'LOCATION':
      return 'Геопозиция';
    case 'CONTACT':
      return 'Контакт';
    case 'CONTROL':
      return _controlPreviewLabel(first);
    case 'INLINE_KEYBOARD':
      return null;
    case 'CALL':
      final video = first['callType']?.toString().toUpperCase() == 'VIDEO';
      final dur = (first['duration'] as num?)?.toInt() ?? 0;
      final hangup = first['hangupType']?.toString();
      final failed =
          dur == 0 ||
          hangup == 'CANCELED' ||
          hangup == 'REJECTED' ||
          hangup == 'MISSED';
      if (first['joinLink'] != null) {
        return video ? 'Групповой видеозвонок' : 'Групповой звонок';
      }
      if (failed) {
        return video ? 'Пропущенный видеозвонок' : 'Пропущенный звонок';
      }
      return video ? 'Видеозвонок' : 'Звонок';
    default:
      return 'Вложение';
  }
}

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

bool _isVideoNote(Map attach) {
  final raw = attach['videoType'];
  if (raw is int) return raw == 1;
  return raw?.toString() == '1';
}

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

String? messagePreviewText(Map msg) {
  final link = msg['link'];
  if (link is Map && link['type']?.toString().toUpperCase() == 'FORWARD') {
    final original = link['message'];
    final inner = original is Map ? _bodyPreviewText(original) : null;
    return inner != null && inner.isNotEmpty
        ? '↪ $inner'
        : '↪ Пересланное сообщение';
  }
  return _bodyPreviewText(msg);
}

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

String? messagePreviewElements(Map msg) {
  final text = msg['text'];
  if (text is! String || text.isEmpty) return null;
  final elements = msg['elements'];
  if (elements is List && elements.isNotEmpty) return jsonEncode(elements);
  return null;
}
