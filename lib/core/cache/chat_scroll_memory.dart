import 'dart:async';

import '../storage/app_database.dart';
import '../utils/logger.dart';

// #***! докуда долистали: нижнее видимое сообщение и на сколько его низ ниже
// низа списка; в списке с якорем на этом сообщении это ровно pixels
typedef ChatScrollPoint = ({String id, int time, double pixels});

// #***! позиции живут в памяти, в базу уходят только при уходе из чата
class ChatScrollMemory {
  ChatScrollMemory._();

  static final Map<String, ChatScrollPoint> _points = {};
  static final Set<String> _dirty = {};
  static final Set<int> _primed = {};

  static String _key(int accountId, int chatId) => '$accountId:$chatId';

  // #***! один запрос на аккаунт, чтобы чат открывался сразу на месте
  static Future<void> prime(int accountId) async {
    if (!_primed.add(accountId)) return;
    try {
      final rows = await AppDatabase.loadChatScrollPoints(accountId);
      for (final row in rows) {
        final chatId = row['chat_id'];
        final id = row['message_id'];
        final time = row['time'];
        final pixels = row['pixels'];
        if (chatId is! int || id is! String || time is! int) continue;
        if (pixels is! num) continue;
        final key = _key(accountId, chatId);
        if (_dirty.contains(key)) continue;
        _points.putIfAbsent(
          key,
          () => (id: id, time: time, pixels: pixels.toDouble()),
        );
      }
    } catch (e) {
      _primed.remove(accountId);
      logger.w('Позиции чатов не прочитались: $e');
    }
  }

  static ChatScrollPoint? of(int accountId, int chatId) =>
      _points[_key(accountId, chatId)];

  static void remember(int accountId, int chatId, ChatScrollPoint? point) {
    final key = _key(accountId, chatId);
    if (_points[key] == point) return;
    if (point == null) {
      _points.remove(key);
    } else {
      _points[key] = point;
    }
    _dirty.add(key);
  }

  static Future<void> persist(int accountId, int chatId) async {
    if (!_dirty.remove(_key(accountId, chatId))) return;
    final point = _points[_key(accountId, chatId)];
    try {
      if (point == null) {
        await AppDatabase.deleteChatScrollPoint(accountId, chatId);
      } else {
        await AppDatabase.saveChatScrollPoint(
          accountId,
          chatId,
          messageId: point.id,
          time: point.time,
          pixels: point.pixels,
        );
      }
    } catch (e) {
      logger.w('Позиция чата $chatId не сохранилась: $e');
    }
  }

  static void forget(int accountId, int chatId) {
    remember(accountId, chatId, null);
    unawaited(persist(accountId, chatId));
  }

  static void forgetAccount(int accountId) {
    bool ofAccount(String key) => key.startsWith('$accountId:');
    _points.removeWhere((key, _) => ofAccount(key));
    _dirty.removeWhere(ofAccount);
    _primed.remove(accountId);
  }
}
