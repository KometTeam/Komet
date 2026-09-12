import 'dart:io';

// #***! язык по дефолту если системный не определили
const String defaultLanguageCode = 'ru';

final RegExp _languageSubtag = RegExp(r'^[a-z]{2,3}$');

// #***! из ru_RU.UTF-8 достаём только ru
String languageCodeOf(String localeName) {
  final subtag = localeName
      .split(RegExp(r'[.@]'))
      .first
      .split(RegExp(r'[-_]'))
      .first
      .toLowerCase();
  return _languageSubtag.hasMatch(subtag) ? subtag : defaultLanguageCode;
}

// #***! на линуксе локаль не читаем, она там часто мусорная
String deviceLanguageCode() {
  if (Platform.isLinux) return defaultLanguageCode;
  try {
    return languageCodeOf(Platform.localeName);
  } catch (_) {
    return defaultLanguageCode;
  }
}
