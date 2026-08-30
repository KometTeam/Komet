// #***! имя копии приложения из --dart-define, чтоб держать несколько установок раздельно
class AppInstance {
  AppInstance._();

  static const String id = String.fromEnvironment('KOMET_INSTANCE');

  static bool get isNamed => id.isNotEmpty;

  static String get suffix => isNamed ? '_$id' : '';
}
