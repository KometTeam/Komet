/// All protocol operation codes.
///
/// Naming follows the server-side convention.
/// Use [Opcode.name] to get a human-readable label for logging.
///
/// файл писла нейронка (я че ебанутый чтоль чтобы вручную хуярить опкоды и их значения)
abstract class Opcode {
  // ── Session ────────────────────────────────────────────────────────
  static const int ping = 1; // Пинг
  static const int debug = 2; // Отладка / понг
  static const int reconnect = 3; // Реконнект
  static const int log = 5; // Аналитика / события
  static const int sessionInit = 6; // Инициализация сессии (хэндшейк)

  // ── Profile ────────────────────────────────────────────────────────
  static const int profile = 16; // Обновление профиля

  // ── Auth ───────────────────────────────────────────────────────────
  static const int authRequest = 17; // Запрос OTP-кода
  static const int auth = 18; // Проверка OTP-кода
  static const int login = 19; // Вход (загрузка чатов/контактов)
  static const int logout = 20; // Выход из аккаунта
  static const int sync = 21; // Синхронизация данных
  static const int config = 22; // Настройки приватности / конфиг
  static const int authConfirm = 23; // Завершение регистрации

  // ── Auth 2FA ───────────────────────────────────────────────────────
  static const int authLoginRestorePassword = 101; // Восстановление пароля
  static const int auth2faDetails = 104; // Детали 2FA
  static const int externalCallback = 105; // Внешний коллбэк
  static const int authValidatePassword = 107; // Валидация пароля
  static const int authValidateHint = 108; // Валидация подсказки пароля
  static const int authVerifyEmail = 109; // Верификация email
  static const int authCheckEmail = 110; // Проверка email
  static const int authSet2fa = 111; // Установка 2FA
  static const int authCreateTrack = 112; // Создание трека авторизации
  static const int authCheckPassword = 113; // Проверка пароля при регистрации
  static const int authLoginCheckPassword = 115; // Проверка пароля при входе
  static const int authLoginProfileDelete = 116; // Удаление профиля при входе

  // ── Assets (стикеры) ───────────────────────────────────────────────
  static const int presetAvatars = 25; // Пресетные аватарки
  static const int assetsGet = 26; // Получение стикерпаков
  static const int assetsUpdate = 27; // Синхронизация стикеров
  static const int assetsGetByIds = 28; // Стикерпаки по ID
  static const int assetsAdd = 29; // Добавление стикерпака
  static const int assetsRemove = 259; // Удаление стикерпака
  static const int assetsMove = 260; // Перемещение стикерпака
  static const int assetsListModify = 261; // Изменение списка стикерпаков

  // ── Contacts ───────────────────────────────────────────────────────
  static const int contactInfo = 32; // Информация о контакте
  static const int contactAdd = 33; // Добавление контакта
  static const int contactUpdate = 34; // Обновление контакта (блок и т.д.)
  static const int contactPresence = 35; // Запрос присутствия по ID
  static const int contactList = 36; // Список заблокированных
  static const int contactSearch = 37; // Поиск контакта
  static const int contactMutual = 38; // Общие контакты
  static const int contactPhotos = 39; // Фото контакта
  static const int contactSort = 40; // Сортировка контактов
  static const int contactVerify = 42; // Верификация контакта
  static const int removeContactPhoto = 43; // Удаление фото контакта
  static const int contactInfoByPhone = 46; // Поиск контакта по номеру

  // ── Chats ──────────────────────────────────────────────────────────
  static const int chatInfo = 48; // Информация о чате / создание группы
  static const int chatHistory = 49; // История сообщений
  static const int chatMark = 50; // Отметка прочитанным
  static const int chatMedia = 51; // Медиа чата
  static const int chatDelete = 52; // Удаление чата
  static const int chatsList = 53; // Список чатов
  static const int chatClear = 54; // Очистка истории чата
  static const int chatUpdate = 55; // Обновление настроек чата
  static const int chatCheckLink = 56; // Проверка ссылки чата
  static const int chatJoin = 57; // Вступление в группу / канал
  static const int chatLeave = 58; // Выход из чата
  static const int chatMembers = 59; // Участники группы
  static const int publicSearch = 60; // Глобальный поиск
  static const int chatPersonalConfig = 61; // Персональные настройки чата
  static const int chatCreate = 63; // Создание чата

