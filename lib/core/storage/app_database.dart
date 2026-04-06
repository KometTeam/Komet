import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ProfileData {
  final int id;
  final String firstName;
  final String? lastName;
  final int phone;
  final int? photoId;
  final String? baseUrl;
  final String? baseRawUrl;
  final String country;
  final int accountStatus;
  final int updateTime;
  final List<int>? profileOptions;

  ProfileData({
    required this.id,
    required this.firstName,
    this.lastName,
    required this.phone,
    this.photoId,
    this.baseUrl,
    this.baseRawUrl,
    required this.country,
    required this.accountStatus,
    required this.updateTime,
    this.profileOptions,
  });

  factory ProfileData.fromServerMap(Map<dynamic, dynamic> contact) {
    final names = contact['names'];
    String firstName = '';
    String? lastName;

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

    final profileOptionsRaw = contact['profileOptions'];
    List<int>? profileOptions;
    if (profileOptionsRaw is List) {
      profileOptions = profileOptionsRaw.map((e) => e as int).toList();
    }

    return ProfileData(
      id: contact['id'] as int,
      firstName: firstName,
      lastName: lastName,
      phone: contact['phone'] as int,
      photoId: contact['photoId'] as int?,
      baseUrl: contact['baseUrl'] as String?,
      baseRawUrl: contact['baseRawUrl'] as String?,
      country: (contact['country'] as String?) ?? '',
      accountStatus: (contact['accountStatus'] as int?) ?? 0,
      updateTime: (contact['updateTime'] as int?) ?? 0,
      profileOptions: profileOptions,
    );
  }

  factory ProfileData.fromDbRow(Map<String, dynamic> row) {
    final profileOptionsStr = row['profile_options'] as String?;
    List<int>? profileOptions;
    if (profileOptionsStr != null && profileOptionsStr.isNotEmpty) {
      profileOptions = profileOptionsStr
          .split(',')
          .map((e) => int.parse(e.trim()))
          .toList();
    }
    return ProfileData(
      id: row['id'] as int,
      firstName: (row['first_name'] as String?) ?? '',
      lastName: row['last_name'] as String?,
      phone: (row['phone'] as int?) ?? 0,
      photoId: row['photo_id'] as int?,
      baseUrl: row['base_url'] as String?,
      baseRawUrl: row['base_raw_url'] as String?,
      country: (row['country'] as String?) ?? '',
      accountStatus: (row['account_status'] as int?) ?? 0,
      updateTime: (row['update_time'] as int?) ?? 0,
      profileOptions: profileOptions,
    );
  }

  Map<String, dynamic> toDbRow() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'phone': phone,
    'photo_id': photoId,
    'base_url': baseUrl,
    'base_raw_url': baseRawUrl,
    'country': country,
    'account_status': accountStatus,
    'update_time': updateTime,
    'profile_options': profileOptions?.join(','),
  };
}

abstract class SyncKey {
  static const chatsSync = 'chats_sync';
  static const contactsSync = 'contacts_sync';
  static const callsSync = 'calls_sync';
  static const draftsSync = 'drafts_sync';
  static const bannersSync = 'banners_sync';
  static const presenceSync = 'presence_sync';
  static const lastLogin = 'last_login';
  static const configHash = 'config_hash';
  static const chatCacheFingerprint = 'chat_cache_fingerprint';
  static const serverTime = 'server_time';
}

class AppDatabase {
  static Database? _db;

