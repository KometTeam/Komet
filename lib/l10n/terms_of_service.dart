import 'package:flutter/widgets.dart';

import 'tos_en.dart';
import 'tos_ru.dart';

String termsOfServiceBody(Locale locale) {
  if (locale.languageCode == 'ru') {
    return kTermsOfServiceRu;
  }
  return kTermsOfServiceEn;
}
