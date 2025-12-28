library;

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:gwid/connection/connection_logger.dart';
import 'package:gwid/connection/connection_state.dart' as conn_state;
import 'package:gwid/connection/health_monitor.dart';
import 'package:gwid/utils/image_cache_service.dart';
import 'package:gwid/models/complaint.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/utils/proxy_service.dart';
import 'package:gwid/services/account_manager.dart';
import 'package:gwid/services/avatar_cache_service.dart';
import 'package:gwid/services/cache_service.dart';
import 'package:gwid/services/chat_cache_service.dart';
import 'package:gwid/services/profile_cache_service.dart';
import 'package:gwid/utils/spoofing_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:gwid/app_urls.dart';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

part 'api_service_connection.dart';
part 'api_service_auth.dart';
part 'api_service_contacts.dart';
part 'api_service_chats.dart';
part 'api_service_media.dart';
part 'api_service_privacy.dart';
part 'api_service_complaints.dart';

typedef Lz4DecompressFunction =
    Int32 Function(
      Pointer<Uint8> src,
      Pointer<Uint8> dst,
      Int32 compressedSize,
      Int32 dstCapacity,
    );
typedef Lz4Decompress =
    int Function(
      Pointer<Uint8> src,
      Pointer<Uint8> dst,
      int compressedSize,
      int dstCapacity,
    );

class ApiService {
  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  int? _userId;
  late int _sessionId;
  int _actionId = 1;
  bool _isColdStartSent = false;
  late int _lastActionTime;

  bool _isAppInForeground = true;

  int _currentUrlIndex = 0;
  Socket? _socket;
  StreamSubscription? _socketSubscription;
  Timer? _pingTimer;
  Timer? _analyticsTimer;
  int _seq = 0;
  final Map<int, Completer<dynamic>> _pending = {};
  bool _socketConnected = false;
  Uint8List? _buffer = Uint8List(0);
  DynamicLibrary? _lz4Lib;
  Lz4Decompress? _lz4BlockDecompress;

  final StreamController<Contact> _contactUpdatesController =
      StreamController<Contact>.broadcast();
  Stream<Contact> get contactUpdates => _contactUpdatesController.stream;

  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  final _reconnectionCompleteController = StreamController<void>.broadcast();
  Stream<void> get reconnectionComplete =>
      _reconnectionCompleteController.stream;

  final Map<String, dynamic> _presenceData = {};
  String? authToken;
  String? userId;

  String? get token => authToken;

  String? _currentPasswordTrackId;
  String? _currentPasswordHint;
  String? _currentPasswordEmail;

  bool _isSessionOnline = false;
  bool _handshakeSent = false;
  Completer<void>? _onlineCompleter;
  final List<Map<String, dynamic>> _messageQueue = [];

  final Map<int, List<Message>> _messageCache = {};

  final Map<int, Contact> _contactCache = {};
  DateTime? _lastContactsUpdate;
  static const Duration _contactCacheExpiry = Duration(minutes: 5);

  final CacheService _cacheService = CacheService();
  final AvatarCacheService _avatarCacheService = AvatarCacheService();
  final ChatCacheService _chatCacheService = ChatCacheService();
  bool _cacheServicesInitialized = false;

  final ConnectionLogger _connectionLogger = ConnectionLogger();
  final conn_state.ConnectionStateManager _connectionStateManager =
      conn_state.ConnectionStateManager();
  final HealthMonitor _healthMonitor = HealthMonitor();

  String? _currentServerUrl;

  bool _isLoadingBlockedContacts = false;

  bool _isSessionReady = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  final _connectionStatusController = StreamController<String>.broadcast();
  Stream<String> get connectionStatus => _connectionStatusController.stream;

  final _connectionLogController = StreamController<String>.broadcast();
  Stream<String> get connectionLog => _connectionLogController.stream;

  List<LogEntry> get logs => _connectionLogger.logs;

  Stream<conn_state.ConnectionInfo> get connectionState =>
      _connectionStateManager.stateStream;

  Stream<HealthMetrics> get healthMetrics => _healthMonitor.metricsStream;

  final List<String> _connectionLogCache = [];
  List<String> get connectionLogCache => _connectionLogCache;

  bool get isOnline => _isSessionOnline;

  Future<void> waitUntilOnline() async {
    if (_isSessionOnline && _isSessionReady) return;
    _onlineCompleter ??= Completer<void>();
    return _onlineCompleter!.future;
  }

