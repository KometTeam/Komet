import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/api.dart';
import '../../backend/modules/account.dart';
import '../utils/logger.dart';

const _channelId = 'komet_messages';
const _channelName = 'Сообщения';
const _prefsTokenKey = 'fcm_push_token';

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.notification != null) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await _display(plugin, message);
}

Future<void> _display(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final data = message.data;
  final title = message.notification?.title ??
      data['title']?.toString() ??
      data['sender']?.toString() ??
      'MAX';
  final body = message.notification?.body ??
      data['body']?.toString() ??
      data['text']?.toString() ??
      data['message']?.toString() ??
      'Новое сообщение';
  await plugin.show(
    id: message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
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

class PushService {
  PushService._();
  static final PushService instance = PushService._();

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
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
          ),
        );

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
    FirebaseMessaging.onMessage.listen((m) {
      _display(_local, m);
    });
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
