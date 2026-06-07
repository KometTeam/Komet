import '../api.dart';
import '../../core/protocol/opcode_map.dart';

class WebAppLaunch {
  final String url;

  const WebAppLaunch({required this.url});
}

class WebAppModule {
  static const int sferumBotId = 2340319;

  final Api _api;

  WebAppModule(this._api);

  Future<WebAppLaunch> fetchLaunch(int botId) async {
    if (_api.state != SessionState.online) {
      throw const WebAppUnavailable('Нет соединения с сервером');
    }
    final packet = await _api.sendRequest(Opcode.webAppInitData, {
      'botId': botId,
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

  Future<WebAppLaunch> fetchSferum() => fetchLaunch(sferumBotId);
}

class WebAppUnavailable implements Exception {
  final String message;

  const WebAppUnavailable(this.message);

  @override
  String toString() => message;
}
