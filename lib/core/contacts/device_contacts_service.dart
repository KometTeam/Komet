import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart'
    hide PermissionStatus;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_phonebook_names.dart';
import '../utils/logger.dart';
import 'phonebook_entry.dart';

// #***! телефонная книга: имена вместо серверных и номера для синка
class DeviceContactsService {
  DeviceContactsService._();

  static const _deniedKey = 'phonebook_denied';
  static const _minWireDigits = 7;
  static const _changeDebounce = Duration(seconds: 5);

  // #***! ключ последние 10 цифр, чтоб +7 и 8 сошлись
  static final Map<String, String> _byLast10 = {};
  static final Map<String, PhonebookEntry> _entries = {};
  static bool _loaded = false;
  static StreamSubscription<void>? _changes;
  static Timer? _changeTimer;

  // #***! растёт после каждого прочтения книги, на него подписан синк
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  static bool get isLoaded => _loaded;

  static int get knownNumbers => _byLast10.length;

  // #***! снимок, книга может перечитаться пока синк идёт
  static Map<String, PhonebookEntry> get entries => Map.of(_entries);

  // #***! номер к последним 10 цифрам
  static String? _last10(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return null;
    return digits.substring(digits.length - 10);
  }

  // #***! запись для SYNC: номер E.164 от андроида если есть, иначе цифры как
  // записаны; без имени шлём фамилию или сам номер
  static PhonebookEntry? entryFor({
    required String number,
    String? normalizedNumber,
    String first = '',
    String last = '',
    String displayName = '',
  }) {
    final normalized = normalizedNumber?.trim() ?? '';
    final raw = normalized.isNotEmpty ? normalized : number.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < _minWireDigits) return null;
    final phone = raw.startsWith('+') ? '+$digits' : digits;
    if (first.isNotEmpty) {
      return PhonebookEntry(
        phone: phone,
        firstName: first,
        lastName: last.isEmpty ? null : last,
      );
    }
    return PhonebookEntry(
      phone: phone,
      firstName: displayName.isNotEmpty ? displayName : phone,
    );
  }

  // #***! имя по номеру
  static String? nameForPhone(int phone) {
    if (!AppPhonebookNames.current.value) return null;
    if (_byLast10.isEmpty) return null;
    final key = _last10(phone.toString());
    if (key == null) return null;
    final name = _byLast10[key];
    if (name == null || name.trim().isEmpty) return null;
    return name.trim();
  }

  static Future<bool> hasPermission() async {
    if (!_supported) return false;
    try {
      return await Permission.contacts.isGranted;
    } catch (e) {
      logger.w('Телефонная книга: не удалось прочитать статус разрешения: $e');
      return false;
    }
  }

  // #***! на старте читаем только если разрешение уже есть
  static Future<void> loadFromStartup() async {
    if (_loaded || !_supported) return;
    if (!await hasPermission()) return;
    await _forgetDenial();
    await _readBook();
  }

  // #***! спрашиваем разрешение, отказ запоминаем
  static Future<bool> ensureLoadedInteractive({bool force = false}) async {
    if (!_supported) return false;
    if (_loaded && !force) return false;

    if (await hasPermission()) {
      await _forgetDenial();
      return _readBook();
    }

    final prefs = await SharedPreferences.getInstance();
    if (!force && prefs.getBool(_deniedKey) == true) return false;

    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      await prefs.setBool(_deniedKey, true);
      return false;
    }
    await prefs.remove(_deniedKey);
    return _readBook();
  }

  static Future<bool> reload() async {
    _loaded = false;
    _byLast10.clear();
    _entries.clear();
    return ensureLoadedInteractive(force: true);
  }

  static Future<void> _forgetDenial() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_deniedKey) == true) await prefs.remove(_deniedKey);
  }

  // #***! дубли номера, берём первое имя
  static Future<bool> _readBook() async {
    try {
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      _byLast10.clear();
      _entries.clear();
      for (final contact in contacts) {
        final name = contact.displayName?.trim() ?? '';
        final first = contact.name?.first?.trim() ?? '';
        final last = contact.name?.last?.trim() ?? '';
        for (final phone in contact.phones) {
          final key = _last10(phone.number);
          if (key != null && name.isNotEmpty) {
            _byLast10.putIfAbsent(key, () => name);
          }
          final entry = entryFor(
            number: phone.number,
            normalizedNumber: phone.normalizedNumber,
            first: first,
            last: last,
            displayName: name,
          );
          if (entry != null) _entries.putIfAbsent(entry.phone, () => entry);
        }
      }
      _loaded = true;
      _watchChanges();
      revision.value++;
      logger.i(
        'Телефонная книга: прочитано ${contacts.length} записей, '
        '${_byLast10.length} номеров, ${_entries.length} для синка',
      );
      return true;
    } catch (e) {
      logger.w('Телефонная книга: не удалось прочитать: $e');
      return false;
    }
  }

  // #***! правки в книге пачкой, одна перечитка на всю пачку
  static void _watchChanges() {
    _changes ??= FlutterContacts.onDatabaseChange.listen(
      (_) {
        _changeTimer?.cancel();
        _changeTimer = Timer(_changeDebounce, () => unawaited(_readBook()));
      },
      onError: (Object e) {
        logger.w('Телефонная книга: слушатель изменений упал: $e');
      },
    );
  }
}