  bool get isActuallyConnected {
    try {
      if (!_socketConnected || _socket == null || !_isSessionOnline) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Completer<Map<String, dynamic>>? _inflightChatsCompleter;
  Map<String, dynamic>? _lastChatsPayload;
  DateTime? _lastChatsAt;
  final Duration _chatsCacheTtl = const Duration(seconds: 5);
  bool _chatsFetchedInThisSession = false;

  Map<String, dynamic>? get lastChatsPayload => _lastChatsPayload;

  int _reconnectDelaySeconds = 2;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  bool _isConnecting = false;

  bool get isConnecting {
    if (_isConnecting || _isReconnecting) return true;
    final state = _connectionStateManager.currentInfo.state;
    return state == conn_state.ConnectionState.connecting ||
           state == conn_state.ConnectionState.reconnecting ||
           state == conn_state.ConnectionState.connected;
  }

  void _log(
    String message, {
    LogLevel level = LogLevel.info,
    String category = 'API',
    Map<String, dynamic>? data,
  }) {
    _connectionLogCache.add(message);
    if (!_connectionLogController.isClosed) {
      _connectionLogController.add(message);
    }
    _connectionLogger.log(
      message,
      level: level,
      category: category,
      data: data,
    );
  }

  void _emitLocal(Map<String, dynamic> frame) {
    try {
      _messageController.add(frame);
    } catch (_) {}
  }

  String generateRandomDeviceId() {
    return const Uuid().v4();
  }

  Future<Map<String, dynamic>> _buildUserAgentPayload() async {
    final spoofedData = await SpoofingService.getSpoofedSessionData();

    if (spoofedData != null) {
      final String finalDeviceId;
      final String? idFromSpoofing = spoofedData['device_id'] as String?;

      if (idFromSpoofing != null && idFromSpoofing.isNotEmpty) {
        finalDeviceId = idFromSpoofing;
      } else {
        finalDeviceId = generateRandomDeviceId();
      }
      return {
        'deviceType': spoofedData['device_type'] as String? ?? 'IOS',
        'locale': spoofedData['locale'] as String? ?? 'ru',
        'deviceLocale': spoofedData['locale'] as String? ?? 'ru',
        'osVersion': spoofedData['os_version'] as String? ?? 'iOS 17.5.1',
        'deviceName': spoofedData['device_name'] as String? ?? 'iPhone',
        'headerUserAgent':
            spoofedData['user_agent'] as String? ??
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
        'appVersion': spoofedData['app_version'] as String? ?? '25.12.1',
        'screen': spoofedData['screen'] as String? ?? '1170x2532 3.0x',
        'timezone': spoofedData['timezone'] as String? ?? 'Europe/Moscow',
      };
    } else {
      return {
        'deviceType': 'WEB',
        'locale': 'ru',
        'deviceLocale': 'ru',
        'osVersion': 'Windows',
        'deviceName': 'Chrome',
        'headerUserAgent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'appVersion': '25.12.1',
        'screen': '1920x1080 1.0x',
        'timezone': 'Europe/Moscow',
      };
    }
  }

  void setAppInForeground(bool isForeground) {
    _isAppInForeground = isForeground;
  }

  void _updateConnectionState(
    conn_state.ConnectionState state, {
    String? message,
    int? attemptNumber,
    Duration? reconnectDelay,
    int? latency,
    Map<String, dynamic>? metadata,
  }) {
    _connectionStateManager.setState(
      state,
      message: message,
      attemptNumber: attemptNumber,
      reconnectDelay: reconnectDelay,
      serverUrl: _currentServerUrl,
      latency: latency,
      metadata: metadata,
    );
  }

  void _startHealthMonitoring() {
    _healthMonitor.startMonitoring(serverUrl: _currentServerUrl);
  }

  void _stopHealthMonitoring() {
    _healthMonitor.stopMonitoring();
  }

  Future<void> initialize() async {
    await _ensureCacheServicesInitialized();
  }

  Future<void> _ensureCacheServicesInitialized() async {
    if (_cacheServicesInitialized) return;
    await Future.wait([
      _cacheService.initialize(),
      _avatarCacheService.initialize(),
      _chatCacheService.initialize(),
      ImageCacheService.instance.initialize(),
    ]);
    _cacheServicesInitialized = true;
  }

  Future<String?> getClipboardData() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  void dispose() {
    _pingTimer?.cancel();
    _analyticsTimer?.cancel();
    _socketSubscription?.cancel();
    _socket?.close();
    _reconnectionCompleteController.close();
    _messageController.close();
  }

  void _initLz4BlockDecompress() {
    if (_lz4BlockDecompress != null) return;

    try {
      if (Platform.isWindows) {
        final dllPath = 'eslz4-win64.dll';
        _lz4Lib = DynamicLibrary.open(dllPath);
        try {
          _lz4BlockDecompress = _lz4Lib!
              .lookup<NativeFunction<Lz4DecompressFunction>>(
                'LZ4_decompress_safe',
              )
              .asFunction();
        } catch (e) {
          try {
            _lz4BlockDecompress = _lz4Lib!
                .lookup<NativeFunction<Lz4DecompressFunction>>(
                  'LZ4_decompress_fast',
                )
                .asFunction();
          } catch (e2) {}
        }
      }
    } catch (e) {}
  }

  void _handleSocketData(Uint8List data) {
    _processIncomingData(data);
  }

  void _processIncomingData(Uint8List newData) {
    _buffer = Uint8List.fromList([..._buffer!, ...newData]);
    while (_buffer!.length >= 10) {
      final header = _buffer!.sublist(0, 10);
      final payloadLen =
          ByteData.view(header.buffer, 6, 4).getUint32(0, Endian.big) &
          0xFFFFFF;
      if (_buffer!.length < 10 + payloadLen) {
        break;
      }
      final fullPacket = _buffer!.sublist(0, 10 + payloadLen);
      _buffer = _buffer!.sublist(10 + payloadLen);
      _processPacket(fullPacket);
    }
  }

  void _processPacket(Uint8List packet) {
    try {
      final ver = packet[0];
      final cmd = ByteData.view(packet.buffer).getUint16(1, Endian.big);
      final seq = packet[3];
      final opcode = ByteData.view(packet.buffer).getUint16(4, Endian.big);
      final packedLen = ByteData.view(
        packet.buffer,
        6,
        4,
      ).getUint32(0, Endian.big);

      final compFlag = packedLen >> 24;
      final payloadLen = packedLen & 0x00FFFFFF;

      final payloadBytes = packet.sublist(10, 10 + payloadLen);
      final payload = _unpackPacketPayload(payloadBytes, compFlag != 0);

      final message = {
        'ver': ver,
        'cmd': cmd,
        'seq': seq,
        'opcode': opcode,
        'payload': payload,
      };

      
      _emitLocal(message);

      final completer = _pending[seq];
      if (completer != null && !completer.isCompleted) {
        completer.complete(payload);
      }

      try {
        handleSocketMessage(message);
      } catch (e, stackTrace) {
        print('Ошибка вызова handleSocketMessage: $e');
        print('Stack trace: $stackTrace');
      }
    } catch (e) {
      print('Ошибка обработки пакета: $e');
    }
  }

  Uint8List _packPacket(
    int ver,
    int cmd,
    int seq,
    int opcode,
    Map<String, dynamic> payload,
  ) {
    final verB = Uint8List(1)..[0] = ver;
    final cmdB = Uint8List(2)
      ..buffer.asByteData().setUint16(0, cmd, Endian.big);
    final seqB = Uint8List(1)..[0] = seq;
    final opcodeB = Uint8List(2)
      ..buffer.asByteData().setUint16(0, opcode, Endian.big);

    final payloadBytes = msgpack.serialize(payload);
    final payloadLen = payloadBytes.length & 0xFFFFFF;
    final payloadLenB = Uint8List(4)
      ..buffer.asByteData().setUint32(0, payloadLen, Endian.big);

    return Uint8List.fromList(
      verB + cmdB + seqB + opcodeB + payloadLenB + payloadBytes,
    );
  }

  dynamic _decodeBlockTokens(dynamic value) {
    if (value is Map) {
      final maybeDecoded = _tryDecodeSingleBlock(value);
      if (maybeDecoded != null) {
        return maybeDecoded;
      }

      final result = <String, dynamic>{};
      value.forEach((k, v) {
        final key = k is String ? k : k.toString();
        result[key] = _decodeBlockTokens(v);
      });
      return result;
    } else if (value is List) {
      return value.map(_decodeBlockTokens).toList();
    }

    return value;
  }

  dynamic _tryDecodeSingleBlock(Map value) {
    try {
      if (value['type'] != 'block') {
        return null;
      }

      final rawData = value['data'];
      if (rawData is! List && rawData is! Uint8List) {
        return null;
      }

      final uncompressedSize =
          (value['uncompressed_size'] ??
                  value['uncompressedSize'] ??
                  value['size'])
              as int?;

      Uint8List compressedBytes = rawData is Uint8List
          ? rawData
          : Uint8List.fromList(List<int>.from(rawData as List));

      if (_lz4BlockDecompress != null && uncompressedSize != null) {
        if (uncompressedSize <= 0 || uncompressedSize > 10 * 1024 * 1024) {
          return null;
        }

        final srcSize = compressedBytes.length;
        final srcPtr = malloc.allocate<Uint8>(srcSize);
        final dstPtr = malloc.allocate<Uint8>(uncompressedSize);

        try {
          final srcList = srcPtr.asTypedList(srcSize);
          srcList.setAll(0, compressedBytes);

          final result = _lz4BlockDecompress!(
            srcPtr,
            dstPtr,
            srcSize,
            uncompressedSize,
          );

          if (result <= 0) {
            return null;
          }

          final actualSize = result;
          final dstList = dstPtr.asTypedList(actualSize);
          final decompressed = Uint8List.fromList(dstList);

          final nested = _deserializeMsgpack(decompressed);
          if (nested != null) {
            return nested;
          }

          return decompressed;
        } finally {
          malloc.free(srcPtr);
          malloc.free(dstPtr);
        }
      }

      try {
        final decompressed = _lz4DecompressBlockPure(
          compressedBytes,
          500000,
        );

        final nested = _deserializeMsgpack(decompressed);
        return nested ?? decompressed;
      } catch (e) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  dynamic _unpackPacketPayload(
    Uint8List payloadBytes, [
    bool isCompressed = false,
  ]) {
    if (payloadBytes.isEmpty) {
      return null;
    }

    try {
      Uint8List decompressedBytes = payloadBytes;

      try {
        decompressedBytes = _lz4DecompressBlockPure(payloadBytes, 500000);
      } catch (lz4Error) {
        decompressedBytes = payloadBytes;
      }

      return _deserializeMsgpack(decompressedBytes);
    } catch (e) {
      return null;
    }
  }

  Uint8List _lz4DecompressBlockPure(Uint8List src, int maxOutputSize) {
    final dst = BytesBuilder(copy: false);
    int srcPos = 0;

    while (srcPos < src.length) {
      if (srcPos >= src.length) break;
      final token = src[srcPos++];
      var literalLen = token >> 4;

      if (literalLen == 15) {
        while (srcPos < src.length) {
          final b = src[srcPos++];
          literalLen += b;
          if (b != 255) break;
        }
      }

      if (literalLen > 0) {
        if (srcPos + literalLen > src.length) {
          throw StateError(
            'LZ4: literal length выходит за пределы входного буфера',
          );
        }
        final literals = src.sublist(srcPos, srcPos + literalLen);
        srcPos += literalLen;
        dst.add(literals);
        if (dst.length > maxOutputSize) {
          throw StateError(
            'LZ4: превышен максимально допустимый размер вывода',
          );
        }
      }

      if (srcPos >= src.length) {
        break;
      }

      if (srcPos + 1 >= src.length) {
        throw StateError('LZ4: неполный offset в потоке');
      }
      final offset = src[srcPos] | (src[srcPos + 1] << 8);
      srcPos += 2;

      if (offset == 0) {
        throw StateError('LZ4: offset не может быть 0');
      }

      var matchLen = (token & 0x0F) + 4;

      if ((token & 0x0F) == 0x0F) {
        while (srcPos < src.length) {
          final b = src[srcPos++];
          matchLen += b;
          if (b != 255) break;
        }
      }

      final dstBytes = dst.toBytes();
      final dstLen = dstBytes.length;
      final matchPos = dstLen - offset;
      if (matchPos < 0) {
        throw StateError(
          'LZ4: match указывает за пределы уже декодированных данных',
        );
      }

      final match = <int>[];
      for (int i = 0; i < matchLen; i++) {
        match.add(dstBytes[matchPos + (i % offset)]);
      }
      dst.add(Uint8List.fromList(match));

      if (dst.length > maxOutputSize) {
        throw StateError('LZ4: превышен максимально допустимый размер вывода');
      }
    }

    return Uint8List.fromList(dst.toBytes());
  }

  dynamic _deserializeMsgpack(Uint8List data) {
    try {
      dynamic payload = msgpack.deserialize(data);

      if (payload is int &&
          data.length > 1 &&
          payload <= -1 &&
          payload >= -32) {
        final candidateOffsets = <int>[1, 2, 3, 4];

        dynamic recovered;

        for (final offset in candidateOffsets) {
          if (offset >= data.length) continue;

          try {
            final tail = data.sublist(offset);
            final realPayload = msgpack.deserialize(tail);
            recovered = realPayload;
            break;
          } catch (e) {}
        }

        if (recovered != null) {
          payload = recovered;
        }
      }

      final decoded = _decodeBlockTokens(payload);
      return decoded;
    } catch (e) {
      return null;
    }
  }
}
