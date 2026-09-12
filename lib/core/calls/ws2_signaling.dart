import 'dart:async';
import 'dart:convert';

import 'package:kolibri/kolibri.dart' as kb;

import 'conversation_params.dart';

// #***! параметры подключения к сигналке
/// Параметры подключения к сигналинг-сокету ws2.
///
/// Строится из двух источников:
/// - входящий звонок: [Ws2Config.fromVcp] (параметры из `vcp` пуша opcode 137);
/// - исходящий звонок: [Ws2Config.fromEndpoint] (`endpoint` из ответа opcode 78,
///   в нём уже вшит токен — дописываем только клиентские параметры).
class Ws2Config {
  /// Готовый URL подключения к ws2.
  final Uri uri;

  /// Внутренний id пользователя в системе звонков.
  final int userId;

  const Ws2Config({required this.uri, required this.userId});

  // #***! capabilities и версия SDK, сервер сверяет и отказывает незнакомым
  static const defaultCapabilities = '3c02f';
  static const _appVersion = 'sdk-0.2.1.3';
  static const defaultDevice = 'Android/Unknown';
  static const defaultOsVersion = '34';

  /// Входящий звонок: из распакованных параметров [ConversationParams].
  /// `userId` — часть после `:` в [ConversationParams.turnUser].
  factory Ws2Config.fromVcp(
    ConversationParams params, {
    required String conversationId,
    String capabilities = defaultCapabilities,
    String? device,
    String? osVersion,
  }) {
    final userId = int.tryParse((params.turnUser ?? '').split(':').last) ?? 0;
    final uri = Uri.parse(params.wsEndpoint).replace(
      queryParameters: {
        'userId': '$userId',
        'token': params.token,
        'conversationId': conversationId,
        'version': '5',
        'capabilities': capabilities,
        'device': device ?? defaultDevice,
        'platform': 'ANDROID',
        'clientType': 'ONE_ME',
        'appVersion': _appVersion,
        'osVersion': osVersion ?? defaultOsVersion,
      },
    );
    return Ws2Config(uri: uri, userId: userId);
  }

  /// Исходящий звонок или вход в конференцию: `endpoint` из ответа opcode 78 /
  /// 166 уже содержит токен и conversationId/userId в query — дописываем
  /// клиентские параметры. Без `tgt=start` медиасервер принимает сокет, но не
  /// поднимает разговор и не шлёт нотификацию `connection`.
  factory Ws2Config.fromEndpoint(
    String endpoint, {
    required int userId,
    String capabilities = defaultCapabilities,
    String? device,
    String? osVersion,
  }) {
    final base = Uri.parse(endpoint);
    final uri = base.replace(
      queryParameters: {
        ...base.queryParameters,
        'version': '5',
        'capabilities': capabilities,
        'device': device ?? defaultDevice,
        'platform': 'ANDROID',
        'clientType': 'ONE_ME',
        'appVersion': _appVersion,
        'osVersion': osVersion ?? defaultOsVersion,
        'tgt': 'start',
      },
    );
    return Ws2Config(uri: uri, userId: userId);
  }
}

// #***! сервер вернул ошибку на команду
/// Ошибка, которую вернул сервер в ответе на команду.
class Ws2CommandException implements Exception {
  final String command;
  final Object? error;
  Ws2CommandException(this.command, this.error);
  @override
  String toString() => 'Ws2CommandException($command): $error';
}

// #***! сигналка ws2, сам сокет держит раст
/// Клиент сигналинга звонка поверх WebSocket `ws2`.
///
/// Тонкий адаптер над Rust-ядром (kolibri [kb.CallSignaling]): ядро держит
/// WebSocket, корреляцию `sequence`/`response`, keepalive `ping`→`pong` и
/// разбор кадров; здесь — прежний Dart-интерфейс для [call_session].
///
/// Конверт сообщений:
/// - запрос: `{"command": ..., ..., "sequence": N}`
/// - ответ:  `{"sequence": N, "response": "<command>", "type": "response"}`
/// - пуш:    `{..., "notification": "<name>", "type": "notification"}`
class Ws2Signaling {
  final Ws2Config config;

  kb.CallSignaling? _call;
  StreamSubscription<String>? _notifSub;

  // #***! уведомления стримом, ответы на команды по завершению future
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final _closed = Completer<Object?>();

  Ws2Signaling(this.config);

  /// Пуши сервера (`type == "notification"`). Фильтруй по полю `notification`.
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  /// Завершается, когда сокет закрыт.
  Future<Object?> get done => _closed.future;

  bool get isConnected => _call?.isConnected() ?? false;

  // #***! подключение к сигналке
  Future<void> connect() async {
    final call = await kb.connectCallSignaling(
      url: config.uri.toString(),
      userAgent: 'okhttp/4.12.0',
    );
    _call = call;
    _notifSub = call.notifications().listen(
      (json) {
        Object? decoded;
        try {
          decoded = jsonDecode(json);
        } catch (_) {
          return;
        }
        if (decoded is Map<String, dynamic>) _notifications.add(decoded);
      },
      onError: (_) => _onDone(null),
      onDone: () => _onDone(null),
      cancelOnError: false,
    );
  }

