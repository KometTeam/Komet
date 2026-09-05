import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../backend/api.dart';
import '../../backend/modules/account/account_models.dart';
import '../../backend/modules/chat_preview.dart';
import '../../backend/modules/chats.dart';
import '../../backend/modules/messages.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
import '../config/komet_settings.dart';
import '../utils/logger.dart';
import 'fkm_bridge.dart';
import 'push_service.dart';

const _fallbackSender = 'MAX';
const _hiddenPreview = 'Новое сообщение';

// #***! FKM, своё фоновое уведомление для флейвора без гугла
/// FKM — уведомления через собственное фоновое соединение, без FCM.
///
/// Пуш из сокета превращается в тот же набор полей, что присылает FCM, и
/// отрисовывается нативным `KometNotifier` — общий код с пушевой версией.
class FkmController {
  FkmController._();
  static final FkmController instance = FkmController._();

  // #***! enabled, на него подписан переключатель в настройках
  final ValueNotifier<bool> enabled = ValueNotifier(false);

  Api? _api;
  StreamSubscription<Packet>? _pushSub;
  StreamSubscription<SessionState>? _stateSub;
  bool _started = false;

  bool get isSupported => FkmBridge.instance.isSupported;

  // #***! подписка на пуши сокета и сессию
  Future<void> init(Api api) async {
    if (_started || !isSupported) return;
    _started = true;
    _api = api;

    FkmBridge.instance.setDisabledCallback(_onDisabledFromNotification);
    enabled.value = await FkmBridge.instance.isEnabled();

    _pushSub = api.pushStream
        .where(
          (packet) =>
              packet.opcode == Opcode.notifMessage ||
              packet.opcode == Opcode.notifMsgDelete,
        )
        .listen(_onPush);
    _stateSub = api.stateStream.listen(_onSessionState);

    if (enabled.value) {
      await initLocalNotificationActions();
      await FkmBridge.instance.setEnabled(true);
      await _pushConnectionState();
    }
  }

  // #***! включение и выключение сервиса
  /// Возвращает false, если пользователь не выдал разрешение на уведомления.
  Future<bool> setEnabled(bool value) async {
    if (!isSupported) return false;
    if (value && !await FkmBridge.instance.requestNotificationPermission()) {
      return false;
    }
    if (value) await initLocalNotificationActions();
    await FkmBridge.instance.setEnabled(value);
    enabled.value = value;
    if (value) await _pushConnectionState();
    return true;
  }

  // #***! выключили FKM кнопкой в уведомлении
  void _onDisabledFromNotification() => enabled.value = false;

  void _onSessionState(SessionState state) {
    if (!enabled.value) return;
    unawaited(FkmBridge.instance.setConnected(state == SessionState.online));
  }

  // #***! говорим нативу есть ли связь, от этого текст постоянного уведомления
  Future<void> _pushConnectionState() => FkmBridge.instance.setConnected(
    _api?.state == SessionState.online,
  );

  // #***! входящий звонок, натив рисует полноэкранное
  /// Входящий звонок, когда приложение не на переднем плане.
  ///
  /// Отдаётся тому же нативному коду, что и FCM-пуш: CallStyle, полноэкранный
  /// интент, рингтон, приём и отклонение уже реализованы там.
  Future<void> showIncomingCall(Map<dynamic, dynamic> payload) async {
    if (!enabled.value) return;
    try {
      final data = await _buildCallNotification(payload);
      if (data != null) await FkmBridge.instance.showCall(data);
    } catch (e) {
      logger.w('FKM: не удалось показать звонок: $e');
    }
  }

  Future<Map<String, String>?> _buildCallNotification(
    Map<dynamic, dynamic> payload,
  ) async {
    final vcp = payload['vcp'];
    final conversationId = payload['conversationId'];
    final callerId = payload['callerId'];
    if (vcp is! String || conversationId is! String || callerId is! int) {
      return null;
    }

    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return null;

    final rawConfig = await AppDatabase.getPrivacyConfig(accountId);
    if (rawConfig != null &&
        PrivacyConfig.fromJson(rawConfig).mCallPushNotification != 'ON') {
      return null;
    }

    final name = ContactCache.get(callerId) ?? _fallbackSender;

    return {
      'type': 'InboundCall',
      'vcp': vcp,
      'conversationId': conversationId,
      'callerId': '$callerId',
      'suid': '$callerId',
      'userName': name,
      'title': name,
      'c': '$accountId',
      'iv': payload['type'] == 'VIDEO' ? 'true' : 'false',
    };
  }

