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

const Set<String> kMiniAppOptions = {'HAS_WEBAPP', 'HAS_WEB_APP', 'WEBAPP'};

bool hasMiniAppOption(Set<String>? options) =>
    options != null && options.any(kMiniAppOptions.contains);

class WebAppLaunch {
  final String url;

  const WebAppLaunch({required this.url});
}

class ExternalCallbackResult {
  final int botId;
  final String? startParam;

  const ExternalCallbackResult({required this.botId, this.startParam});

  static ExternalCallbackResult? fromPayload(dynamic payload) {
    final data = _findResponseMap(payload);
    if (data == null) return null;
    final botId = _asInt(data['botId'] ?? data['bot_id']);
    if (botId == null) return null;
    final startParam = data['startParam'] ?? data['start_param'];
    return ExternalCallbackResult(
      botId: botId,
      startParam: startParam?.toString(),
    );
  }

  static Map? _findResponseMap(dynamic value) {
    if (value is! Map) return null;
    if (value.containsKey('botId') || value.containsKey('bot_id')) return value;
    for (final key in const ['data', 'result', 'response']) {
      final nested = _findResponseMap(value[key]);
      if (nested != null) return nested;
    }
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
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

  Future<WebAppLaunch> handleExternalCallback(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.queryParameters['externalCallback'] != '1') {
      throw const WebAppUnavailable('Некорректный callback Цифрового ID');
    }
    if (_api.state != SessionState.online) {
      throw const WebAppUnavailable('Нет соединения с сервером');
    }
    final packet = await _api.sendRequest(Opcode.externalCallback, {
      'url': url,
    });
    final result = ExternalCallbackResult.fromPayload(packet.payload);
    if (result == null) {
      throw const WebAppUnavailable(
        'Сервер не вернул данные для завершения Цифрового ID',
      );
    }
    return fetchLaunch(result.botId, startParam: result.startParam);
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
