import '../../core/storage/app_database.dart';

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

    final rows = contacts
        .whereType<Map>()
        .map((c) => _parseContact(c.cast<dynamic, dynamic>(), accountId))
        .whereType<Map<String, dynamic>>()
        .toList();

    if (rows.isNotEmpty) {
      await AppDatabase.saveContacts(rows);
    }
  }

  static Future<List<CachedContact>> getContacts(int accountId) async {
    final rows = await AppDatabase.loadContacts(accountId);
    return rows.map(CachedContact.fromDbRow).toList();
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
      final name =
          names.firstWhere(
                (n) => n is Map && n['type'] == 'ONEME',
                orElse: () => names.first,
              )
              as Map;
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
