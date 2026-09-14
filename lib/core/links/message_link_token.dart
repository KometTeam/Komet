import 'dart:convert';

abstract final class MessageLinkToken {
  static final RegExp _token = RegExp(r'^[A-Za-z0-9_-]{11}$');
  static final BigInt _byteMask = BigInt.from(0xff);
  static final BigInt _maxId = (BigInt.one << 64) - BigInt.one;

  static String? encode(String messageId) {
    final parsed = BigInt.tryParse(messageId);
    if (parsed == null || parsed <= BigInt.zero || parsed > _maxId) return null;
    var value = parsed;
    final bytes = List<int>.filled(8, 0);
    for (var i = 7; i >= 0; i--) {
      bytes[i] = (value & _byteMask).toInt();
      value = value >> 8;
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String? decode(String token) {
    if (!_token.hasMatch(token)) return null;
    final List<int> bytes;
    try {
      bytes = base64Url.decode('$token=');
    } on FormatException {
      return null;
    }
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value == BigInt.zero ? null : value.toString();
  }

  static String? messageUrl({
    required int chatId,
    required String messageId,
    String? publicLink,
  }) {
    final token = encode(messageId);
    if (token == null) return null;
    final base = publicLink?.trim() ?? '';
    if (base.isEmpty) return 'https://max.ru/c/$chatId/$token';
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return '$trimmed/$token';
  }
}
