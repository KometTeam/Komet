import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
const _groupKey = 'komet_messages_group';
const _callNotifId = 424242;
const _historyLimit = 6;

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {}

class _NotifMessage {
  _NotifMessage(this.text, this.senderKey, this.senderName, this.ts);
  final String text;
  final String senderKey;
  final String senderName;
  final int ts;
}

Future<void> _showMessageNotification(
  FlutterLocalNotificationsPlugin plugin,
  Map<String, dynamic> data,
) async {
  final chatId = int.tryParse(data['mc']?.toString() ?? '') ?? 0;
  final senderKey = data['suid']?.toString() ?? '';
  final senderName =
      data['userName']?.toString() ?? data['title']?.toString() ?? 'MAX';
  final chatTitle = data['title']?.toString() ?? senderName;
  final text = data['msg']?.toString() ??
      data['body']?.toString() ??
      data['text']?.toString() ??
      data['message']?.toString() ??
      'Новое сообщение';
  final ts = int.tryParse(data['ctime']?.toString() ?? '') ??
      int.tryParse(data['ttime']?.toString() ?? '') ??
      DateTime.now().millisecondsSinceEpoch;
  final isGroup = chatTitle != senderName;
  final account = int.tryParse(data['c']?.toString() ?? '') ?? 0;
  final replyTo = int.tryParse(data['msgid']?.toString() ?? '');

  final notifId = (chatId != 0 ? chatId : senderKey.hashCode) & 0x7fffffff;
  if (!await _isActive(plugin, notifId)) {
    await _clearHistory(chatId);
  }

  final photo = await _avatarBytes(senderKey);
  final avatar = photo ?? await _initialsAvatar(senderName);
  print('PUSHDBG avatar sender=$senderKey photo=${photo?.length} '
      'final=${avatar?.length}');
  final history = await _appendHistory(chatId, senderKey, senderName, text, ts);

  final persons = <String, Person>{};
  Person personFor(String key, String name) => persons.putIfAbsent(
        key,
        () => Person(
          key: key,
          name: name,
          icon: (key == senderKey && avatar != null)
              ? ByteArrayAndroidIcon(avatar)
              : null,
        ),
      );

  final messages = [
    for (final h in history)
      Message(
        h.text,
        DateTime.fromMillisecondsSinceEpoch(h.ts),
        personFor(h.senderKey, h.senderName),
      ),
  ];

  final style = MessagingStyleInformation(
    const Person(name: 'Вы'),
    conversationTitle: isGroup ? chatTitle : null,
    groupConversation: isGroup,
    messages: messages,
  );

  await plugin.show(
    id: notifId,
    title: chatTitle,
    body: text,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        styleInformation: style,
        groupKey: _groupKey,
        largeIcon: avatar != null ? ByteArrayAndroidBitmap(avatar) : null,
        ticker: text,
        actions: account != 0
            ? const [
                AndroidNotificationAction(
                  'reply',
                  'Ответить',
                  inputs: [
                    AndroidNotificationActionInput(label: 'Сообщение…'),
                  ],
                  semanticAction: SemanticAction.reply,
                ),
              ]
            : null,
      ),
    ),
    payload: jsonEncode({'c': account, 'chat': chatId, 'mid': replyTo}),
  );
}

Future<void> _showCallNotification(
  FlutterLocalNotificationsPlugin plugin,
  Map<String, dynamic> data,
) async {
  final name =
      data['userName']?.toString() ?? data['msg']?.toString() ?? 'Неизвестный';
  final avatar = await _avatarBytes(data['suid']?.toString() ?? '') ??
      await _initialsAvatar(name);
  await plugin.show(
    id: _callNotifId,
    title: 'Входящий звонок',
    body: name,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.call,
        largeIcon: avatar != null ? ByteArrayAndroidBitmap(avatar) : null,
        ticker: 'Входящий звонок',
      ),
    ),
  );
}

