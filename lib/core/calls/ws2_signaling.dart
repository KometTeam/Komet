import 'dart:async';
import 'dart:convert';

import 'package:kolibri/kolibri.dart' as kb;

import 'conversation_params.dart';

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

  static const _defaultCapabilities = '3c03f';
  static const _appVersion = 'sdk-0.1.16.4';

  /// Входящий звонок: из распакованных параметров [ConversationParams].
  /// `userId` — часть после `:` в [ConversationParams.turnUser].
  factory Ws2Config.fromVcp(
    ConversationParams params, {
    required String conversationId,
    String capabilities = _defaultCapabilities,
    String device = 'Komet',
    String osVersion = '36',
  }) {
    final userId =
        int.tryParse((params.turnUser ?? '').split(':').last) ?? 0;
    final uri = Uri.parse(params.wsEndpoint).replace(queryParameters: {
      'userId': '$userId',
      'entityType': 'USER',
      'conversationId': conversationId,
      'token': params.token,
      'version': '5',
      'capabilities': capabilities,
      'device': device,
      'platform': 'ANDROID',
      'clientType': 'ONE_ME',
      'appVersion': _appVersion,
      'osVersion': osVersion,
    });
    return Ws2Config(uri: uri, userId: userId);
  }

  /// Исходящий звонок: `endpoint` из ответа opcode 78 уже содержит токен и
  /// conversationId/userId в query — дописываем клиентские параметры.
  factory Ws2Config.fromEndpoint(
    String endpoint, {
    required int userId,
    String capabilities = _defaultCapabilities,
    String device = 'Komet',
  }) {
    final base = Uri.parse(endpoint);
    final uri = base.replace(queryParameters: {
      ...base.queryParameters,
      'platform': 'ANDROID',
      'version': '5',
      'capabilities': capabilities,
      'clientType': 'ONE_ME',
      'appVersion': _appVersion,
      'device': device,
      'tgt': 'start',
    });
    return Ws2Config(uri: uri, userId: userId);
  }
}

/// Ошибка, которую вернул сервер в ответе на команду.
class Ws2CommandException implements Exception {
  final String command;
  final Object? error;
  Ws2CommandException(this.command, this.error);
  @override
  String toString() => 'Ws2CommandException($command): $error';
}

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

  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final _closed = Completer<Object?>();

  Ws2Signaling(this.config);

  /// Пуши сервера (`type == "notification"`). Фильтруй по полю `notification`.
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  /// Завершается, когда сокет закрыт.
  Future<Object?> get done => _closed.future;

  bool get isConnected => _call?.isConnected() ?? false;

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
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
    } catch (e) {
      throw Ws2CommandException(command, e);
    }
  }

  /// Передаёт SDP (offer/answer) другому участнику.
  Future<void> transmitSdp({
    required int participantId,
    required String type,
    required String sdp,
    String participantType = 'USER',
    int deviceIdx = 0,
    String capabilities = '1',
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

  Future<void> changeMediaSettings({
    bool isAudioEnabled = true,
    bool isVideoEnabled = false,
    bool isScreenSharingEnabled = false,
    bool isAnimojiEnabled = false,
  }) {
    return sendCommand(
      'change-media-settings',
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

  /// Принять входящий звонок (сторона вызываемого).
  Future<void> acceptCall() => sendCommand('accept-call');

  Future<void> hangup({String reason = 'HUNGUP'}) =>
      sendCommand('hangup', extra: {'reason': reason});

  Future<void> allocateConsumer() => sendCommand(
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
            'producerScreenDataChannelVersion': 1,
            'consumerScreenDataChannelVersion': 1,
            'animojiDataChannelVersion': 2,
            'animojiBackendRender': true,
            'asrDataChannelVersion': 1,
            'consumerFastScreenShare': true,
            'consumerFastScreenShareQualityOnDemand': true,
            'audioShare': true,
            'simulcast': true,
            'simulcastNativeOrder': true,
            'red': true,
            'videoTracksCount': 10,
            'csrcAccessible': true,
          },
        },
      );

  Future<void> acceptProducer({
    required String description,
    required List<int> ssrcs,
    Object? sessionId,
  }) =>
      sendCommand('accept-producer', extra: {
        'description': description,
        'ssrcs': ssrcs,
        'sessionId': ?sessionId,
      });

  Future<void> changeSimulcast({
    String mediaSource = 'CAMERA',
    required List<Map<String, dynamic>> layers,
  }) =>
      sendCommand('change-simulcast',
          extra: {'mediaSource': mediaSource, 'layers': layers});

  Future<void> close() async {
    await _notifSub?.cancel();
    _notifSub = null;
    _call?.close();
    _call = null;
  }
}
