import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_phonebook_names.dart';

class DeviceContactsService {
  DeviceContactsService._();

  static const _grantedKey = 'phonebook_granted';
  static const _deniedKey = 'phonebook_denied';

  static final Map<String, String> _byLast10 = {};
  static bool _loaded = false;

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  static String? _last10(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return null;
    return digits.substring(digits.length - 10);
  }

  static String? nameForPhone(int phone) {
    if (!AppPhonebookNames.current.value) return null;
    if (_byLast10.isEmpty) return null;
    final key = _last10(phone.toString());
    if (key == null) return null;
    final name = _byLast10[key];
    if (name == null || name.trim().isEmpty) return null;
    return name.trim();
  }

  static Future<void> loadFromStartup() async {
    if (_loaded || !_supported) return;
    if (!AppPhonebookNames.current.value) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_grantedKey) != true) return;
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) return;
    await _readBook();
  }

  static Future<bool> ensureLoadedInteractive({bool force = false}) async {
    if (_loaded || !_supported) return false;
    if (!AppPhonebookNames.current.value) return false;
    final prefs = await SharedPreferences.getInstance();
    if (!force && prefs.getBool(_deniedKey) == true) return false;
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      await prefs.setBool(_deniedKey, true);
      return false;
    }
    await prefs.remove(_deniedKey);
    await prefs.setBool(_grantedKey, true);
    return _readBook();
  }

  static Future<bool> reload() async {
    _loaded = false;
    _byLast10.clear();
    return ensureLoadedInteractive(force: true);
  }

  static Future<bool> _readBook() async {
    try {
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
      return _byLast10.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
