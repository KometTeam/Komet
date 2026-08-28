import 'dart:io';

const String defaultLanguageCode = 'ru';

final RegExp _languageSubtag = RegExp(r'^[a-z]{2,3}$');

String languageCodeOf(String localeName) {
  final subtag = localeName
      .split(RegExp(r'[.@]'))
      .first
      .split(RegExp(r'[-_]'))
      .first
      .toLowerCase();
  return _languageSubtag.hasMatch(subtag) ? subtag : defaultLanguageCode;
}

String deviceLanguageCode() {
  if (Platform.isLinux) return defaultLanguageCode;
  try {
    return languageCodeOf(Platform.localeName);
  } catch (_) {
    return defaultLanguageCode;
  }
}
