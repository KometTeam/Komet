import 'dart:convert';
import 'dart:typed_data';

class ShareRecipientSnapshot {
  const ShareRecipientSnapshot({
    required this.id,
    required this.title,
    required this.type,
    this.disabledReason,
  });

  final int id;
  final String title;
  final String type;
  final String? disabledReason;

  Map<String, Object?> toMap() => {
    'id': id.toString(),
    'title': title,
    'type': type,
    if (disabledReason != null) 'disabledReason': disabledReason,
  };
}

class ShareAccountSnapshot {
  const ShareAccountSnapshot({
    required this.accountId,
    required this.accountName,
    required this.token,
    required this.session,
    required this.login,
    required this.chats,
  });

  final int accountId;
  final String accountName;
  final String token;
  final Map<String, Object?> session;
  final Map<dynamic, dynamic> login;
  final List<ShareRecipientSnapshot> chats;

  Map<String, Object?> toMap() {
    final loginOptions = Map<dynamic, dynamic>.from(login)
      ..remove('token')
      ..remove('chatCacheFingerprint');
    return {
      'accountId': accountId.toString(),
      'accountName': accountName,
      'token': token,
      'session': session,
      'login': _encode(loginOptions),
      'chats': chats.map((chat) => chat.toMap()).toList(growable: false),
    };
  }

  static Object? _encode(Object? value) {
    if (value is Uint8List) return {r'$bin': base64Encode(value)};
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key is int ? '\$int:$key' : key, _encode(item)),
      );
    }
    if (value is List) return value.map(_encode).toList(growable: false);
    return value;
  }
}
