import 'dart:async';
import 'dart:math';

import '../../core/contacts/device_contacts_service.dart';
import '../../core/contacts/phonebook_entry.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/logger.dart';
import '../api.dart';
import 'contacts.dart';

// #***! ответ SYNC: кого сервер нашёл и какой номер в какой id ушёл
class PhonebookSyncResult {
  final Map<dynamic, dynamic> raw;
  final List<CachedContact> contacts;
  final Map<String, int> phones;

  const PhonebookSyncResult({
    required this.raw,
    this.contacts = const [],
    this.phones = const {},
  });

  factory PhonebookSyncResult.fromPayload(
    Map<dynamic, dynamic> payload,
    int accountId,
  ) {
    final contacts = payload['contacts'];
    final phones = payload['phones'];
    return PhonebookSyncResult(
      raw: payload,
      contacts: [
        if (contacts is List)
          for (final contact in contacts.whereType<Map>())
            ?ContactsModule.contactFromServer(contact, accountId),
      ],
      phones: {
        if (phones is Map)
          for (final MapEntry(:key, :value) in phones.entries)
            if (value is int) key.toString(): value,
      },
    );
  }
}

// #***! телефонная книга на сервер как в MAX: SYNC (21) с contactList по 100
// номеров, в ответе contacts это кто нашёлся, phones это номер -> id
class PhonebookSync {
  PhonebookSync(this._api) {
    DeviceContactsService.revision.addListener(_schedule);
  }

  static const _batchSize = 100;

  final Api _api;
  int? _accountId;
  Future<void>? _running;
  bool _rerun = false;

  void start(int accountId) {
    _accountId = accountId;
    _schedule();
  }

  void stop() => _accountId = null;

  // #***! дев-меню: одна запись тем же путём что из книги, ответ наружу
  Future<PhonebookSyncResult> sendManual(PhonebookEntry entry) async {
    final accountId = _accountId;
    if (accountId == null) throw StateError('Нет активного аккаунта');
    final payload = await _send([entry], accountId);
    return PhonebookSyncResult.fromPayload(payload, accountId);
  }

  // #***! один прогон за раз, запрос во время прогона даёт ещё один после
  void _schedule() {
    if (_running != null) {
      _rerun = true;
      return;
    }
    _rerun = false;
    _running = _runOnce().whenComplete(() {
      _running = null;
      if (_rerun) _schedule();
    });
  }

  Future<void> _runOnce() async {
    final accountId = _accountId;
    if (accountId == null || !DeviceContactsService.isLoaded) return;
    if (_api.state != SessionState.online) return;
    try {
      await _sync(accountId);
    } catch (e) {
      logger.w('Телефонная книга: синк не удался: $e');
    }
  }

  // #***! шлём только новое и переименованное, пропавшие из книги забываем
  Future<void> _sync(int accountId) async {
    final book = DeviceContactsService.entries;
    final sent = await AppDatabase.loadSyncedPhonebook(accountId);
    await AppDatabase.forgetPhonebookPhones(
      accountId,
      sent.keys.where((phone) => !book.containsKey(phone)).toList(),
    );
    final pending = [
      for (final entry in book.values)
        if (sent[entry.phone] != entry) entry,
    ];
    if (pending.isEmpty) return;
    logger.i(
      'Телефонная книга: отправляю ${pending.length} номеров (акк $accountId)',
    );

    for (var i = 0; i < pending.length; i += _batchSize) {
      if (_accountId != accountId) return;
      final batch = pending.sublist(i, min(i + _batchSize, pending.length));
      await _send(batch, accountId);
      await AppDatabase.markPhonebookSynced(accountId, batch);
    }
  }

  Future<Map<dynamic, dynamic>> _send(
    List<PhonebookEntry> batch,
    int accountId,
  ) async {
    final packet = await _api.sendRequest(Opcode.sync, {
      'contactList': {for (final entry in batch) entry.phone: entry.toWire()},
    }, silent: true);
    final payload = packet.payload;
    if (payload is! Map) return const {};
    await _applyResult(payload, accountId);
    return payload;
  }

  // #***! свой номер в книге сервер тоже вернёт, себя в контакты не кладём
  Future<void> _applyResult(
    Map<dynamic, dynamic> payload,
    int accountId,
  ) async {
    final phones = payload['phones'];
    final contacts = payload['contacts'];
    final found = contacts is List
        ? contacts.whereType<Map>().where((c) => c['id'] != accountId).toList()
        : const <Map>[];
    logger.i(
      'Телефонная книга: на сервере ${phones is Map ? phones.length : 0} '
      'номеров, контактов ${found.length}',
    );
    if (found.isEmpty) return;
    await ContactsModule.applyPartialContactList({
      'contacts': found,
    }, accountId);
  }
}
