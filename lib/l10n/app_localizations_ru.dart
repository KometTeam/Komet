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

  @override
  String get msgActionsCopy => 'Копировать';

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
  String get notificationsFkmDownloadFcm => 'Скачай лучше FCM-версию.';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsFkmSectionTitle => 'FKM';

  @override
  String get notificationsFkmEnableLabel => 'Включить уведомления';

  @override
  String get notificationsFkmEnableSubtitle =>
      'Для работы FKM уведомлений, приложению понадобится держать уведомление в шторке.';

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
  String get devicesPromoTitle => 'Устройства в KOMET';

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
  String get appearanceTitle => 'Внешний вид';

  @override
  String get appearanceVisualStyleTitle => 'Визуал';

  @override
  String get appearanceVisualStyleSubtitle =>
      'Material You или объёмные Glossy-капсулы';

  @override
  String get appearanceVisualStyleMaterialYou => 'Material You';

  @override
  String get appearanceVisualStyleGlossy => 'Glossy';

  @override
  String get appearanceChatChromeTitle => 'Элементы экрана чата';

  @override
  String get appearanceChatChromeSubtitle =>
      'Фон панелей сверху и снизу: цвет, размытие или прозрачно. При размытии и прозрачности сообщения заходят под панели';

  @override
  String get appearanceChatChromeColor => 'Цвет';

  @override
  String get appearanceChatChromeBlur => 'Блюр';

  @override
  String get appearanceChatChromeNone => 'Нет';

  @override
  String get appearanceChatChromeTransparent => 'Прозр.';

  @override
  String get appearanceGradientTitle => 'Градиент';

  @override
  String get appearanceGradientSubtitle => 'Объём и блики в Glossy-капсулах';

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
  String get callStatusConnecting => 'Соединение';

  @override
  String get callGroupConnecting => 'Соединение…';

  @override
  String get callGroupWaitingParticipants => 'Ожидание участников…';

  @override
  String get callParticipantYou => 'Вы';

  @override
  String get callParticipantFallback => 'Участник';

  @override
  String get callTooltipMinimize => 'Свернуть';

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
  String get hubCheckersTileSubtitle => 'Русские шашки';

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
  String nfcPeerIdFallback(String id) {
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
      one: '1 участник',
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
  String get sharedCopyLink => 'Копировать ссылку';

  @override
  String get sharedLinkCopied => 'Ссылка скопирована';

  @override
  String get chatInfoActionLeave => 'Покинуть';

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
  String get chatInfoRoleOwner => 'владелец';

  @override
  String get chatInfoRoleAdmin => 'Адмін';

  @override
  String get chatInfoNoData => 'Нет данных';

  @override
  String get chatInfoHideExtra => 'Скрыть';

  @override
  String get chatInfoShowMoreExtra => 'Подробнее';

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
  String get securitySettingsUnavailable =>
      'Изменение настроек пока недоступно';

  @override
  String get securityFindByPhone => 'Найти меня по номеру';

  @override
  String get securityWhoCanCall => 'Кто может мне звонить';

  @override
  String get securityWhoCanInvite => 'Кто может приглашать в чаты';

  @override
  String get securityShowContact => 'Показывать контакт';

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
  String get passwordEntryInvalidEmailError => 'Введите корректный email';

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
      'Внимание! После удаления пароля защита вашего аккаунта ослабнет.';

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
  String get attachSheetCameraComingSoon => 'Камера скоро появится';

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
  String get attachSheetLimitedAccessInfo => 'Доступны не все фото';

  @override
  String get attachSheetSectionInProgress => 'Раздел в разработке';

  @override
  String get attachSheetNoGalleryAccessTitle => 'Нет доступа к галерее';

  @override
  String get attachSheetNoGalleryAccessSubtitle =>
      'Разрешите доступ к фото, чтобы выбрать их отсюда';

  @override
  String get attachSheetAllow => 'Разрешить';

  @override
  String get attachSheetSettings => 'Настройки';

  @override
  String get attachSheetAddCaptionHint => 'Добавить подпись...';

  @override
  String get attachSheetCamera => 'Камера';

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
}
