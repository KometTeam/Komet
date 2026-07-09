import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:komet/core/storage/app_instance.dart';
import 'package:komet/core/utils/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show databaseFactorySqflitePlugin;
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

  factory ProfileData.fromServerProfile(Map<dynamic, dynamic> profile) {
    final contact = profile['contact'];
    if (contact is! Map) {
      throw const FormatException('No contact in profile');
    }
    return ProfileData.fromServerMap(
      contact.cast<dynamic, dynamic>(),
      profileOptions: _parseProfileOptions(profile['profileOptions']),
    );
  }

  factory ProfileData.fromServerMap(
    Map<dynamic, dynamic> contact, {
    List<int>? profileOptions,
  }) {
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
      profileOptions:
          profileOptions ?? _parseProfileOptions(contact['profileOptions']),
    );
  }

  static List<int>? _parseProfileOptions(dynamic raw) {
    if (raw is! List) return null;
    final options = raw
        .map((e) => e is int ? e : int.tryParse(e.toString()))
        .whereType<int>()
        .toList();
    return options.isEmpty ? null : options;
  }

  factory ProfileData.fromDbRow(Map<String, dynamic> row) {
    final profileOptionsStr = row['profile_options'] as String?;
    List<int>? profileOptions;
    if (profileOptionsStr != null && profileOptionsStr.isNotEmpty) {
      try {
        profileOptions = profileOptionsStr
            .split(',')
            .where((e) => e.trim().isNotEmpty)
            .map((e) => int.parse(e.trim()))
            .toList();
      } catch (_) {
        profileOptions = null;
      }
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

  Map<String, dynamic> toDbRow({bool isActive = false}) => {
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
    'is_active': isActive ? 1 : 0,
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
  static const loginInfo = 'login_info';
}

class AppDatabase {
  static Database? _db;

  static String? _mobileDbDir;

  static Future<void> init() async {
    if (Platform.isAndroid || Platform.isIOS) {
      _mobileDbDir = await databaseFactorySqflitePlugin.getDatabasesPath();
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  static Completer<Database>? _initCompleter;

  static Future<Database> get _instance async {
    if (_db != null) return _db!;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<Database>();
    try {
      _db = await _open();
      _initCompleter!.complete(_db!);
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
    return _db!;
  }

  static Future<String> _databasesDir() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      final dir = await getApplicationSupportDirectory();
      return dir.path;
    }
    return _mobileDbDir ??= await databaseFactorySqflitePlugin
        .getDatabasesPath();
  }

  static Future<void> _migrateLegacyDb(String target) async {
    if (AppInstance.isNamed) return;
    if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) return;
    try {
      if (await File(target).exists()) return;
      final legacy = File(join(await getDatabasesPath(), 'komet.db'));
      if (legacy.path == target) return;
      if (await legacy.exists()) {
        await legacy.copy(target);
        logger.i('[db] перенёс komet.db -> $target');
      }
    } catch (e) {
      logger.w('legacy db migration failed: $e');
    }
  }

  static Future<Database> _open() async {
    final dbPath = await _databasesDir();
    await Directory(dbPath).create(recursive: true);
    final target = join(dbPath, 'komet${AppInstance.suffix}.db');
    await _migrateLegacyDb(target);
    return openDatabase(
      target,
      version: 19,
      onOpen: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => _createTables(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addColumnIfMissing(
            db,
            'profile',
            'is_active',
            'INTEGER NOT NULL DEFAULT 0',
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
          await _addColumnIfMissing(db, 'profile', 'profile_options', 'TEXT');
        }
        if (oldVersion < 8) {
          await _addColumnIfMissing(db, 'chats_cache', 'participants', 'TEXT');
        }
        if (oldVersion < 9) {
          await _addColumnIfMissing(db, 'contacts', 'options', 'TEXT');
          await _addColumnIfMissing(db, 'chats_cache', 'options', 'TEXT');
        }
        if (oldVersion < 10) {
          await _addColumnIfMissing(db, 'chats_cache', 'owner', 'INTEGER');
          await _addColumnIfMissing(db, 'chats_cache', 'admins', 'TEXT');
        }
        if (oldVersion < 11) {
          await _createIndexes(db);
        }
        if (oldVersion < 12) {
          await _addColumnIfMissing(
            db,
            'chats_cache',
            'last_msg_status',
            'TEXT',
          );
        }
        if (oldVersion < 13) {
          await _addColumnIfMissing(
            db,
            'messages',
            'deleted',
            'INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 14) {
          await _addColumnIfMissing(
            db,
            'chats_cache',
            'in_list',
            'INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (oldVersion < 15) {
          await _addColumnIfMissing(db, 'messages', 'edit_history', 'TEXT');
        }
        if (oldVersion < 16) {
          await _addColumnIfMissing(
            db,
            'chats_cache',
            'last_msg_elements',
            'TEXT',
          );
        }
        if (oldVersion < 17) {
          await db.execute(_chatParticipantsSchema);
          await _createChatParticipantsIndex(db);
          await _backfillChatParticipants(db);
        }
        if (oldVersion < 18) {
          await _addColumnIfMissing(
            db,
            'chats_cache',
            'pinned_msg_id',
            'INTEGER',
          );
          await _addColumnIfMissing(
            db,
            'chats_cache',
            'pinned_msg_text',
            'TEXT',
          );
          await _addColumnIfMissing(
            db,
            'chats_cache',
            'pinned_msg_time',
            'INTEGER',
          );
        }
        if (oldVersion < 19) {
          await _addColumnIfMissing(
            db,
            'chats_cache',
            'pinned_msg_is_preview',
            'INTEGER NOT NULL DEFAULT 0',
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
    await db.execute(_chatParticipantsSchema);
    await _createIndexes(db);
    await _createChatParticipantsIndex(db);
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(account_id, chat_id, time DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chats_account ON chats_cache(account_id, last_event_time DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contacts_account ON contacts(account_id)',
    );
  }

  static Future<void> _createChatParticipantsIndex(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_participants_lookup '
      'ON chat_participants(account_id, participant_id, chat_id)',
    );
  }

  static List<int> _participantIdsFromRaw(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final ids = <int>[];
      for (final key in decoded.keys) {
        final id = key is int ? key : int.tryParse(key.toString());
        if (id != null) ids.add(id);
      }
      return ids;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _backfillChatParticipants(Database db) async {
    final chats = await db.query(
      'chats_cache',
      columns: ['id', 'account_id', 'participants'],
      where: "type = 'DIALOG'",
    );
    final batch = db.batch();
    for (final chat in chats) {
      final accountId = chat['account_id'];
      final chatId = chat['id'];
      if (accountId is! int || chatId is! int) continue;
      for (final pid in _participantIdsFromRaw(chat['participants'])) {
        batch.insert('chat_participants', {
          'account_id': accountId,
          'chat_id': chatId,
          'participant_id': pid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    await batch.commit(noResult: true);
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
      update_time  INTEGER NOT NULL DEFAULT 0,
      options      TEXT
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
      last_msg_elements TEXT,
      last_msg_sender INTEGER,
      last_msg_status TEXT,
      unread_count    INTEGER NOT NULL DEFAULT 0,
      last_event_time INTEGER NOT NULL DEFAULT 0,
      cached_at       INTEGER NOT NULL,
      fav_index       INTEGER,
      dont_disturb_until INTEGER NOT NULL DEFAULT 0,
      is_online       INTEGER NOT NULL DEFAULT 0,
      seen_time       INTEGER NOT NULL DEFAULT 0,
      participants    TEXT NOT NULL DEFAULT "",
      options         TEXT,
      owner           INTEGER,
      admins          TEXT,
      in_list         INTEGER NOT NULL DEFAULT 1,
      pinned_msg_id   INTEGER,
      pinned_msg_text TEXT,
      pinned_msg_time INTEGER,
      pinned_msg_is_preview INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (id, account_id)
    )
  ''';

  static const _chatParticipantsSchema = '''
    CREATE TABLE chat_participants (
      account_id     INTEGER NOT NULL,
      chat_id        INTEGER NOT NULL,
      participant_id INTEGER NOT NULL,
      PRIMARY KEY (account_id, chat_id, participant_id),
      FOREIGN KEY (chat_id, account_id)
        REFERENCES chats_cache (id, account_id) ON DELETE CASCADE
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
      deleted    INTEGER NOT NULL DEFAULT 0,
      edit_history TEXT,
      PRIMARY KEY (id, account_id),
      FOREIGN KEY (chat_id, account_id) REFERENCES chats_cache (id, account_id) ON DELETE CASCADE
    )
  ''';

  static Future<void> saveProfile(
    ProfileData profile, {
    bool isActive = true,
  }) async {
    final db = await _instance;
    final row = profile.toDbRow(isActive: isActive);
    final cols = row.keys.toList();
    final placeholders = List.filled(cols.length, '?').join(', ');
    final updates = cols
        .where((c) => c != 'id')
        .map((c) => '$c = excluded.$c')
        .join(', ');
    await db.rawInsert(
      'INSERT INTO profile (${cols.join(', ')}) VALUES ($placeholders) '
      'ON CONFLICT(id) DO UPDATE SET $updates',
      cols.map((c) => row[c]).toList(),
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

  static Future<void> saveLoginInfo(int accountId, String jsonInfo) async {
    final db = await _instance;
    await db.insert('sync_state', {
      'account_id': accountId,
      'key': SyncKey.loginInfo,
      'value': jsonInfo,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getLoginInfo(int accountId) async {
    return getSyncValue(accountId, SyncKey.loginInfo);
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // Chats cache

  static Future<void> saveChats(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      final db = await _instance;
      final cols = rows.first.keys.toList();
      final placeholders = List.filled(cols.length, '?').join(', ');
      final updates = cols
          .where((c) => c != 'id' && c != 'account_id')
          .map((c) => '$c = excluded.$c')
          .join(', ');
      final sql =
          'INSERT INTO chats_cache (${cols.join(', ')}) '
          'VALUES ($placeholders) '
          'ON CONFLICT(id, account_id) DO UPDATE SET $updates';
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final row in rows) {
          batch.rawInsert(sql, cols.map((c) => row[c]).toList());
        }
        await batch.commit(noResult: true);
        for (final row in rows) {
          if (!row.containsKey('participants')) continue;
          if (row['type'] != 'DIALOG') continue;
          final accountId = row['account_id'];
          final chatId = row['id'];
          if (accountId is! int || chatId is! int) continue;
          await txn.delete(
            'chat_participants',
            where: 'account_id = ? AND chat_id = ?',
            whereArgs: [accountId, chatId],
          );
          for (final pid in _participantIdsFromRaw(row['participants'])) {
            await txn.insert('chat_participants', {
              'account_id': accountId,
              'chat_id': chatId,
              'participant_id': pid,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      });
    } catch (e) {
      logger.e("Ошибка при сохранении чата: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> loadChat(
    int accountId,
    int chatId,
  ) async {
    final db = await _instance;
    return db.query(
      'chats_cache',
      where: 'account_id = ? AND id = ?',
      whereArgs: [accountId, chatId],
      orderBy: 'last_event_time DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> loadChats(
    int accountId, {
    bool includeHidden = false,
  }) async {
    final db = await _instance;
    return db.query(
      'chats_cache',
      where: includeHidden
          ? 'account_id = ? AND in_list IN (1, 2)'
          : 'account_id = ? AND in_list = 1',
      whereArgs: [accountId],
      orderBy: 'last_event_time DESC',
    );
  }

  static Future<int> sumUnread(
    int accountId, {
    int? excludeChatId,
    Set<int>? excludeChatIds,
  }) async {
    final db = await _instance;
    final buffer = StringBuffer('account_id = ? AND in_list = 1');
    final args = <Object?>[accountId];
    if (excludeChatId != null) {
      buffer.write(' AND id != ?');
      args.add(excludeChatId);
    }
    if (excludeChatIds != null && excludeChatIds.isNotEmpty) {
      final placeholders = List.filled(excludeChatIds.length, '?').join(', ');
      buffer.write(' AND id NOT IN ($placeholders)');
      args.addAll(excludeChatIds);
    }
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(unread_count), 0) AS total '
      'FROM chats_cache WHERE $buffer',
      args,
    );
    return (result.first['total'] as int?) ?? 0;
  }

  static Future<int?> findDialogChatByParticipant(
    int accountId,
    int contactId,
  ) async {
    final db = await _instance;
    final rows = await db.rawQuery(
      'SELECT p.chat_id AS id FROM chat_participants p '
      'JOIN chats_cache c ON c.id = p.chat_id AND c.account_id = p.account_id '
      "WHERE p.account_id = ? AND p.participant_id = ? AND c.type = 'DIALOG' "
      'LIMIT 1',
      [accountId, contactId],
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  static Future<List<Map<String, dynamic>>> loadDialogChats(
    int accountId,
  ) async {
    final db = await _instance;
    return db.query(
      'chats_cache',
      where: "account_id = ? AND type = 'DIALOG'",
      whereArgs: [accountId],
    );
  }

  static String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  static Future<List<Map<String, dynamic>>> searchContacts(
    int accountId,
    String query, {
    int limit = 30,
  }) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    final db = await _instance;
    final like = '%${_escapeLike(term)}%';
    return db.query(
      'contacts',
      where:
          'account_id = ? AND '
          "(first_name LIKE ? ESCAPE '\\' OR last_name LIKE ? ESCAPE '\\' "
          "OR CAST(phone AS TEXT) LIKE ? ESCAPE '\\')",
      whereArgs: [accountId, like, like, like],
      orderBy: 'first_name ASC, last_name ASC',
      limit: limit,
    );
  }

  static Future<List<Map<String, dynamic>>> searchChatsByTitle(
    int accountId,
    String query, {
    int limit = 30,
  }) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    final db = await _instance;
    final like = '%${_escapeLike(term)}%';
    return db.query(
      'chats_cache',
      where: "account_id = ? AND title LIKE ? ESCAPE '\\'",
      whereArgs: [accountId, like],
      orderBy: 'last_event_time DESC',
      limit: limit,
    );
  }

  static Future<List<Map<String, dynamic>>> loadChatsByIds(
    int accountId,
    List<int> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final db = await _instance;
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.query(
      'chats_cache',
      where: 'account_id = ? AND id IN ($placeholders)',
      whereArgs: [accountId, ...ids],
    );
  }

  static Future<void> deleteChat(int chatId, int accountId) async {
    final db = await _instance;
    await db.delete(
      'chats_cache',
      where: 'id = ? AND account_id = ?',
      whereArgs: [chatId, accountId],
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
    bool onlyVisible = false,
  }) async {
    final db = await _instance;
    return db.query(
      'messages',
      where: onlyVisible
          ? 'account_id = ? AND chat_id = ? AND deleted = 0'
          : 'account_id = ? AND chat_id = ?',
      whereArgs: [accountId, chatId],
      orderBy: 'time DESC',
      limit: limit,
      offset: offset,
    );
  }

  static Future<List<Map<String, dynamic>>> loadMessagesBefore(
    int accountId,
    int chatId, {
    required int beforeTime,
    int limit = 30,
    bool onlyVisible = false,
  }) async {
    final db = await _instance;
    return db.query(
      'messages',
      where: onlyVisible
          ? 'account_id = ? AND chat_id = ? AND deleted = 0 AND time < ?'
          : 'account_id = ? AND chat_id = ? AND time < ?',
      whereArgs: [accountId, chatId, beforeTime],
      orderBy: 'time DESC',
      limit: limit,
    );
  }

  static Future<void> markMessageDeleted(
    int accountId,
    int chatId,
    String messageId,
  ) async {
    final db = await _instance;
    await db.update(
      'messages',
      {'deleted': 1},
      where: 'account_id = ? AND chat_id = ? AND id = ?',
      whereArgs: [accountId, chatId, messageId],
    );
  }

  static Future<void> markMessagesDeleted(
    int accountId,
    int chatId,
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return;
    final db = await _instance;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in messageIds) {
        batch.update(
          'messages',
          {'deleted': 1},
          where: 'account_id = ? AND chat_id = ? AND id = ?',
          whereArgs: [accountId, chatId, id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<void> clearMessages(int accountId, int chatId) async {
    final db = await _instance;
    await db.delete(
      'messages',
      where: 'account_id = ? AND chat_id = ?',
      whereArgs: [accountId, chatId],
    );
  }

  static Future<List<Map<String, dynamic>>> loadMessagesByIds(
    int accountId,
    int chatId,
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return const [];
    final db = await _instance;
    final placeholders = List.filled(messageIds.length, '?').join(',');
    return db.query(
      'messages',
      where: 'account_id = ? AND chat_id = ? AND id IN ($placeholders)',
      whereArgs: [accountId, chatId, ...messageIds],
    );
  }

  static Future<Map<String, dynamic>?> loadMessage(
    int accountId,
    int chatId,
    String messageId,
  ) async {
    final db = await _instance;
    final rows = await db.query(
      'messages',
      where: 'account_id = ? AND chat_id = ? AND id = ?',
      whereArgs: [accountId, chatId, messageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<void> deleteMessage(
    int accountId,
    int chatId,
    String messageId,
  ) async {
    final db = await _instance;
    await db.delete(
      'messages',
      where: 'account_id = ? AND chat_id = ? AND id = ?',
      whereArgs: [accountId, chatId, messageId],
    );
  }

  static Future<List<Map<String, dynamic>>> loadPendingMessages(
    int accountId,
  ) async {
    final db = await _instance;
    return db.query(
      'messages',
      where: 'account_id = ? AND status = ?',
      whereArgs: [accountId, 'pending'],
      orderBy: 'time ASC',
    );
  }
}
