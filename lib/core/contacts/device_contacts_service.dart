import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_phonebook_names.dart';
import '../utils/logger.dart';

// #***! имена из телефонной книги вместо серверных
class DeviceContactsService {
  DeviceContactsService._();

  static const _deniedKey = 'phonebook_denied';

  // #***! ключ последние 10 цифр, чтоб +7 и 8 сошлись
  static final Map<String, String> _byLast10 = {};
  static bool _loaded = false;

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  static bool get isLoaded => _loaded;

  static int get knownNumbers => _byLast10.length;

  // #***! номер к последним 10 цифрам
  static String? _last10(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return null;
    return digits.substring(digits.length - 10);
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
    if (!AppPhonebookNames.current.value) return;
    if (!await hasPermission()) return;
    await _forgetDenial();
    await _readBook();
  }

  // #***! спрашиваем разрешение, отказ запоминаем
  static Future<bool> ensureLoadedInteractive({bool force = false}) async {
    if (!_supported) return false;
    if (!AppPhonebookNames.current.value) return false;
    if (_loaded && !force) return false;

    if (await hasPermission()) {
      await _forgetDenial();
      return _readBook();
    }

    final prefs = await SharedPreferences.getInstance();
    if (!force && prefs.getBool(_deniedKey) == true) return false;

    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      await prefs.setBool(_deniedKey, true);
      return false;
    }
    await prefs.remove(_deniedKey);
    return _readBook();
  }

  static Future<bool> reload() async {
    _loaded = false;
    _byLast10.clear();
    return ensureLoadedInteractive(force: true);
  }

  static Future<void> _forgetDenial() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_deniedKey) == true) await prefs.remove(_deniedKey);
  }

  // #***! дубли номера, берём первое имя
  static Future<bool> _readBook() async {
    try {
      FlutterContacts.config.includeNonVisibleOnAndroid = true;
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      _byLast10.clear();
      for (final contact in contacts) {
        final name = contact.displayName.trim();
        if (name.isEmpty) continue;
        for (final phone in contact.phones) {
          final key = _last10(phone.number);
          if (key != null) {
            _byLast10.putIfAbsent(key, () => name);
          }
        }
      }
      _loaded = true;
      logger.i(
        'Телефонная книга: прочитано ${contacts.length} записей, '
        '${_byLast10.length} номеров',
      );
      return true;
    } catch (e) {
      logger.w('Телефонная книга: не удалось прочитать: $e');
      return false;
    }
  }
}
