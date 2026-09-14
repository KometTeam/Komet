import '../../core/utils/format.dart';
import 'messages.dart';

typedef MessageInfoRow = ({String label, String value});

// #***! эти поля раскладываем по своим строкам, остальные скаляры payload
// дописываем как есть — новое поле сервера появится в панели само
const Set<String> _ownRows = {
  'id',
  'cid',
  'sender',
  'time',
  'updateTime',
  'type',
  'status',
  'text',
  'attaches',
  'elements',
  'link',
  'reactionInfo',
};

const Map<int, String> _e2eeNames = {
  CachedMessage.e2eeText: 'text',
  CachedMessage.e2eeFailed: 'failed',
  CachedMessage.e2eeFile: 'file',
};

// #***! технические поля сообщения ровно теми именами, что приходят с сервера
List<MessageInfoRow> buildMessageInfoRows(CachedMessage message) {
  final payload = message.payload ?? const <String, dynamic>{};
  final rows = <MessageInfoRow>[];

  void add(String label, Object? value) {
    if (value == null) return;
    final text = value.toString();
    if (text.isEmpty) return;
    rows.add((label: label, value: text));
  }

  add('id', message.id);
  add('cid', payload['cid']);
  add('chatId', message.chatId);
  add('sender', message.senderId == 0 ? null : message.senderId);
  add('type', payload['type']);
  add('status', message.status);
  add('time', _stamp(message.time));
  add('updateTime', _stamp(_asInt(payload['updateTime'])));
  add('text.length', message.text?.length);
  add('attaches', _attachesSummary(message));
  add('elements', _elementsSummary(payload['elements']));
  add('link', _linkSummary(payload['link']));
  add('reactionInfo', _reactionsSummary(payload['reactionInfo']));
  add('editHistory', message.editHistory?.length);
  add('e2ee', _e2eeNames[message.e2ee]);
  if (message.deleted) add('deleted', true);

  for (final entry in payload.entries) {
    if (_ownRows.contains(entry.key)) continue;
    final value = entry.value;
    if (value is Map || value is List) continue;
    add(entry.key, value);
  }

  return rows;
}

String? _stamp(int? ms) {
  if (ms == null || ms <= 0) return null;
  final at = DateTime.fromMillisecondsSinceEpoch(ms);
  return '$ms · ${formatDateTimeNumeric(at)}';
}

int? _asInt(Object? raw) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '');
}

String? _attachesSummary(CachedMessage message) {
  final raw = message.previewPayload['attaches'];
  if (raw is! List || raw.isEmpty) return null;
  return _joinCounted([
    for (final attach in raw.whereType<Map>())
      attach['_type']?.toString() ?? '?',
  ]);
}

String? _elementsSummary(Object? raw) {
  if (raw is! List || raw.isEmpty) return null;
  return _joinCounted([
    for (final element in raw.whereType<Map>())
      element['type']?.toString() ?? '?',
  ]);
}

// #***! повторы схлопываем в «LINK ×3», иначе разметка займёт весь экран
String? _joinCounted(List<String> values) {
  if (values.isEmpty) return null;
  final counts = <String, int>{};
  for (final value in values) {
    counts.update(value, (n) => n + 1, ifAbsent: () => 1);
  }
  return [
    for (final entry in counts.entries)
      entry.value > 1 ? '${entry.key} ×${entry.value}' : entry.key,
  ].join(', ');
}

String? _linkSummary(Object? raw) {
  if (raw is! Map) return null;
  final parts = <String>[];
  final type = raw['type']?.toString();
  if (type != null && type.isNotEmpty) parts.add(type);
  final name = raw['chatName']?.toString();
  final chatId = raw['chatId'];
  if (name != null && name.isNotEmpty) {
    parts.add(chatId == null ? name : '$name ($chatId)');
  } else if (chatId != null) {
    parts.add(chatId.toString());
  }
  final inner = raw['message'];
  if (inner is Map) {
    final innerId = inner['id']?.toString();
    if (innerId != null && innerId.isNotEmpty) parts.add(innerId);
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

String? _reactionsSummary(Object? raw) {
  if (raw is! Map) return null;
  final counters = raw['counters'];
  if (counters is! List || counters.isEmpty) return null;
  final parts = <String>[];
  var total = 0;
  for (final counter in counters.whereType<Map>()) {
    final reaction = counter['reaction']?.toString();
    if (reaction == null || reaction.isEmpty) continue;
    final count = _asInt(counter['count']) ?? 0;
    total += count;
    parts.add('$reaction $count');
  }
  if (parts.isEmpty) return null;
  final your = raw['yourReaction']?.toString();
  final declared = _asInt(raw['totalCount']) ?? total;
  return [
    parts.join(', '),
    'total $declared',
    if (your != null && your.isNotEmpty) 'your $your',
  ].join(' · ');
}
