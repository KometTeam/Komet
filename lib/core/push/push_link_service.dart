import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/logger.dart';
import 'push_proxy_client.dart';

class PushLinkSession {
  final String linkId;
  final String qrLink;
  final DateTime expiresAt;
  final Duration pollEvery;

  const PushLinkSession({
    required this.linkId,
    required this.qrLink,
    required this.expiresAt,
    required this.pollEvery,
  });

  factory PushLinkSession.fromJson(Map<String, dynamic> json) {
    return PushLinkSession(
      linkId: json['link_id'] as String,
      qrLink: json['qr_link'] as String? ?? '',
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 2)),
      pollEvery: Duration(
        milliseconds: (json['poll_every_ms'] as int? ?? 5000),
      ),
    );
  }
}

class PushLinkStatus {
  static const waiting = 'waiting';
  static const password = 'password';
  static const done = 'done';
  static const expired = 'expired';

  final String status;
  final int? accountId;
  final String? hint;

  const PushLinkStatus({required this.status, this.accountId, this.hint});

  factory PushLinkStatus.fromJson(Map<String, dynamic> json) {
    return PushLinkStatus(
      status: json['status'] as String? ?? PushLinkStatus.expired,
      accountId: json['account_id'] as int?,
      hint: json['hint'] as String?,
    );
  }

  bool get isWaiting => status == waiting;
  bool get isPassword => status == password;
  bool get isDone => status == done;
  bool get isExpired => status == expired;
}

class PushLinkException implements Exception {
  final String message;

  const PushLinkException(this.message);

  @override
  String toString() => message;
}

class PushLinkService {
  PushLinkService._();

  static final PushLinkService instance = PushLinkService._();

  PushLinkSession? _session;

  PushLinkSession? get activeSession => _session;

  Future<PushLinkSession> start({
    required String apnsToken,
    required String voipToken,
    required String deviceId,
    required bool isDev,
  }) async {
    final response = await PushProxyClient.instance.post('/link/start', {
      'apns_token': apnsToken,
      'voip_token': voipToken,
      'device_id': deviceId,
      'is_development': isDev,
    });
    final body = await _decode(response, 'link/start');
    final session = PushLinkSession.fromJson(body);
    _session = session;
    logger.i(
      'PushLink: линк ${session.linkId} создан, ttl до ${session.expiresAt}',
    );
    return session;
  }

  Future<PushLinkStatus> status(String linkId) async {
    final response = await PushProxyClient.instance.post('/link/status', {
      'link_id': linkId,
    });
    final body = await _decode(response, 'link/status');
    return PushLinkStatus.fromJson(body);
  }

  Future<PushLinkStatus> password(String linkId, String password) async {
    final response = await PushProxyClient.instance.post('/link/password', {
      'link_id': linkId,
      'password': password,
    });
    final body = await _decode(response, 'link/password');
    return PushLinkStatus.fromJson(body);
  }

  Future<void> cancel(String linkId) async {
    try {
      await PushProxyClient.instance.post('/link/cancel', {'link_id': linkId});
    } catch (e) {
      if (kDebugMode) {
        logger.w('PushLink: отмена линка: $e');
      }
    } finally {
      if (_session?.linkId == linkId) {
        _session = null;
      }
    }
  }

  Future<void> clear() async {
    _session = null;
  }

  Future<Map<String, dynamic>> _decode(
    HttpClientResponse response,
    String step,
  ) async {
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw PushLinkException(
        body.isEmpty ? 'HTTP ${response.statusCode}' : body,
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const PushLinkException('неожиданный ответ сервера');
    }
    return decoded;
  }
}
