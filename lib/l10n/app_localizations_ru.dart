// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get loginTitle => 'Войдите в Komet';

  @override
  String get loginSubtitle =>
      'Проверьте код страны и введите свой\nномер телефона.';

  @override
  String get loginCountry => 'Страна';

  @override
  String get loginPhoneNumber => 'Номер телефона';

  @override
  String get loginPhoneHint => '(000) 000-00-00';

  @override
  String get loginOtherSignInMethods => 'Другие способы входа';

  @override
  String get loginTermsIntro => 'Продолжая, вы соглашаетесь с \n';

  @override
  String get loginTermsLink => 'пользовательскими соглашениями';

  @override
  String get loginTermsOfUse => 'Условия использования';

  @override
  String get loginConfirmPhoneTitle => 'Это правильный номер?';

  @override
  String get loginEdit => 'Изменить';

  @override
  String get loginDone => 'Готово';

  @override
  String get loginReadTermsNotification =>
      'Сначала прочитайте условия использования';

  @override
  String get loginSpoofRedacted => 'Подделка спуфа';

  @override
  String get loginProxy => 'Прокси';

  @override
  String get loginSignInWithQr => 'По QR code';

  @override
  String get loginSignInWithToken => 'По токену';

  @override
  String get loginSignInWithSessionFile => 'По файлу сессии';

  @override
  String get loginLanguage => 'Язык';

  @override
  String get languageNameRu => 'Русский';

  @override
  String get languageNameEn => 'English';

  @override
  String get selectCountryTitle => 'Выберите страну';

  @override
  String get selectCountrySearchHint => 'Поиск страны…';

  @override
  String get codeConfirmationSmsSent =>
      'Мы отправили SMS с кодом подтверждения на ваш номер телефона.';

  @override
  String codeResendInSeconds(int seconds) {
    return 'Отправить повторно через $seconds сек.';
  }

  @override
  String get codeResendSms => 'Отправить код по SMS';

  @override
  String get codeError2faMissing => 'Ошибка: отсутствуют данные для 2FA';
}
