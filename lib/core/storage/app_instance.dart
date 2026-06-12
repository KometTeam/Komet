class AppInstance {
  AppInstance._();

  static const String id = String.fromEnvironment('KOMET_INSTANCE');

  static bool get isNamed => id.isNotEmpty;

  static String get suffix => isNamed ? '_$id' : '';
}
