import '../../core/storage/app_database.dart';
import 'messages.dart';

class CachedContact {
  final int id;
  final int accountId;
  final String firstName;
  final String? lastName;
  final int phone;
  final int? photoId;
  final String? baseUrl;
  final String? baseRawUrl;
  final int updateTime;

  const CachedContact({
    required this.id,
    required this.accountId,
    required this.firstName,
    this.lastName,
    required this.phone,
    this.photoId,
    this.baseUrl,
    this.baseRawUrl,
    required this.updateTime,
  });

  factory CachedContact.fromDbRow(Map<String, dynamic> row) => CachedContact(
    id: row['id'] as int,
    accountId: row['account_id'] as int,
    firstName: row['first_name'] as String,
    lastName: row['last_name'] as String?,
    phone: row['phone'] as int,
    photoId: row['photo_id'] as int?,
    baseUrl: row['base_url'] as String?,
    baseRawUrl: row['base_raw_url'] as String?,
    updateTime: row['update_time'] as int,
  );
}

class ContactsModule {
  static Future<void> syncFromLoginPayload(
    Map<dynamic, dynamic> data,
    int accountId,
  ) async {
    final contacts = data['contacts'];
    if (contacts is! List || contacts.isEmpty) return;

    final rows = <Map<String, dynamic>>[];
    for (final raw in contacts.whereType<Map>()) {
      final contact = raw.cast<dynamic, dynamic>();
      final row = _parseContact(contact, accountId);
      if (row != null) rows.add(row);
      _primeContactCache(contact);
    }

    if (rows.isNotEmpty) {
      await AppDatabase.saveContacts(rows);
    }
  }

  static void _primeContactCache(Map<dynamic, dynamic> contact) {
    final id = contact['id'];
    if (id is! int) return;

    final names = contact['names'];
    if (names is List && names.isNotEmpty) {
      final nameRaw = names.firstWhere(
        (n) => n is Map && n['type'] == 'ONEME',
        orElse: () => names.firstWhere((n) => n is Map, orElse: () => null),
      );
      if (nameRaw is Map) {
        final firstName = (nameRaw['firstName'] as String?) ?? '';
        final lastName = nameRaw['lastName'] as String?;
        final fullName = (lastName != null && lastName.isNotEmpty)
            ? '$firstName $lastName'
            : firstName;
        if (fullName.isNotEmpty) ContactCache.put(id, fullName);
      }
    }

    final baseUrl = contact['baseUrl'] as String?;
    if (baseUrl != null && baseUrl.isNotEmpty) {
      ContactCache.putAvatar(id, baseUrl);
    }
  }

  static Future<List<CachedContact>> getContacts(int accountId) async {
    final rows = await AppDatabase.loadContacts(accountId);
    return rows.map(CachedContact.fromDbRow).toList();
  }

  /// Прогревает in-memory ContactCache из локальных контактов.
  /// Нужно вызывать на cold start: иначе кэш пуст до следующего логина.
  static Future<void> primeCacheFromDb(int accountId) async {
    final contacts = await getContacts(accountId);
    for (final c in contacts) {
      final fullName = (c.lastName != null && c.lastName!.isNotEmpty)
          ? '${c.firstName} ${c.lastName}'
          : c.firstName;
      if (fullName.isNotEmpty) ContactCache.put(c.id, fullName);
      if (c.baseUrl != null && c.baseUrl!.isNotEmpty) {
        ContactCache.putAvatar(c.id, c.baseUrl);
      }
    }
  }

  static Map<String, dynamic>? _parseContact(
    Map<dynamic, dynamic> contact,
    int accountId,
  ) {
    final id = contact['id'];
    if (id is! int) return null;

    String firstName = '';
    String? lastName;

    final names = contact['names'];
    if (names is List && names.isNotEmpty) {
      final nameRaw = names.firstWhere(
        (n) => n is Map && n['type'] == 'ONEME',
        orElse: () => names.firstWhere((n) => n is Map, orElse: () => null),
      );
      if (nameRaw is! Map) return null;
      final name = nameRaw;
      firstName = (name['firstName'] as String?) ?? '';
      lastName = name['lastName'] as String?;
    }

    return {
      'id': id,
      'account_id': accountId,
      'first_name': firstName,
      'last_name': lastName,
      'phone': (contact['phone'] as int?) ?? 0,
      'photo_id': contact['photoId'] as int?,
      'base_url': contact['baseUrl'] as String?,
      'base_raw_url': contact['baseRawUrl'] as String?,
      'update_time': (contact['updateTime'] as int?) ?? 0,
    };
  }
}
