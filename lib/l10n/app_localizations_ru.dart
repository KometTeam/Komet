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
  String get serverTrustMincifryTitle => 'Доверять сертификату Минцифры';

  @override
  String get serverTrustMincifrySubtitle =>
      'Нужно для api2.oneme.ru: его сертификат выпущен под корнем Russian Trusted Root CA, которого нет в обычном хранилище. Корень зашит в приложение, остальные хосты проверяются как раньше.';

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
      'Вход по токену работает только со спуфом. Укажите данные устройства, к которому привязан токен, в противном случае он может быть отозван.';

  @override
  String get tokenLoginButton => 'Войти';

  @override
  String get tokenLoginError =>
      'Заполните токен, имя устройства, версию ОС и Device ID';

  @override
  String get tokenLoginFailed => 'Не удалось войти';

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
  String get codeErrorInvalid => 'Неверный код';

  @override
  String get codeConfirmation2faWarning =>
      'По умолчанию код приходит в МАХ. Если код не приходит по SMS - не заходите в Komet/MAX 30 минут, и попробуйте заново.';

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
      'Выключена. Используется реальное устройство';

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
      'Рекомендуемый метод. Используются случайные данные, но ваш реальный часовой пояс и локаль остаются настоящими для правдоподобности.';

  @override
  String get spoofMethodFullDescription =>
      'Все данные генерируются случайно. Будьте осторожны.';

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
  String get spoofDialogUnsureTitle => 'Уверен?';

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
  String get spoofDialogApplyWarning => 'Ваш спуф изменится сразу. 😜';

  @override
  String get spoofDialogReloginTitle => 'Готово!';

  @override
  String get spoofDialogReloginContent =>
      'Ваш спуф изменён, но в списке устройств видны изменения только при перезаходе в аккаунт.';

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
  String get infoTitle => 'Информация';

  @override
  String get infoAccountSection => 'Аккаунт';

  @override
  String get infoPacketSection => 'Пакет входа';

  @override
  String get infoChatsSection => 'Чаты в пакете входа';

  @override
  String get infoChatSettingsSection => 'Настройки отдельных чатов';

  @override
  String get infoServerSection => 'Сервер';

  @override
  String get infoUserSection => 'Пользователь';

  @override
  String get infoExperimentsSection => 'Эксперименты';

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
  String get infoPhone => 'Телефон:';

  @override
  String get infoPhotoId => 'id аватарки:';

  @override
  String get infoAccountStatus => 'Статус аккаунта:';

  @override
  String get infoContactOptions => 'Опции контакта:';

  @override
  String get infoProfileOptions => 'Опции профиля:';

  @override
  String get infoNames => 'Имена:';

  @override
  String get infoBaseUrl => 'Ссылка на аватарку:';

  @override
  String get infoBaseRawUrl => 'Исходная аватарка:';

  @override
  String get infoChatMarker => 'chatMarker';

  @override
  String get infoServerTime => 'Время сервера:';

  @override
  String get infoUpdates => 'Количество обновлений:';

  @override
  String get infoMessagesCount => 'Сообщений в пакете:';

  @override
  String get infoContactsCount => 'Контактов в пакете:';

  @override
  String get infoPresenceCount => 'Статусов присутствия:';

  @override
  String get infoConfigHash => 'Хеш конфигурации:';

  @override
  String get infoChatsCount => 'Загружено чатов:';

  @override
  String get infoChatsActive => 'Активных:';

  @override
  String get infoChatsHidden => 'Скрытых:';

  @override
  String get infoChatsDialogs => 'Диалогов:';

  @override
  String get infoChatsGroups => 'Групп:';

  @override
  String get infoChatsChannels => 'Каналов:';

  @override
  String get infoChatsUnread => 'Непрочитанных чатов:';

  @override
  String get infoChatsNewMessages => 'Новых сообщений:';

  @override
  String get infoChatsMessages => 'Сообщений в загруженных чатах:';

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
  String get commentsWrite => 'Комментировать';

  @override
  String get commentsTitle => 'Комментарии';

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count комментария',
      many: '$count комментариев',
      few: '$count комментария',
      one: '$count комментарий',
    );
    return '$_temp0';
  }

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
  String get editProfileBio => 'О себе';

  @override
  String get editProfileRemovePhoto => 'Удалить фото';

  @override
  String get registrationTitle => 'Создание профиля';

  @override
  String get registrationSubtitle => 'Укажите имя и выберите аватар';

  @override
  String get registrationChooseAvatar => 'Выберите аватар';

  @override
  String get msgActionsCopy => 'Копировать';

  @override
  String get msgActionsCopyLink => 'Скопировать ссылку';

  @override
  String get msgActionsSelectAll => 'Выбрать всё';

  @override
  String get emojiSearchHint => 'Поиск эмодзи';

  @override
  String get msgActionsEdit => 'Изменить';

  @override
  String get msgActionsReply => 'Ответить';

  @override
  String get msgActionsForward => 'Переслать';

  @override
  String get msgActionsMarkUnread => 'Непрочитанное';

  @override
  String get msgActionsPin => 'Закрепить';

  @override
  String get msgActionsUnpin => 'Открепить';

  @override
  String get pinnedMessageTitle => 'Закреплённое сообщение';

  @override
  String get msgActionsEditHistory => 'История изменений';

  @override
  String get msgActionsInfo => 'Info';

  @override
  String get msgActionsReadBy => 'Кем прочитано';

  @override
  String get msgActionsReadByEmpty => 'Пока никто не прочитал';

  @override
  String get msgActionsReadByUnknownUser => 'Пользователь';

  @override
  String get msgActionsReport => 'Пожаловаться';

  @override
  String get msgActionsDelete => 'Удалить';

  @override
  String get msgActionsCopied => 'Скопировано';

  @override
  String get msgActionsLoadReasonsFailed => 'Не удалось загрузить причины';

  @override
  String get msgActionsCurrentVersion => 'текущая версия';

  @override
  String msgActionsCurrentVersionWithDate(String date) {
    return 'текущая версия · $date';
  }

  @override
  String get msgActionsNoText => '(без текста)';

  @override
  String notificationsSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get notificationsFkmAlreadyHasFcm => 'А зачем? У тебя уже FCM.';

  @override
  String get notificationsFkmIosUnsupported =>
      'На iOS пуш-уведомления пока недоступны';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsFkmSectionTitle => 'Уведомления без Google (FKM)';

  @override
  String get notificationsFkmEnableLabel => 'Включить уведомления';

  @override
  String get notificationsFkmEnableSubtitle =>
      'Komet сам держит соединение с сервером и показывает уведомления. Пока это включено, в шторке висит служебное уведомление.';

  @override
  String get notificationsFkmUnsupported => 'FKM работает только на Android';

  @override
  String get notificationsFkmBatteryAction => 'Настроить';

  @override
  String get notificationsFkmBatteryMessage =>
      'Иначе система усыпит фоновое соединение, и уведомления начнут опаздывать или пропадать.';

  @override
  String get notificationsFkmBatteryTitle => 'Отключить экономию батареи?';

  @override
  String get notificationsFkmPermissionDenied =>
      'Без разрешения на уведомления FKM не заработает';

  @override
  String get notificationsFkmConfirmAction => 'Включить FKM';

  @override
  String get notificationsFkmConfirmMessage =>
      'Уведомления начнут приходить через собственное фоновое соединение, а в шторке будет постоянно висеть уведомление сервиса. Выключить FKM можно прямо в нём.';

  @override
  String get notificationsMainSectionTitle => 'Уведомления';

  @override
  String get notificationsAllLabel => 'Все уведомления';

  @override
  String get notificationsNewSectionTitle => 'Все новые уведомления';

  @override
  String get notificationsPreviewLabel => 'Предпросмотр сообщений';

  @override
  String get notificationsSoundLabel => 'Звук';

  @override
  String get notificationsAdditionalSectionTitle => 'Дополнительно';

  @override
  String get notificationsCallsLabel => 'Уведомления о звонках';

  @override
  String get notificationsNewContactsLabel => 'Уведомления от новых контактов';

  @override
  String get notificationsHapticsSectionTitle => 'Тактильная отдача';

  @override
  String get notificationsHapticsLabel => 'Тактильная отдача';

  @override
  String get notificationsHapticsSubtitle =>
      'Виброотклик при действиях в приложении';

  @override
  String devicesLoadFailed(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get devicesQrLinkDialogTitle => 'Ссылка из QR';

  @override
  String get devicesQrLinkDialogHint => 'Вставьте содержимое QR-кода';

  @override
  String get devicesAllTerminated => 'Все сессии завершены';

  @override
  String devicesGenericError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String devicesIpLookupError(String error) {
    return 'Ошибка IP: $error';
  }

  @override
  String get devicesTitle => 'Устройства';

  @override
  String get devicesPromoTitle => 'Устройства в Komet';

  @override
  String get devicesPromoSubtitle => 'Кто имеет доступ к вашему аккаунту?';

  @override
  String get devicesScanQrButton => 'Сканировать QR';

  @override
  String get devicesCurrentSuffix => ' (текущая)';

  @override
  String get devicesOnlineStatus => 'В сети';

  @override
  String get devicesTerminateOthersButton =>
      'Завершить все сессии, кроме текущей';

  @override
  String get devicesMobileNetworkLabel => 'Мобильная сеть';

  @override
  String get devicesProxyDetectedLabel => 'Обнаружен прокси/VPN';

  @override
  String get themeSettingsTitle => 'Тема';

  @override
  String get themeSettingsModeCardTitle => 'Режим темы';

  @override
  String get themeSettingsModeCardSubtitle =>
      'Светлая, тёмная или авто-переключение';

  @override
  String get themeSettingsModeSystem => 'Системная';

  @override
  String get themeSettingsModeLight => 'Светлая';

  @override
  String get themeSettingsModeDark => 'Тёмная';

  @override
  String get themeSettingsModeSchedule => 'По расписанию';

  @override
  String get themeSettingsAmoledTitle => 'AMOLED-чёрный';

  @override
  String get themeSettingsAmoledSubtitle =>
      'Чистый чёрный фон для OLED-экранов';

  @override
  String get themeSettingsScheduleTitle => 'Расписание';

  @override
  String get themeSettingsScheduleSubtitleEnabled =>
      'Когда автоматически включается тёмная тема';

  @override
  String get themeSettingsScheduleSubtitleDisabled =>
      'Доступно в режиме «По расписанию»';

  @override
  String get themeSettingsScheduleDarkFrom => 'Тёмная с';

  @override
  String get themeSettingsScheduleLightFrom => 'Светлая с';

  @override
  String get themeSettingsCustomTitle => 'Своя';

  @override
  String get appearanceTitle => 'Внешний вид';

  @override
  String get appearanceVisualStyleTitle => 'Визуал';

  @override
  String get appearanceVisualStyleSubtitle =>
      'Material You или объёмные Glossy-капсулы';

  @override
  String get appearanceStyleAuto => 'Как в теме';

  @override
  String get appearanceVisualStyleMaterialYou => 'Material You';

  @override
  String get appearanceVisualStyleGlossy => 'Glossy';

  @override
  String get appearanceVisualStyleLiquidGlass => 'Liquid Glass';

  @override
  String get appearanceGlassMaterial => 'Стекло';

  @override
  String get appearanceChatChromeTitle => 'Элементы экрана чата';

  @override
  String get appearanceChatChromeSubtitle =>
      'Фон панелей ввода и верхнего бара';

  @override
  String get appearanceChatChromeColor => 'Цвет';

  @override
  String get appearanceChatChromeBlur => 'Блюр';

  @override
  String get appearanceChatChromeNone => 'Нет';

  @override
  String get appearanceChatChromeTransparent => 'Frost blur';

  @override
  String get appearanceComposerTitle => 'Вид панели ввода';

  @override
  String get appearanceComposerSubtitle => 'Стиль и фон панели ввода сообщений';

  @override
  String get appearanceComposerBackgroundStandard => 'Default';

  @override
  String get appearanceComposerBackgroundFrost => 'Frost blur';

  @override
  String get appearanceNavPillTitle => 'Вид переключателей';

  @override
  String get appearanceNavPillSubtitle =>
      'Переключатель разделов на экране чатов';

  @override
  String get appearanceNavPillGlossy => 'Glossy';

  @override
  String get appearanceNavPillFrost => 'G-FrostBlur';

  @override
  String get playbackPillAt => 'в';

  @override
  String get playbackPillYou => 'Вы';

  @override
  String get appearanceGradientTitle => 'Градиент';

  @override
  String get appearanceGradientSubtitle => 'Объём и блики в Glossy-капсулах';

  @override
  String get appearanceSpectrumTitle => 'Спектр на фоне';

  @override
  String get appearanceSpectrumSubtitle =>
      'Экспериментально — живые полосы под интерфейсом';

  @override
  String get appearanceAccentColorTitle => 'Акцентный цвет';

  @override
  String get appearanceAccentColorSystem => 'Системный';

  @override
  String get appearanceAccentColorSubtitle =>
      'Основной цвет интерфейса и пузырей';

  @override
  String get appearanceAccentColorSystemActive => 'Системный цвет активен';

  @override
  String get appearanceAccentColorReset => 'Сбросить на системный';

  @override
  String get appearanceBubbleShapeTitle => 'Форма сообщения';

  @override
  String get appearanceBubbleShapeSubtitle => 'Скругление углов пузырей';

  @override
  String get appearanceBubbleShapeMobile => 'TG Mobile';

  @override
  String get appearanceBubbleShapeDesktop => 'TG Desktop';

  @override
  String get appearanceBubbleBehaviorTitle => 'Поведение сообщения';

  @override
  String get appearanceBubbleBehaviorSubtitle =>
      'Меняется ли форма пузыря по соседям в группе';

  @override
  String get appearanceBubbleBehaviorMutable => 'Изменяемая';

  @override
  String get appearanceBubbleBehaviorImmutable => 'Неизменяемая';

  @override
  String get appearancePreviewHello => 'Привет!';

  @override
  String get appearancePreviewHowIsIt => 'Как тебе?';

  @override
  String get appearancePreviewHmm => 'хм...';

  @override
  String get appearancePreviewNotBad => 'Вполне неплохо!';

  @override
  String get callKometDetectedNotification =>
      'Этот человек использует Komet! :3';

  @override
  String get callStatusConnecting => 'Соединение...';

  @override
  String get callGroupConnecting => 'Соединение...';

  @override
  String get callGroupWaitingParticipants => 'Ожидание участников…';

  @override
  String get callLinkGroupCall => 'Групповой звонок';

  @override
  String get callLinkSendInMax => 'Отправить в MAX';

  @override
  String get callLinkStart => 'Начать звонок';

  @override
  String get callLinkSent => 'Ссылка отправлена';

  @override
  String get callLinkSendFailed => 'Не удалось отправить ссылку';

  @override
  String get callLinkCreateFailed => 'Не удалось создать звонок';

  @override
  String get callParticipantYou => 'Вы';

  @override
  String get callParticipantFallback => 'Участник';

  @override
  String get callTooltipMinimize => 'Свернуть';

  @override
  String get callTooltipExpand => 'Развернуть';

  @override
  String get callTooltipKometHub => 'Komet';

  @override
  String get callInfoTitle => 'О звонке';

  @override
  String get callPeerMicOff => 'Микрофон выключен';

  @override
  String get callPeerCameraOn => 'Камера включена';

  @override
  String get callUnknownName => 'Неизвестный';

  @override
  String get callIncoming => 'Входящий звонок';

  @override
  String get callStatusRinging => 'Вызов';

  @override
  String get callStatusEnded => 'Звонок завершён';

  @override
  String get callDecline => 'Отклонить';

  @override
  String get callAccept => 'Принять';

  @override
  String get callSpeaker => 'Динамик';

  @override
  String get callVideoLabel => 'Видео';

  @override
  String get callScreenLabel => 'Экран';

  @override
  String get callUnmute => 'Вкл. звук';

  @override
  String get callMute => 'Выкл. звук';

  @override
  String get callEndButton => 'Завершить';

  @override
  String callCameraUnavailable(Object error) {
    return 'Камера недоступна: $error';
  }

  @override
  String get callTooltipMicrophone => 'Микрофон';

  @override
  String get callMicrophoneTitle => 'Микрофон';

  @override
  String get callMicrophoneSystem => 'Системный по умолчанию';

  @override
  String get callMicrophoneEmpty => 'Микрофоны не найдены';

  @override
  String get callMicrophoneRefresh => 'Обновить список';

  @override
  String get callMicrophoneMonitors => 'Мониторы — звук системы';

  @override
  String callMicrophoneFallback(Object index) {
    return 'Микрофон $index';
  }

  @override
  String callMicrophoneFailed(Object error) {
    return 'Не удалось переключить микрофон: $error';
  }

  @override
  String get callMicStillLive => 'Всё равно слышно';

  @override
  String get callNoMuteHint =>
      '--no-mute: звук идёт даже с выключенным микрофоном';

  @override
  String get callInfoClient => 'Клиент';

  @override
  String get callInfoPlatform => 'Платформа';

  @override
  String get callInfoCountry => 'Страна';

  @override
  String get callInfoInContacts => 'В контактах';

  @override
  String get callValueYes => 'да';

  @override
  String get callValueNo => 'нет';

  @override
  String get callInfoPeerIp => 'IP собеседника';

  @override
  String get callInfoPeerNetwork => 'Сеть собеседника';

  @override
  String get callInfoPath => 'Путь соединения';

  @override
  String get callInfoCodec => 'Кодек';

  @override
  String get callInfoServer => 'Сервер';

  @override
  String get callInfoTopology => 'Топология';

  @override
  String get callInfoStatus => 'Статус';

  @override
  String get callStatusValueConnected => 'соединён';

  @override
  String get callStatusValueConnecting => 'соединение…';

  @override
  String get callInfoPeerMic => 'Микрофон собеседника';

  @override
  String get callMicValueOn => 'включён';

  @override
  String get callMicValueOff => 'выключен';

  @override
  String get callInfoPeerCamera => 'Камера собеседника';

  @override
  String get callCameraValueOn => 'включена';

  @override
  String get callCameraValueOff => 'выключена';

  @override
  String get callInfoVideoTrack => 'Видео-дорожка';

  @override
  String callInfoVideoTrackPresent(int count) {
    return 'есть ($count)';
  }

  @override
  String get callInfoVideoSize => 'Размер видео';

  @override
  String get callInfoFrameRendering => 'Отрисовка кадров';

  @override
  String get callBadgeEncrypted => 'Зашифрован';

  @override
  String get callBadgeAudio => 'Аудио';

  @override
  String get callBadgeRecording => 'Запись';

  @override
  String get callBadgeNoiseSuppression => 'Шумоподавление';

  @override
  String get callBadgeAnimoji => 'Анимодзи';

  @override
  String get callInfoNoDataYet => 'Данные появятся после соединения…';

  @override
  String get hubTitleMenu => 'Komet';

  @override
  String get hubChatPageTitle => 'Анонимный чат';

  @override
  String get hubGamesTitle => 'Игры';

  @override
  String get hubCheckersTitle => 'Шашки';

  @override
  String get hubChatTileTitle => 'Чат';

  @override
  String get hubChatTileSubtitle => 'Анонимные сообщения';

  @override
  String get hubGamesTileSubtitle => 'Сыграть с собеседником';

  @override
  String get hubCheckersTileSubtitle => 'Шашки';

  @override
  String get hubMoreSoonTitle => 'Скоро ещё…';

  @override
  String get hubMoreSoonSubtitle => 'В разработке';

  @override
  String get hubChatPrivacyNote =>
      'Напрямую через звонок, нигде не сохраняется';

  @override
  String get hubChatEmpty => 'Сообщений пока нет';

  @override
  String get hubChatInputHint => 'Сообщение…';

  @override
  String get hubCheckersRestart => 'Заново';

  @override
  String get hubCheckersYouWhite => 'Вы играете белыми';

  @override
  String get hubCheckersYouBlack => 'Вы играете чёрными';

  @override
  String get hubCheckersWon => 'Вы выиграли 🎉';

  @override
  String get hubCheckersLost => 'Вы проиграли';

  @override
  String get hubCheckersYourMove => 'Ваш ход';

  @override
  String get hubCheckersOpponentMove => 'Ход соперника…';

  @override
  String get scheduledPickTimeTitle => 'Когда отправить';

  @override
  String get scheduledEditTitle => 'Изменить';

  @override
  String get scheduledMessageTextHint => 'Текст сообщения';

  @override
  String get scheduledSave => 'Сохранить';

  @override
  String get scheduledEditFailed => 'Не удалось изменить сообщение';

  @override
  String get scheduledDeleteConfirmTitle =>
      'Удалить запланированное сообщение?';

  @override
  String get scheduledDeleteConfirmMessage => 'Сообщение не будет отправлено.';

  @override
  String get scheduledDeleteConfirmLabel => 'Удалить';

  @override
  String get scheduledDeleteFailed => 'Не удалось удалить сообщение';

  @override
  String get scheduledAppBarTitle => 'Отложенные';

  @override
  String get scheduledEmpty => 'Нет отложенных сообщений';

  @override
  String get scheduledAttachPhoto => 'Фото';

  @override
  String get scheduledAttachVideo => 'Видео';

  @override
  String get scheduledAttachVoice => 'Голосовое';

  @override
  String get scheduledAttachFile => 'Файл';

  @override
  String get scheduledAttachLocation => 'Геопозиция';

  @override
  String get scheduledAttachForwarded => 'Переслано';

  @override
  String get scheduledAttachGeneric => 'Вложение';

  @override
  String contactProfileLoadError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get contactProfileBot => 'Бот';

  @override
  String get contactProfileOnline => 'В сети';

  @override
  String get contactProfileRecentlyActive => 'Был(-а) недавно';

  @override
  String get contactProfileActionChat => 'Чат';

  @override
  String get contactProfileActionSound => 'Звук';

  @override
  String get contactProfileActionCall => 'Звонок';

  @override
  String get contactProfileActionAddContact => 'Добавить в контакты';

  @override
  String get contactProfileInfoPhone => 'Телефон';

  @override
  String get contactProfileInfoCountry => 'Страна';

  @override
  String get contactProfileInfoGender => 'Пол';

  @override
  String get contactProfileInfoRegistration => 'Регистрация';

  @override
  String get contactProfileInfoUpdated => 'Обновлён';

  @override
  String get contactProfileInfoAccountStatus => 'Статус аккаунта';

  @override
  String get contactProfileInfoDescription => 'Описание';

  @override
  String get contactProfileInfoLink => 'Ссылка';

  @override
  String get contactProfileInfoFlags => 'Флаги';

  @override
  String nfcPeerNameFallback(String id) {
    return 'Контакт #$id';
  }

  @override
  String get nfcPeerFirstNameFallback => 'Контакт';

  @override
  String get nfcContactAdded => 'Контакт добавлен';

  @override
  String nfcAddFailed(String error) {
    return 'Не удалось добавить: $error';
  }

  @override
  String get nfcReasonBluetoothOff => 'Включите Bluetooth и попробуйте снова';

  @override
  String get nfcReasonPermission => 'Нужны разрешения Bluetooth для обмена';

  @override
  String get nfcReasonDefault => 'Не удалось установить соединение';

  @override
  String get nfcSheetTitle => 'Обмен контактом';

  @override
  String get nfcUnsupported => 'NFC недоступен на этом устройстве';

  @override
  String get nfcDisabled =>
      'Включите NFC в настройках телефона и попробуйте снова';

  @override
  String get nfcScanningTitle => 'Поднесите телефоны друг к другу';

  @override
  String get nfcScanningSubtitle =>
      'Оба устройства должны держать этот экран открытым';

  @override
  String get nfcExchangingTitle => 'Идёт обмен контактами…';

  @override
  String get nfcExchangingSubtitle => 'Почти готово';

  @override
  String contactIdFallback(String id) {
    return 'ID $id';
  }

  @override
  String get nfcAdded => 'Добавлено';

  @override
  String get nfcAddContact => 'Добавить контакт';

  @override
  String get chatInfoTabGeneralChats => 'Общие чаты';

  @override
  String get chatInfoTabMedia => 'Медиа';

  @override
  String get chatInfoTabFiles => 'Файлы';

  @override
  String get chatInfoTabVoice => 'Голосовые';

  @override
  String get chatInfoTabLinks => 'Ссылки';

  @override
  String get chatInfoTabMembers => 'Участники';

  @override
  String get chatInfoEmptyGeneralChats => 'Нет общих чатов';

  @override
  String get chatInfoEmptyMedia => 'Нет медиа';

  @override
  String get chatInfoEmptyFiles => 'Нет файлов';

  @override
  String get chatInfoEmptyVoice => 'Нет голосовых';

  @override
  String get chatInfoEmptyLinks => 'Нет ссылок';

  @override
  String chatInfoOnlineOfTotal(String online, String total) {
    return '$online из $total в сети';
  }

  @override
  String sharedMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String get sharedLoadMore => 'Показать ещё';

  @override
  String get sharedGoToMessage => 'Перейти к сообщению';

  @override
  String get sharedDownload => 'Скачать';

  @override
  String photoViewerCounter(int index, int total) {
    return 'Фото $index из $total';
  }

  @override
  String photoViewerCounterFile(int total) {
    return 'ФАЙЛ из $total';
  }

  @override
  String photoViewerSentToday(String sender, String time) {
    return '$sender • сегодня в $time';
  }

  @override
  String photoViewerSentOn(String sender, String date, String time) {
    return '$sender • $date в $time';
  }

  @override
  String get photoViewerSaveAs => 'Сохранить как…';

  @override
  String get photoViewerSaveToGallery => 'Сохранить в галерею';

  @override
  String get photoViewerViewAll => 'Все фото чата';

  @override
  String get photoViewerRotate => 'Повернуть';

  @override
  String mediaViewerCounter(int index, int total) {
    return '$index из $total';
  }

  @override
  String get mediaViewerViewAll => 'Все медиа чата';

  @override
  String get videoViewerSettings => 'Настройки';

  @override
  String get videoViewerSpeed => 'Скорость';

  @override
  String get videoViewerQuality => 'Качество';

  @override
  String get videoViewerFailed => 'Не удалось воспроизвести видео';

  @override
  String get videoViewerRetry => 'Повторить';

  @override
  String get videoViewerClose => 'Закрыть';

  @override
  String get sharedCopyLink => 'Копировать ссылку';

  @override
  String get sharedLinkCopied => 'Ссылка скопирована';

  @override
  String get chatInfoActionLeave => 'Покинуть';

  @override
  String get chatInfoActionSubscribe => 'Подписаться';

  @override
  String get chatInfoSubscribed => 'Вы подписались на канал';

  @override
  String get chatInfoSubscribeFailed => 'Не удалось подписаться на канал';

  @override
  String get chatInfoActionJoin => 'Вступить';

  @override
  String get chatInfoJoinedGroup => 'Вы вступили в группу';

  @override
  String get chatInfoJoinGroupFailed => 'Не удалось вступить в группу';

  @override
  String get chatInfoActionMuted => 'Без звука';

  @override
  String get chatInfoNotificationsOn => 'Уведомления включены';

  @override
  String get chatInfoNotificationsOff => 'Уведомления отключены';

  @override
  String get chatInfoMenuBlock => 'Заблокировать';

  @override
  String get chatInfoMenuUnblock => 'Разблокировать';

  @override
  String get chatInfoMenuDeleteChat => 'Удалить чат';

  @override
  String get chatInfoMenuClearHistory => 'Очистить историю';

  @override
  String get chatInfoClearHistoryTitle => 'Очистить историю';

  @override
  String get chatInfoClearHistoryMessage =>
      'Все сообщения в этом чате будут удалены без возможности восстановления.';

  @override
  String get chatInfoClearHistoryForAll => 'Для всех';

  @override
  String get chatInfoClearHistoryConfirm => 'Очистить';

  @override
  String get chatInfoClearHistoryDone => 'История очищена';

  @override
  String get chatInfoDeleteChatTitle => 'Удалить чат';

  @override
  String get chatInfoDeleteChatMessage =>
      'Чат будет удалён вместе со всей перепиской.';

  @override
  String get chatInfoDeleteChatConfirm => 'Удалить';

  @override
  String get chatInfoLeaveGroupTitle => 'Покинуть группу';

  @override
  String get chatInfoLeaveGroupMessage =>
      'Вы больше не будете получать сообщения этой группы.';

  @override
  String get chatInfoLeaveChannelTitle => 'Покинуть канал';

  @override
  String get chatInfoLeaveChannelMessage =>
      'Вы больше не будете получать публикации этого канала.';

  @override
  String get chatInfoLeaveConfirm => 'Покинуть';

  @override
  String get chatInfoLeaveFailed => 'Не удалось покинуть чат';

  @override
  String get chatInfoCallConfirmTitle => 'Начать звонок';

  @override
  String chatInfoCallConfirmMessage(String name) {
    return 'Позвонить $name?';
  }

  @override
  String get chatInfoConfirmYes => 'Да';

  @override
  String get chatInfoConfirmNo => 'Нет';

  @override
  String get chatInfoCallFailed => 'Не удалось начать звонок';

  @override
  String get chatInfoBlockConfirmTitle => 'Заблокировать';

  @override
  String chatInfoBlockConfirmMessage(String name) {
    return 'Вы уверены, что хотите заблокировать $name?';
  }

  @override
  String get chatInfoBlockDone => 'Пользователь заблокирован';

  @override
  String get chatInfoUnblockDone => 'Пользователь разблокирован';

  @override
  String get chatInfoBlockFailed => 'Не удалось изменить блокировку';

  @override
  String get chatInfoComplaintTitle => 'Пожаловаться';

  @override
  String get chatInfoComplaintSubtitle => 'Выберите причину жалобы';

  @override
  String get chatInfoComplaintSend => 'Пожаловаться';

  @override
  String get chatInfoComplaintClose => 'Закрыть';

  @override
  String get chatInfoComplaintEmpty => 'Не удалось загрузить причины жалобы';

  @override
  String get chatInfoComplaintSent => 'Жалоба отправлена';

  @override
  String get chatInfoComplaintFailed => 'Не удалось отправить жалобу';

  @override
  String get chatInfoActionCancel => 'Отмена';

  @override
  String get chatInfoBio => 'О себе';

  @override
  String get chatInfoInviteLink => 'Ссылка-приглашение';

  @override
  String get chatInfoCollapse => 'Свернуть';

  @override
  String get chatInfoShowMore => 'Ещё';

  @override
  String get chatInfoAddMember => 'Добавить участника';

  @override
  String get chatInfoRoleOwner => 'Владелец';

  @override
  String get chatInfoRoleAdmin => 'Админ';

  @override
  String get chatInfoMemberDeleted => 'Аккаунт удалён';

  @override
  String get chatInfoInviteByLink => 'Пригласить по ссылке';

  @override
  String get chatInfoInviteLinkHint =>
      'Вы можете пригласить любого человека по этой ссылке';

  @override
  String get chatInfoAddMembersAction => 'Добавить';

  @override
  String get chatInfoMembersSearchHint => 'Поиск';

  @override
  String get chatInfoAddMembersEmpty => 'Некого добавить';

  @override
  String get chatInfoMembersAdded => 'Участники добавлены';

  @override
  String get chatInfoAddMembersError => 'Не удалось добавить участников';

  @override
  String get chatInfoNoData => 'Нет данных';

  @override
  String get chatInfoHideExtra => 'Скрыть';

  @override
  String get chatInfoShowMoreExtra => 'Подробнее';

  @override
  String get chatSendConfirmMessage => 'Отправить это сообщение в чат?';

  @override
  String get chatSendConfirmAction => 'Отправить';

  @override
  String get chatInfoRowDisableForward => 'Пересылка запрещена';

  @override
  String get chatInfoRowCopyDisabled => 'Копирование запрещено';

  @override
  String get chatInfoRowOnlyAdminCall => 'Звонить могут админы';

  @override
  String get chatInfoRowAllCanPin => 'Все могут закреплять';

  @override
  String get chatInfoRowMembersSeeLink => 'Ссылка видна участникам';

  @override
  String get chatInfoRowConfirmBeforeSend => 'Подтверждать отправку';

  @override
  String get chatInfoRowOnlyOwnerIconTitle => 'Название меняет владелец';

  @override
  String get chatInfoRowPromotedDisabled => 'Реклама отключена';

  @override
  String get chatInfoRowUserId => 'ID пользователя';

  @override
  String get chatInfoRowId => 'ID чата';

  @override
  String get chatInfoRowCreated => 'Создан';

  @override
  String get chatInfoRowModified => 'Изменён';

  @override
  String get chatInfoRowMembersCount => 'Участников';

  @override
  String get chatInfoRowOwner => 'Владелец';

  @override
  String get chatInfoRowCreatedGroup => 'Создана';

  @override
  String get chatInfoRowJoined => 'Вступил';

  @override
  String get chatInfoRowModifiedGroup => 'Изменена';

  @override
  String get chatInfoRowHasBots => 'Есть боты';

  @override
  String get chatInfoRowBlockedCount => 'Заблокировано';

  @override
  String get chatInfoRowOfficialGroup => 'Официальная';

  @override
  String get chatInfoRowSignAdmin => 'Подпись адм.';

  @override
  String get chatInfoRowSubscribersCount => 'Подписчиков';

  @override
  String get chatInfoRowOfficialChannel => 'Официальный';

  @override
  String get chatInfoRowComments => 'Комментарии';

  @override
  String get chatInfoRowRkn => 'РКН';

  @override
  String get chatInfoRowOnlyAdmin => 'Только адм.';

  @override
  String get securityTitle => 'Безопасность';

  @override
  String securityLoadError(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String securitySaveError(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get securityPrivacyAll => 'Все';

  @override
  String get securityPrivacyContacts => 'Мои контакты';

  @override
  String get securityPrivacyNobody => 'Никто';

  @override
  String get securityFamilyProtection => 'Семейная защита';

  @override
  String get securityEnabledFem => 'Включена';

  @override
  String get securityDisabledFem => 'Отключена';

  @override
  String get securityPasswordTitle => 'Пароль для входа';

  @override
  String get securityEnabledMasc => 'Включён';

  @override
  String get securityDisabledMasc => 'Отключён';

  @override
  String get securityModeTitle => 'Безопасный режим';

  @override
  String get securityModeSubtitle => 'Скрывает личную информацию';

  @override
  String get securityModeLocked =>
      'Отключите безопасный режим, чтобы изменить эту настройку';

  @override
  String get securityModeSheetSubtitle => 'Без лишнего общения и контента';

  @override
  String get securityModeSheetSearch =>
      'Вас не смогут найти по номеру телефона';

  @override
  String get securityModeSheetCalls =>
      'Позвонить вам смогут только люди из вашего списка контактов';

  @override
  String get securityModeSheetInvites =>
      'Пригласить вас в группу смогут только те, с кем вы уже общались';

  @override
  String get securityModeSheetContent =>
      'Вы увидите только безопасные посты и каналы';

  @override
  String get securityModeSheetEnable => 'Включить';

  @override
  String get securityFindByPhone => 'Найти меня по номеру';

  @override
  String get securityWhoCanCall => 'Кто может мне звонить';

  @override
  String get securityWhoCanInvite => 'Кто может приглашать в чаты';

  @override
  String get securityShowContent => 'Показывать контент';

  @override
  String get securityContentSafe => 'Безопасный';

  @override
  String get securityContentAll => 'Весь';

  @override
  String get securityShowOnlineStatus => 'Видеть статус «в сети»';

  @override
  String get securityShowMyNumber => 'Видеть мой номер';

  @override
  String get securityConfirmTitle => 'Вы уверены?';

  @override
  String get securityHiddenStatusWarning =>
      'Вы не сможете видеть статусы посещения других пользователей.';

  @override
  String get securityConfidentialityHeader => 'КОНФИДЕНЦИАЛЬНОСТЬ';

  @override
  String get securityReadReceipts => 'Галочки «Прочитано»';

  @override
  String get securityAltKeyboard => 'Альтернативная клавиатура';

  @override
  String get securityUnsafeFiles => 'Принимать опасные файлы';

  @override
  String get securityAudioTranscription => 'Транскрибация аудио';

  @override
  String get securityConfidentialityWarning =>
      'Этих тумблеров нету в оригинальном приложении, и они могут быть вам недоступны.\n\nВ случае отказа, сервер сбросит соединение. (conection closed)';

  @override
  String get securityConfidentialityDecline => 'Не';

  @override
  String get securityBlacklistTitle => 'Чёрный список';

  @override
  String securityBlacklistNotification(String count) {
    return 'Чёрный список: $count контактов';
  }

  @override
  String get passwordEntryWrongPassword => 'Неверный пароль';

  @override
  String get passwordEntryConfirmTitle => 'Подтвердите пароль';

  @override
  String get passwordEntryCurrentPasswordHint => 'Текущий пароль';

  @override
  String get passwordEntryContinue => 'Продолжить';

  @override
  String get passwordEntryNotSetTitle => 'Пароль не установлен';

  @override
  String get passwordEntry2faSubtitle => 'Двухфакторная аутентификация';

  @override
  String get passwordEntrySetupAction => 'Установить пароль';

  @override
  String get passwordEntryGateMessage =>
      'Введите пароль для входа, чтобы управлять защитой';

  @override
  String get passwordEntryGenericPasswordHint => 'Пароль';

  @override
  String get passwordEntrySetTitle => 'Пароль установлен';

  @override
  String passwordEntryHintPrefix(String hint) {
    return 'Подсказка: $hint';
  }

  @override
  String get passwordEntryChangePasswordAction => 'Изменить пароль';

  @override
  String get passwordEntryChangeEmailAction => 'Изменить почту';

  @override
  String get passwordEntryDeleteAction => 'Удалить пароль';

  @override
  String get passwordEntryMinPasswordError =>
      'Пароль должен быть минимум 6 символов';

  @override
  String get passwordEntryMismatchError => 'Пароли не совпадают';

  @override
  String get passwordEntryInvalidEmailError => 'Введите нормальный email';

  @override
  String get passwordEntryInvalidCodeError => 'Введите 6-значный код';

  @override
  String get passwordEntrySetupTitle => 'Установка пароля';

  @override
  String get passwordEntryStepPassword => 'Пароль';

  @override
  String get passwordEntryStepHint => 'Подсказка';

  @override
  String get passwordEntryStepEmail => 'Почта';

  @override
  String get passwordEntryStepCode => 'Код';

  @override
  String get passwordEntryChoosePassword => 'Придумайте пароль';

  @override
  String get passwordEntryMinCharsHint => 'Минимум 6 символов';

  @override
  String get passwordEntryEnterPasswordHint => 'Введите пароль';

  @override
  String get passwordEntryEnterAgain => 'Введите пароль ещё раз';

  @override
  String get passwordEntryRepeatHint => 'Повторите пароль';

  @override
  String get passwordEntryHintForPassword => 'Подсказка для пароля';

  @override
  String get passwordEntryOptional => 'Необязательно';

  @override
  String get passwordEntryHintFieldHint => 'Введите подсказку (необязательно)';

  @override
  String get passwordEntryLinkEmail => 'Привяжите email';

  @override
  String get passwordEntryEmailPurpose =>
      'Для восстановления пароля. Необязательно';

  @override
  String get passwordEntryEmailHintOptional =>
      'example@mail.ru (необязательно)';

  @override
  String get passwordEntryEnterCode => 'Введите код';

  @override
  String passwordEntryCodeSentTo(String email) {
    return 'Код отправлен на $email';
  }

  @override
  String get passwordEntryChangedNotif => 'Пароль изменён';

  @override
  String get passwordEntryNewPassword => 'Новый пароль';

  @override
  String get passwordEntryNewPasswordHint => 'Введите новый пароль';

  @override
  String get passwordEntryRepeatNewPasswordHint => 'Повторите новый пароль';

  @override
  String get passwordEntryEmailChangedNotif => 'Почта изменена';

  @override
  String get passwordEntryNewEmail => 'Новая почта';

  @override
  String get passwordEntryEmailHint => 'example@mail.ru';

  @override
  String get passwordEntryRemovedNotif => 'Пароль удалён';

  @override
  String get passwordEntryRemoveTitle => 'Удаление пароля';

  @override
  String get passwordEntryRemoveWarning =>
      'После удаления пароля ваш аккаунт будет менее защищен. Уверены?';

  @override
  String get cloudStorageNoActiveProfile => 'Нет активного профиля';

  @override
  String get cloudStorageSetupFailed => 'Не удалось создать среду';

  @override
  String get cloudStorageTitle => 'Облачное хранилище';

  @override
  String get cloudStorageNotConfiguredTitle =>
      'Среда для облачного хранилища не настроена';

  @override
  String get cloudStorageNotConfiguredSubtitle => 'Начнем? Это быстро.';

  @override
  String get cloudStorageStart => 'Начать';

  @override
  String cloudStorageUploadingPercent(String percent) {
    return 'Загрузка $percent%';
  }

  @override
  String get cloudStorageStartUploadHint =>
      'Начните загрузку для прогресс-бара';

  @override
  String get cloudStorageEmptyTitle => 'Облачных файлов пока нет...';

  @override
  String get cloudStorageEmptySubtitle => 'Добавите?';

  @override
  String get cloudStorageUpload => 'Загрузить';

  @override
  String get cloudStorageFromFile => 'С файла';

  @override
  String get cloudStorageById => 'По ID';

  @override
  String get cloudStorageFileIdLabel => 'ID файла';

  @override
  String get cloudStorageSizeLabel => 'Размер';

  @override
  String get cloudStorageNoLinkYet => 'Ссылки пока нет. Создайте.';

  @override
  String cloudStorageLinkExpiresIn(String time) {
    return 'Ссылка истечет $time';
  }

  @override
  String get cloudStorageLinkCopied => 'Ссылка скопирована';

  @override
  String get cloudStorageInvalidId => 'Неверный ID';

  @override
  String get cloudStorageSendError => 'Ошибка отправки';

  @override
  String get cloudStorageSendByIdTitle => 'Отправить по ID';

  @override
  String get cloudStorageSend => 'Отправить';

  @override
  String get digitalIdGosuslugiLinkUnavailable =>
      'Привязка Госуслуг недоступна на этой платформе. Сделайте это в приложении на телефоне.';

  @override
  String get digitalIdGosuslugiLinkFailed =>
      'Не удалось получить ссылку Госуслуг';

  @override
  String get digitalIdGosuslugiTitle => 'Госуслуги';

  @override
  String get digitalIdDocsUnavailable =>
      'Документы пока недоступны. Попробуйте позже.';

  @override
  String get digitalIdTitle => 'Цифровой ID';

  @override
  String get digitalIdNotConfiguredTitle => 'Цифровой ID не настроен';

  @override
  String get digitalIdLinkGosuslugiHint =>
      'Привяжите аккаунт Госуслуг, чтобы документы появились в Цифровом ID. Номер телефона в MAX должен совпадать с номером в профиле Госуслуг.';

  @override
  String get digitalIdLinkOrRefreshHint =>
      'Привяжите Госуслуги, чтобы получить доступ к документам, или обновите страницу, если уже настраивали Цифровой ID.';

  @override
  String get digitalIdLoadDocuments => 'Загрузить документы';

  @override
  String get digitalIdLinkGosuslugiButton => 'Привязать Госуслуги';

  @override
  String get digitalIdGosuslugiProfileFallback => 'Профиль Госуслуг';

  @override
  String digitalIdBirthDate(String date) {
    return 'Дата рождения: $date';
  }

  @override
  String get digitalIdPersonalDataTitle => 'Личные данные';

  @override
  String get digitalIdSnilsLabel => 'СНИЛС';

  @override
  String get digitalIdInnLabel => 'ИНН';

  @override
  String get digitalIdBirthPlaceLabel => 'Место рождения';

  @override
  String get digitalIdRegistrationAddressLabel => 'Адрес регистрации';

  @override
  String get digitalIdDocumentsTitle => 'Документы';

  @override
  String digitalIdDocSeries(String series) {
    return 'серия $series';
  }

  @override
  String digitalIdDocNumber(String number) {
    return '№ $number';
  }

  @override
  String get digitalIdPassesTitle => 'Пропуска';

  @override
  String digitalIdCardInn(String inn) {
    return 'ИНН $inn';
  }

  @override
  String get digitalIdBiometryConfigured =>
      'Биометрия настроена на этом устройстве';

  @override
  String get digitalIdBiometryNotConfigured =>
      'Биометрия на этом устройстве не настроена';

  @override
  String get digitalIdDocPassport => 'Паспорт РФ';

  @override
  String get digitalIdDocOms => 'Полис ОМС';

  @override
  String get digitalIdDocDriverLicense => 'Водительское удостоверение';

  @override
  String get digitalIdDocVehicleSts => 'СТС';

  @override
  String get digitalIdDocChildBirthCert => 'Свидетельство о рождении';

  @override
  String get digitalIdDocPensionCert => 'Пенсионное удостоверение';

  @override
  String get digitalIdDocDisabledCert => 'Справка об инвалидности';

  @override
  String get digitalIdDocLargeFamilyCert => 'Удостоверение многодетной семьи';

  @override
  String get digitalIdDocStudentTicket => 'Студенческий билет';

  @override
  String get digitalIdDocChildInn => 'ИНН ребёнка';

  @override
  String get digitalIdDocChildOms => 'Полис ОМС ребёнка';

  @override
  String get attachSheetGallery => 'Галерея';

  @override
  String get attachSheetPoll => 'Опрос';

  @override
  String get attachSheetCameraError => 'Не удалось открыть камеру';

  @override
  String get attachSheetSendFileTitle => 'Отправить файл';

  @override
  String get attachSheetSendFileSubtitle =>
      'Документ, архив или любой другой файл';

  @override
  String get attachSheetChooseFileButton => 'Выбрать файл';

  @override
  String get attachSheetShareLocationTitle => 'Поделиться геопозицией';

  @override
  String get attachSheetShareLocationSubtitle =>
      'Отправить ваше текущее местоположение';

  @override
  String get attachSheetSendLocationButton => 'Отправить геопозицию';

  @override
  String get attachSheetCreatePoll => 'Создать опрос';

  @override
  String get attachSheetCreatePollSubtitle => 'Вопрос с вариантами ответа';

  @override
  String get attachSheetNoImagesFound => 'Изображений не найдено';

  @override
  String get attachSheetMoreActions => 'Ещё';

  @override
  String get attachSheetSendSeparately => 'Отправить по отдельности';

  @override
  String get attachSheetLimitedAccessInfo => 'Доступны не все фото';

  @override
  String get attachSheetSectionInProgress => 'Раздел в разработке';

  @override
  String get attachSheetContact => 'Контакт';

  @override
  String get attachSheetContactSearchHint => 'Поиск по контактам';

  @override
  String get attachSheetNoContacts => 'У вас пока нет контактов';

  @override
  String get attachSheetNoContactsFound => 'Контакты не найдены';

  @override
  String get attachSheetNoGalleryAccessTitle => 'Нет доступа к галерее';

  @override
  String get attachSheetNoGalleryAccessSubtitle =>
      'Разрешите доступ к фото, чтобы выбрать их отсюда';

  @override
  String get attachSheetAllow => 'Разрешить';

  @override
  String get attachSheetGalleryFailedTitle => 'Не удалось загрузить галерею';

  @override
  String get attachSheetRetry => 'Повторить';

  @override
  String get attachSheetSettings => 'Настройки';

  @override
  String get attachSheetAddCaptionHint => 'Добавить подпись...';

  @override
  String get attachSheetCamera => 'Камера';

  @override
  String get attachSheetCameraAllow => 'Разрешите камеру';

  @override
  String get photoEditorApplyFailed => 'Не удалось применить';

  @override
  String get photoEditorFlipTooltip => 'Отразить';

  @override
  String get photoEditorRotateTooltip => 'Повернуть';

  @override
  String get photoEditorCancel => 'ОТМЕНА';

  @override
  String get photoEditorReset => 'СБРОС';

  @override
  String get photoEditorDone => 'ГОТОВО';

  @override
  String get photoEditorTextDialogTitle => 'Текст';

  @override
  String get photoEditorTextDialogHint => 'Введите текст';

  @override
  String get photoEditorOk => 'ОК';

  @override
  String get photoEditorApplyChangesFailed => 'Не удалось применить изменения';

  @override
  String get photoEditorClearAll => 'Очистить всё';

  @override
  String get photoEditorAddText => 'Добавить текст';

  @override
  String get photoEditorTabDraw => 'РИСУНОК';

  @override
  String get photoEditorTabStickers => 'СТИКЕРЫ';

  @override
  String get photoEditorTabText => 'ТЕКСТ';

  @override
  String get photoEditorChannelAll => 'Все';

  @override
  String get photoEditorChannelRed => 'Красный';

  @override
  String get photoEditorChannelGreen => 'Зелёный';

  @override
  String get photoEditorChannelBlue => 'Синий';

  @override
  String get photoEditorEnhance => 'Улучшение';

  @override
  String get photoEditorExposure => 'Экспозиция';

  @override
  String get photoEditorContrast => 'Контраст';

  @override
  String get photoEditorSaturation => 'Насыщенность';

  @override
  String get photoEditorWarmth => 'Тёплость';

  @override
  String get photoEditorVignette => 'Виньетка';

  @override
  String get photoEditorBlurOff => 'Откл.';

  @override
  String get photoEditorBlurRadial => 'Радиальное';

  @override
  String get photoEditorBlurLinear => 'Линейное';

  @override
  String get fontSettingsInvalidInput => 'Введите ссылку или название шрифта';

  @override
  String fontSettingsFontNotFound(String name) {
    return 'Шрифт «$name» не найден или нет сети';
  }

  @override
  String fontSettingsFontAdded(String name) {
    return 'Шрифт «$name» добавлен';
  }

  @override
  String fontSettingsFontRemoved(String name) {
    return 'Шрифт «$name» удалён';
  }

  @override
  String get fontSettingsAddFontTitle => 'Добавить шрифт';

  @override
  String get fontSettingsAddFontDescription =>
      'Вставьте ссылку Google Fonts или название шрифта';

  @override
  String get fontSettingsAddFontConfirm => 'Добавить';

  @override
  String get fontSettingsPickFile => 'Выбрать файл';

  @override
  String get fontSettingsPickFileHint => 'Шрифт в формате .ttf, .otf или .ttc';

  @override
  String get fontSettingsNotAFont => 'Это не файл шрифта';

  @override
  String get fontSettingsCancel => 'Отмена';

  @override
  String get fontSettingsTitle => 'Шрифты';

  @override
  String get fontSettingsSectionFont => 'Шрифт';

  @override
  String get fontSettingsLoading => 'Загрузка…';

  @override
  String get fontSettingsSectionFontSize => 'Размер шрифта';

  @override
  String get fontSettingsPreviewLabel => 'ПРЕДПРОСМОТР';

  @override
  String get fontSettingsReset => 'Сбросить';

  @override
  String get updateAvailableTitle => 'Доступно обновление';

  @override
  String updateAvailableBody(String version) {
    return 'Вышла версия $version. Обновить приложение?';
  }

  @override
  String get updateWhatsNew => 'ЧТО НОВОГО';

  @override
  String get updateAction => 'Обновить';

  @override
  String get updateLater => 'Позже';

  @override
  String get updateSkip => 'Пропустить';

  @override
  String get updateDownloading => 'Загрузка обновления…';

  @override
  String get updateDownloadFailed => 'Не удалось скачать обновление';

  @override
  String get updateCheck => 'Проверить обновление';

  @override
  String get updateChecking => 'Проверяем обновления…';

  @override
  String get updateUpToDate => 'Установлена актуальная версия';

  @override
  String get updateCheckFailed =>
      'Не удалось проверить обновления. Повторите позже';

  @override
  String get profileResurrecting =>
      'Упс! Сервер не прислал profile. Попробую регенерировать…';

  @override
  String get profilePhoneRegenFailed =>
      'Не удалось регенерировать данные об номере. Перезайдите и сообщите об проблеме разработчикам';

  @override
  String get addContactTitle => 'Новый контакт';

  @override
  String get addContactFirstName => 'Имя';

  @override
  String get addContactLastName => 'Фамилия (необязательно)';

  @override
  String get addContactSave => 'Сохранить контакт';

  @override
  String addContactNotFound(String phone) {
    return '$phone не найден';
  }

  @override
  String get addContactNotFoundSubtitle => 'Этого номера пока нет в приложении';

  @override
  String get addContactSearchOther => 'Искать другой номер';

  @override
  String get addContactError => 'Не удалось добавить контакт';

  @override
  String get contactBubbleNew => 'Новый контакт';

  @override
  String get contactBubbleAlreadyAdded => 'Уже твой контакт';

  @override
  String get contactBubbleOpenProfile => 'Открыть профиль';

  @override
  String get miniAppOpen => 'Открыть';

  @override
  String get miniAppFailed => 'Не удалось открыть приложение';

  @override
  String get editContactMenu => 'Редактировать контакт';

  @override
  String get editContactTitle => 'Редактировать контакт';

  @override
  String get editContactFirstName => 'Имя';

  @override
  String get editContactLastName => 'Фамилия';

  @override
  String get editContactSave => 'Сохранить';

  @override
  String get editContactDelete => 'Удалить контакт';

  @override
  String get editContactDeleteConfirmTitle => 'Удалить контакт?';

  @override
  String get editContactDeleteConfirmBody =>
      'Контакт будет удалён из вашего списка.';

  @override
  String get editContactDeleteCancel => 'Отмена';

  @override
  String get editContactError => 'Не удалось сохранить изменения';

  @override
  String get downloadsTitle => 'Недавние загрузки';

  @override
  String get downloadsTooltip => 'Загрузки';

  @override
  String get downloadsSettings => 'Настройки';

  @override
  String get downloadsEmpty => 'Скачанные файлы появятся здесь';

  @override
  String get downloadsUnknownSource => 'Источник неизвестен';

  @override
  String get downloadsPhoto => 'Фото';

  @override
  String get downloadsVideo => 'Видео';

  @override
  String get downloadsGif => 'GIF';

  @override
  String get downloadsAudio => 'Аудио';

  @override
  String get downloadsFile => 'Файл';

  @override
  String get downloadsOpenFailed => 'Не удалось открыть файл';

  @override
  String get audioPlaybackChannel => 'Воспроизведение аудио';

  @override
  String get audioPlaybackFailed => 'Не удалось воспроизвести файл';

  @override
  String get downloadsClearHistory => 'Очистить историю загрузок';

  @override
  String get downloadsClearTitle => 'Очистить историю загрузок?';

  @override
  String get downloadsClearBody =>
      'Файлы останутся на устройстве, но этот список будет очищен.';

  @override
  String get downloadsClearConfirm => 'Очистить';

  @override
  String get downloadsHistoryCleared => 'История загрузок очищена';

  @override
  String uploadNotificationPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      one: 'Фото',
    );
    return '$_temp0';
  }

  @override
  String get uploadNotificationVideo => 'Видео';

  @override
  String get uploadNotificationVideoNote => 'Кружок';

  @override
  String get uploadNotificationVoice => 'Голосовое сообщение';

  @override
  String get uploadNotificationFile => 'Файл';

  @override
  String uploadNotificationMultiple(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отправка файлов: $count',
    );
    return '$_temp0';
  }

  @override
  String get uploadNotificationPreparing => 'Подготовка…';

  @override
  String uploadSpeedBytes(String value) {
    return '$value Б/с';
  }

  @override
  String uploadSpeedKb(String value) {
    return '$value КБ/с';
  }

  @override
  String uploadSpeedMb(String value) {
    return '$value МБ/с';
  }

  @override
  String get savedMessagesEmptyPreview => 'Сохраните что-нибудь';

  @override
  String proxyCurrentState(String value) {
    return 'Сейчас: $value';
  }

  @override
  String get blacklistEmpty => 'Никто не заблокирован';

  @override
  String get joinRequestsTitle => 'Заявки на вступление';

  @override
  String get joinRequestsEmpty => 'Нет заявок';

  @override
  String get joinRequestsApprove => 'Принять';

  @override
  String get joinRequestsDecline => 'Отклонить';

  @override
  String get joinRequestsApproved => 'Заявка принята';

  @override
  String get joinRequestsDeclined => 'Заявка отклонена';

  @override
  String get joinRequestsActionFailed => 'Не удалось, попробуйте ещё раз';

  @override
  String get joinRequestsLoadError => 'Не удалось загрузить заявки';

  @override
  String get blacklistLoadError => 'Не удалось загрузить чёрный список';

  @override
  String get videoEditorQualityLow => 'Небольшой размер';

  @override
  String get videoEditorQualityHigh => 'Высокое качество';

  @override
  String get videoEditorCaptionHint => 'Добавить подпись...';

  @override
  String get videoEditorMuteTooltip => 'Отправить без звука';

  @override
  String get videoEditorProcessing => 'Обработка видео…';

  @override
  String get videoEditorExportFailed => 'Не удалось обработать видео';

  @override
  String get videoEditorFrameFailed => 'Не удалось получить кадр';

  @override
  String get videoEditorQualityTooltip => 'Качество';

  @override
  String get webPushTitle => 'Уведомления на iOS';

  @override
  String get webPushIntro =>
      'На iOS у Комета нет обычных пушей: Apple выдаёт токен уведомлений только приложениям, подписанным сертификатом разработчика, а sideload-сборка такого не получает.\n\nОбход — веб-приложение на экране «Домой». Уведомления шлёт сам сервер MAX через Apple, а показывает их отдельная иконка.\n\nДля этого нужна веб-сессия. Комет создаст её и подтвердит сам, с этого же устройства — вводить номер и код не придётся.';

  @override
  String get webPushConfirm => 'Продолжить';

  @override
  String get webPushPasswordExplainer =>
      'На аккаунте включена двухфакторная защита.';

  @override
  String webPushPasswordHintLabel(String hint) {
    return 'Подсказка: $hint';
  }

  @override
  String get webPushPasswordHint => 'Пароль';

  @override
  String get webPushInstallTitle => 'Установите приложение';

  @override
  String get webPushInstallBody =>
      'Откройте push.komet.pw в Safari, добавьте на экран «Домой» и запустите появившуюся иконку. Из вкладки браузера уведомления не работают — так устроена iOS.\n\nВ приложении разрешите уведомления, создайте подписку и нажмите «Открыть Комет». Дальше подписка зарегистрируется сама.';

  @override
  String get webPushLinkedTitle => 'Уведомления подключены';

  @override
  String get webPushLinkedBody =>
      'Подписка зарегистрирована на сервере. Не удаляйте иконку с экрана «Домой» — вместе с ней пропадут уведомления.\n\nЕсли пуши перестанут приходить, откройте приложение и свяжите заново: Apple иногда меняет адрес подписки.';

  @override
  String get webPushOpenSite => 'Открыть push.komet.pw';

  @override
  String get webPushSignOut => 'Отключить уведомления';

  @override
  String get webPushLinked => 'Уведомления подключены';

  @override
  String webPushLinkFailed(String error) {
    return 'Не удалось подключить уведомления: $error';
  }

  @override
  String get webPushNotAuthorized =>
      'Сначала войдите в разделе «Уведомления через PWA»';

  @override
  String get webPushConnect => 'Подключить уведомления';

  @override
  String get webPushWaitingBody =>
      'Комет подтверждает вход веб-сессии с этого устройства. Обычно занимает несколько секунд.';

  @override
  String get webPushNeedsOnline =>
      'Нет связи с сервером. Дождитесь подключения и попробуйте снова.';

  @override
  String get webPushSignOutConfirm =>
      'Веб-сессия будет завершена и исчезнет из списка устройств. Чтобы вернуть уведомления, подключение придётся пройти заново.';

  @override
  String get webPushSignOutAction => 'Отключить';

  @override
  String get webPushStatusService => 'Сервис';

  @override
  String get webPushStatusToken => 'Токен';

  @override
  String get webPushStatusLinkedAt => 'Привязан';

  @override
  String get webPushStatusDevice => 'Устройство';

  @override
  String get securityDeleteProfileTitle => 'Удалить профиль';

  @override
  String get securityDeleteProfileSubtitle =>
      'Профиль и все данные удалятся через 30 дней';

  @override
  String get securityDeleteProfileConfirmTitle => 'Удалить профиль?';

  @override
  String get securityDeleteProfileConfirmMessage =>
      'Ваш профиль MAX будет удалён через 30 дней. До этого момента заявку можно отменить.';

  @override
  String get securityDeleteProfileConfirmAction => 'Удалить';

  @override
  String securityDeleteProfileScheduled(String date) {
    return 'Профиль будет удалён $date';
  }

  @override
  String get securityDeleteProfileKeep => 'Не удалять профиль';

  @override
  String get securityDeleteProfileRequested => 'Заявка на удаление принята';

  @override
  String get securityDeleteProfileCanceled => 'Удаление профиля отменено';

  @override
  String securityDeleteProfileError(String error) {
    return 'Не удалось отправить запрос: $error';
  }

  @override
  String get composerPasteAttachment => 'Вставить файл';

  @override
  String get pasteAttachTitleImage => 'Отправить изображение';

  @override
  String get pasteAttachTitleVideo => 'Отправить видео';

  @override
  String get pasteAttachTitleFile => 'Отправить файл';

  @override
  String pasteAttachTitleMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отправить $count файла',
      many: 'Отправить $count файлов',
      few: 'Отправить $count файла',
      one: 'Отправить $count файл',
    );
    return '$_temp0';
  }

  @override
  String get pasteAttachCaptionHint => 'Подпись';

  @override
  String get pasteAttachSend => 'Отправить';

  @override
  String get pasteAttachCancel => 'Отмена';

  @override
  String get pasteAttachFailed => 'В буфере обмена нечего вставить';

  @override
  String get profileQrTitle => 'Мой QR-код';

  @override
  String get profileQrHint => 'Отсканируйте код, чтобы открыть профиль';

  @override
  String get profileQrUnavailable => 'Не удалось получить ссылку на профиль';

  @override
  String get authLimitsLoginTitle => 'Аккаунт временно ограничен';

  @override
  String authLimitsLoginSubtitle(DateTime until) {
    final intl.DateFormat untilDateFormat = intl.DateFormat(
      'd MMMM, HH:mm',
      localeName,
    );
    final String untilString = untilDateFormat.format(until);

    return 'Ограничения снимутся примерно $untilString';
  }

  @override
  String get authLimitsLogin2faTitle => 'Двухфакторная аутентификация';

  @override
  String get authLimitsLogin2faBody =>
      'Нельзя установить или снять пароль для входа.';

  @override
  String get authLimitsLoginSessionsTitle => 'Завершение сеансов';

  @override
  String get authLimitsLoginSessionsBody =>
      'Нельзя завершить все сеансы сразу.';

  @override
  String get authLimitsSignupTitle => 'Аккаунт может быть ограничен';

  @override
  String get authLimitsSignupSubtitle =>
      'Ограничения выдают не всем, и сервер снимает их сам';

  @override
  String get authLimitsSignupMessagesTitle => 'Сообщения';

  @override
  String get authLimitsSignupMessagesBody =>
      'Возможно, писать получится только тем, у кого вы уже есть в контактах.';

  @override
  String get authLimitsSignupGroupsTitle => 'Группы';

  @override
  String get authLimitsSignupGroupsBody =>
      'Вступление в группы может быть недоступно.';

  @override
  String get authLimitsSignupMoreTitle => 'Возможны и другие ограничения';

  @override
  String get authLimitsSignupMoreBody =>
      'Полного списка сервер не сообщает — если действие не сработало, попробуйте позже.';

  @override
  String get authLimitsConfirm => 'Понятно';

  @override
  String get e2eeTitle => 'Сквозное шифрование';

  @override
  String get e2eeStatusNone => 'Выключено';

  @override
  String e2eeStatusOffered(String name) {
    return 'Ждём, пока $name примет запрос';
  }

  @override
  String e2eeStatusPending(String name) {
    return '$name предлагает включить шифрование';
  }

  @override
  String get e2eeStatusEstablished => 'Включено';

  @override
  String e2eeStatusKeyChanged(String name) {
    return 'Ключ шифрования $name изменился';
  }

  @override
  String get e2eeEnable => 'Включить';

  @override
  String get e2eeAccept => 'Принять';

  @override
  String get e2eeDecline => 'Отклонить';

  @override
  String get e2eeCancelOffer => 'Отменить запрос';

  @override
  String get e2eeReset => 'Сбросить сессию';

  @override
  String get e2eeResetConfirm =>
      'Сбросить зашифрованную сессию? Обеим сторонам придётся включить шифрование заново.';

  @override
  String get e2eeFingerprint => 'Код безопасности';

  @override
  String e2eeFingerprintHint(String name) {
    return 'Сравните эти 60 цифр с $name вне MAX — при встрече или по другому каналу. Совпадают — значит, сервер не подменил ключи.';
  }

  @override
  String get e2eeVerified => 'Проверено лично';

  @override
  String get e2eeCeiling =>
      'Шифруется только текст сообщений и фото. Сервер по-прежнему видит, кто с кем и когда переписывается, видит, что переписка зашифрована, и может не доставлять сообщения. Скрыть это нельзя.';

  @override
  String e2eeNeedsKomet(String name) {
    return 'Чтобы это работало, $name должен пользоваться Komet.';
  }

  @override
  String get e2eeOfferSent => 'Запрос отправлен';

  @override
  String get e2eeOfferFailed => 'Не удалось отправить запрос';

  @override
  String get e2eeAcceptFailed => 'Не удалось принять запрос';

  @override
  String e2eeBannerPending(String name) {
    return '$name предлагает включить сквозное шифрование';
  }

  @override
  String e2eeBannerKeyChanged(String name) {
    return 'Ключ шифрования $name изменился. Проверьте код безопасности, прежде чем принять.';
  }

  @override
  String get e2eeTransferTitle => 'Перенос на другое устройство';

  @override
  String get e2eeTransferHint =>
      'Файл переноса содержит ваш ключ и сессии. После импорта на новом устройстве перестаньте пользоваться этим для зашифрованных чатов.';

  @override
  String get e2eeExport => 'Экспортировать';

  @override
  String get e2eeImport => 'Импортировать';

  @override
  String get e2eeTransferPassword => 'Пароль переноса';

  @override
  String get e2eeExportFailed => 'Не удалось экспортировать';

  @override
  String e2eeImported(int count) {
    return 'Перенесено сессий: $count';
  }

  @override
  String get e2eeImportFailed =>
      'Не удалось импортировать — неверный пароль или повреждённый файл';

  @override
  String get e2eeLegacyNote =>
      'Парольный режим для групп: без forward secrecy, любой, кто знает пароль, читает всю историю.';

  @override
  String get e2eeTooLong =>
      'Сообщение слишком длинное для зашифрованного чата. Разделите его.';

  @override
  String get e2eeEncryptFailed => 'Не удалось зашифровать сообщение';

  @override
  String get e2eeRotateIdentity => 'Сменить свой ключ';

  @override
  String get e2eeRotateConfirm =>
      'Создать новый ключ? Все зашифрованные сессии сбросятся, собеседники увидят предупреждение о смене ключа, коды безопасности изменятся.';

  @override
  String get e2eeRotated => 'Ключ заменён';

  @override
  String get e2eeRotateFailed => 'Не удалось заменить ключ';

  @override
  String get e2eeForwardBlocked =>
      'В зашифрованном чате пересылка недоступна: текст сообщения подставил бы сервер, а не ваше устройство.';

  @override
  String get e2eeEditUnavailable =>
      'Это сообщение не расшифровать на этом устройстве, поэтому его нельзя изменить.';

  @override
  String get e2eeScheduledMediaBlocked =>
      'Отложенные фото в зашифрованном чате пока не поддерживаются. Отправьте сейчас или выключите шифрование.';

  @override
  String get e2eeSearchBlocked =>
      'В зашифрованном чате поиск недоступен: запрос ушёл бы на сервер, а сервер видит только шифртекст.';

  @override
  String get e2eeAwaitingPeer =>
      'Сессия перенесена с другого устройства. Дождитесь одного сообщения от собеседника, иначе оба устройства выведут одинаковый ключ.';

  @override
  String e2eeBannerRehandshake(String name) {
    return '$name заново включает шифрование. Принимайте, только если этого ждали — иначе сервер повторяет старый запрос, чтобы сбросить вашу сессию.';
  }

  @override
  String get e2eeExportedAndDisabled =>
      'Перенос создан. На этом устройстве шифрование выключено: импортируйте файл на новом и включите там.';

  @override
  String get chatNoAccessMessage => 'У вас нет доступа к этому чату';

  @override
  String get chatNoAccessOk => 'Ок';

  @override
  String get chatEmptyTitle => 'Сообщений пока нет';

  @override
  String get chatGreetingHint => 'Напишите сообщение или отправьте этот стикер';

  @override
  String get chatCallBannerTitle => 'Звонок в чате';

  @override
  String get chatVideoCallBannerTitle => 'Видеозвонок в чате';

  @override
  String chatCallParticipants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String get chatCallJoin => 'Присоединиться';

  @override
  String get composerHintMessage => 'Сообщение';

  @override
  String get composerHintComment => 'Комментарий';

  @override
  String get composerHintCommandArgs => 'Заполните аргументы команды';

  @override
  String get emojiPanelRecent => 'Недавние';

  @override
  String get emojiPanelAnimated => 'Анимированные';

  @override
  String get attachmentFileFallback => 'Файл';

  @override
  String get attachmentContactFallback => 'Контакт';

  @override
  String userFallbackName(Object id) {
    return 'Пользователь #$id';
  }

  @override
  String get devicesUnknownValue => 'Неизвестно';

  @override
  String infoLoadError(Object error) {
    return 'Ошибка: $error';
  }

  @override
  String get chatInfoTabInfo => 'Инфо';

  @override
  String get callInfoConversationId => 'ID разговора';

  @override
  String get chatQrTitle => 'QR-код';

  @override
  String get chatQrHint => 'Отсканируйте код, чтобы открыть чат';

  @override
  String get linkQrUnavailable => 'Не удалось получить ссылку';

  @override
  String get notificationsDesktopNote =>
      'На компьютере уведомления пока не показываются. Ниже — push-настройки аккаунта для телефонов.';

  @override
  String get fileNoAppToOpen =>
      'Нет приложения, чтобы открыть этот файл. Выберите, куда его отправить.';

  @override
  String get lockTitle => 'Введите код-пароль';

  @override
  String get lockBiometricReason => 'Разблокируйте Komet';

  @override
  String lockBlocked(String time) {
    return 'Слишком много попыток. Повторите через $time';
  }

  @override
  String lockAttemptsLeft(int count) {
    return 'Неверный код-пароль. Осталось попыток: $count';
  }

  @override
  String get lockNow => 'Заблокировать Komet';

  @override
  String get passcodeTitle => 'Код-пароль';

  @override
  String get passcodeCreate => 'Придумайте код-пароль';

  @override
  String get passcodeRepeat => 'Повторите код-пароль';

  @override
  String get passcodeMismatch => 'Коды не совпали, попробуйте ещё раз';

  @override
  String get passcodeDigitsHint => 'Четыре цифры';

  @override
  String get passcodeEnable => 'Включить код-пароль';

  @override
  String get passcodeEnabled => 'Код-пароль включён';

  @override
  String get passcodeChanged => 'Код-пароль изменён';

  @override
  String get passcodeChange => 'Сменить код-пароль';

  @override
  String get passcodeBiometric => 'Разблокировка по биометрии';

  @override
  String get passcodeBiometricHint => 'Отпечаток или лицо вместо кода';

  @override
  String get passcodeAutoLock => 'Автоблокировка';

  @override
  String get passcodeAutoLockHint =>
      'Блокировать Komet, если им не пользоваться';

  @override
  String get passcodeAutoLockOff => 'Выключена';

  @override
  String passcodeAutoLockAfter(int minutes) {
    return 'Через $minutes мин';
  }

  @override
  String get passcodeDisable => 'Выключить код-пароль';

  @override
  String get passcodeDisableTitle => 'Выключить код-пароль?';

  @override
  String get passcodeDisableMessage =>
      'Komet будет открываться без кода-пароля.';

  @override
  String get passcodeDisableAction => 'Выключить';

  @override
  String get passcodeCancel => 'Отмена';

  @override
  String get passcodeDisabled => 'Код-пароль выключен';

  @override
  String get passcodeOnDescription =>
      'Komet спрашивает код при каждом входе. Замок в шапке списка чатов закрывает его сразу.';

  @override
  String get passcodeOffDescription =>
      'Защитите переписку: Komet будет спрашивать код при каждом входе.';

  @override
  String get passcodeForgotHint =>
      'Если забудете код, придётся очистить данные Komet или переустановить его и войти заново. После пяти неверных попыток ввод блокируется на пять минут.';

  @override
  String get mediaDevicesTitle => 'Камера и микрофон';

  @override
  String get mediaDevicesMicrophone => 'Микрофон';

  @override
  String get mediaDevicesMicrophoneHint => 'Для звонков и голосовых сообщений';

  @override
  String get mediaDevicesCamera => 'Камера';

  @override
  String get mediaDevicesCameraHint => 'Для звонков и, по желанию, для кружков';

  @override
  String get mediaDevicesSystemMicrophone => 'Системный микрофон';

  @override
  String get mediaDevicesSystemCamera => 'Системная камера';

  @override
  String mediaDevicesCameraFallback(int number) {
    return 'Камера $number';
  }

  @override
  String get mediaDevicesFront => 'Фронтальная';

  @override
  String get mediaDevicesBack => 'Тыловая';

  @override
  String get mediaDevicesVideoNotes => 'Кружки';

  @override
  String get mediaDevicesVideoNoteCustom => 'Своя камера';

  @override
  String get mediaDevicesVideoNoteCustomHint =>
      'Снимать кружки камерой, выбранной выше';

  @override
  String get mediaDevicesVideoNoteCustomMissing =>
      'Выберите камеру выше, пока снимает системная';

  @override
  String get mediaDevicesVideoNoteRear => 'Начинать с тыловой камеры';

  @override
  String get mediaDevicesVideoNoteRearHint =>
      'Иначе кружок открывается с фронтальной';

  @override
  String get chatPreviewMarkRead => 'Пометить прочитанным';

  @override
  String get chatPreviewOpen => 'Открыть';

  @override
  String get attachSheetSendAsVideoNote => 'Отправить как кружок';

  @override
  String attachSheetVideoNoteTooLong(int seconds) {
    return 'Кружок не может быть длиннее $seconds с';
  }

  @override
  String get undoAction => 'Отменить';

  @override
  String get undoContinue => 'Продолжить';

  @override
  String get undoMessageUnpinned => 'Вы открепили сообщение';

  @override
  String undoMessagesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сообщения удалены',
      many: '$count сообщений удалено',
      few: '$count сообщения удалены',
      one: 'Сообщение удалено',
    );
    return '$_temp0';
  }

  @override
  String undoChatsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count чата удалены',
      many: '$count чатов удалено',
      few: '$count чата удалены',
      one: 'Чат удалён',
    );
    return '$_temp0';
  }

  @override
  String undoChatsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count чата в архиве',
      many: '$count чатов в архиве',
      few: '$count чата в архиве',
      one: 'Чат в архиве',
    );
    return '$_temp0';
  }

  @override
  String undoChatsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count чата возвращены из архива',
      many: '$count чатов возвращено из архива',
      few: '$count чата возвращены из архива',
      one: 'Чат возвращён из архива',
    );
    return '$_temp0';
  }

  @override
  String get undoLeftGroup => 'Вы вышли из группы';

  @override
  String get undoLeftChannel => 'Вы отписались от канала';

  @override
  String get forwardHideSender => 'Скрыть имя отправителя';

  @override
  String get forwardShowSender => 'Показать имя отправителя';

  @override
  String get forwardHideSenderUnavailable =>
      'Опросы, звонки и служебные сообщения пересылаются только с именем отправителя';

  @override
  String get forwardWithoutSender => 'Пересылка без автора';

  @override
  String forwardWithoutSenderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Пересылка без автора: $count сообщения',
      many: 'Пересылка без автора: $count сообщений',
      few: 'Пересылка без автора: $count сообщения',
      one: 'Пересылка без автора: $count сообщение',
    );
    return '$_temp0';
  }

  @override
  String get adminsTitle => 'Администраторы';

  @override
  String get channelFollowersTitle => 'Подписчики';

  @override
  String get channelStatsTitle => 'Статистика канала';

  @override
  String get channelStatsUnavailable => 'Статистика канала пока недоступна';

  @override
  String get adminsAdd => 'Добавить администратора';

  @override
  String get channelPickAdminTitle => 'Выберите подписчика';

  @override
  String get adminsPickEmpty => 'Некого назначить';

  @override
  String get membersSearchHint => 'Найти по имени';

  @override
  String adminRoleYou(String role) {
    return '$role (вы)';
  }

  @override
  String get channelAddFollowers => 'Добавить подписчиков';

  @override
  String get channelFollowersEmpty => 'Подписчиков пока нет';

  @override
  String get membersLoadFailed => 'Не удалось загрузить список';

  @override
  String get adminAppointTitle => 'Назначить администратора';

  @override
  String get adminEditTitle => 'Права администратора';

  @override
  String get channelRightEditChannel => 'Изменять канал';

  @override
  String get adminRightEditInfoHint => 'Фото, название, описание';

  @override
  String get channelRightCreatePosts => 'Публиковать посты';

  @override
  String get channelRightEditPosts => 'Редактировать чужие посты';

  @override
  String get channelRightDeletePosts => 'Удалять чужие посты';

  @override
  String get channelRightPinPosts => 'Закреплять посты';

  @override
  String get channelRightManageFollowers => 'Добавлять и удалять подписчиков';

  @override
  String get channelRightViewStats => 'Смотреть статистику канала';

  @override
  String get adminRightManageAdmins => 'Назначать и снимать администраторов';

  @override
  String get adminRightManageAdminsHint =>
      'Сможет снимать только тех администраторов, которых назначил сам';

  @override
  String get adminAppointAction => 'Назначить администратором';

  @override
  String get adminSave => 'Сохранить';

  @override
  String get adminAppointed => 'Администратор назначен';

  @override
  String get adminSaved => 'Права сохранены';

  @override
  String get ownershipTransfer => 'Передать права владельца';

  @override
  String ownershipTransferConfirm(String name) {
    return '$name станет новым владельцем.';
  }

  @override
  String get ownershipTransferAction => 'Передать';

  @override
  String get ownershipTransferred => 'Права владельца переданы';

  @override
  String get adminRemove => 'Снять с администраторов';

  @override
  String adminRemoveConfirm(String name) {
    return '$name больше не будет администратором.';
  }

  @override
  String get adminRemoveAction => 'Снять';

  @override
  String get adminRemoved => 'Снят с администраторов';

  @override
  String get adminActionFailed => 'Не удалось применить изменения';

  @override
  String get channelInviteSendInMax => 'Отправить в MAX';

  @override
  String get channelInviteShowQr => 'Показать QR-код';

  @override
  String get channelInviteRevoke => 'Перевыпустить ссылку';

  @override
  String get channelInviteRevokeConfirm =>
      'Текущая ссылка перестанет работать, вступить можно будет только по новой.';

  @override
  String get channelInviteRevokeAction => 'Перевыпустить';

  @override
  String get channelInviteRevoked => 'Ссылка перевыпущена';

  @override
  String get channelJoinRequests => 'Заявки на вступление';

  @override
  String get channelJoinRequestsHint =>
      'Вступить в канал можно будет только после одобрения заявки администратором';

  @override
  String get groupPickAdminTitle => 'Выберите участника';

  @override
  String get groupRightEditInfo => 'Изменять чат';

  @override
  String get groupRightDeleteMessages => 'Удалять сообщения';

  @override
  String get groupRightPinMessages => 'Закреплять сообщения';

  @override
  String get groupRightManageMembers => 'Добавлять и удалять участников';

  @override
  String get groupRightEditLink => 'Обновлять ссылку на чат';

  @override
  String get groupSettingsTitle => 'Настройки группы';

  @override
  String get groupSettingsName => 'Название чата';

  @override
  String get groupSettingsDescription => 'Описание чата';

  @override
  String get groupSettingsSaved => 'Изменения сохранены';

  @override
  String get groupSettingsPhotoUpdated => 'Фото обновлено';

  @override
  String get groupSettingsPhotoTooLarge =>
      'Картинка слишком большая (макс 8 МБ)';

  @override
  String get groupSettingsLeave => 'Покинуть чат';

  @override
  String get reactionsTitle => 'Реакции';

  @override
  String get reactionsSummaryAll => 'Все';

  @override
  String get reactionsSummaryOff => 'Выключены';

  @override
  String reactionsSummaryCount(int allowed, int total) {
    return '$allowed из $total';
  }

  @override
  String get reactionsEnable => 'Включить реакции';

  @override
  String get reactionsCountHeader => 'Количество реакций к публикации';

  @override
  String reactionsCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count реакции',
      many: '$count реакций',
      few: '$count реакции',
      one: '$count реакция',
    );
    return '$_temp0';
  }

  @override
  String get reactionsAllowedHeader => 'Разрешённые реакции';

  @override
  String get reactionsEdit => 'Изменить';

  @override
  String get reactionsDone => 'Готово';

  @override
  String get reactionsReset => 'Сбросить настройки реакций';

  @override
  String get reactionsLoadFailed => 'Не удалось загрузить настройки реакций';

  @override
  String get reactionsNoneAllowed => 'Оставьте хотя бы одну реакцию';

  @override
  String get memberPermissionsTitle => 'Разрешения участников';

  @override
  String get memberPermissionEditInfo =>
      'Изменять название, фото и описание чата';

  @override
  String get memberPermissionAddMembers => 'Добавлять участников';

  @override
  String get memberPermissionPin => 'Закреплять сообщения';

  @override
  String get memberPermissionInvite => 'Приглашать по ссылке';

  @override
  String get memberPermissionCall => 'Звонить в чате';

  @override
  String get ownerLeaveTitle => 'Вы владелец';

  @override
  String get ownerLeaveChannelMessage =>
      'Чтобы покинуть канал, сначала передайте права владельца другому подписчику.';

  @override
  String get ownerLeaveGroupMessage =>
      'Чтобы покинуть группу, сначала передайте права владельца другому участнику.';

  @override
  String get ownershipPickTitle => 'Новый владелец';

  @override
  String get ownershipPickEmpty => 'Некому передать права';

  @override
  String get forwardOneTitle => 'Переслать сообщение';

  @override
  String forwardBatchTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Переслать $count сообщения',
      many: 'Переслать $count сообщений',
      few: 'Переслать $count сообщения',
      one: 'Переслать $count сообщение',
    );
    return '$_temp0';
  }

  @override
  String get forwardCommentHint => 'Добавить комментарий...';

  @override
  String get forwardOffline => 'Нет соединения';

  @override
  String get forwardFailed => 'Не удалось переслать';

  @override
  String forwardDelivered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Переслано в $count чата',
      many: 'Переслано в $count чатов',
      few: 'Переслано в $count чата',
      one: 'Переслано в $count чат',
    );
    return '$_temp0';
  }

  @override
  String forwardDeliveredPartly(int delivered, int failed) {
    return 'Переслано в $delivered, не удалось в $failed';
  }

  @override
  String get reactionUnavailable => 'Эта реакция недоступна в чате';

  @override
  String get membersSearchMore => 'Искать среди остальных';

  @override
  String get groupRestrictionsTitle => 'Ограничения';

  @override
  String get groupRestrictionForward => 'Запретить пересылку';

  @override
  String get groupRestrictionForwardHint =>
      'Сообщения из этого чата нельзя будет переслать';

  @override
  String get groupRestrictionCopy => 'Запретить копирование';

  @override
  String get groupRestrictionCopyHint =>
      'Текст сообщений нельзя будет скопировать';

  @override
  String get groupRestrictionConfirmSend => 'Подтверждать отправку';

  @override
  String get groupRestrictionConfirmSendHint =>
      'Перед отправкой каждого сообщения будет появляться подтверждение';

  @override
  String get notificationsBadgeSectionTitle => 'Счётчик на иконке';

  @override
  String get notificationsBadgeLabel => 'Показывать счётчик';

  @override
  String get notificationsBadgeMutedLabel => 'Учитывать чаты без звука';

  @override
  String get notificationsBadgeMessagesLabel => 'Считать сообщения';

  @override
  String get notificationsBadgeMessagesSubtitle =>
      'Если выключено — считаются непрочитанные чаты';

  @override
  String get accountSwitchFailed => 'Не удалось переключить аккаунт';

  @override
  String get accountSessionLostTitle => 'Нужно войти заново';

  @override
  String accountSessionLostBody(String name) {
    return 'Сессия аккаунта «$name» на этом устройстве больше не действует.';
  }

  @override
  String get accountSessionLostSignIn => 'Войти';

  @override
  String get accountSessionLostRemove => 'Удалить с устройства';

  @override
  String get accountSessionLostRemoved => 'Аккаунт удалён с устройства';

  @override
  String get contactsSearchHint => 'Поиск по контактам';

  @override
  String get contactsSearchEmpty => 'Ничего не найдено';

  @override
  String get contactsNfcExchange => 'Обмен по NFC';

  @override
  String get contactsFindUser => 'Добавить контакт';

  @override
  String get contactDeleted => 'Контакт удалён';

  @override
  String get contactDeleteFailed => 'Не удалось удалить контакт';

  @override
  String get contactLocalPhotoChoose => 'Выбрать фото';

  @override
  String get contactLocalPhotoReset => 'Вернуть фото профиля';

  @override
  String get contactLocalPhotoSaved => 'Фото видно только вам';

  @override
  String get contactLocalPhotoFailed => 'Не удалось обработать изображение';

  @override
  String get contactLocalPhotoTooLarge =>
      'Картинка слишком большая (макс. 8 МБ)';

  @override
  String get channelTypeTitle => 'Тип канала и ссылка';

  @override
  String get channelCreatedTitle => 'Приватный канал создан';

  @override
  String get channelCreatedSubtitle => 'Его уже можно настроить';

  @override
  String get channelTypePrivate => 'Приватный';

  @override
  String get channelTypePrivateHint => 'Канал доступен только по ссылке';

  @override
  String get channelTypePublic => 'Публичный';

  @override
  String get channelTypePublicHint => 'Канал можно найти в поиске';

  @override
  String get channelTypePublicUnavailable => 'Публичные каналы пока недоступны';

  @override
  String get channelInviteLinkCaption => 'Ссылка-приглашение в ваш канал';

  @override
  String get channelBusinessTitle => 'Публичный для бизнеса';

  @override
  String get channelBusinessHint =>
      'Для юрлиц, ИП, самозанятых и госорганизаций';

  @override
  String get channelSettingsTitle => 'Настройки канала';

  @override
  String get channelSettingsName => 'Название канала';

  @override
  String get channelSettingsDescription => 'Описание канала';

  @override
  String get channelConfirmPosting => 'Подтверждать публикацию';

  @override
  String get channelConfirmPostingHint =>
      'Чтобы перепроверить пост и избежать ошибок';

  @override
  String get channelComments => 'Комментарии';

  @override
  String get channelCommentsEnableTitle => 'Комментарии — часть вашего канала';

  @override
  String get channelCommentsEnableMessage =>
      'Следите за обсуждениями и поддерживайте порядок: комментарии можно удалять, а пользователей — ограничивать';

  @override
  String get channelCommentsEnable => 'Включить';

  @override
  String get channelCommentsKeepOff => 'Не включать';

  @override
  String get channelDelete => 'Удалить канал';

  @override
  String get channelDeleteTitle => 'Удалить канал?';

  @override
  String get channelDeleteMessage =>
      'Чтобы канал не удалился у всех подписчиков, можно передать права другому владельцу';

  @override
  String get channelDeleteTransfer => 'Передать права и выйти';

  @override
  String get followerRemove => 'Удалить';

  @override
  String get followerRemoveTitle => 'Удалить подписчика';

  @override
  String followerRemoveConfirm(String name) {
    return '$name больше не будет подписан на канал.';
  }

  @override
  String get followerRemoved => 'Подписчик удалён';

  @override
  String get channelReadyTitle => 'Канал готов';

  @override
  String get channelReadyHint => 'Публикуйте посты и приглашайте подписчиков';

  @override
  String get groupReadyTitle => 'Группа готова';

  @override
  String get groupReadyHint =>
      'Напишите первое сообщение и пригласите участников';

  @override
  String get botStart => 'Начать';

  @override
  String get memberRemoveTitle => 'Удалить участника';

  @override
  String memberRemoveConfirm(String name) {
    return '$name будет удалён из группы.';
  }

  @override
  String get memberRemoved => 'Участник удалён';

  @override
  String get chatScreenReactionUpdateFailed => 'Не удалось обновить реакцию';

  @override
  String get chatScreenBotStartFailed => 'Не удалось запустить бота';

  @override
  String get chatScreenMessageNotLoaded => 'Сообщение не загружено';

  @override
  String get chatScreenMarkUnreadFailed => 'Не удалось пометить непрочитанным';

  @override
  String get chatScreenMessagePinned => 'Сообщение закреплено';

  @override
  String get chatScreenNothingToForward => 'Нечего пересылать';

  @override
  String get chatScreenDeleteMessagesFailed => 'Не удалось удалить сообщения';

  @override
  String get chatScreenDeleteMessageTitle => 'Удалить сообщение';

  @override
  String get chatScreenDeleteMessageConfirm =>
      'Вы точно хотите удалить это сообщение?';

  @override
  String chatScreenDeleteAlsoFor(String name) {
    return 'Также удалить для $name';
  }

  @override
  String get chatScreenMenuMute => 'Отключить уведомления';

  @override
  String get chatScreenMenuChangeWallpaper => 'Изменить обои';

  @override
  String get chatScreenMenuEncryption => 'Шифрование сообщений';

  @override
  String get chatScreenChatLinkUnavailable => 'Не удалось получить ссылку чата';

  @override
  String get chatScreenSubscribeFailed => 'Не удалось подписаться';

  @override
  String get chatScreenJoinFailed => 'Не удалось вступить';

  @override
  String get chatScreenWallpaperSaveFailed => 'Не удалось сохранить обои';

  @override
  String get chatScreenCallsDialogsOnly => 'Звонки доступны только в диалогах';

  @override
  String chatScreenMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String chatScreenSubscribersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count подписчика',
      many: '$count подписчиков',
      few: '$count подписчика',
      one: '$count подписчик',
    );
    return '$_temp0';
  }

  @override
  String get chatScreenFormatHeading => 'Заголовок';

  @override
  String get chatScreenFormatBold => 'Жирный';

  @override
  String get chatScreenFormatItalic => 'Курсив';

  @override
  String get chatScreenFormatUnderline => 'Подчёркнутый';

  @override
  String get chatScreenFormatStrikethrough => 'Зачёркнутый';

  @override
  String get chatScreenFormatMonospace => 'Моноширинный';

  @override
  String get chatScreenFormatQuote => 'Цитата';

  @override
  String get chatScreenFormatMention => 'Упоминание';

  @override
  String get chatScreenMessageTooLong =>
      'Слишком длинное сообщение. Разделите на несколько';

  @override
  String get chatScreenEncryptionKeyMissing => 'Не задан ключ шифрования';

  @override
  String get chatScreenPluginFilesEncryptUnsupported =>
      'Файлы плагинов пока нельзя зашифровать';

  @override
  String chatScreenCommandMissingArgument(String name, String usage) {
    return 'Не указан аргумент $name. Формат: $usage';
  }

  @override
  String chatScreenPluginError(String error) {
    return 'Ошибка плагина: $error';
  }

  @override
  String chatScreenCommandFillField(String name) {
    return 'Заполните поле $name';
  }

  @override
  String chatScreenScheduledFor(String when) {
    return 'Запланировано на $when';
  }

  @override
  String get chatScreenScheduleFailed => 'Не удалось запланировать сообщение';

  @override
  String get chatScreenMessageNotSentYet => 'Сообщение ещё не отправлено';

  @override
  String get chatScreenChannelUnavailable => 'Канал недоступен';

  @override
  String get chatScreenChannelFallback => 'Канал';

  @override
  String get chatScreenNoEncryptFiles => 'Файлы пока нельзя зашифровать';

  @override
  String get chatScreenNoEncryptLocation =>
      'Геолокацию пока нельзя зашифровать';

  @override
  String get chatScreenNoEncryptPolls => 'Опросы пока нельзя зашифровать';

  @override
  String get chatScreenNoEncryptContacts => 'Контакты пока нельзя зашифровать';

  @override
  String get stickerPackSheetRemoved => 'Стикерпак удалён';

  @override
  String get stickerPackSheetAdded => 'Стикерпак добавлен';

  @override
  String get stickerPackSheetActionFailed => 'Не удалось выполнить действие';

  @override
  String get stickerPackSheetLinkUnavailable => 'Ссылка недоступна';

  @override
  String stickerPackSheetForwardedTo(String chat) {
    return 'Переслано в «$chat»';
  }

  @override
  String get stickerPackSheetUnavailable => 'Стикерпак недоступен';

  @override
  String stickerPackSheetStickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count стикера',
      many: '$count стикеров',
      few: '$count стикера',
      one: '$count стикер',
    );
    return '$_temp0';
  }

  @override
  String get stickerPackSheetRemove => 'Убрать';

  @override
  String get performanceScreenTitle => 'Производительность';

  @override
  String get performanceScreenLowWarning =>
      'Производительность приложения может снизиться, вы уверены?';

  @override
  String get performanceScreenHighWarning =>
      'Это врядли даст хотя-бы немного заметный прирост к FPS, но может потреблять больше памяти. Вы уверены?';

  @override
  String get performanceScreenCacheTitle => 'Кеш сообщений';

  @override
  String get performanceScreenCacheSubtitle =>
      'Сколько пикселей сообщений держать построенными за пределами видимой области.';

  @override
  String performanceScreenCurrentExtent(int value) {
    return 'Текущий cacheExtent: $value';
  }

  @override
  String get performanceScreenLessUsage => 'Меньше потребление';

  @override
  String get performanceScreenMoreFps => 'Больше FPS';

  @override
  String get chatWallpaperSheetImageTooLarge =>
      'Картинка слишком большая (макс 16 МБ)';

  @override
  String get chatWallpaperSheetTitle => 'Обои';

  @override
  String get chatWallpaperSheetSampleIncoming =>
      'Как насчёт новых обоев для этого чата?';

  @override
  String get chatWallpaperSheetSampleOutgoing => 'Выглядит отлично 🔥';

  @override
  String get chatWallpaperSheetNone => 'Без обоев';

  @override
  String get chatWallpaperSheetYourPhoto => 'Ваше фото';

  @override
  String get chatWallpaperSheetFromGallery => 'Из галереи';

  @override
  String get maxLinkNavChatNotFound => 'Чат не найден';

  @override
  String get maxLinkNavProfileFallback => 'Профиль';

  @override
  String get maxLinkNavPlatformUnsupported =>
      'На вашей платформе это недоступно';

  @override
  String get maxLinkNavAppFallback => 'Приложение';

  @override
  String get maxLinkNavNothingToSend => 'Нечего отправлять';

  @override
  String get maxLinkNavFolderNotFound => 'Папка не найдена';

  @override
  String get maxLinkNavSignInFirst => 'Сначала войдите в аккаунт';

  @override
  String get pollCreateValidationHint => 'Введите вопрос и минимум 2 варианта';

  @override
  String get pollCreateAnswersTitle => 'Варианты ответа';

  @override
  String get pollCreateMultipleAnswers => 'Несколько вариантов ответа';

  @override
  String get pollCreateAnonymous => 'Анонимное голосование';

  @override
  String get pollCreateTitle => 'Новый опрос';

  @override
  String get pollCreateSubmit => 'Создать';

  @override
  String get pollCreateQuestionHint => 'Задайте вопрос';

  @override
  String pollCreateOptionHint(int number) {
    return 'Вариант $number';
  }

  @override
  String get pollCreateAddOption => 'Добавить вариант';

  @override
  String get webQrLoginTitle => 'Вход по QR';

  @override
  String get webQrLoginMessage =>
      'Вы точно хотите войти в аккаунт через веб или приложение MAX на компьютере?';

  @override
  String get webQrLoginConfirmed => 'Вход подтверждён';

  @override
  String webQrLoginFailed(String error) {
    return 'Не удалось подтвердить вход: $error';
  }

  @override
  String get messageActionsScreenTitle => 'Меню действий';

  @override
  String get messageActionsScreenRadialDescription =>
      'Дуга кнопок вокруг точки нажатия';

  @override
  String get messageActionsScreenList => 'Список';

  @override
  String get messageActionsScreenListDescription =>
      'Вертикальное меню рядом с сообщением';

  @override
  String get messageActionsScreenStyle => 'Стиль';

  @override
  String get messageActionsScreenStyleSubtitle =>
      'Как показывается меню при долгом нажатии на сообщение';

  @override
  String get videoNoteBubbleTranscriptionFailed => 'Не удалось распознать';

  @override
  String get webAppScreenCloseConfirm => 'Закрыть мини-приложение?';

  @override
  String get voiceRecordUnsupported =>
      'Голосовые сообщения недоступны на этой платформе';

  @override
  String get voiceRecordNoMicAccess => 'Нет доступа к микрофону';

  @override
  String get voiceRecordStartFailed => 'Не удалось начать запись';

  @override
  String get voiceRecordEncodeFailed => 'Не удалось закодировать запись';

  @override
  String get spoofScreenFullWarningTitle => 'Могут быть последствия.';

  @override
  String get spoofScreenFullWarningSubtitle =>
      'Меняй, только если знаешь что делаешь.';

  @override
  String callScreenShareFailed(String error) {
    return 'Трансляция не запустилась: $error';
  }

  @override
  String get themeSettingsCustomizeAction => 'Настроить';

  @override
  String get chatListNavChats => 'Чаты';

  @override
  String get chatListNavCalls => 'Звонки';

  @override
  String get chatListNavContacts => 'Контакты';

  @override
  String get chatListShareSendFailed => 'Не удалось отправить';

  @override
  String chatListMuteFailedCount(int count, String error) {
    return 'Не удалось изменить $count чат(ов): $error';
  }

  @override
  String get chatListDeleteStatusChanged =>
      'Статус чатов изменился, попробуйте ещё раз';

  @override
  String chatListDeleteChatWith(String name) {
    return 'Удалить чат с $name?';
  }

  @override
  String chatListDeleteChatsCount(int count) {
    return 'Удалить $count чатов?';
  }

  @override
  String get chatListDeleteIrreversible =>
      'Восстановить переписку не получится';

  @override
  String chatListDeleteOwnedChat(String name) {
    return 'Хотите удалить чат «$name»?';
  }

  @override
  String chatListDeleteGroupsForAll(int count) {
    return 'Удалить $count групп у всех?';
  }

  @override
  String get chatListDeleteOwnedChatBody =>
      'Передайте права владельца, чтобы остальные участники могли продолжить общение';

  @override
  String get chatListDeleteCannotUndo => 'Действие нельзя отменить';

  @override
  String get chatListDeleteChatForAll => 'Удалить чат у всех';

  @override
  String get chatListDeleteForAll => 'Удалить у всех';

  @override
  String get chatListYourStory => 'Ваша история';

  @override
  String get chatListAllChatsFolder => 'Все чаты';

  @override
  String chatListRecipientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count получателя',
      many: '$count получателей',
      few: '$count получателя',
      one: '$count получатель',
    );
    return '$_temp0';
  }

  @override
  String get chatListSavedMessages => 'Избранное';

  @override
  String get chatListReadAll => 'Прочитать всё';

  @override
  String get chatListForwardingHint => 'Пересылка...';

  @override
  String get chatListEmpty => 'Кажется, тут пусто...';

  @override
  String get chatListOpenToLoad => 'зайдите в чат для подгрузки';

  @override
  String get chatListArchive => 'Архив';

  @override
  String get chatListNewStory => 'Новая история';

  @override
  String get chatListOpenVideoFailed => 'Не удалось открыть видео';

  @override
  String get chatListOpenPhotoFailed => 'Не удалось открыть фото';

  @override
  String get chatListDraftPrefix => 'Черновик: ';

  @override
  String get chatListPreviewWrongKey => 'неверный ключ';

  @override
  String get chatListPreviewUnavailable => 'недоступно на этом устройстве';

  @override
  String get chatListMessagePerson => 'Написать человеку';

  @override
  String get chatListCreateGroup => 'Создать группу';

  @override
  String get chatListCreateChannel => 'Создать канал';

  @override
  String get chatListCreateContact => 'Создать контакт';

  @override
  String get chatListCreateFolder => 'Создать папку';

  @override
  String get chatListMessageAction => 'Написать';

  @override
  String get chatListNoUnreadChats => 'Непрочитанных чатов нет';

  @override
  String get chatListAllMarkedRead => 'Все чаты отмечены прочитанными';

  @override
  String get callsTabStatusMissed => 'Пропущенный';

  @override
  String get callsTabStatusCanceled => 'Отменённый';

  @override
  String get callsTabStatusOutgoing => 'Исходящий';

  @override
  String get callsTabStatusIncoming => 'Входящий';

  @override
  String get callsTabCallBack => 'Перезвонить';

  @override
  String get callsTabPeerUnknown => 'Не удалось определить собеседника';

  @override
  String get callsTabAlreadyInCall => 'Звонок уже идёт';

  @override
  String callsTabStartFailed(String error) {
    return 'Не удалось начать звонок: $error';
  }

  @override
  String get callsTabJoinTitle => 'Присоединиться к звонку';

  @override
  String get callsTabJoinDescription => 'Вставьте ссылку-приглашение';

  @override
  String get callsTabNotACallLink => 'Это не ссылка на звонок';

  @override
  String get callsTabCreateCall => 'Создать звонок';

  @override
  String get callsTabMissed => 'Пропущенные';

  @override
  String get callsTabEmpty => 'Нет звонков';

  @override
  String get chatEncryptionProfileNotLoaded => 'Профиль ещё не загружен';

  @override
  String get chatEncryptionEnterKeyHint => 'Введите ключ шифрования';

  @override
  String get chatEncryptionEnabled => 'Шифрование включено';

  @override
  String get chatEncryptionDisabled => 'Шифрование отключено';

  @override
  String get chatEncryptionTitle => 'Шифрование сообщений';

  @override
  String get chatEncryptionToggle => 'Шифровать сообщения';

  @override
  String get chatEncryptionToggleSubtitle =>
      'Текст сообщений в этом чате будет зашифрован ключом ниже';

  @override
  String get chatEncryptionKeyLabel => 'Ключ';

  @override
  String get chatEncryptionKeyHint => 'Введите ключ';

  @override
  String get chatEncryptionKeyNote =>
      'Ключ хранится только на этом устройстве. Собеседник должен ввести такой же ключ, иначе он не прочитает сообщения. Это парольный режим для групп: без forward secrecy, любой, кто знает пароль, читает всю историю.';

  @override
  String get storyViewerDeleteTitle => 'Удалить историю?';

  @override
  String get storyViewerDeleteMessage =>
      'История пропадёт у всех, кто может её посмотреть.';

  @override
  String get storyViewerDeleteFailed => 'Не удалось удалить историю';

  @override
  String storyViewerDeleteFailedWithReason(String reason) {
    return 'Не удалось удалить историю: $reason';
  }

  @override
  String get storyViewerEmpty => 'Историй нет';

  @override
  String get storyViewerJustNow => 'только что';

  @override
  String storyViewerMinutesAgo(int count) {
    return '$count мин';
  }

  @override
  String storyViewerHoursAgo(int count) {
    return '$count ч';
  }

  @override
  String storyViewerDaysAgo(int count) {
    return '$count дн';
  }

  @override
  String get webviewPermissionCamera => 'камера';

  @override
  String get webviewPermissionMicrophone => 'микрофон';

  @override
  String get webviewPermissionCameraAndMicrophone => 'камера и микрофон';

  @override
  String get webviewPermissionGeolocation => 'геолокация';

  @override
  String get webviewPermissionOther => 'дополнительный доступ';

  @override
  String get webviewPermissionWebPage => 'Веб-страница';

  @override
  String get webviewPermissionTitle => 'Запрос доступа';

  @override
  String webviewPermissionMessage(String host, String resources) {
    return '$host запрашивает доступ к: $resources.';
  }

  @override
  String get webviewPermissionDeny => 'Запретить';

  @override
  String get createChannelFailed => 'Не удалось создать канал';

  @override
  String get createChannelAvatarProcessFailed =>
      'Не удалось обработать аватарку';

  @override
  String get createChannelAvatarUploadFailed => 'Не удалось загрузить аватарку';

  @override
  String get createChannelDescription =>
      'В канале публикуете только вы, участники читают. Пригласить их можно после создания.';

  @override
  String get createChannelCancel => 'Отменить';

  @override
  String get createChannelCreating => 'Создаю...';

  @override
  String get createChannelCreate => 'Создать';

  @override
  String get codeConfirmationConnectionDropped =>
      'Соединение прервалось, восстанавливаем…';

  @override
  String get codeConfirmationNoConnection => 'Нет соединения с сервером';

  @override
  String get codeConfirmationConnectionRestored => 'Соединение восстановлено';

  @override
  String codeConfirmationReconnectFailed(String error) {
    return 'Не удалось восстановить соединение: $error';
  }

  @override
  String codeConfirmationRefreshFailed(String error) {
    return 'Не удалось обновить код: $error';
  }

  @override
  String get codeConfirmationNewCodeSent => 'Выслали новый код';

  @override
  String get codeConfirmationSmsNoToken => 'SMS-вход: сервер не вернул токен';

  @override
  String get codeConfirmationCodeExpired => 'Код устарел — выслали новый';

  @override
  String get pollViewVoteFailed => 'Не удалось проголосовать';

  @override
  String get pollViewLoading => 'Загрузка опроса…';

  @override
  String get pollViewMultipleAnswers => 'Несколько вариантов ответа';

  @override
  String get pollViewSingleAnswer => 'Один вариант ответа';

  @override
  String pollViewVotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count голоса',
      many: '$count голосов',
      few: '$count голоса',
      one: '$count голос',
    );
    return '$_temp0';
  }

  @override
  String get pollViewVote => 'Проголосовать';

  @override
  String get customizationChatBackground => 'Фон чатов';

  @override
  String get customizationMessageActions => 'Меню действий';

  @override
  String get customizationAppIcon => 'Иконка приложения';

  @override
  String get customizationTitle => 'Кастомизация';

  @override
  String get folderActionNewFolder => 'Новая папка';

  @override
  String folderActionDeleteConfirm(String title) {
    return 'Удалить папку «$title»? Чаты останутся на месте.';
  }

  @override
  String get folderActionDeleteFailed => 'Не удалось удалить папку';

  @override
  String get webAppBiometryAccessNotice =>
      'Мини-приложение сможет запрашивать подтверждение отпечатком или лицом.';

  @override
  String get webAppBiometryAuthReason =>
      'Подтвердите действие в мини-приложении';

  @override
  String get webAppBiometryAccessTitle => 'Разрешить биометрию?';

  @override
  String get webAppPhoneRequestTitle => 'Передать номер телефона?';

  @override
  String get webAppPhoneRequestMessage =>
      'Мини-приложение получит ваш номер телефона.';

  @override
  String get webAppPhoneRequestShare => 'Поделиться';

  @override
  String get promptDialogConfirm => 'Подтвердить';

  @override
  String get emojiPanelLoadFailed => 'Не удалось загрузить эмодзи';

  @override
  String get emojiPanelEmpty => 'Нет эмодзи';

  @override
  String get mediaPreviewEditorOpenFailed => 'Не удалось открыть редактор';

  @override
  String get fontSettingsSampleText => 'Съешь ещё этих мягких булок';

  @override
  String get callParticipantsNoServer => 'Нет связи с сервером звонка';

  @override
  String callParticipantsActionFailed(String error) {
    return 'Не удалось: $error';
  }

  @override
  String get callParticipantsMuteMic => 'Выключить микрофон';

  @override
  String get callParticipantsRequestCamera => 'Запросить камеру';

  @override
  String get callParticipantsRevokeAdmin => 'Снять администратора';

  @override
  String get callParticipantsRevokeSpeaker => 'Убрать из спикеров';

  @override
  String get callParticipantsMakeSpeaker => 'Сделать спикером';

  @override
  String get callParticipantsPromote => 'Повысить (promote)';

  @override
  String get callParticipantsDemote => 'Понизить (demote)';

  @override
  String get callParticipantsRemoveFromCall => 'Удалить из звонка';

  @override
  String get callParticipantsCallSettings => 'Настройки звонка';

  @override
  String get callParticipantsFeatureAccess => 'Кому доступны функции';

  @override
  String get callParticipantsInviteLink => 'Ссылка-приглашение участника';

  @override
  String get callParticipantsOptionAuthOnly => 'Только авторизованные';

  @override
  String get callParticipantsOptionWaitingHall => 'Зал ожидания';

  @override
  String get callParticipantsOptionRecurring => 'Повторяющийся звонок';

  @override
  String get callParticipantsOptionFeedback => 'Сбор отзывов';

  @override
  String get callParticipantsOptionAudienceMode => 'Режим зрителей';

  @override
  String get callParticipantsSpeechTranscription => 'Расшифровка речи';

  @override
  String get callParticipantsOptionWaitForAdmin => 'Ждать администратора';

  @override
  String get callParticipantsOptionAdminIsHere => 'Администратор на месте';

  @override
  String get callParticipantsFeatureMovieShare => 'Совместный просмотр';

  @override
  String get callParticipantsCallRecording => 'Запись звонка';

  @override
  String get callParticipantsFeatureSpeaker => 'Быть спикером';

  @override
  String callParticipantsTitle(int count) {
    return 'Участники · $count';
  }

  @override
  String get callParticipantsMuteAll => 'Заглушить всех';

  @override
  String get callParticipantsLowerAllHands => 'Опустить руки';

  @override
  String get callParticipantsLowerHand => 'Опустить руку';

  @override
  String get callParticipantsRaiseHand => 'Поднять руку';

  @override
  String get callParticipantsStopRecording => 'Остановить запись';

  @override
  String get callParticipantsStartRecording => 'Начать запись';

  @override
  String get callParticipantsRolePermissions => 'Права ролей';

  @override
  String get callParticipantsAddByLink => 'Добавить по ссылке';

  @override
  String get callParticipantsCreator => 'Создатель';

  @override
  String get callParticipantsAdmin => 'Администратор';

  @override
  String get callParticipantsSpeaker => 'Спикер';

  @override
  String get callParticipantsHandRaised => 'Поднял руку';

  @override
  String get chatMediaSendEnableLocation => 'Включите геолокацию';

  @override
  String get chatMediaSendNoLocationAccess => 'Нет доступа к геолокации';

  @override
  String get chatMediaSendLocationFailed => 'Не удалось получить геопозицию';

  @override
  String get chatMediaSendScheduledEncryptedPhotos =>
      'Отложенные фото в зашифрованном чате пока не поддерживаются';

  @override
  String get chatMediaSendVideoNotEncryptable =>
      'Видео пока нельзя зашифровать';

  @override
  String get chatMediaSendPhotoEncryptFailed => 'Не удалось зашифровать фото';

  @override
  String get chatMediaSendNoEncryptionKey => 'Не задан ключ шифрования';

  @override
  String get chatMediaSendNoUploadUrl => 'сервер не выдал ссылку';

  @override
  String get chatMediaSendUploadRejected => 'загрузка отклонена';

  @override
  String get chatMediaSendServerRejected => 'сервер не принял сообщение';

  @override
  String chatMediaSendFileFailed(String detail) {
    return 'Файл не отправлен: $detail';
  }

  @override
  String chatMediaSendVideoNoteFailed(String detail) {
    return 'Кружок не отправлен: $detail';
  }

  @override
  String chatMediaSendVoiceFailed(String detail) {
    return 'Голосовое не отправлено: $detail';
  }

  @override
  String chatMediaSendPhotoFailed(String detail) {
    return 'Фото не отправлено: $detail';
  }

  @override
  String chatMediaSendVideoFailed(String detail) {
    return 'Видео не отправлено: $detail';
  }

  @override
  String get chatMediaSendScheduled => 'Запланировано';

  @override
  String chatMediaSendScheduledAt(String date) {
    return 'Запланировано на $date';
  }

  @override
  String get chatMediaSendScheduleFailed => 'Не удалось запланировать';

  @override
  String get messageListToday => 'Сегодня';

  @override
  String get messageListYesterday => 'Вчера';

  @override
  String messageListDateThisYear(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String messageListDateOtherYear(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'd MMMM y',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get messageListUnreadMessages => 'Непрочитанные сообщения';

  @override
  String get photoViewerSavedToGallery => 'Сохранено в галерею';

  @override
  String photoViewerSavedTo(String path) {
    return 'Сохранено: $path';
  }

  @override
  String get photoViewerSaveFileFailed => 'Не удалось сохранить файл';

  @override
  String get photoViewerFileSaved => 'Файл сохранён';

  @override
  String get photoViewerErrorNoLink => 'нет ссылки';

  @override
  String get photoViewerErrorNoMedia => 'нет медиа';

  @override
  String get photoViewerMediaLoadFailed => 'Не удалось загрузить медиа';

  @override
  String get avatarPhotoLoadFailed => 'Не удалось загрузить фото';

  @override
  String get avatarPhotoDeleteTitle => 'Удалить фото?';

  @override
  String get avatarPhotoDeleteBody =>
      'Фотография пропадёт из профиля и из истории аватарок.';

  @override
  String loginScreenReconnectFailed(String error) {
    return 'Не удалось переподключиться: $error';
  }

  @override
  String get loginScreenSmsWarningTitle =>
      'ЕСЛИ НА ВАШЕМ АККАУНТЕ НЕТ 2FA ВСЕ СЕССИИ БУДУТ СБРОШЕНЫ';

  @override
  String get loginScreenSmsWarningBody =>
      'Способ экспериментальный, его использование на ваш страх и риск.';

  @override
  String get loginScreenOfflineWait =>
      'Нет соединения с сервером. Подождите подключения.';

  @override
  String get loginScreenOfflineRetry =>
      'Нет соединения с сервером. Попробуйте ещё раз.';

  @override
  String get loginScreenConnecting => 'Подключаемся к серверу, секунду…';

  @override
  String get loginScreenAlwaysSendSms => 'Всегда слать СМС (ЭКСПЕРИМЕНТАЛЬНО)';

  @override
  String get editProfileNameEmpty => 'Имя не может быть пустым';

  @override
  String get editProfileSaved => 'Профиль сохранён';

  @override
  String get editProfileAvatarUploadFailed => 'Не удалось загрузить аватарку';

  @override
  String get editProfileAvatarUpdated => 'Аватарка обновлена';

  @override
  String get editProfilePhotoDeleted => 'Фото удалено';

  @override
  String get findUserInvalidPhone => 'Введите корректный номер телефона';

  @override
  String get findUserPhoneNotFound => 'Контакт с таким номером не найден';

  @override
  String get findUserInvalidId => 'Введите числовой ID';

  @override
  String get findUserIdNotFound => 'Контакт с таким ID не найден';

  @override
  String get findUserPhoneTab => 'Номер';

  @override
  String get findUserPhoneHint => 'Введите номер телефона';

  @override
  String get findUserIdHint => 'Введите ID контакта';

  @override
  String get loginSuccessGreetingWelcome => 'Добро пожаловать в Komet!';

  @override
  String get loginSuccessGreetingEmergencyExit =>
      'Аварийный выход на высоте 30 тысяч футов. Иллюзия безопасности.';

  @override
  String get loginSuccessGreetingFunnyThings =>
      'Иногда забавные вещи могут быть уголовно наказуемы';

  @override
  String get loginSuccessGreetingFarewell =>
      'Если вы видите это сообщение, значит меня уже нет в живых.';

  @override
  String get loginSuccessGreetingGondor => 'Где был Гондор когда...';

  @override
  String get loginSuccessGreetingEasterEgg => 'Вы нашли пасхалку!';

  @override
  String get chatTextSendUnknownCommand => 'ТАКОЙ КОМАНДЫ НЕТУ🚨🚨🚨';

  @override
  String get chatTextSendSaveFailed => 'Не удалось сохранить сообщение';

  @override
  String get voiceBubbleLoadFailed => 'Не удалось загрузить аудио';

  @override
  String get voiceBubblePlaybackError => 'Ошибка воспроизведения';

  @override
  String get voiceBubbleTranscribe => 'Т';

  @override
  String get voiceBubbleTranscribing => 'транскрибация...';

  @override
  String get voiceBubbleTranscriptionFailed => 'ошибка транскрибации';

  @override
  String chatInfoStoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count истории',
      many: '$count историй',
      few: '$count истории',
      one: '$count история',
    );
    return '$_temp0';
  }

  @override
  String chatInfoMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String chatInfoSubscriberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count подписчика',
      many: '$count подписчиков',
      few: '$count подписчика',
      one: '$count подписчик',
    );
    return '$_temp0';
  }

  @override
  String get customGradientTitle => 'Своя тема';

  @override
  String get customGradientAnimation => 'Анимация';

  @override
  String get customGradientAnimationSubtitle => 'Плавный перелив цветов';

  @override
  String get videoBubbleOpenFailed => 'Не удалось открыть видео';

  @override
  String get videoBubbleLoadFailed => 'Не удалось получить видео';

  @override
  String get accountSwitcherNoName => 'Без имени';

  @override
  String get accountSwitcherAddAccount => 'Добавить аккаунт';

  @override
  String infoScreenWeeksShort(int weeks) {
    return '$weeks нед';
  }

  @override
  String infoScreenDaysShort(int days) {
    return '$days дн';
  }

  @override
  String get pluginsScreenPickKinetFile => 'Выберите файл с расширением .kinet';

  @override
  String get pluginsScreenReadFileFailed =>
      'Не удалось прочитать выбранный файл';

  @override
  String pluginsScreenOpenFailed(String error) {
    return 'Не удалось открыть .kinet: $error';
  }

  @override
  String get pluginsScreenHttpsRequired => 'Нужна корректная HTTPS-ссылка';

  @override
  String pluginsScreenDownloadFailed(String error) {
    return 'Не удалось загрузить .kinet: $error';
  }

  @override
  String pluginsScreenVersionAuthor(String version, String author) {
    return 'Версия $version · $author';
  }

  @override
  String pluginsScreenSignatureVerified(String fingerprint) {
    return 'Подпись Ed25519 проверена\n$fingerprint';
  }

  @override
  String get pluginsScreenNotSigned => 'Плагин не подписан';

  @override
  String get pluginsScreenPermissionsTitle => 'Плагин получит разрешения:';

  @override
  String get pluginsScreenAllowAndInstall => 'Разрешить и установить';

  @override
  String pluginsScreenInstalled(String name) {
    return '$name установлен';
  }

  @override
  String pluginsScreenInstallFailed(String error) {
    return 'Не удалось установить плагин: $error';
  }

  @override
  String get pluginsScreenNoUpdates => 'Обновлений нет';

  @override
  String get pluginsScreenUpdateTitle => 'Обновить плагин?';

  @override
  String get pluginsScreenUpdated => 'Плагин обновлён';

  @override
  String pluginsScreenUpdateFailed(String error) {
    return 'Не удалось обновить: $error';
  }

  @override
  String get pluginsScreenUninstallTitle => 'Удалить плагин?';

  @override
  String get pluginsScreenUninstalled => 'Плагин и его данные удалены';

  @override
  String pluginsScreenUninstallFailed(String error) {
    return 'Не удалось удалить: $error';
  }

  @override
  String get pluginsScreenTitle => 'Плагины';

  @override
  String get pluginsScreenInstallFile => 'Установить .kinet';

  @override
  String get pluginsScreenInstallUrl => 'Установить по URL';

  @override
  String get pluginsScreenBundled => 'Встроенный плагин Komet';

  @override
  String pluginsScreenSigned(String fingerprint) {
    return 'Подписан · $fingerprint';
  }

  @override
  String get pluginsScreenUnsigned => 'Не подписан';

  @override
  String get pluginsScreenCheckUpdates => 'Проверить обновления';

  @override
  String get pluginsScreenDownload => 'Загрузить';

  @override
  String get kometSettingsViewDeletedSubtitle =>
      'Показывать удалённые сообщения';

  @override
  String get kometSettingsViewRedactedSubtitle =>
      'Показывать историю у редактированных сообщений';

  @override
  String get kometSettingsFullTimestampSubtitle =>
      'Показывать время в секундах у сообщений';

  @override
  String get kometSettingsShowForwardSubtitle =>
      'Показывать метку на пересланных сообщениях, даже если на них не указан автор';

  @override
  String get kometSettingsTypingTimeSubtitle =>
      'Пытается рассчитать примерное время, сколько печаталось сообщение';

  @override
  String get kometSettingsFoldersHeader => 'Папки';

  @override
  String get kometSettingsHideAllFolderSubtitle =>
      'Скрыть папку «Все», когда есть другие папки. Чаты сортируются только по вашим папкам';

  @override
  String get kometSettingsShowHiddenChatsSubtitle =>
      'Показывать скрытые чаты, которые обычно не отображаются в списке: от групповых звонков, закрытые каналы и покинутые чаты';

  @override
  String get kometSettingsArchiveOnPullSubtitle =>
      'Прятать архив и показывать его, если потянуть список чатов вниз, после историй';

  @override
  String get kometSettingsGhostModeSubtitle => 'Вас не видно в сети';

  @override
  String get kometSettingsAntiReadSubtitle => 'Нечиталка сообщений';

  @override
  String get kometSettingsSelfOnlineCheckSubtitle =>
      'Каждые ~10 секунд сверяет, когда вы были онлайн. Полезно для проверки ghost mode';

  @override
  String get kometSettingsDebugHeader => 'Отладка';

  @override
  String get kometSettingsDebugLogsLabel => 'Запись отладочных логов';

  @override
  String get kometSettingsDebugLogsSubtitle =>
      'Пишет трафик протокола в файл на устройстве — помогает диагностировать баги при репортах';

  @override
  String get sharedContentSavedToGallery => 'Сохранено в галерею';

  @override
  String get sharedContentFileSaved => 'Файл сохранён';

  @override
  String get sharedContentVideoLoadFailed => 'Не удалось загрузить видео';

  @override
  String get sharedContentAudioLoadFailed => 'Не удалось загрузить аудио';

  @override
  String get sharedContentPlaybackError => 'Ошибка воспроизведения';

  @override
  String get messageBubbleButtonUnsupported => 'Кнопка не поддерживается';

  @override
  String get messageBubblePlatformUnavailable =>
      'На вашей платформе это недоступно';

  @override
  String messageBubbleEditedTime(String time) {
    return '$time ред.';
  }

  @override
  String get messageBubbleWrongKey => 'неверный ключ';

  @override
  String get messageBubbleUnavailableOnDevice =>
      'недоступно на этом устройстве';

  @override
  String get messageBubbleReplyDeleted => 'сообщение удалено';

  @override
  String get searchScreenSavedMessages => 'Избранное';

  @override
  String get searchScreenStartTyping => 'Начните вводить запрос';

  @override
  String get searchScreenByPhone => 'По номеру';

  @override
  String get searchScreenContacts => 'Контакты';

  @override
  String get searchScreenChats => 'Чаты';

  @override
  String get searchScreenGlobalSearch => 'Глобальный поиск';

  @override
  String get searchScreenUntitled => 'Без названия';

  @override
  String get fileBubbleCorrupted => 'Файл повреждён';

  @override
  String get fileBubbleWrongKey => 'Неверный ключ';

  @override
  String get fileBubbleTapToOpen => 'Нажмите, чтобы открыть';

  @override
  String get fileBubbleDownloadFailed => 'Не удалось загрузить файл';

  @override
  String get fileBubbleDecryptPhotoFailed => 'Не удалось расшифровать фото';

  @override
  String get fileBubbleUnknownFile => 'Не удалось определить файл';

  @override
  String get fileBubbleOpenFailedReason => 'не удалось открыть';

  @override
  String get fileBubbleDownloadFailedReason => 'не удалось загрузить';

  @override
  String get storyComposerUploadUrlFailed =>
      'Не удалось получить адрес загрузки';

  @override
  String get storyComposerPhotoUploadFailed => 'Не удалось загрузить фото';

  @override
  String get storyComposerVideoUploadFailed => 'Не удалось загрузить видео';

  @override
  String get storyComposerPublished => 'История опубликована';

  @override
  String get storyComposerPublish => 'Опубликовать';

  @override
  String get storyComposerContacts => 'Контакты';

  @override
  String textEntityProfileNotFound(String nickname) {
    return 'Профиль @$nickname не найден';
  }

  @override
  String get textEntityCopyPhone => 'Скопировать номер телефона';

  @override
  String get textEntityPhoneCopied => 'Номер скопирован';

  @override
  String get textEntityCall => 'Позвонить';

  @override
  String get textEntityCopyCard => 'Скопировать номер карты';

  @override
  String get textEntityCardCopied => 'Номер карты скопирован';

  @override
  String get textEntityDialFailed => 'Не удалось открыть приложение звонков';

  @override
  String get textEntityNotOnMax => 'Человека ещё нет в MAX';

  @override
  String get callLinkHandlerAlreadyInCall => 'Звонок уже идёт';

  @override
  String callLinkHandlerJoinPromptWithCount(String name, int count) {
    return 'Присоединиться к звонку «$name»? Сейчас в звонке: $count.';
  }

  @override
  String callLinkHandlerJoinPrompt(String name) {
    return 'Присоединиться к звонку «$name»?';
  }

  @override
  String get callLinkHandlerJoinFailed => 'Не удалось присоединиться к звонку';

  @override
  String get appIconScreenUnsupported =>
      'Смена иконки доступна только на Android и iOS';

  @override
  String appIconScreenChanged(String name) {
    return 'Иконка изменена на «$name»';
  }

  @override
  String appIconScreenChangeFailed(String error) {
    return 'Не удалось сменить иконку: $error';
  }

  @override
  String get appIconScreenTitle => 'Иконка приложения';

  @override
  String get appIconScreenAppearance => 'Внешний вид иконки';

  @override
  String get appIconScreenHint =>
      'На Android приложение закроется — лаунчер подхватит новую иконку. На iOS — мгновенно с системным диалогом.';

  @override
  String get appIconScreenOnlyMobile => 'Доступно только на Android и iOS';

  @override
  String get password2faConnectionDropped => 'Соединение прервалось…';

  @override
  String get password2faConnectionDroppedRelogin =>
      'Соединение прервалось — войдите заново';

  @override
  String get password2faEnterPassword => 'Введите пароль для завершения входа';

  @override
  String get contactsTabFindContact => 'Найти контакт';

  @override
  String get contactsTabFind => 'Найти';

  @override
  String get contactsTabLastSeenRecently => 'Был(а) недавно';

  @override
  String get contactsTabTitle => 'Контакты';

  @override
  String get contactsTabEmpty => 'Нет контактов';

  @override
  String securityScreenBlockedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count контакта',
      many: '$count контактов',
      few: '$count контакта',
      one: '$count контакт',
    );
    return '$_temp0';
  }

  @override
  String get attachmentPanelInvalidFileId => 'Неверный fileId';

  @override
  String get attachmentPanelPickFile => 'Выбрать из файла';

  @override
  String get attachmentPanelSendById => 'Отправить по id';

  @override
  String selectionBarSelectedCount(int count) {
    return 'Выбрано $count';
  }

  @override
  String get metaMarksLikelyForwarded => 'Сообщения скорее всего пересланы';

  @override
  String metaMarksTypingTime(String duration) {
    return 'Сообщение печаталось примерно ~$duration';
  }

  @override
  String get searchViewHint => 'Поиск...';

  @override
  String get searchViewNoResults => 'Поиск ничего не вернул...';

  @override
  String get adaptiveShellSelectChat => 'Выберите чат';

  @override
  String get settingsTabPhotoDeleted => 'Фото удалено';

  @override
  String settingsTabPhotoDeleteFailed(String error) {
    return 'Не удалось удалить фото: $error';
  }

  @override
  String settingsTabAppVersion(String version, String build) {
    return 'Версия $version ($build)';
  }

  @override
  String get settingsTabCloudStorageSubtitle => 'Через МАХ';

  @override
  String get settingsTabCloudStorageWhitelistTitle =>
      'Работает при белых списках';

  @override
  String get settingsTabCloudStorageWhitelistBody =>
      'Вы сможете передать файл даже при ограниченном интернете.';

  @override
  String get settingsTabCloudStorageLimitsTitle =>
      'Файлы до 4ГБ, безлимитное количество.';

  @override
  String get settingsTabCloudStorageLimitsBody =>
      'Можете хранить массивный обьем информации.';

  @override
  String get settingsTabCloudStoragePrivacyTitle =>
      'Не обеспечивается конфединциальность файлов';

  @override
  String get settingsTabCloudStoragePrivacyBody =>
      'Облачное хранилище работает через ваш аккаунт на сервере МАХ, нужные люди всё равно могут его посмотреть.';

  @override
  String get settingsTabLogoutConfirmTitle => 'Выйти из аккаунта?';

  @override
  String get settingsTabLogoutConfirmBody =>
      'Данные аккаунта будут удалены с этого устройства.';

  @override
  String get settingsTabLogoutConfirm => 'Выйти';

  @override
  String settingsTabLogoutFailed(String error) {
    return 'Не удалось выйти: $error';
  }

  @override
  String get settingsTabSferumSignIn => 'Войти в Сферум';

  @override
  String get settingsTabSferumTitle => 'Сферум';

  @override
  String get settingsTabCloudStorageBeta => 'Облачное хранилище [BETA]';

  @override
  String get settingsTabDevelopers => 'Для разработчиков';

  @override
  String get settingsTabLogout => 'Выйти из аккаунта';

  @override
  String get settingsTabOnline => 'онлайн';

  @override
  String settingsTabLastSeen(String time) {
    return 'Был(-а) $time';
  }

  @override
  String get settingsTabOffline => 'офлайн';

  @override
  String get folderEditTypeContacts => 'Контакты';

  @override
  String get folderEditTypeNonContacts => 'Не в контактах';

  @override
  String get folderEditTypeChannels => 'Каналы';

  @override
  String get folderEditTypeBots => 'Боты';

  @override
  String get folderEditSavedMessages => 'Избранное';

  @override
  String get folderEditNoActiveAccount => 'Нет активного аккаунта';

  @override
  String get folderEditSaveFailed => 'Не удалось сохранить папку';

  @override
  String folderEditDeleteConfirm(String title) {
    return 'Удалить папку «$title»? Чаты останутся на месте.';
  }

  @override
  String get folderEditDeleteFailed => 'Не удалось удалить папку';

  @override
  String get folderEditNewTitle => 'Новая папка';

  @override
  String get folderEditEditTitle => 'Изменение папки';

  @override
  String get folderEditNameHint => 'Название папки';

  @override
  String get folderEditChatTypesSection => 'ТИПЫ ЧАТОВ';

  @override
  String get folderEditChatsSection => 'ЧАТЫ И КАНАЛЫ';

  @override
  String get folderEditSavedMessagesSubtitle => 'Сообщения себе';

  @override
  String get folderEditShowOnlySection => 'ПОКАЗЫВАТЬ ТОЛЬКО';

  @override
  String get folderEditNotMutedChats => 'Чаты с уведомлениями';

  @override
  String get folderEditUnreadChats => 'Непрочитанные чаты';

  @override
  String get folderEditClearSelection => 'Очистить выбор';

  @override
  String get folderEditDeleteFolder => 'Удалить папку';

  @override
  String get folderEditCreate => 'Создать папку';

  @override
  String get composerInputMuteNotifications => 'Отключить уведомления';

  @override
  String get composerInputForwardFromYou => 'Пересылка от вас';

  @override
  String get composerInputForwardMessage => 'Пересылка сообщения';

  @override
  String composerInputForwardFrom(String name) {
    return 'Пересылка от $name';
  }

  @override
  String composerInputForwardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Пересылка: $count сообщения',
      many: 'Пересылка: $count сообщений',
      few: 'Пересылка: $count сообщения',
      one: 'Пересылка: $count сообщение',
    );
    return '$_temp0';
  }

  @override
  String composerInputReplyTo(String name) {
    return 'Ответ $name';
  }

  @override
  String get composerInputSwipeToCancel => '‹ Влево — отмена';

  @override
  String get composerInputSwipeToCancelHint => '‹ влево — отмена';

  @override
  String get composerInputHistoryEmpty => 'история пуста...';

  @override
  String get createGroupFailed => 'Не удалось создать группу';

  @override
  String get createGroupAvatarProcessFailed => 'Не удалось обработать аватарку';

  @override
  String get createGroupAvatarUploadFailed => 'Не удалось загрузить аватарку';

  @override
  String get createGroupSelectParticipants => 'Выберите участников';

  @override
  String get createGroupCancel => 'Отменить';

  @override
  String get createGroupNext => 'Далее';

  @override
  String get createGroupTitle => 'Создать группу';

  @override
  String get createGroupNameHint => 'Название группы';

  @override
  String get createGroupCreating => 'Создаю...';

  @override
  String get createGroupCreate => 'Создать';

  @override
  String controlBubbleQuotedTitle(String title) {
    return '«$title»';
  }

  @override
  String get controlBubbleCreatedByMe => ' создали чат';

  @override
  String get controlBubbleCreatedByOther => ' создал(а) чат';

  @override
  String get controlBubbleAddedByMe => ' добавили ';

  @override
  String get controlBubbleAddedByOther => ' добавил(а) ';

  @override
  String get controlBubbleLeftByMe => ' покинули чат';

  @override
  String get controlBubbleLeftByOther => ' покинул(а) чат';

  @override
  String get controlBubbleJoinedByMe => ' присоединились к чату';

  @override
  String get controlBubbleJoinedByOther => ' присоединился(-ась) к чату';

  @override
  String get controlBubblePinnedByMe => ' закрепили сообщение';

  @override
  String get controlBubblePinnedByOther => ' закрепил(а) сообщение';

  @override
  String get controlBubbleRenamedByMe => ' изменили название чата';

  @override
  String get controlBubbleRenamedByOther => ' изменил(а) название чата';

  @override
  String controlBubbleRenamedTo(String title) {
    return ' на $title';
  }

  @override
  String get controlBubblePhotoChangedByMe => ' изменили фото чата';

  @override
  String get controlBubblePhotoChangedByOther => ' изменил(а) фото чата';

  @override
  String get controlBubbleBotStarted => 'Бот запущен';

  @override
  String get maxLinkNoPublicLink => 'У профиля нет публичной ссылки';

  @override
  String get maxLinkShareFailed => 'Не удалось поделиться ссылкой';

  @override
  String get maxLinkOpenProfileFailed => 'Не удалось открыть профиль';

  @override
  String get maxLinkOpenChatFailed => 'Не удалось открыть чат';

  @override
  String get maxLinkJoinThisChatConfirm => 'Вступить в этот чат?';

  @override
  String maxLinkJoinChatConfirm(String title) {
    return 'Вступить в «$title»?';
  }

  @override
  String get maxLinkProfileFallback => 'Профиль';

  @override
  String get videoNoteCameraUnavailable => 'Камера недоступна';

  @override
  String get videoNoteNeedCameraAndMic =>
      'Для кружков нужен доступ к камере и микрофону';

  @override
  String get videoNoteNoMicAccess => 'Нет доступа к микрофону';

  @override
  String get videoNoteNoCameraAccess => 'Нет доступа к камере';

  @override
  String get videoNoteCameraNotReady => 'Камера ещё не готова';

  @override
  String get videoNoteStartFailed => 'Не удалось начать запись кружка';

  @override
  String get videoNoteSaveFailed => 'Не удалось сохранить кружок';

  @override
  String get scheduleTimePickerTitle => 'Отправить позже';

  @override
  String get scheduleTimePickerToday => 'Сегодня';

  @override
  String get scheduleTimePickerTomorrow => 'Завтра';

  @override
  String get scheduleTimePickerTodayLower => 'сегодня';

  @override
  String get scheduleTimePickerTomorrowLower => 'завтра';

  @override
  String scheduleTimePickerSendAt(String day, String time) {
    return 'Отправить $day в $time';
  }

  @override
  String get scheduleTimePickerPastTime => 'Время должно быть в будущем';

  @override
  String get chatBackgroundSaveFailed => 'Не удалось сохранить обои';

  @override
  String get chatBackgroundTitle => 'Фон чатов';

  @override
  String get chatBackgroundDescription =>
      'Эти обои применяются ко всем чатам, где не выбран свой фон.';

  @override
  String get chatBackgroundTintTitle => 'Подстраивать интерфейс под обои';

  @override
  String get chatBackgroundTintSubtitle =>
      'Акцентный цвет приложения возьмётся из фона';

  @override
  String get chatBackgroundPick => 'Выбрать обои';

  @override
  String get chatBackgroundSampleIncoming => 'Единый фон для всех чатов';

  @override
  String get chatBackgroundSampleOutgoing => 'Красиво ✨';

  @override
  String get chatWallpaperPreviewTitle => 'Обои';

  @override
  String get chatWallpaperPreviewBlur => 'Размытие';

  @override
  String get chatWallpaperPreviewMotion => 'Движение';

  @override
  String get chatWallpaperPreviewDimming => 'Затемнение';

  @override
  String get chatWallpaperPreviewSampleIncoming =>
      'Как насчёт новых обоев для этого чата?';

  @override
  String get chatWallpaperPreviewSampleOutgoing => 'Отличная идея.';

  @override
  String get stickerPanelLoadFailed => 'Не удалось загрузить стикеры';

  @override
  String get stickerPanelEmpty => 'Нет стикеров';

  @override
  String get stickerPanelEmojiTab => 'Эмодзи';

  @override
  String get stickerPanelStickersTab => 'Стикеры';

  @override
  String get callBubbleGroupVideo => 'Групповой видеозвонок';

  @override
  String get callBubbleCanceledVideo => 'Отменённый видеозвонок';

  @override
  String get callBubbleMissedVideo => 'Пропущенный видеозвонок';

  @override
  String get callBubbleOutgoingVideo => 'Исходящий видеозвонок';

  @override
  String get callBubbleIncomingVideo => 'Входящий видеозвонок';

  @override
  String get callBubbleCanceled => 'Отменённый звонок';

  @override
  String get callBubbleMissed => 'Пропущенный звонок';

  @override
  String get callBubbleOutgoing => 'Исходящий звонок';

  @override
  String maxRouteUnsupported(String route) {
    return 'Ссылка не поддерживается: $route';
  }

  @override
  String maxRouteIncomplete(String route) {
    return 'Неполная ссылка: $route';
  }

  @override
  String get cloudStorageScreenExpired => 'истекла';

  @override
  String cloudStorageScreenExpiresInDays(int days) {
    return 'через $days д';
  }

  @override
  String cloudStorageScreenExpiresInHours(int hours, int minutes) {
    return 'через $hours ч $minutes мин';
  }

  @override
  String cloudStorageScreenExpiresInMinutes(int minutes) {
    return 'через $minutes мин';
  }

  @override
  String get webQrScanTitle => 'QR для веба и ПК';

  @override
  String get webQrScanCameraUnavailable => 'Камера недоступна';

  @override
  String get webQrScanHint => 'Наведите камеру на QR-код на экране компьютера';

  @override
  String get messageRowEditTitle => 'Изменить сообщение';

  @override
  String get locationBubbleOpenInMaps => 'Открыть на карте';

  @override
  String get commandArgumentsCancel => 'Отменить команду';

  @override
  String commandArgumentsOptional(String name) {
    return '$name · необязательно';
  }

  @override
  String get storyRingYourStory => 'Ваша история';

  @override
  String formatBytesB(String value) {
    return '$value Б';
  }

  @override
  String formatBytesKb(String value) {
    return '$value КБ';
  }

  @override
  String formatBytesMb(String value) {
    return '$value МБ';
  }

  @override
  String formatBytesGb(String value) {
    return '$value ГБ';
  }

  @override
  String formatApproxSeconds(String whole, String fraction) {
    return '$whole,$fraction с';
  }

  @override
  String formatApproxMinutes(String whole, String fraction) {
    return '$whole,$fraction мин';
  }

  @override
  String get lastSeenJustNow => 'Был(-а) только что';

  @override
  String lastSeenMinutesAgo(int minutes) {
    return 'Был(-а) $minutes мин назад';
  }

  @override
  String lastSeenHoursAgo(int hours) {
    return 'Был(-а) $hours ч назад';
  }

  @override
  String lastSeenDaysAgo(int days) {
    return 'Был(-а) $days дн назад';
  }

  @override
  String get genderMale => 'Мужской';

  @override
  String get genderFemale => 'Женский';

  @override
  String get connectionStatusConnecting => 'Соединение...';

  @override
  String get connectionStatusWaitingForNetwork => 'Ожидание сети...';

  @override
  String get chatActivityTyping => 'Печатает...';

  @override
  String get chatActivityChoosingSticker => 'Выбирает стикер...';

  @override
  String chatActivityTypingOne(String name) {
    return '$name печатает...';
  }

  @override
  String chatActivityTypingTwo(String first, String second) {
    return '$first и $second печатают...';
  }

  @override
  String chatActivityTypingMany(String name, int count) {
    return '$name и ещё $count печатают...';
  }

  @override
  String chatActivityStickerOne(String name) {
    return '$name выбирает стикер...';
  }

  @override
  String chatActivityStickerTwo(String first, String second) {
    return '$first и $second выбирают стикеры...';
  }

  @override
  String chatActivityStickerMany(String name, int count) {
    return '$name и ещё $count выбирают стикеры...';
  }

  @override
  String get shareTitleMessage => 'Отправить сообщение';

  @override
  String get shareTitlePhoto => 'Отправить фотографию';

  @override
  String shareTitlePhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отправить $count фотографии',
      many: 'Отправить $count фотографий',
      few: 'Отправить $count фотографии',
      one: 'Отправить $count фотографию',
    );
    return '$_temp0';
  }

  @override
  String shareTitleVideos(int count) {
    return 'Отправить $count видео';
  }

  @override
  String shareTitleFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отправить $count файла',
      many: 'Отправить $count файлов',
      few: 'Отправить $count файла',
      one: 'Отправить $count файл',
    );
    return '$_temp0';
  }

  @override
  String shareSubtitleToChats(String names) {
    return 'В чат $names';
  }

  @override
  String shareSubtitleChatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'В $count чата',
      many: 'В $count чатов',
      few: 'В $count чата',
      one: 'В $count чат',
    );
    return '$_temp0';
  }

  @override
  String get pluginPermissionChatWrite => 'Отправка сообщений';

  @override
  String get pluginPermissionChatEdit =>
      'Редактирование отправленных сообщений';

  @override
  String get pluginPermissionUiNotify => 'Показ уведомлений';

  @override
  String get pluginPermissionContactRead => 'Чтение данных собеседника';

  @override
  String get pluginPermissionReplyRead =>
      'Чтение сообщения, на которое отвечает команда';

  @override
  String get pluginPermissionNetwork => 'Доступ к интернету';

  @override
  String get pluginPermissionPhotoWrite => 'Отправка фотографий';

  @override
  String get pluginPermissionFileWrite => 'Отправка файлов';

  @override
  String get pluginPermissionStorage => 'Локальное хранилище плагина';

  @override
  String pluginUpdateNewPermissions(String permissions) {
    return 'Обновление запрашивает новые разрешения: $permissions';
  }

  @override
  String get transcriptionNotRecognized => 'Не распознали голос';

  @override
  String get chatWallpaperThemeOcean => 'Океан';

  @override
  String get chatWallpaperThemeSunset => 'Закат';

  @override
  String get chatWallpaperThemeLavender => 'Лаванда';

  @override
  String get chatWallpaperThemeMint => 'Мята';

  @override
  String get chatWallpaperThemeGraphite => 'Графит';

  @override
  String get chatWallpaperThemeSky => 'Небо';

  @override
  String get chatWallpaperThemePeach => 'Персик';

  @override
  String get chatWallpaperThemeForest => 'Лес';

  @override
  String get chatWallpaperThemeGrape => 'Виноград';

  @override
  String get chatWallpaperThemeNight => 'Ночь';

  @override
  String get chatWallpaperThemeRose => 'Роза';

  @override
  String get chatWallpaperThemeAmber => 'Янтарь';

  @override
  String get mediaSaveFileNotFound => 'файл не найден';

  @override
  String get mediaSaveNoGalleryAccess => 'нет доступа к галерее';

  @override
  String get commandShrugDescription => 'отправить каомодзи';

  @override
  String scheduleTimePickerDayLabel(String weekday, String date) {
    return '$weekday, $date.';
  }

  @override
  String get avatarEditorSetPhoto => 'Установить фото';

  @override
  String get avatarEditorDraw => 'Рисовать';

  @override
  String get avatarPickerFilesTitle => 'Выбрать фото из файлов';

  @override
  String get avatarPickerFilesSubtitle => 'Если нужного фото нет в галерее';
}