  // #***! роутер пушей, новое правка удаление
  Future<void> _onPush(Packet packet) async {
    if (!enabled.value) return;
    try {
      if (packet.opcode == Opcode.notifMsgDelete) {
        await _onDeletePush(packet);
      } else {
        await _onMessagePush(packet);
      }
    } catch (e) {
      logger.w('FKM: не удалось обновить уведомления: $e');
    }
  }

  // #***! новое сообщение в уведомление
  Future<void> _onMessagePush(Packet packet) async {
    final payload = packet.payload;
    if (payload is! Map) return;

    final chatId = payload['chatId'];
    if (chatId is! int) return;

    final msg = payload['message'];
    if (msg is! Map) return;

    if (payload['postId'] != null || msg['postId'] != null) return;

    final msgId = msg['id']?.toString();
    switch (msg['status']?.toString()) {
      case 'REMOVED':
        if (msgId != null) await _removeNotification(chatId, msgId);
        return;
      case 'EDITED':
        if (msgId != null) await _editNotification(chatId, msgId, msg);
        return;
    }

    final data = await _buildNotification(chatId, msg);
    if (data != null) await FkmBridge.instance.showMessage(data);
  }

  // #***! сообщение удалили, гасим уведомление
  Future<void> _onDeletePush(Packet packet) async {
    final payload = packet.payload;
    if (payload is! Map) return;

    final chat = payload['chat'];
    final chatId = (chat is Map && chat['id'] is int)
        ? chat['id'] as int
        : payload['chatId'];
    if (chatId is! int) return;

    final ids = payload['messageIds'];
    if (ids is! List) return;
    for (final raw in ids) {
      final id = raw?.toString();
      if (id == null || id.isEmpty) continue;
      await _removeNotification(chatId, id);
    }
  }

  /// Удалённое сообщение уезжает из шторки, а при включённом «показывать
  /// удалённые сообщения» остаётся в ней зачёркнутым.
  Future<void> _removeNotification(int chatId, String msgId) =>
      FkmBridge.instance.removeMessage({
        'mc': '$chatId',
        'msgid': msgId,
        'keep': KometSettings.viewDeleted.value ? 'true' : 'false',
      });

  // #***! отредактировали, правим показанное
  Future<void> _editNotification(
    int chatId,
    String msgId,
    Map<dynamic, dynamic> msg,
  ) async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;

    final rawConfig = await AppDatabase.getPrivacyConfig(accountId);
    if (rawConfig != null) {
      final config = PrivacyConfig.fromJson(rawConfig);
      if (config.chatsPushNotification != 'ON') return;
      if (!config.pushDetails) return;
    }

    final text = _previewText(msg);
    if (text == _hiddenPreview) return;

    await FkmBridge.instance.editMessage({
      'mc': '$chatId',
      'msgid': msgId,
      'msg': text,
    });
  }

  // #***! сборка уведомления, заголовок текст аватарка
  Future<Map<String, String>?> _buildNotification(
    int chatId,
    Map<dynamic, dynamic> msg,
  ) async {
    final senderId = msg['sender'];
    if (senderId is! int) return null;

    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null || senderId == accountId) return null;

    final rawConfig = await AppDatabase.getPrivacyConfig(accountId);
    var showPreview = true;
    if (rawConfig != null) {
      final config = PrivacyConfig.fromJson(rawConfig);
      if (config.chatsPushNotification != 'ON') return null;
      showPreview = config.pushDetails;
    }

    final rows = await AppDatabase.loadChat(accountId, chatId);
    final chat = rows.isEmpty ? null : CachedChat.fromDbRow(rows.first);
    if (chat != null && chat.isMuted) return null;

    final senderName =
        ContactCache.get(senderId) ?? chat?.title ?? _fallbackSender;
    final chatTitle = (chat != null && chat.isGroupChat)
        ? (chat.title ?? senderName)
        : senderName;

    final text = showPreview ? _previewText(msg) : _hiddenPreview;
    final time = msg['time'];
    final msgId = msg['id'];

    return {
      'mc': '$chatId',
      'c': '$accountId',
      'suid': '$senderId',
      'userName': senderName,
      'title': chatTitle,
      'msg': text,
      'ctime': '${time is int ? time : DateTime.now().millisecondsSinceEpoch}',
      if (msgId != null) 'msgid': '$msgId',
    };
  }

  // #***! текст превью, для вложений их описание
  String _previewText(Map<dynamic, dynamic> msg) {
    final text = msg['text']?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
    final attach = attachPreviewLabel(msg['attaches']);
    if (attach != null && attach.isNotEmpty) return attach;
    return _hiddenPreview;
  }

  void dispose() {
    _pushSub?.cancel();
    _stateSub?.cancel();
    _pushSub = null;
    _stateSub = null;
    _started = false;
  }
}