  static Future<void> init() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  static Future<Database> get _instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'komet.db'),
      version: 7,
      onOpen: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => _createTables(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE profile ADD COLUMN is_active INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('DROP TABLE IF EXISTS sync_state');
          await db.execute(_syncStateSchema);
        }
        if (oldVersion < 3) {
          await db.execute(_chatsCacheSchema);
        }
        if (oldVersion < 4) {
          await db.execute(_contactsSchema);
        }
        if (oldVersion < 5) {
          await db.execute('DROP TABLE IF EXISTS chats_cache');
          await db.execute(_chatsCacheSchema);
        }
        if (oldVersion < 6) {
          await db.execute(_messagesSchema);
        }
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE profile ADD COLUMN profile_options TEXT',
          );
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE profile (
        id           INTEGER PRIMARY KEY,
        first_name   TEXT    NOT NULL,
        last_name    TEXT,
        phone        INTEGER NOT NULL,
        photo_id     INTEGER,
        base_url     TEXT,
        base_raw_url TEXT,
        country      TEXT    NOT NULL DEFAULT '',
        account_status INTEGER NOT NULL DEFAULT 0,
        update_time  INTEGER NOT NULL DEFAULT 0,
        is_active    INTEGER NOT NULL DEFAULT 0,
        profile_options TEXT
      )
    ''');
    await db.execute(_syncStateSchema);
    await db.execute(_chatsCacheSchema);
    await db.execute(_contactsSchema);
    await db.execute(_messagesSchema);
  }

  static const _contactsSchema = '''
    CREATE TABLE contacts (
      id           INTEGER PRIMARY KEY,
      account_id   INTEGER NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
      first_name   TEXT    NOT NULL,
      last_name    TEXT,
      phone        INTEGER NOT NULL,
      photo_id     INTEGER,
      base_url     TEXT,
      base_raw_url TEXT,
      update_time  INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const _syncStateSchema = '''
    CREATE TABLE sync_state (
      account_id INTEGER NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
      key        TEXT    NOT NULL,
      value      TEXT    NOT NULL,
      PRIMARY KEY (account_id, key)
    )
  ''';

  static const _chatsCacheSchema = '''
    CREATE TABLE chats_cache (
      id              INTEGER NOT NULL,
      account_id      INTEGER NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
      type            TEXT    NOT NULL,
      title           TEXT,
      icon_url        TEXT,
      last_msg_id     INTEGER,
      last_msg_time   INTEGER,
      last_msg_text   TEXT,
      last_msg_sender INTEGER,
      unread_count    INTEGER NOT NULL DEFAULT 0,
      last_event_time INTEGER NOT NULL DEFAULT 0,
      cached_at       INTEGER NOT NULL,
      fav_index       INTEGER,
      dont_disturb_until INTEGER NOT NULL DEFAULT 0,
      is_online       INTEGER NOT NULL DEFAULT 0,
      seen_time       INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (id, account_id)
    )
  ''';

  static const _messagesSchema = '''
    CREATE TABLE messages (
      id         TEXT    NOT NULL,
      account_id INTEGER NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
      chat_id    INTEGER NOT NULL,
      sender_id  INTEGER NOT NULL,
      text       TEXT,
      time       INTEGER NOT NULL,
      status     TEXT,
      payload    TEXT,
      PRIMARY KEY (id, account_id),
      FOREIGN KEY (chat_id, account_id) REFERENCES chats_cache (id, account_id) ON DELETE CASCADE
    )
  ''';

  static Future<void> saveProfile(ProfileData profile) async {
    final db = await _instance;
    await db.insert(
      'profile',
      profile.toDbRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<ProfileData?> loadProfile(int accountId) async {
    final db = await _instance;
    final rows = await db.query(
      'profile',
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProfileData.fromDbRow(rows.first);
  }

  static Future<List<ProfileData>> loadAllProfiles() async {
    final db = await _instance;
    final rows = await db.query('profile', orderBy: 'is_active DESC, id ASC');
    return rows.map(ProfileData.fromDbRow).toList();
  }

  static Future<ProfileData?> loadActiveProfile() async {
    final db = await _instance;
    final rows = await db.query('profile', where: 'is_active = 1', limit: 1);
    if (rows.isEmpty) return null;
    return ProfileData.fromDbRow(rows.first);
  }

  static Future<void> setActiveAccount(int accountId) async {
    final db = await _instance;
    await db.transaction((txn) async {
      await txn.update('profile', {'is_active': 0});
      await txn.update(
        'profile',
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [accountId],
      );
    });
  }

  static Future<void> deleteAccount(int accountId) async {
    final db = await _instance;
    await db.delete('profile', where: 'id = ?', whereArgs: [accountId]);
  }

  static Future<void> setSyncValue(
    int accountId,
    String key,
    String value,
  ) async {
    final db = await _instance;
    await db.insert('sync_state', {
      'account_id': accountId,
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getSyncValue(int accountId, String key) async {
    final db = await _instance;
    final rows = await db.query(
      'sync_state',
      where: 'account_id = ? AND key = ?',
      whereArgs: [accountId, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  static Future<Map<String, String>> getAllSyncValues(int accountId) async {
    final db = await _instance;
    final rows = await db.query(
      'sync_state',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  static Future<void> savePrivacyConfig(
    int accountId,
    String jsonConfig,
  ) async {
    final db = await _instance;
    await db.insert('sync_state', {
      'account_id': accountId,
      'key': 'privacy_config',
      'value': jsonConfig,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getPrivacyConfig(int accountId) async {
    final db = await _instance;
    final rows = await db.query(
      'sync_state',
      where: 'account_id = ? AND key = ?',
      whereArgs: [accountId, 'privacy_config'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // Chats cache

  static Future<void> saveChats(List<Map<String, dynamic>> rows) async {
    final db = await _instance;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'chats_cache',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> loadChats(int accountId) async {
    final db = await _instance;
    return db.query(
      'chats_cache',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'last_event_time DESC',
    );
  }

  static Future<void> clearChatsCache(int accountId) async {
    final db = await _instance;
    await db.delete(
      'chats_cache',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  static Future<void> saveContacts(List<Map<String, dynamic>> rows) async {
    final db = await _instance;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'contacts',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> loadContacts(int accountId) async {
    final db = await _instance;
    return db.query(
      'contacts',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  static Future<void> saveMessages(List<Map<String, dynamic>> rows) async {
    final db = await _instance;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(
          'messages',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<List<Map<String, dynamic>>> loadMessages(
    int accountId,
    int chatId, {
    int? limit,
    int? offset,
  }) async {
    final db = await _instance;
    return db.query(
      'messages',
      where: 'account_id = ? AND chat_id = ?',
      whereArgs: [accountId, chatId],
      orderBy: 'time DESC',
      limit: limit,
      offset: offset,
    );
  }

  static Future<void> clearMessages(int accountId, int chatId) async {
    final db = await _instance;
    await db.delete(
      'messages',
      where: 'account_id = ? AND chat_id = ?',
      whereArgs: [accountId, chatId],
    );
  }
}
