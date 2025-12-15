/// НЕ ТРОГАТЬ НАХУЙ пожалуйста
class AppUrls {
  AppUrls._();

  /// Вебсокеты
  /// вроде в ConnectionManager ConnectionManagerSimple ApiService
  static const List<String> websocketUrls = [
    'wss://ws-api.oneme.ru:443/websocket',
    'wss://ws-api.oneme.ru/websocket',
    'wss://ws-api.oneme.ru:8443/websocket',
    'ws://ws-api.oneme.ru:80/websocket',
    'ws://ws-api.oneme.ru/websocket',
    'ws://ws-api.oneme.ru:8080/websocket',
  ];

  ///не понятно
  static const String webOrigin = 'https://web.max.ru';

  /// Юзается на экране TOS, можно заменить на пiрно
  static const String legalUrl = 'https://legal.max.ru/ps';

  static const String telegramChannel = 'https://t.me/TeamKomet';

  ///для групп когда присоединиться хочеш
  static const String joinLinkPrefix = 'https://max.ru/join/';

  ///для поиска по айди, я все еще не ебу где эта функция
  static const String idLinkPrefix = 'https://max.ru/id';

  ///проверка вайтлиста для тестерских билдов
  ///Крякнуть как нехуй делать но кому не похуй??
  static const String whitelistCheckUrl = 'https://wl.liarts.ru/wl';
}
