import 'dart:convert';

String? attachPreviewLabel(dynamic attaches) {
  if (attaches is! List || attaches.isEmpty) return null;
  final first = attaches.first;
  if (first is! Map) return null;
  final type = (first['_type'] as String? ?? '').toUpperCase();
  switch (type) {
    case 'PHOTO':
      return 'Фото';
    case 'VIDEO':
      return 'Видео';
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
