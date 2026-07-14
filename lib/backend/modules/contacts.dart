import 'package:flutter/foundation.dart';

import '../../core/config/debug_test.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/logger.dart';
import '../api.dart';
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
  final Set<String> options;

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
    this.options = const {},
  });

  bool get isOfficial => options.contains('OFFICIAL');
  bool get isBot => options.contains('BOT');
  bool get isServiceAccount => options.contains('SERVICE_ACCOUNT');
  bool get isVerified => isOfficial;

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
    options: _decodeOptions(row['options']),
  );

  static Set<String> _decodeOptions(dynamic raw) {
    if (raw is! String || raw.isEmpty) return const {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }
}

class PhoneLookupResult {
  final int id;
  final String? name;
  final String? avatarUrl;

  const PhoneLookupResult({required this.id, this.name, this.avatarUrl});
}

class ContactPhotos {
  final List<String> urls;
  final int total;

  const ContactPhotos({required this.urls, required this.total});

  static const empty = ContactPhotos(urls: [], total: 0);
}

class ContactsModule {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Future<PhoneLookupResult?> findByPhone(Api api, String phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized == null) return null;
    final packet = await api.sendRequest(Opcode.contactInfoByPhone, {
      'phone': normalized,
    });
    if (packet.isError) return null;
    final contact = (packet.payload as Map?)?['contact'];
    if (contact is! Map) return null;
    final id = contact['id'];
    if (id is! int) return null;

    String? name;
    final names = contact['names'];
    if (names is List) {
      final n = names.firstWhere((e) => e is Map, orElse: () => null);
      if (n is Map) {
        final first =
            (n['firstName'] as String?) ?? (n['name'] as String?) ?? '';
        final last = (n['lastName'] as String?) ?? '';
        final full = '$first $last'.trim();
        if (full.isNotEmpty) name = full;
      }
    }

    return PhoneLookupResult(
      id: id,
      name: name,
      avatarUrl: contact['baseUrl'] as String?,
    );
  }

  static String? _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 5) return null;
    return '+$digits';
  }

  static Future<CachedContact?> addContact(
    Api api,
    int id,
    String firstName, {
    int phone = 0,
  }) async {
    final resp = await api.sendRequest(Opcode.contactUpdate, {
      'action': 'ADD',
      'contactId': id,
      'firstName': firstName,
    });

    final profile = await AppDatabase.loadActiveProfile();
    if (profile == null) return null;

    final data = resp.payload;
    final contact = (data is Map && data['contact'] is Map)
        ? (data['contact'] as Map).cast<dynamic, dynamic>()
        : null;

    final row = contact != null
        ? _parseContact(contact, profile.id)
        : {
            'id': id,
            'account_id': profile.id,
            'first_name': firstName,
            'last_name': null,
            'phone': 0,
            'photo_id': null,
            'base_url': null,
            'base_raw_url': null,
            'update_time': 0,
            'options': null,
          };

    if (row == null) return null;
    if (phone > 0 && ((row['phone'] as int?) ?? 0) == 0) {
      row['phone'] = phone;
    }
    await AppDatabase.saveContacts([row]);
    if (contact != null) _primeContactCache(contact);
    revision.value++;
    return CachedContact.fromDbRow(row);
  }

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
      revision.value++;
    }
    logger.i(
      'Контакты: получено ${contacts.length}, сохранено ${rows.length} (акк $accountId)',
    );
  }

  static Future<void> syncFromServer(Api api, int accountId) async {
    final map = await api.sendRequestMap(Opcode.contactsGet, {
      'contactsSync': 0,
    });
    if (map == null) return;
    await syncFromLoginPayload(map.cast<dynamic, dynamic>(), accountId);
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

  static Future<ContactPhotos> fetchPhotos(
    Api api,
    int contactId, {
    int from = 0,
    int count = 25,
  }) async {
    final map = await api.sendRequestMap(Opcode.contactPhotos, {
      'contactId': contactId,
      'from': from,
      'count': count,
    });
    if (map == null) return ContactPhotos.empty;
    final rawUrls = map['urls'];
    final urls = rawUrls is List
        ? rawUrls.whereType<String>().toList()
        : <String>[];
    final total = map['total'] is int ? map['total'] as int : urls.length;
    return ContactPhotos(urls: urls, total: total);
  }

  static Future<List<CachedContact>> getContacts(int accountId) async {
    final rows = await AppDatabase.loadContacts(accountId);
    return rows.map(CachedContact.fromDbRow).toList();
  }

  static const List<String> _debugFirstNames = [
    'Алиса', 'Борис', 'Вера', 'Глеб', 'Дарья', 'Егор', 'Жанна', 'Захар',
    'Ирина', 'Кирилл', 'Лия', 'Максим', 'Нина', 'Олег', 'Полина', 'Роман',
    'София', 'Тимур', 'Ульяна', 'Фёдор', 'Ханна', 'Цветана', 'Чеслав', 'Шура',
  ];

  static const List<String> _debugLastNames = [
    'Иванов', 'Петров', 'Сидоров', 'Кузнецов', 'Смирнов', 'Попов', 'Волков',
    'Соколов', 'Морозов', 'Новиков', 'Фёдоров', 'Козлов',
  ];

  static List<CachedContact> debugContacts() {
    final count = DebugTest.contactCount;
    final out = <CachedContact>[];
    for (var i = 0; i < count; i++) {
      final first = _debugFirstNames[i % _debugFirstNames.length];
      final last =
          _debugLastNames[(i ~/ _debugFirstNames.length) %
              _debugLastNames.length];
      out.add(
        CachedContact(
          id: 900000000 + i,
          accountId: DebugTest.debugAccountId,
          firstName: '$first ${i + 1}',
          lastName: last,
          phone: 79000000000 + i,
          baseUrl: 'https://i.pravatar.cc/150?u=komet_debug_$i',
          updateTime: 1,
          options: i % 6 == 0 ? const {'OFFICIAL'} : const {},
        ),
      );
    }
    return out;
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

    final optionsRaw = contact['options'];
    String? optionsStr;
    if (optionsRaw is List) {
      optionsStr = optionsRaw.whereType<String>().join(',');
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
      'options': optionsStr,
    };
  }
}
