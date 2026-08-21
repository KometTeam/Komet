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
import '../utils/logger.dart';
import 'fkm_bridge.dart';
import 'push_service.dart';

const _fallbackSender = 'MAX';
const _hiddenPreview = 'Новое сообщение';

/// FKM — уведомления через собственное фоновое соединение, без FCM.
///
/// Пуш из сокета превращается в тот же набор полей, что присылает FCM, и
/// отрисовывается нативным `KometNotifier` — общий код с пушевой версией.
class FkmController {
  FkmController._();
  static final FkmController instance = FkmController._();

  final ValueNotifier<bool> enabled = ValueNotifier(false);

  Api? _api;
  StreamSubscription<Packet>? _pushSub;
  StreamSubscription<SessionState>? _stateSub;
  bool _started = false;

  bool get isSupported => FkmBridge.instance.isSupported;

  Future<void> init(Api api) async {
    if (_started || !isSupported) return;
    _started = true;
    _api = api;

    FkmBridge.instance.setDisabledCallback(_onDisabledFromNotification);
    enabled.value = await FkmBridge.instance.isEnabled();

    _pushSub = api.pushStream
        .where((packet) => packet.opcode == Opcode.notifMessage)
        .listen(_onMessagePush);
    _stateSub = api.stateStream.listen(_onSessionState);

    if (enabled.value) {
      await initLocalNotificationActions();
      await FkmBridge.instance.setEnabled(true);
      await _pushConnectionState();
    }
  }

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

  void _onDisabledFromNotification() => enabled.value = false;

  void _onSessionState(SessionState state) {
    if (!enabled.value) return;
    unawaited(FkmBridge.instance.setConnected(state == SessionState.online));
  }

  Future<void> _pushConnectionState() => FkmBridge.instance.setConnected(
    _api?.state == SessionState.online,
  );

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

  Future<void> _onMessagePush(Packet packet) async {
    if (!enabled.value) return;
    try {
      final data = await _buildNotification(packet);
      if (data != null) await FkmBridge.instance.showMessage(data);
    } catch (e) {
      logger.w('FKM: не удалось показать уведомление: $e');
    }
  }

  Future<Map<String, String>?> _buildNotification(Packet packet) async {
    final payload = packet.payload;
    if (payload is! Map) return null;

    final chatId = payload['chatId'];
    if (chatId is! int) return null;

    final msg = payload['message'];
    if (msg is! Map) return null;

    if (payload['postId'] != null || msg['postId'] != null) return null;

    final status = msg['status']?.toString();
    if (status == 'REMOVED' || status == 'EDITED') return null;

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
