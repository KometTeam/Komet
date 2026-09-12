import 'package:flutter/widgets.dart';

import '../core/config/build_profile.dart';
import 'tos_en.dart';
import 'tos_ru.dart';
import 'tos_store_en.dart';
import 'tos_store_ru.dart';

String termsOfServiceBody(Locale locale) {
  final russian = locale.languageCode == 'ru';
  if (BuildProfile.isStore) {
    return russian ? kTermsOfServiceStoreRu : kTermsOfServiceStoreEn;
  }
  return russian ? kTermsOfServiceRu : kTermsOfServiceEn;
}
