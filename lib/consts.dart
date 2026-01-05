export 'app_durations.dart';
export 'app_sizes.dart';
export 'app_urls.dart';
export 'app_colors.dart';
import 'package:flutter/material.dart';

const String appVersion = "0.4.1";

const String appName = "Komet";

/// Лимиты
class AppLimits {
  AppLimits._();

  /// Спустя сколько времени нельзя редактировать сообщение
  static const int messageEditHours = 6969;

  /// Количество сообщений ГОСТ
  static const int pageSize = 100;

  /// при оптимизированной загрузки
  static const int optimizedPageSize = 50;

  /// Сделайте кто небудь плагин на ультра оптимизацию пжпжп
  static const int ultraOptimizedPageSize = 10;

  /// Подгрузка истории
  static const int historyLoadBatch = 30;

  /// Максимальное количество недавних эмодзи в панели вот этой вот как ее
  static const int maxRecentEmoji = 20;

  static const int maxLogPayloadLength = 30000;
}

class AppSettings {
  AppSettings._();
  // у меня блять кеш не чиститься на линухе // А БЛЯЯЯ Я ДЕБИЛ ЭТО СЕРЕГА НЕ ДОБАВИЛ В НОТИФИКАТЕ
  static const bool startFresh = false;
}

class AppAnimationValues {
  AppAnimationValues._();

  /// Новое сообщение в чате анимаиця скок по Y
  static const double newMessageSlideOffset = 30.0;

  /// прозрачность подсветки когда ищешь соо начальная
  static const double highlightOpacityStart = 0.3;

  /// прозрачность подсветки когда ищешь соо начальная кнечаня
  static const double highlightOpacityEnd = 0.6;
}

class AppColors {
  AppColors._();

  /// комет свг колор
  static const Color kometSvgColor = Color(0xFFE1BEE7);
}