Future<List<_NotifMessage>> _appendHistory(
  int chatId,
  String senderKey,
  String senderName,
  String text,
  int ts,
) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'notif_hist_$chatId';
  final list = <Map<String, dynamic>>[];
  final raw = prefs.getString(key);
  if (raw != null) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map) list.add(e.cast<String, dynamic>());
        }
      }
    } catch (_) {}
  }
  list.add({'t': text, 'k': senderKey, 'n': senderName, 'ts': ts});
  while (list.length > _historyLimit) {
    list.removeAt(0);
  }
  await prefs.setString(key, jsonEncode(list));
  return [
    for (final e in list)
      _NotifMessage(
        e['t']?.toString() ?? '',
        e['k']?.toString() ?? '',
        e['n']?.toString() ?? '',
        int.tryParse(e['ts']?.toString() ?? '') ?? ts,
      ),
  ];
}

Future<bool> _isActive(FlutterLocalNotificationsPlugin plugin, int id) async {
  try {
    final active = await plugin.getActiveNotifications();
    return active.any((n) => n.id == id);
  } catch (_) {
    return true;
  }
}

Future<void> _clearHistory(int chatId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('notif_hist_$chatId');
}

const _avatarPalette = <int>[
  0xFF5B8DEF,
  0xFFEF5B8D,
  0xFF3FB950,
  0xFFE3883A,
  0xFF9B72F0,
  0xFF2AA9B5,
  0xFFE05252,
  0xFF6A7BE0,
];

String _initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

Future<Uint8List?> _initialsAvatar(String name) async {
  try {
    const size = 128;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..isAntiAlias = true
      ..color = ui.Color(
        _avatarPalette[name.isEmpty ? 0 : name.hashCode.abs() % _avatarPalette.length],
      );
    canvas.drawCircle(const ui.Offset(64, 64), 64, paint);
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        fontSize: 56,
        fontWeight: ui.FontWeight.w600,
      ),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
      ..addText(_initialsOf(name));
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 128));
    canvas.drawParagraph(paragraph, ui.Offset(0, (size - paragraph.height) / 2));
    final image = await recorder.endRecording().toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return null;
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _avatarBytes(String senderKey) async {
  if (senderKey.isEmpty) return null;
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('contact_cache_v1');
    if (raw == null) return null;
    final map = jsonDecode(raw);
    if (map is! Map) return null;
    final entry = map[senderKey];
    final url = entry is Map ? entry['a']?.toString() : null;
    if (url == null || url.isEmpty) return null;
    return await _downloadBytes(url);
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _downloadBytes(String url) async {
  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    final req = await client.getUrl(Uri.parse(url));
    final resp = await req.close().timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) return null;
    return await consolidateHttpClientResponseBytes(resp);
  } catch (_) {
    return null;
  } finally {
    client?.close(force: true);
  }
}

@pragma('vm:entry-point')
void _onNotificationResponse(NotificationResponse response) {
  print('REPLYDBG cb action=${response.actionId} '
      'input=${response.input} payload=${response.payload}');
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
    print('REPLYDBG call decline sent');
  } catch (e) {
    print('REPLYDBG call decline error $e');
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
  print('REPLYDBG start acc=$account chat=$chatId reply=$replyTo');

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
    print('REPLYDBG token=${token != null && token.isNotEmpty}');
    if (token != null && token.isNotEmpty) {
      api = Api()..spoofScope = '$account';
      await api.connect();
      if (api.state != SessionState.online) {
        await api.stateStream
            .firstWhere((s) => s == SessionState.online)
            .timeout(const Duration(seconds: 20));
      }
      print('REPLYDBG online');
      final login = await api.sendRequest(Opcode.login, <dynamic, dynamic>{
        'token': token,
        'interactive': false,
        'exp': {
          'chatsCountGroups': Uint8List.fromList([0x0b, 0x32]),
        },
        'presenceSync': 0,
      });
      print('REPLYDBG login ok=${login.isOk}');
      if (login.isOk) {
        await MessagesModule(api).sendMessage(
          account,
          chatId,
          text,
          replyToMessageId: replyTo,
        );
        sent = true;
        print('REPLYDBG sent');
      }
    }
  } catch (e) {
    sent = false;
    print('REPLYDBG error $e');
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
