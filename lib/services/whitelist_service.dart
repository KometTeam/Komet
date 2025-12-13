import 'dart:convert';
import 'dart:io';
import 'package:gwid/api/api_service.dart';

class WhitelistService {
  static final WhitelistService _instance = WhitelistService._internal();
  factory WhitelistService() => _instance;
  WhitelistService._internal();

  bool _enabled = false;
  final Set<int> _allowedUserIds = {};
  final Set<String> _allowedPhoneNumbers = {};

  bool get isEnabled => _enabled;
  Set<int> get allowedUserIds => Set.unmodifiable(_allowedUserIds);
  Set<String> get allowedPhoneNumbers => Set.unmodifiable(_allowedPhoneNumbers);

  Future<void> loadWhitelist() async {
    try {
      final file = await _getWhitelistFile();
      if (!await file.exists()) {
        _enabled = false;
        _allowedUserIds.clear();
        _allowedPhoneNumbers.clear();
        return;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      _enabled = json['cumlist'] == true;

      _allowedUserIds.clear();
      if (json['userIds'] != null) {
        final ids = (json['userIds'] as List)
            .map((e) => (e is int ? e : int.tryParse(e.toString())))
            .whereType<int>()
            .toList();
        _allowedUserIds.addAll(ids);
      }

      _allowedPhoneNumbers.clear();
      if (json['phoneNumbers'] != null) {
        final phonesList = json['phoneNumbers'] as List;
        for (var phoneEntry in phonesList) {
          final phoneStr = phoneEntry.toString().trim();
          if (phoneStr.isNotEmpty) {
            if (phoneStr.contains(',')) {
              final splitPhones = phoneStr.split(',');
              for (var splitPhone in splitPhones) {
                final normalizedSplit = _normalizePhone(splitPhone.trim());
                if (normalizedSplit.isNotEmpty) {
                  _allowedPhoneNumbers.add(normalizedSplit);
                }
              }
            } else {
              final normalized = _normalizePhone(phoneStr);
              if (normalized.isNotEmpty) {
                _allowedPhoneNumbers.add(normalized);
              }
            }
          }
        }
      }
    } catch (e) {
      _enabled = false;
      _allowedUserIds.clear();
      _allowedPhoneNumbers.clear();
    }
  }

  Future<File> _getWhitelistFile() async {
    final file = File('whitelist.json');
    return file;
  }

  bool isAllowed(int? userId, String? phoneNumber) {
    if (!_enabled) {
      return true;
    }

    if (userId != null && _allowedUserIds.contains(userId)) {
      return true;
    }

    if (phoneNumber != null) {
      final normalizedPhone = _normalizePhone(phoneNumber);
      if (_allowedPhoneNumbers.contains(normalizedPhone)) {
        return true;
      }
    }

    return false;
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  Future<bool> checkAndValidate(int? userId, String? phoneNumber) async {
    if (!_enabled) return true;

    final isAllowed = this.isAllowed(userId, phoneNumber);

    if (!isAllowed) {
      await ApiService.instance.logout();
    }

    return isAllowed;
  }
}
