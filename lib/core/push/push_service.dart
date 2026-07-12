import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/api.dart';
import '../../backend/modules/account.dart';
import '../../backend/modules/messages.dart';
import '../calls/conversation_params.dart';
import '../calls/ws2_signaling.dart';
import '../protocol/opcode_map.dart';
import '../storage/app_instance.dart';
import '../storage/token_storage.dart';
import '../utils/logger.dart';

const _channelId = 'komet_messages';
const _channelName = 'Сообщения';
const _prefsTokenKey = 'fcm_push_token';

Future<void> _clearHistory(int chatId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('notif_hist_$chatId');
}

@pragma('vm:entry-point')
void _onNotificationResponse(NotificationResponse response) {
  if (response.actionId == 'call_decline') {
    final payload = response.payload;
    if (payload != null) unawaited(_handleCallDecline(payload));
    return;
  }
  if (response.actionId != 'reply') return;
  final text = response.input?.trim();
  final payload = response.payload;
  if (text == null || text.isEmpty || payload == null) return;
  unawaited(_handleReply(payload, text));
}

Future<void> _handleCallDecline(String payloadJson) async {
  String vcp;
  String conversationId;
  try {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) return;
    vcp = decoded['vcp']?.toString() ?? '';
    conversationId = decoded['conversationId']?.toString() ?? '';
  } catch (_) {
    return;
  }
  if (vcp.isEmpty || conversationId.isEmpty) return;

  final params = ConversationParams.decode(vcp);
  if (params == null) return;

  final config = Ws2Config.fromVcp(params, conversationId: conversationId);
  final signaling = Ws2Signaling(config);
  try {
    await signaling.connect();
    await signaling.hangup(reason: 'REJECTED');
  } catch (_) {
  } finally {
    await signaling.close();
  }
}

Future<void> _handleReply(String payloadJson, String text) async {
  int account;
  int chatId;
  int? replyTo;
  try {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) return;
    account = (decoded['c'] as num?)?.toInt() ?? 0;
    chatId = (decoded['chat'] as num?)?.toInt() ?? 0;
    replyTo = (decoded['mid'] as num?)?.toInt();
  } catch (_) {
    return;
  }
  if (account == 0 || chatId == 0) return;

  WidgetsFlutterBinding.ensureInitialized();
  if (AppInstance.isNamed) {
    try {
      SharedPreferences.setPrefix('flutter.${AppInstance.id}.');
    } catch (_) {}
  }

  final plugin = FlutterLocalNotificationsPlugin();
  final notifId = chatId & 0x7fffffff;
  Api? api;
  var sent = false;
  try {
    final token = await TokenStorage.readToken(account);
    if (token != null && token.isNotEmpty) {
      api = Api()..spoofScope = '$account';
      await api.connect();
      if (api.state != SessionState.online) {
        await api.stateStream
            .firstWhere((s) => s == SessionState.online)
            .timeout(const Duration(seconds: 20));
      }
      final login = await api.sendRequest(
        Opcode.login,
        AccountModule(api).buildLoginPayload(token, interactive: false),
      );
      if (login.isOk) {
        await MessagesModule(
          api,
        ).sendMessage(account, chatId, text, replyToMessageId: replyTo);
        sent = true;
      }
    }
  } catch (_) {
    sent = false;
  } finally {
    await api?.disconnect();
  }

  if (sent) {
    await _clearHistory(chatId);
    await plugin.cancel(id: notifId);
  } else {
    await plugin.show(
      id: notifId,
      title: 'Komet',
      body: 'Не удалось отправить ответ',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static Future<void> clearChatNotification(int chatId) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancel(id: chatId & 0x7fffffff);
    await _clearHistory(chatId);
  }

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Api? _api;
  AccountModule? _account;
  String? _token;
  bool _initialized = false;

  Future<void> init({required Api api, required AccountModule account}) async {
    if (_initialized) return;
    _api = api;
    _account = account;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      logger.w('Push: Firebase init не удался: $e');
      return;
    }

    _initialized = true;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onNotificationResponse,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
          ),
        );

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    messaging.onTokenRefresh.listen((t) async {
      _token = t;
      await _persistToken(t);
      await _registerWithServer();
    });

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_prefsTokenKey);
    try {
      _token = await messaging.getToken() ?? _token;
      if (_token != null) await _persistToken(_token!);
      logger.i('Push: FCM-токен получен (${_token?.length ?? 0} симв.)');
    } catch (e) {
      logger.w('Push: getToken не удался: $e');
    }
  }

  Future<void> onLoginSuccess() async {
    if (!_initialized) return;
    if (_token == null) {
      try {
        _token = await FirebaseMessaging.instance.getToken();
        if (_token != null) await _persistToken(_token!);
      } catch (_) {}
    }
    await _registerWithServer();
  }

  Future<void> unregister() async {
    if (!_initialized || _token == null) return;
    final account = _account;
    if (account != null) {
      try {
        await account.unregisterPushToken(_token!);
      } catch (e) {
        logger.w('Push: unregister не удался: $e');
      }
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsTokenKey);
  }

  Future<void> _registerWithServer() async {
    final account = _account;
    final api = _api;
    if (account == null || api == null) return;
    if (api.state != SessionState.online) return;
    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await account.registerPushToken(token);
      logger.i('Push: токен зарегистрирован на сервере MAX');
    } on WrongDeviceTokenException {
      logger.w('Push: WRONG_DEVICE_TOKEN, переполучаю токен');
      try {
        await FirebaseMessaging.instance.deleteToken();
        final fresh = await FirebaseMessaging.instance.getToken();
        if (fresh != null && fresh.isNotEmpty) {
          _token = fresh;
          await _persistToken(fresh);
          await account.registerPushToken(fresh);
          logger.i('Push: токен перерегистрирован');
        }
      } catch (e) {
        logger.w('Push: повторная регистрация не удалась: $e');
      }
    } catch (e) {
      logger.w('Push: регистрация токена не удалась: $e');
    }
  }

  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsTokenKey, token);
  }
}