  void _onDone(Object? error) {
    if (!_closed.isCompleted) _closed.complete(error);
    if (!_notifications.isClosed) _notifications.close();
  }

  // #***! отправка команды с ожиданием ответа
  /// Отправляет команду и ждёт ответ сервера. Бросает [Ws2CommandException],
  /// если сервер вернул ошибку.
  Future<Map<String, dynamic>> sendCommand(
    String command, {
    Map<String, dynamic> extra = const {},
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final call = _call;
    if (call == null) {
      return Future.error(StateError('ws2 не подключён'));
    }
    try {
      final response = await call
          .sendCommand(command: command, extraJson: jsonEncode(extra))
          .timeout(timeout);
      final decoded = jsonDecode(response);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (e) {
      throw Ws2CommandException(command, e);
    }
  }

  // #***! SDP и кандидаты гоняются теми же командами
  /// Передаёт SDP (offer/answer) другому участнику.
  Future<void> transmitSdp({
    required int participantId,
    required String type,
    required String sdp,
    String participantType = 'USER',
    int deviceIdx = 0,
    String capabilities = Ws2Config.defaultCapabilities,
  }) {
    return sendCommand(
      'transmit-data',
      extra: {
        'participantId': participantId,
        'participantType': participantType,
        'deviceIdx': deviceIdx,
        'data': {
          'sdp': {'type': type, 'sdp': sdp},
        },
        'capabilities': capabilities,
      },
    );
  }

  /// Передаёт ICE-кандидата другому участнику (trickle).
  Future<void> transmitCandidate({
    required int participantId,
    required String candidate,
    required String sdpMid,
    required int sdpMLineIndex,
    String participantType = 'USER',
    int deviceIdx = 0,
  }) {
    return sendCommand(
      'transmit-data',
      extra: {
        'participantId': participantId,
        'participantType': participantType,
        'deviceIdx': deviceIdx,
        'data': {
          'candidate': {
            'candidate': candidate,
            'sdpMid': sdpMid,
            'sdpMLineIndex': sdpMLineIndex,
          },
        },
      },
    );
  }

  // #***! смена состояния микрофона и камеры
  Future<void> changeMediaSettings({
    bool isAudioEnabled = true,
    bool isVideoEnabled = false,
    bool isScreenSharingEnabled = false,
    bool isAnimojiEnabled = false,
    bool? isFastScreenSharingEnabled,
    bool? isAudioSharingEnabled,
  }) {
    return sendCommand(
      'change-media-settings',
      extra: {
        'mediaSettings': {
          'isVideoEnabled': isVideoEnabled,
          'isAudioEnabled': isAudioEnabled,
          'isScreenSharingEnabled': isScreenSharingEnabled,
          'isAnimojiEnabled': isAnimojiEnabled,
          'isFastScreenSharingEnabled': ?isFastScreenSharingEnabled,
          'isAudioSharingEnabled': ?isAudioSharingEnabled,
        },
      },
    );
  }

  // #***! переход P2P в SFU когда участников больше двух
  Future<void> switchTopology({
    String topology = 'SERVER',
    bool force = false,
  }) {
    return sendCommand(
      'switch-topology',
      extra: {'topology': topology, 'force': force},
    );
  }

  Future<void> requestRealloc() => sendCommand('request-realloc');

  // #***! принятие входящего
  /// Принять входящий звонок (сторона вызываемого).
  Future<void> acceptCall({
    bool isAudioEnabled = true,
    bool isVideoEnabled = false,
    bool isScreenSharingEnabled = false,
    bool isAnimojiEnabled = false,
  }) {
    return sendCommand(
      'accept-call',
      extra: {
        'mediaSettings': {
          'isVideoEnabled': isVideoEnabled,
          'isAudioEnabled': isAudioEnabled,
          'isScreenSharingEnabled': isScreenSharingEnabled,
          'isAnimojiEnabled': isAnimojiEnabled,
        },
      },
    );
  }

  // #***! завершение
  Future<void> hangup({String reason = 'HUNGUP'}) =>
      sendCommand('hangup', extra: {'reason': reason});

  // #***! дальше выделение и приём потоков в SFU
  Future<Map<String, dynamic>> allocateConsumer() => sendCommand(
    'allocate-consumer',
    extra: const {
      'capabilities': {
        'maxH264Decoders': 10,
        'producerNotificationDataChannelVersion': 7,
        'producerCommandDataChannelVersion': 2,
        'audioMix': true,
        'consumerUpdate': true,
        'onDemandTracks': true,
        'singleSession': true,
        'unifiedPlan': true,
        'fastScreenShare': true,
        'consumerFastScreenShareQualityOnDemand': true,
        'red': true,
        'videoTracksCount': 10,
        'csrcAccessible': true,
      },
    },
  );

  Future<Map<String, dynamic>> acceptProducer({
    required String description,
    required List<String> ssrcs,
    Object? sessionId,
  }) => sendCommand(
    'accept-producer',
    extra: {
      'description': description,
      if (ssrcs.isNotEmpty) 'ssrcs': ssrcs,
      'sessionId': ?sessionId,
    },
  );

  Future<void> close() async {
    await _notifSub?.cancel();
    _notifSub = null;
    _call?.close();
    _call = null;
  }
}
