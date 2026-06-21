import '../../core/cache/info_cache.dart';
import '../../core/utils/format.dart';
import 'slash_command.dart';

Future<void> runInfo(CommandContext ctx) async {
  final targetId = ctx.otherUserId;
  if (targetId == null) {
    ctx.notify('Команда доступна только в диалоге');
    return;
  }

  if (!ctx.isOnline()) {
    ctx.notify('Нет соединения');
    return;
  }

  final messageId = await ctx.postMessage('сбор данных...');
  if (messageId.isEmpty) return;

  final contact = await ContactInfoFetch.get(targetId, forceRefresh: true);
  if (!ctx.isActive()) return;

  await ctx.updateMessage(
    messageId,
    contact == null ? 'Данные не получены' : _summary(contact, targetId),
  );
}

String _summary(Map<String, dynamic> c, int targetId) {
  final flags = (c['options'] as List?)?.whereType<String>().toList() ?? const [];
  final region = (c['country'] as String?)?.trim();

  return 'Никнейм: ${_nick(c)}\n'
      'Дата регистрации: ${_date(c['registrationTime'])}\n'
      'Дата последнего изменения профиля: ${_date(c['updateTime'])}\n'
      'id: ${c['id'] ?? targetId}\n'
      'Регион: ${region == null || region.isEmpty ? '—' : region}\n'
      'Флаги: ${flags.isEmpty ? '—' : flags.join(', ')}\n'
      'ip: not fetched';
}

String _nick(Map<String, dynamic> c) {
  final names = c['names'];
  if (names is List && names.isNotEmpty && names.first is Map) {
    final n = names.first as Map;
    final name = (n['name'] as String?) ??
        '${n['firstName'] ?? ''} ${n['lastName'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
  }
  return '—';
}

String _date(dynamic ms) {
  if (ms is! int || ms <= 0) return '—';
  return formatDateTimeWords(DateTime.fromMillisecondsSinceEpoch(ms));
}