  // ── Messages ───────────────────────────────────────────────────────
  static const int msgSend = 64; // Отправка сообщения
  static const int msgTyping = 65; // Индикатор набора текста
  static const int msgDelete = 66; // Удаление сообщения
  static const int msgEdit = 67; // Редактирование сообщения
  static const int chatSearch = 68; // Поиск по чату
  static const int msgSharePreview = 70; // Превью ссылки
  static const int msgGet = 71; // Получение сообщения по ID
  static const int msgSearchTouch = 72; // Точечный поиск сообщений
  static const int msgSearch = 73; // Поиск сообщений
  static const int msgGetStat = 74; // Статистика сообщения
  static const int chatSubscribe = 75; // Подписка на обновления чата
  static const int msgDeleteRange = 92; // Удаление диапазона сообщений

  // ── Reactions ──────────────────────────────────────────────────────
  static const int msgReaction = 178; // Отправка реакции
  static const int msgCancelReaction = 179; // Отмена реакции
  static const int msgGetReactions = 180; // Получение реакций
  static const int msgGetDetailedReactions = 181; // Детальные реакции
  static const int chatReactionsSettingsSet = 257; // Установка настроек реакций
  static const int reactionsSettingsGetByChatId = 258; // Настройки реакций чата

  // ── Calls & Video ──────────────────────────────────────────────────
  static const int videoChatStart = 76; // Начало видеочата
  static const int chatMembersUpdate = 77; // Обновление участников / добавление
  static const int videoChatStartActive = 78; // Инициация активного звонка
  static const int videoChatHistory = 79; // История звонков
  static const int videoChatCreateJoinLink = 84; // Ссылка для входа в видеочат
  static const int videoChatMembers = 195; // Участники видеочата
  static const int getInboundCalls = 103; // Входящие звонки

  // ── Media & Files ──────────────────────────────────────────────────
  static const int photoUpload = 80; // Загрузка фото
  static const int stickerUpload = 81; // Загрузка стикера
  static const int videoUpload = 82; // Загрузка видео
  static const int videoPlay = 83; // URL видео
  static const int chatPinSetVisibility = 86; // Видимость закрепов
  static const int fileUpload = 87; // Загрузка файла
  static const int fileDownload = 88; // Скачивание файла
  static const int linkInfo = 89; // Информация по ссылке / вход в канал
  static const int audioPlay = 301; // Воспроизведение аудио

  // ── Sessions ───────────────────────────────────────────────────────
  static const int sessionsInfo = 96; // Запрос активных сессий
  static const int sessionsClose = 97; // Закрытие всех сессий
  static const int phoneBindRequest = 98; // Запрос привязки телефона
  static const int phoneBindConfirm = 99; // Подтверждение привязки телефона

  // ── Bots ───────────────────────────────────────────────────────────
  static const int chatComplain = 117; // Жалоба на чат
  static const int msgSendCallback = 118; // Коллбэк бота
  static const int suspendBot = 119; // Приостановка бота
  static const int chatBotCommands = 144; // Команды бота
  static const int botInfo = 145; // Информация о боте

  // ── Location ───────────────────────────────────────────────────────
  static const int locationStop = 124; // Остановка трансляции геолокации

  // ── Mentions ───────────────────────────────────────────────────────
  static const int getLastMentions = 127; // Последние упоминания

  // ── Stickers (creation) ────────────────────────────────────────────
  static const int stickerCreate = 193; // Создание стикера
  static const int stickerSuggest = 194; // Предложение стикера

