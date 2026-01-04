import 'dart:async';
import 'dart:convert';
import 'package:gwid/utils/fresh_mode_helper.dart';

enum QueueItemType { sendMessage, loadChat }

class QueueItem {
  final String id;
  final QueueItemType type;
  final int opcode;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final bool persistent;
  final int? chatId;
  final int? cid;

  QueueItem({
    required this.id,
    required this.type,
    required this.opcode,
    required this.payload,
    required this.createdAt,
    this.persistent = false,
    this.chatId,
    this.cid,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'opcode': opcode,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'persistent': persistent,
      'chatId': chatId,
      'cid': cid,
    };
  }

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'],
      type: QueueItemType.values.firstWhere((e) => e.name == json['type']),
      opcode: json['opcode'],
      payload: Map<String, dynamic>.from(json['payload']),
      createdAt: DateTime.parse(json['createdAt']),
      persistent: json['persistent'] ?? false,
      chatId: json['chatId'],
      cid: json['cid'],
    );
  }
}

class MessageQueueService {
  static final MessageQueueService _instance = MessageQueueService._internal();
  factory MessageQueueService() => _instance;
  MessageQueueService._internal();

  final List<QueueItem> _queue = [];
  final StreamController<List<QueueItem>> _queueController =
      StreamController<List<QueueItem>>.broadcast();

  // Локальный массив для отслеживания обработанных сообщений из очереди
  final Set<String> _processedMessageIds = {};
  static const int _maxProcessedMessageIds = 1000;

  Stream<List<QueueItem>> get queueStream => _queueController.stream;
  List<QueueItem> get queue => List.unmodifiable(_queue);

  static const String _queueKey = 'message_queue';

  Future<void> initialize() async {
    await _loadQueue();
  }

  Future<void> _loadQueue() async {
    if (FreshModeHelper.shouldSkipLoad()) {
      _queue.clear();
      return;
    }

    try {
      final prefs = await FreshModeHelper.getSharedPreferences();
      final queueJson = prefs.getString(_queueKey);
      if (queueJson != null) {
        final List<dynamic> items = jsonDecode(queueJson);
        _queue.clear();
        _queue.addAll(
          items
              .map((json) => QueueItem.fromJson(json))
              .where((item) => item.persistent),
        );
        print('Загружено ${_queue.length} элементов из очереди');
        _queueController.add(_queue);
      }
    } catch (e) {
      print('Ошибка загрузки очереди: $e');
    }
  }

  Future<void> _saveQueue() async {
    if (FreshModeHelper.shouldSkipSave()) return;

    try {
      final prefs = await FreshModeHelper.getSharedPreferences();
      final persistentItems = _queue.where((item) => item.persistent).toList();
      final queueJson = jsonEncode(
        persistentItems.map((item) => item.toJson()).toList(),
      );
      await prefs.setString(_queueKey, queueJson);
    } catch (e) {
      print('Ошибка сохранения очереди: $e');
    }
  }

  void addToQueue(QueueItem item) {
    _queue.add(item);
    _queueController.add(_queue);
    if (item.persistent) {
      _saveQueue();
    }
    print(
      'Добавлен в очередь: ${item.type.name}, opcode=${item.opcode}, persistent=${item.persistent}',
    );
  }

  void removeFromQueue(String itemId) {
    final initialLength = _queue.length;
    _queue.removeWhere((item) => item.id == itemId);
    final removed = _queue.length < initialLength;
    if (removed) {
      _queueController.add(_queue);
      _saveQueue();
      print('Удален из очереди: $itemId');
    }
  }

  void clearTemporaryQueue({int? chatId}) {
    if (chatId != null) {
      _queue.removeWhere((item) => !item.persistent && item.chatId == chatId);
    } else {
      _queue.removeWhere((item) => !item.persistent);
    }
    _queueController.add(_queue);
    print(
      'Временная очередь очищена${chatId != null ? ' для чата $chatId' : ''}',
    );
  }

  void clearAllQueues() {
    _queue.clear();
    _queueController.add(_queue);
    _saveQueue();
    print('Все очереди очищены');
  }

  List<QueueItem> getPersistentItems() {
    return _queue.where((item) => item.persistent).toList();
  }

  List<QueueItem> getTemporaryItems({int? chatId}) {
    if (chatId != null) {
      return _queue
          .where((item) => !item.persistent && item.chatId == chatId)
          .toList();
    }
    return _queue.where((item) => !item.persistent).toList();
  }

  QueueItem? findByCid(int cid) {
    try {
      return _queue.firstWhere((item) => item.cid == cid);
    } catch (e) {
      return null;
    }
  }

  /// Проверяет, было ли сообщение уже обработано
  bool isMessageProcessed(String messageId) {
    return _processedMessageIds.contains(messageId);
  }

  /// Отмечает сообщение как обработанное
  void markMessageAsProcessed(String messageId) {
    _processedMessageIds.add(messageId);
    // Ограничиваем размер множества, чтобы не занимать слишком много памяти
    if (_processedMessageIds.length > _maxProcessedMessageIds) {
      // Удаляем случайный элемент, так как Set не гарантирует порядок
      // В реальности это нормально, так как вероятность отправки одного и того же
      // сообщения после обработки 1000 других сообщений крайне мала
      final toRemove = _processedMessageIds.take(100).toList();
      _processedMessageIds.removeAll(toRemove);
    }
  }

  /// Очищает список обработанных сообщений
  void clearProcessedMessages() {
    _processedMessageIds.clear();
  }

  void dispose() {
    _queueController.close();
  }
}
