import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';

abstract class EntryBannerApps {
  static const String sferumKey = 'entry_banner_app_sferum';
  static const String digitalIdKey = 'entry_banner_app_digital_id';

  static const Map<String, String> iconMatchers = {
    sferumKey: 'sferum',
    digitalIdKey: 'digital',
  };
}

class WebAppLaunch {
  final String url;

  const WebAppLaunch({required this.url});
}

class WebAppModule {
  final Api _api;

  WebAppModule(this._api);

  Future<WebAppLaunch> fetchLaunch(
    int botId, {
    String? startParam,
    int? chatId,
  }) async {
    if (_api.state != SessionState.online) {
      throw const WebAppUnavailable('Нет соединения с сервером');
    }
    final packet = await _api.sendRequest(Opcode.webAppInitData, {
      'botId': botId,
      'startParam': ?startParam,
      'chatId': ?chatId,
    });
    if (!packet.isOk) {
      throw const WebAppUnavailable('Не удалось открыть мини-приложение');
    }
    final data = packet.payload;
    final url = (data is Map) ? data['url'] as String? : null;
    if (url == null || url.isEmpty) {
      throw const WebAppUnavailable('Сервер не вернул адрес приложения');
    }
    return WebAppLaunch(url: url);
  }

  Future<WebAppLaunch> fetchSferum() async {
    final botId = await _resolveEntryApp(EntryBannerApps.sferumKey);
    if (botId == null) {
      throw const WebAppUnavailable(
        'Сферум сейчас недоступен. Переподключитесь и попробуйте снова.',
      );
    }
    return fetchLaunch(botId);
  }

  Future<WebAppLaunch> fetchDigitalId() async {
    final botId = await _resolveEntryApp(EntryBannerApps.digitalIdKey);
    if (botId == null) {
      throw const WebAppUnavailable(
        'Цифровой ID сейчас недоступен. Переподключитесь и попробуйте снова.',
      );
    }
    return fetchLaunch(botId);
  }

  Future<int?> _resolveEntryApp(String key) async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return null;
    final raw = await AppDatabase.getSyncValue(accountId, key);
    return int.tryParse(raw ?? '');
  }
}

class WebAppUnavailable implements Exception {
  final String message;

  const WebAppUnavailable(this.message);

  @override
  String toString() => message;
}