  // ── Notifications (push от сервера) ────────────────────────────────
  static const int notifMessage = 128; // Новое сообщение
  static const int notifTyping = 129; // Индикатор набора
  static const int notifMark = 130; // Прочитано
  static const int notifContact = 131; // Обновление контакта
  static const int notifPresence = 132; // Статус онлайн
  static const int notifConfig = 134; // Обновление конфига
  static const int notifChat = 135; // Обновление чата
  static const int notifAttach = 136; // Загрузка файла завершена
  static const int notifCallStart = 137; // Входящий звонок
  static const int notifContactSort = 139; // Пересортировка контактов
  static const int notifMsgDeleteRange = 140; // Удаление диапазона
  static const int notifMsgDelete = 142; // Удаление сообщения
  static const int notifCallbackAnswer = 143; // Ответ бота
  static const int notifLocation = 147; // Обновление геолокации
  static const int notifLocationRequest = 148; // Запрос геолокации
  static const int notifAssetsUpdate = 150; // Обновление стикеров
  static const int notifDraft = 152; // Черновик
  static const int notifDraftDiscard = 153; // Сброс черновика
  static const int notifMsgDelayed = 154; // Отложенное сообщение
  static const int notifMsgReactionsChanged = 155; // Изменение реакций
  static const int notifMsgYouReacted = 156; // Ваша реакция
  static const int notifProfile = 159; // Обновление профиля
  static const int notifBanners = 292; // Баннеры
  static const int notifFolders = 277; // Обновление папок

  // ── Misc ───────────────────────────────────────────────────────────
  static const int okToken = 158; // OK-токен
  static const int webAppInitData = 160; // Данные WebApp
  static const int complain = 161; // Жалоба
  static const int complainReasonsGet = 162; // Причины жалобы
  static const int draftSave = 176; // Сохранение черновика
  static const int draftDiscard = 177; // Удаление черновика
  static const int chatHide = 196; // Скрытие чата
  static const int chatSearchCommonParticipants = 198; // Общие участники
  static const int profileDelete = 199; // Удаление профиля
  static const int profileDeleteTime = 200; // Таймер удаления профиля
  static const int authQrApprove = 290; // Подтверждение QR-входа
  static const int chatSuggest = 300; // Предложения чатов

  // ── Polls ──────────────────────────────────────────────────────────
  static const int sendVote = 304; // Голосование
  static const int votersListByAnswer = 305; // Список голосовавших
  static const int getPollUpdates = 306; // Обновления опроса

  // ── Folders ────────────────────────────────────────────────────────
  static const int foldersGet = 272; // Получение папок
  static const int foldersGetById = 273; // Папка по ID
  static const int foldersUpdate = 274; // Обновление / создание папки
  static const int foldersReorder = 275; // Сортировка папок
  static const int foldersDelete = 276; // Удаление папки

  // ── Human-readable names ───────────────────────────────────────────

  static String name(int opcode) => _names[opcode] ?? 'UNKNOWN($opcode)';

