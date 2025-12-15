import 'dart:convert';
import 'dart:io';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/app_urls.dart';
import 'package:http/http.dart' as http;

class WhitelistService {
  static final WhitelistService _instance = WhitelistService._internal();
  factory WhitelistService() => _instance;
  WhitelistService._internal();

  bool _enabled = false;

  bool get isEnabled => _enabled;

  Future<void> loadWhitelist() async {
    try {
      final file = await _getWhitelistFile();
      if (!await file.exists()) {
        _enabled = false;
        return;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      _enabled = json['cumlist'] == true;
    } catch (e) {
      _enabled = false;
    }
  }

  Future<File> _getWhitelistFile() async {
    return File('whitelist.json');
  }

  Future<void> validateCurrentUserIfNeeded() async {
    if (!_enabled) return;

    final idStr = ApiService.instance.userId;
    final int? id = idStr != null ? int.tryParse(idStr) : null;

    if (id == null) {
      return;
    }

    await checkAndValidate(id);
  }

  Future<bool> checkAndValidate(int? userId) async {
    if (!_enabled) return true;

    if (userId == null) {
      return false;
    }

    try {
      final url = Uri.parse('${AppUrls.whitelistCheckUrl}?id=$userId');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final isWhitelisted = json['wl'] == true;

        if (!isWhitelisted) {
          await ApiService.instance.logout();
        }

        return isWhitelisted;
      } else {
        await ApiService.instance.logout();
        return false;
      }
    } catch (e) {
      await ApiService.instance.logout();
      return false;
    }
  }
}
