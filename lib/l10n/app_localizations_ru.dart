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
  String get tokenLoginTitle => 'Вход по токену';

  @override
  String get tokenLoginTokenLabel => 'Токен';

  @override
  String get tokenLoginNote =>
      'Вход по токену работает только со спуфом. Укажите данные устройства, к которому привязан токен, иначе аккаунт могут заблокировать.';

  @override
  String get tokenLoginButton => 'Войти';

  @override
  String get tokenLoginError =>
      'Заполните токен, имя устройства, версию ОС и Device ID';

  @override
  String get tokenLoginFailed => 'Не удалось войти';

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
  String get codeConfirmation2faWarning =>
      'MAX может требовать 2FA на вашем аккаунте для входа. Если вы не получили код — установите 2FA с клиента, на котором вы авторизованы.';

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
  String get spoofEnableTitle => 'Подмена устройства';

  @override
  String get spoofEnableSubtitleOn => 'Включена для этого аккаунта';

  @override
  String get spoofEnableSubtitleOff =>
      'Выключена — используется реальное устройство';

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
      'Определяет, какие устройства генерируются: Android или iOS';

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
  String get spoofFieldDeviceLocale => 'Системная локаль (производная)';

  @override
  String get spoofIdentifiersSectionTitle => 'Идентификаторы';

  @override
  String get spoofIdentifiersDescription =>
      'mt_instanceid и clientSessionId генерируются автоматически при каждом запуске приложения. Изменить можно только Device ID.';

  @override
  String get spoofFieldInstanceId => 'mt_instanceid';

  @override
  String get spoofFieldClientSessionId => 'clientSessionId';

  @override
  String get spoofFieldPushDeviceType => 'Тип push-уведомлений';

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

  @override
  String get infoTitle => 'Info';

  @override
  String get infoAccountSection => 'Аккаунт';

  @override
  String get infoServerSection => 'Сервер';

  @override
  String get infoUserSection => 'Пользователь';

  @override
  String get infoYMapSection => 'Y-Map';

  @override
  String get infoFileUploadTypes => 'запрещённые типы файлов';

  @override
  String get infoWhiteListLinks => 'безопасные ссылки';

  @override
  String get infoRegistrationTime => 'Дата регистрации:';

  @override
  String get infoCountry => 'Регион аккаунта:';

  @override
  String get infoVideoChatHistory => 'videoChatHistory';

  @override
  String get infoUpdateTime => 'Последнее обновление аватарки:';

  @override
  String get infoId => 'id аккаунта:';

  @override
  String get infoChatMarker => 'chatMarker';

  @override
  String get infoAccountRemovalEnabled => 'Мгновенное удаление аккаунта:';

  @override
  String get infoImageSize => 'image-size';

  @override
  String get infoGce => 'gce';

  @override
  String get infoGcce => 'gcce';

  @override
  String get infoMaxMsgLength => 'макс. длина сообщения:';

  @override
  String get infoQuotesEnabled => 'quotes-enabled';

  @override
  String get infoCallsEndpoint => 'calls-endpoint';

  @override
  String get infoSendLocationEnabled => 'отправка гео.:';

  @override
  String get infoLgce => 'lgce';

  @override
  String get infoWud => 'wud';

  @override
  String get infoVideoMsgEnabled => 'Кружки:';

  @override
  String get infoGrse => 'grse';

  @override
  String get infoEditTimeout => 'Можно редактировать сообщение в течении:';

  @override
  String get infoImageQuality => 'image-quality';

  @override
  String get infoUnsafeFilesAlert => 'unsafe-files-alert';

  @override
  String get infoAccountNicknameEnabled => 'account-nickname-enabled';

  @override
  String get infoMentionsEntityNamesLimit => 'макс. кол-во упоминаний:';

  @override
  String get infoReactionsEnabled => 'reactions-enabled';

  @override
  String get infoTile => 'tile';

  @override
  String get infoGeocoder => 'geocoder';

  @override
  String get infoStatic => 'static';

  @override
  String get chatInfoSubscribers => 'подписчиков:';

  @override
  String get chatInfoInvitedBy => 'Приглашён от:';

  @override
  String get chatInfoLink => 'ссылка:';

  @override
  String get chatInfoOfficial => 'оффициальный:';

  @override
  String get chatInfoComments => 'комментарии:';

  @override
  String get chatInfoAplus => 'подтверждён Роскомнадзором:';

  @override
  String get chatInfoSignAdmin => 'Подпись админов:';

  @override
  String get chatInfoLastChanged => 'последнее изменение:';

  @override
  String get chatInfoJoinTime => 'заход в канал:';

  @override
  String get chatInfoCreated => 'канал создан:';

  @override
  String get chatInfoTitle => 'Информация';

  @override
  String get chatInfoMembers => 'участников:';

  @override
  String get chatInfoLastSeen => 'был(а) недавно';

  @override
  String get chatInfoHasBots => 'Есть боты:';

  @override
  String get chatInfoBlockedCount => 'в ЧС группы:';

  @override
  String get chatInfoOfficialStatus => 'Официальный статус:';

  @override
  String get chatInfoJoined => 'Зашли в:';

  @override
  String get chatInfoGroupCreated => 'Группа создана в:';

  @override
  String get chatInfoGroupOwner => 'Создатель группы:';

  @override
  String get chatInfoDialogStarted => 'ЛС начат в:';

  @override
  String get editProfileTitle => 'Редактирование профиля';

  @override
  String get editProfileSave => 'Сохранить';

  @override
  String get editProfileFirstName => 'Имя';

  @override
  String get editProfileLastName => 'Фамилия';

  @override
  String get editProfileRemovePhoto => 'Удалить фото';

  @override
  String get registrationTitle => 'Создание профиля';

  @override
  String get registrationSubtitle => 'Укажите имя и выберите аватар';

  @override
  String get registrationChooseAvatar => 'Выберите аватар';
}
