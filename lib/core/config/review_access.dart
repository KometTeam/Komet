import 'dart:convert';

import '../../models/spoof_profile.dart';
import '../crypto/chat_crypto_service.dart';

class ReviewCredentials {
  final String token;
  final SpoofProfile? spoof;

  const ReviewCredentials({required this.token, this.spoof});
}

abstract final class ReviewAccess {
  static const String _phone = String.fromEnvironment('KOMET_REVIEW_PHONE');
  static const String _payload = String.fromEnvironment('KOMET_REVIEW_PAYLOAD');

  static bool get enabled => _phone.isNotEmpty && _payload.isNotEmpty;

  static bool matchesPhone(String phone) =>
      enabled && _digits(phone) == _digits(_phone);

  static Future<ReviewCredentials?> unlock(String code) async {
    if (!enabled) return null;
    final plaintext = await ChatCryptoService.instance.decryptWithPassword(
      _payload,
      '${_digits(_phone)}:$code',
    );
    if (plaintext == null) return null;
    try {
      final decoded = jsonDecode(plaintext);
      if (decoded is! Map<String, dynamic>) return null;
      final token = decoded['token'];
      if (token is! String || token.isEmpty) return null;
      final spoof = decoded['spoof'];
      return ReviewCredentials(
        token: token,
        spoof: spoof is Map<String, dynamic>
            ? SpoofProfile.fromJson(spoof)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');
}
