import '../../core/storage/app_database.dart';

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
