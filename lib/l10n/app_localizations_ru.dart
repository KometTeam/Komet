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
  String get loginSpoofRedacted => 'Подмена данных';

  @override
  String get loginProxy => 'Прокси';

  @override
  String get loginChangeServer => 'Смена сервера';

  @override
  String get serverSettingsTitle => 'Сервер';

  @override
  String get serverHostLabel => 'Хост';

  @override
  String get serverPortLabel => 'Порт';

  @override
  String get serverApply => 'Применить и переподключиться';

  @override
  String get serverUseDefault => 'Сбросить к умолчанию';

  @override
  String get serverInvalidHostOrPort =>
      'Укажите корректный хост и порт (1–65535)';

  @override
  String get serverSettingsSaved => 'Настройки сервера применены';

  @override
  String get serverReconnectFailed => 'Не удалось подключиться к серверу';

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

  @override
  String get proxySettingsTitle => 'Прокси';

  @override
  String get proxyTypeNone => 'Выключен';

  @override
  String get proxyTypeSocks5 => 'SOCKS5';

  @override
  String get proxyTypeHttp => 'HTTP(S)';

  @override
  String get proxyHostLabel => 'Хост прокси';

  @override
  String get proxyPortLabel => 'Порт прокси';

  @override
  String get proxyUsernameLabel => 'Логин (необязательно)';

  @override
  String get proxyPasswordLabel => 'Пароль (необязательно)';

  @override
  String get proxyApply => 'Применить и переподключиться';

  @override
  String get proxyDisable => 'Отключить прокси';

  @override
  String get proxySettingsSaved => 'Настройки прокси применены';

  @override
  String get proxyInvalidHostOrPort =>
      'Укажите корректный хост и порт прокси (1–65535)';

  @override
  String get spoofScreenTitle => 'Подмена данных сессии';

  @override
  String get spoofInfoHint =>
      'Нажмите \"Сгенерировать\":\n• Короткое нажатие: случайный пресет.\n• Длинное нажатие: реальные данные.';

  @override
  String get spoofMethodTitle => 'Метод подмены';

  @override
  String get spoofMethodPartial => 'Частичный';

  @override
  String get spoofMethodFull => 'Полный';

  @override
  String get spoofMethodPartialDescription =>
      'Рекомендуемый метод. Используются случайные данные, но ваш реальный часовой пояс и локаль для большей правдоподобности.';

  @override
  String get spoofMethodFullDescription =>
      'Все данные, включая часовой пояс и локаль, генерируются случайно. Использование этого метода на ваш страх и риск!';

  @override
  String get spoofDeviceTypeTitle => 'Тип устройства';

  @override
  String get spoofDeviceTypeDescription =>
      'Данное поле не изменяемое, во избежании проблем с ассоциацией токена';

  @override
  String get spoofDeviceTypeLabel => 'Тип устройства';

  @override
  String get spoofMainSectionTitle => 'Основные данные';

  @override
  String get spoofFieldDeviceName => 'Имя устройства';

  @override
  String get spoofFieldOsVersion => 'Версия ОС';

  @override
  String get spoofRegionalSectionTitle => 'Региональные данные';

  @override
  String get spoofFieldScreen => 'Разрешение экрана';

  @override
  String get spoofFieldTimezone => 'Часовой пояс';

  @override
  String get spoofFieldLocale => 'Локаль';

  @override
  String get spoofIdentifiersSectionTitle => 'Идентификаторы';

  @override
  String get spoofIdentifiersDescription =>
      'mt_instanceid и clientSessionId генерируются автоматически при каждом запуске приложения. Изменить можно только Device ID.';

  @override
  String get spoofFieldDeviceId => 'ID Устройства';

  @override
  String get spoofRegenerateIdTooltip => 'Сгенерировать новый ID';

  @override
  String get spoofFieldAppVersion => 'Версия приложения';

  @override
  String get spoofFieldBuildNumber => 'Build Number';

  @override
  String get spoofFieldArchitecture => 'Архитектура';

  @override
  String get spoofButtonGenerate => 'Сгенерировать';

  @override
  String get spoofButtonApply => 'Применить';

  @override
  String get spoofDialogUnsureTitle => 'Ты уверен?';

  @override
  String get spoofDialogUnsureContent =>
      'Приложение может начать работать нестабильно из-за несовместимости API';

  @override
  String get spoofDialogCancel => 'Отмена';

  @override
  String get spoofDialogYes => 'Да';

  @override
  String get spoofDialogApplyTitle => 'Применить настройки?';

  @override
  String get spoofDialogApplyContent => 'Нужно перезайти в приложение, ок?';

  @override
  String get spoofDialogApplyWarning =>
      'Ваш спуф изменится сразу. Но из-за особенностей МАХ, для того что-бы это стало заметно, вы должны перелогиниться в аккаунт';

  @override
  String get spoofDialogReloginTitle => 'Готово!';

  @override
  String get spoofDialogReloginContent =>
      'Из-за особенности МАХ, ваш спуф изменён, но видны изменения будут только при перезаходе в аккаунт.';

  @override
  String get spoofDialogReloginWarning => 'Перезайти сейчас?';

  @override
  String get spoofDialogReloginDeny => 'Позже';

  @override
  String get spoofDialogReloginConfirm => 'Перелогиниться сейчас';

  @override
  String get spoofDialogApplyDeny => 'Не';

  @override
  String get spoofDialogApplyConfirm => 'Ок!';

  @override
  String spoofErrorApplyFailed(String error) {
    return 'Ошибка при применении настроек: $error';
  }

  @override
  String get profileMenuSpoof => 'Подмена данных';
}
