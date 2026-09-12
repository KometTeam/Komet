import '../../backend/modules/messages.dart' show CachedMessage;
import '../../core/storage/app_database.dart';
import 'performance_monitor.dart';

// #***! генератор синтетической нагрузки для меню разработчика — набивает
// локальную БД фейковыми сообщениями, чтобы можно было стресс-тестировать
// скролл/рендер без реальной большой переписки
class LoadSimulator {
  LoadSimulator._();

  static const _prefix = 'sim_';

  static const _words = [
    'лорем',
    'ипсум',
    'долор',
    'сит',
    'амет',
    'тест',
    'нагрузка',
    'сообщение',
    'быстро',
    'скролл',
    'рендер',
    'кадр',
    'пузырь',
    'история',
    'протокол',
    'клиент',
  ];

  static String _fakeText(int seed) {
    final rand = seed * 2654435761 % 4294967296;
    final wordCount = 3 + (rand % 28);
    final buffer = StringBuffer();
    for (var i = 0; i < wordCount; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(_words[(rand + i * 7) % _words.length]);
    }
    return buffer.toString();
  }

  /// Пишет [count] синтетических сообщений в чат [chatId] для аккаунта
  /// [accountId], растянутых по времени с интервалом [stepMs] назад от
  /// текущего момента. Каждое второе — "от другого" (fakeOtherId).
  static Future<void> generateMessages({
    required int accountId,
    required int chatId,
    required int count,
    int fakeOtherId = 900000000,
    int stepMs = 45000,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < count; i++) {
      final isMe = i.isEven;
      final message = CachedMessage(
        id: '$_prefix${chatId}_${now}_$i',
        accountId: accountId,
        chatId: chatId,
        senderId: isMe ? accountId : fakeOtherId,
        text: _fakeText(i),
        time: now - (count - i) * stepMs,
        status: 'sent',
      );
      rows.add(message.toDbRow());
    }
    PerformanceMonitor.instance.mark('load-sim:generate($chatId)');
    await AppDatabase.saveMessages(rows);
    PerformanceMonitor.instance.markActivityEnd();
  }

  /// Параллельно пишет [perChat] сообщений в каждый чат из [chatIds] —
  /// имитация одновременной нагрузки от нескольких чатов сразу (например
  /// пока грузится список чатов или после долгого офлайна).
  static Future<void> generateAcrossChats({
    required int accountId,
    required List<int> chatIds,
    required int perChat,
  }) => Future.wait([
    for (final chatId in chatIds)
      generateMessages(accountId: accountId, chatId: chatId, count: perChat),
  ]);

  static Future<void> clear({
    required int accountId,
    required int chatId,
  }) => AppDatabase.deleteSyntheticMessages(accountId, chatId, prefix: _prefix);

  static Future<void> clearAcrossChats({
    required int accountId,
    required List<int> chatIds,
  }) => Future.wait([
    for (final chatId in chatIds) clear(accountId: accountId, chatId: chatId),
  ]);
}