  static const Map<int, String> _names = {
    ping: 'PING',
    debug: 'DEBUG',
    reconnect: 'RECONNECT',
    log: 'LOG',
    sessionInit: 'SESSION_INIT',
    profile: 'PROFILE',
    authRequest: 'AUTH_REQUEST',
    auth: 'AUTH',
    login: 'LOGIN',
    logout: 'LOGOUT',
    sync: 'SYNC',
    config: 'CONFIG',
    authConfirm: 'AUTH_CONFIRM',
    authLoginRestorePassword: 'AUTH_LOGIN_RESTORE_PASSWORD',
    auth2faDetails: 'AUTH_2FA_DETAILS',
    externalCallback: 'EXTERNAL_CALLBACK',
    authValidatePassword: 'AUTH_VALIDATE_PASSWORD',
    authValidateHint: 'AUTH_VALIDATE_HINT',
    authVerifyEmail: 'AUTH_VERIFY_EMAIL',
    authCheckEmail: 'AUTH_CHECK_EMAIL',
    authSet2fa: 'AUTH_SET_2FA',
    authCreateTrack: 'AUTH_CREATE_TRACK',
    authCheckPassword: 'AUTH_CHECK_PASSWORD',
    authLoginCheckPassword: 'AUTH_LOGIN_CHECK_PASSWORD',
    authLoginProfileDelete: 'AUTH_LOGIN_PROFILE_DELETE',
    presetAvatars: 'PRESET_AVATARS',
    assetsGet: 'ASSETS_GET',
    assetsUpdate: 'ASSETS_UPDATE',
    assetsGetByIds: 'ASSETS_GET_BY_IDS',
    assetsAdd: 'ASSETS_ADD',
    assetsRemove: 'ASSETS_REMOVE',
    assetsMove: 'ASSETS_MOVE',
    assetsListModify: 'ASSETS_LIST_MODIFY',
    contactInfo: 'CONTACT_INFO',
    contactAdd: 'CONTACT_ADD',
    contactUpdate: 'CONTACT_UPDATE',
    contactPresence: 'CONTACT_PRESENCE',
    contactList: 'CONTACT_LIST',
    contactSearch: 'CONTACT_SEARCH',
    contactMutual: 'CONTACT_MUTUAL',
    contactPhotos: 'CONTACT_PHOTOS',
    contactSort: 'CONTACT_SORT',
    contactVerify: 'CONTACT_VERIFY',
    removeContactPhoto: 'REMOVE_CONTACT_PHOTO',
    contactInfoByPhone: 'CONTACT_INFO_BY_PHONE',
    chatInfo: 'CHAT_INFO',
    chatHistory: 'CHAT_HISTORY',
    chatMark: 'CHAT_MARK',
    chatMedia: 'CHAT_MEDIA',
    chatDelete: 'CHAT_DELETE',
    chatsList: 'CHATS_LIST',
    chatClear: 'CHAT_CLEAR',
    chatUpdate: 'CHAT_UPDATE',
    chatCheckLink: 'CHAT_CHECK_LINK',
    chatJoin: 'CHAT_JOIN',
    chatLeave: 'CHAT_LEAVE',
    chatMembers: 'CHAT_MEMBERS',
    publicSearch: 'PUBLIC_SEARCH',
    chatPersonalConfig: 'CHAT_PERSONAL_CONFIG',
    chatCreate: 'CHAT_CREATE',
    msgSend: 'MSG_SEND',
    msgTyping: 'MSG_TYPING',
    msgDelete: 'MSG_DELETE',
    msgEdit: 'MSG_EDIT',
    chatSearch: 'CHAT_SEARCH',
    msgSharePreview: 'MSG_SHARE_PREVIEW',
    msgGet: 'MSG_GET',
    msgSearchTouch: 'MSG_SEARCH_TOUCH',
    msgSearch: 'MSG_SEARCH',
    msgGetStat: 'MSG_GET_STAT',
    chatSubscribe: 'CHAT_SUBSCRIBE',
    msgDeleteRange: 'MSG_DELETE_RANGE',
    msgReaction: 'MSG_REACTION',
    msgCancelReaction: 'MSG_CANCEL_REACTION',
    msgGetReactions: 'MSG_GET_REACTIONS',
    msgGetDetailedReactions: 'MSG_GET_DETAILED_REACTIONS',
    chatReactionsSettingsSet: 'CHAT_REACTIONS_SETTINGS_SET',
    reactionsSettingsGetByChatId: 'REACTIONS_SETTINGS_GET_BY_CHAT_ID',
    videoChatStart: 'VIDEO_CHAT_START',
    chatMembersUpdate: 'CHAT_MEMBERS_UPDATE',
    videoChatStartActive: 'VIDEO_CHAT_START_ACTIVE',
    videoChatHistory: 'VIDEO_CHAT_HISTORY',
    videoChatCreateJoinLink: 'VIDEO_CHAT_CREATE_JOIN_LINK',
    videoChatMembers: 'VIDEO_CHAT_MEMBERS',
    getInboundCalls: 'GET_INBOUND_CALLS',
    photoUpload: 'PHOTO_UPLOAD',
    stickerUpload: 'STICKER_UPLOAD',
    videoUpload: 'VIDEO_UPLOAD',
    videoPlay: 'VIDEO_PLAY',
    chatPinSetVisibility: 'CHAT_PIN_SET_VISIBILITY',
    fileUpload: 'FILE_UPLOAD',
    fileDownload: 'FILE_DOWNLOAD',
    linkInfo: 'LINK_INFO',
    audioPlay: 'AUDIO_PLAY',
    sessionsInfo: 'SESSIONS_INFO',
    sessionsClose: 'SESSIONS_CLOSE',
    phoneBindRequest: 'PHONE_BIND_REQUEST',
    phoneBindConfirm: 'PHONE_BIND_CONFIRM',
    chatComplain: 'CHAT_COMPLAIN',
    msgSendCallback: 'MSG_SEND_CALLBACK',
    suspendBot: 'SUSPEND_BOT',
    chatBotCommands: 'CHAT_BOT_COMMANDS',
    botInfo: 'BOT_INFO',
    locationStop: 'LOCATION_STOP',
    getLastMentions: 'GET_LAST_MENTIONS',
    stickerCreate: 'STICKER_CREATE',
    stickerSuggest: 'STICKER_SUGGEST',
    notifMessage: 'NOTIF_MESSAGE',
    notifTyping: 'NOTIF_TYPING',
    notifMark: 'NOTIF_MARK',
    notifContact: 'NOTIF_CONTACT',
    notifPresence: 'NOTIF_PRESENCE',
    notifConfig: 'NOTIF_CONFIG',
    notifChat: 'NOTIF_CHAT',
    notifAttach: 'NOTIF_ATTACH',
    notifCallStart: 'NOTIF_CALL_START',
    notifContactSort: 'NOTIF_CONTACT_SORT',
    notifMsgDeleteRange: 'NOTIF_MSG_DELETE_RANGE',
    notifMsgDelete: 'NOTIF_MSG_DELETE',
    notifCallbackAnswer: 'NOTIF_CALLBACK_ANSWER',
    notifLocation: 'NOTIF_LOCATION',
    notifLocationRequest: 'NOTIF_LOCATION_REQUEST',
    notifAssetsUpdate: 'NOTIF_ASSETS_UPDATE',
    notifDraft: 'NOTIF_DRAFT',
    notifDraftDiscard: 'NOTIF_DRAFT_DISCARD',
    notifMsgDelayed: 'NOTIF_MSG_DELAYED',
    notifMsgReactionsChanged: 'NOTIF_MSG_REACTIONS_CHANGED',
    notifMsgYouReacted: 'NOTIF_MSG_YOU_REACTED',
    notifProfile: 'NOTIF_PROFILE',
    notifBanners: 'NOTIF_BANNERS',
    notifFolders: 'NOTIF_FOLDERS',
    okToken: 'OK_TOKEN',
    webAppInitData: 'WEB_APP_INIT_DATA',
    complain: 'COMPLAIN',
    complainReasonsGet: 'COMPLAIN_REASONS_GET',
    draftSave: 'DRAFT_SAVE',
    draftDiscard: 'DRAFT_DISCARD',
    chatHide: 'CHAT_HIDE',
    chatSearchCommonParticipants: 'CHAT_SEARCH_COMMON_PARTICIPANTS',
    profileDelete: 'PROFILE_DELETE',
    profileDeleteTime: 'PROFILE_DELETE_TIME',
    authQrApprove: 'AUTH_QR_APPROVE',
    chatSuggest: 'CHAT_SUGGEST',
    sendVote: 'SEND_VOTE',
    votersListByAnswer: 'VOTERS_LIST_BY_ANSWER',
    getPollUpdates: 'GET_POLL_UPDATES',
    foldersGet: 'FOLDERS_GET',
    foldersGetById: 'FOLDERS_GET_BY_ID',
    foldersUpdate: 'FOLDERS_UPDATE',
    foldersReorder: 'FOLDERS_REORDER',
    foldersDelete: 'FOLDERS_DELETE',
  };
}
