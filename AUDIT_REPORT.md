# Komet — Аудит качества кода

_Многоагентный аудит: 22 искателя по подсистемам + 6 сквозных охотников за дублированием, каждая находка перепроверена отдельным скептиком по реальному коду. 57 агентов, 231 подтверждённая находка._

## 🔧 Прогресс исправлений

Статусы: ✅ сделано · 🔧 в работе · ⏭️ отложено (крупный рефактор/риск) · ⬜ не начато

Легенда важна: одной сессии на все 231 не хватит. Здесь отмечается, что уже поправлено, чтобы следующая сессия продолжила с места.

### Сессия 1 (2026-07-04)

| # | Находка | Файлы | Статус |
|---|---------|-------|--------|
| H1 | Outbox: per-row catch+log+continue вместо break/swallow | `outbox.dart` | ✅ |
| H2 | switchAccount: не глотать падение connect, сообщать об ошибке | `account.dart` | ✅ |
| H5 | Пароль прокси → secure storage (TokenStorage) | `proxy_config.dart` | ✅ |
| H7 | DebugSessionLog → общий redactForLog | `debug_session_log.dart`, `log_redact.dart` | ✅ |
| H10 | Батч-префетч контактов ensureContactNames | `chat_list_screen.dart` | ✅ |
| H12 | popUntil: назвать роут SecurityScreen | `settings_tab.dart` | ✅ |
| QW | PollView.initState → fetch(force: false) | `poll_view.dart` | ✅ |
| QW | SnackBar → showCustomNotification | `spoof_screen.dart` | ✅ |
| QW | Убрать print()-дебаг из релиза | `push_service.dart`, `chat_list_screen.dart`, `chat_screen.dart` | ✅ |
| QW | tz.initializeTimeZones за одноразовый флаг | `api.dart` | ✅ |
| QW | Guard push-handler dispatch в try/catch+log | `dispatcher.dart` | ✅ |
| QW | calls.dart uuid → Random.secure (общий util) | `calls.dart`, `device_identity.dart`, `spoofing_service.dart`, `utils/ids.dart` | ✅ |
| QW | SelfCheckService pause/resume по lifecycle | `self_check.dart`, `main.dart` | ✅ |
| QW | chat_info: local _formatLastSeen → общий formatLastSeen | `chat_info_screen.dart` | ✅ |
| QW | cloud-storage: слить 4 chatUpdate в один | `cloud_storage.dart` | ✅ |
| QW | _loadForwardedSenderNames → copyWith | `chat_screen.dart` | ✅ |
| QW | WebAppScreen/DigitalIdWebScreen дубль | `web_app_screen.dart`, `digital_id_web_screen.dart` | ⏭️ |
| QW | formatPhone: RegExp в static final | `format.dart` | ✅ |
| H15 | Декомпозиция chat_screen.dart (god-file) | `chat_screen.dart`, `chat/`, `chat/view/` | ✅ (сессии 3–8: **логика** — список изолирован + prank + `ChatController` (message-state + history/pagination + initial-load) + Composer-под-контроллеры **voice/video-note/command-panel/sticker** + **ChatSearchController**; сессия 9: **H15b тонкая композиция** — build-дерево композера/поиска/selection/header вынесено в 7 виджетов под `chat/view/` + `UploadStatus`; **chat_screen 6770→4909 строк**, −27%. send-пути/`_photoUploadProgress`/оркестраторы `_buildAppBar`/`_buildComposerArea` обоснованно в State) |
| H16 | Декомпозиция message_bubble.dart | — | ✅ (сессия 5: `BubbleContext` + 12 per-type бабблов вынесены; `MessageBubble` 2832→1225, тонкий диспетчер) |
| H17 | ChatsModule → instantiable repository | `backend/modules/chats.dart`, `chat_parsing.dart`, +14 вызывателей | ✅ (сессия 10) |
| H3 | Общий HTTP-хелпер для 5 upload-путей | `file_uploader.dart` | ✅ (сессия 3) |
| H4 | PersistedSetting<T> для ~17 config-классов | `core/config/*` | ✅ (сессия 3) |
| H6 | CustomFontService: legacy UA | `custom_font_service.dart` | ⏭️ требует проверки на устройстве |
| H11 | Убрать `as dynamic` в message_bubble | `message_bubble.dart` | ✅ (сессия 4) |
| H14 | Типизированный ContactInfo/ChatInfo | `backend/modules/*`, экраны | ✅ (сессия 4: ContactInfo; сессия 5: ChatInfo) |

**Сессия 1 итог (2026-07-04):** закрыто 17 пунктов (все локальные high + быстрые победы). `flutter analyze` — **0 ошибок, 0 новых предупреждений**. Изменения в рабочем дереве, не закоммичены.

Сделано: убрано глотание ошибок в Outbox/switchAccount (+вызыватели показывают уведомление); прокси-креды переведены в secure storage (с миграцией старых plaintext); debug-лог теперь через общий `redactForLog`; батч-префетч контактов; popUntil чинит возврат на SecurityScreen; уведомление-конвенция (SnackBar→showCustomNotification); все `print()`-дебаги вырезаны из релиза; общий `utils/ids.dart` (secure UUID) вместо 3 копий; `SelfCheckService` пауза/резюм по lifecycle; last-seen через общий хелпер; 4 privacy-запроса → 1; tz-инициализация один раз; guard на push-хендлеры; логаут чистит spoof-состояние; `formatPhone` не компилит RegExp каждый вызов.

Обнаружено попутно: `_showMessageNotification` / `_showCallNotification` в `push_service.dart` — мёртвый Dart-код (живой путь уведомлений — нативный Kotlin FCM). Помечено к удалению отдельной сессией (риск каскада по хелперам `_avatarBytes`/`_appendHistory`/…).

> ⏭️-пункты — следующие сессии: крупные декомпозиции (chat_screen/message_bubble/ChatsModule), общий HTTP-хелпер аплоада, PersistedSetting<T>, типизированные ContactInfo/ChatInfo, CustomFontService (нужна проверка на устройстве) — требуют отдельного плана и прогонов сборки.

### Сессия 2 (2026-07-04) — мелкое/среднее

| Находка | Файлы | Статус |
|---------|-------|--------|
| Общие `formatDurationClock` + `formatFileStamp`; убраны локальные `_fileStamp`×2 и `_fmt` | `format.dart`, `traffic_monitor_screen.dart`, `debug_menu_screen.dart`, `video_player_screen.dart` | ✅ |
| Общий `Debouncer` вместо ручных Timer-дебаунсов | `utils/debouncer.dart`, `search_screen.dart`, `appearance_screen.dart` | ✅ |
| Перф: поиск страны не лоуэркейсит весь список на каждый ввод | `select_country_screen.dart` | ✅ |
| `sendFileMessage`: убран лишний фиксированный 3s-sleep (retry-цикл покрывает) | `messages.dart` | ✅ |
| Дедуп извлечения серверной ошибки (`_throwSendError`) в sendMessage/forwardMessage | `messages.dart` | ✅ |
| Логирование вместо проглатывания ошибок (Polls/CallBridge/resolveContacts) | `polls.dart`, `call_bridge.dart`, `calls.dart` | ✅ |
| Дедуп парсинга arch из `Platform.version` (Linux/Windows) | `api.dart` | ✅ |

### Сессия 3 (2026-07-04) — крупная декомпозиция chat_screen

| Находка | Файлы | Статус |
|---------|-------|--------|
| H8/H9: список сообщений больше не ребилдится на изменение высоты композера — высота вынесена в отдельный спейсер-item (index 0), убран из `padding`/гейта | `chat_screen.dart` | ✅ |
| H8/H9: read-receipt больше не ребилдит весь список — статус-галочка `sent→read` реактивна через per-icon `ValueListenableBuilder<int>(_otherReadTime)` внутри бабла (текст + голос) | `chat_screen.dart`, `message_bubble.dart` | ✅ |
| H15 (шаг 1): список вынесен в отдельный виджет `_ChatMessageList` (кэш-инстанс + `_messageListKey`) — 24 `setState` предка больше не каскадят в список; список ребилдится только по `_messagesRev`. Добавлен `_bumpMessages()` в точки смены `chat`/`_isLoadingMore`/визуального стиля | `chat_screen.dart` | ✅ |
| H4: `PersistedSetting<T>`/`PersistedEnum<T>` (`persisted_setting.dart`); мигрированы ~16 простых классов с сохранением статических фасадов; `load()` теперь self-assign; из `main.dart` убран парный блок из 18 присвоений (→ `Future.wait`). Бэспоку: `AppThemeSchedule` (self-assign), `AppIconConfig`/`KometSettings`/`AppAccent` (иной паттерн) | `core/config/*`, `main.dart` | ✅ |
| H3: единый `_sendHttpRequest` (жизненный цикл сокета/заголовки из Map) + `_withProgress` (троттл-прогресс) + единый билдер заголовков; 5 upload-путей переведены на примитивы, поведение сохранено (порядок заголовков, статус-vs-полное чтение, отмена, прогресс) | `file_uploader.dart` | ✅ |

**Сессия 3 итог (2026-07-04):** H8/H9 закрыты полностью (главная перф-проблема); первый шаг декомпозиции H15 — список изолирован от каскадных ребилдов предка. `flutter analyze` — **0 ошибок, 0 новых предупреждений**. Дальше по H15: вынести ChatController/ChatComposer/ChatSearchOverlay/ChatSelectionBar; H16 — разнести бабблы по типам.

### Сессия 4 (2026-07-04) — H16/H11/H14 + шаг H15

| Находка | Файлы | Статус |
|---------|-------|--------|
| H11: убраны все 10 `as dynamic` — `_buildVideoAttachment`/`_playVideo`/`_buildFileAttachment`/`_downloadFile` типизированы `VideoAttachment`/`FileAttachment`, сужение один раз в диспетчере `_buildGenericAttachment` | `message_bubble.dart` | ✅ |
| H16 (шаг 1): два stateful-плеера вынесены в отдельные файлы — `VoiceMessageBubble`(+`_WaveformPainter`) и `VideoNoteBubble`; реактивность голосового статуса через `otherReadTime` сохранена; `message_bubble.dart` 3521→2836 строк | `message_bubble.dart`, `widgets/attachment/bubbles/voice_bubble.dart`, `widgets/attachment/bubbles/video_note_bubble.dart` | ✅ |
| H14: типизированный `ContactInfo` (+`ContactName`) с каноническим `displayName` (приоритет ONEME → первый непустой label); парсинг один раз на границе `ContactInfoFetch` (`InfoCache<ContactInfo>`); удалены 5 ручных экстракторов (`_contactName`×2, `_displayName`, `_peerName`, `_nick`), контакт теперь рендерит одно имя на всех экранах | `models/contact_info.dart`, `core/cache/info_cache.dart`, `calls/call_screen.dart`, `contacts/contact_profile_screen.dart`, `contacts/nfc_exchange_sheet.dart`, `chats/chat_info_screen.dart`, `commands/info_command.dart`, `contacts/contacts_tab.dart` | ✅ |
| H15 (шаг 2): prank-пасхалка (state + `checkTrigger`/`pinkTheme`/reveal/cleanup, ~95 строк) вынесена в `ChatPrankController`; fragile message-core (`_messages`/`_messagesRev`/`_isLoadingMore`/`_ChatMessageList`) не тронут | `chat_screen.dart`, `chats/chat/chat_prank_controller.dart` | ✅ |

**Сессия 4 итог (2026-07-04):** H11 и H14(ContactInfo) закрыты полностью; H16 и H15 продвинуты (плееры + prank вынесены). `flutter analyze` — **0 ошибок, 0 новых предупреждений** (только 2 известных пред-существующих: dead push-код). Изменения в рабочем дереве, не закоммичены. Дальше: H16 — per-type content-бабблы (photo/poll/share/call/location/contact/file) в дисп­етчер по `AttachmentType` (требует продвижения `_BubbleCtx`→общий контекст с `message`/колбэками); H15 — ChatController(ChangeNotifier: история/пагинация/подписки), ChatComposer, ChatSearchOverlay; H14 — типизированный ChatInfo (снять int/String-коэрцию в `chat_info_screen`).

### Сессия 5 (2026-07-04) — H16 (шаг 2) + H15 (шаг 3) + H14-добивка

| Находка | Файлы | Статус |
|---------|-------|--------|
| H16 (шаг 2): приватный `_BubbleCtx` продвинут в публичный `BubbleContext` (несёт `message`/`isMe`/`myId`/`chatType`/`overrideStatus`/`otherReadTime`/`uploadProgress`/`onStickerTap` + общие рендер-хелперы `clockText`/`meta`/`caption`/`compactTime`/`statusIcon`/`deletedIcon`). 12 per-type content-бабблов вынесены по `AttachmentType` в `widgets/attachment/bubbles/` (poll, share, call, location, contact, sticker, photo(+грид/тайлы/оверлеи/viewer), video(+плеер), file(+download), forwarded photo/generic/contact). `MessageBubble` теперь тонкий диспетчер (chrome: build/bubble/makeCtx + text/control/reply/keyboard/reactions/sender). `message_bubble.dart` 2832→1225 строк; compact-time-оверлей на фото/видео и `_buildMeta/_buildCaption/_buildCompactTime` сохранены (стали методами `BubbleContext`) | `message_bubble.dart`, `widgets/attachment/bubbles/{bubble_context,poll,share,call,location,contact,sticker,photo,video,file,forwarded}_bubble.dart` | ✅ |
| H15 (шаг 3, часть 1): создан `ChatController extends ChangeNotifier` (`chat/chat_controller.dart`), владеющий message-render-state (`messages`/`messagesRev`/`hasMoreHistory`/`isLoadingMore`/`historyKickedOff`) + чистые операции `bump()`/`prependOlder()`. `_ChatScreenState` делегирует через прозрачные геттеры/сеттеры — все ~118 сайтов (`_messages`/`_messagesRev`/флаги) и `_ChatMessageList` (слушает `host._messagesRev`) не тронуты; `_bumpMessages`-гейт и `_combinedItemsCache`-инвалидация сохранены. Безопасный шов; миграция history/pagination/subscriptions-**логики** в контроллер — часть 2 | `chat_screen.dart`, `chats/chat/chat_controller.dart` | 🔧 |
| H14-добивка: типизированный `ChatInfo` (`models/chat_info.dart`, зеркалит `ContactInfo`: `raw` + типобезопасные `participantIds`/`adminIds`/`owner` + `isAdmin`/`isOwner`/`participantsCount`/`link`/`description`). Парсинг один раз на границе `ChatInfoFetch` (`InfoCache<ChatInfo>`). Снята int/String-коэрция: `admins.containsKey(id.toString())‖containsKey(id)` → `chatInfo.isAdmin(id)`; `k is int ? k : int.tryParse(...)` × 2 → `participantIds`. `cacheServerChat(chatInfo.raw, …)` в `chats.dart` (единственный бэкенд-риппл) | `models/chat_info.dart`, `core/cache/info_cache.dart`, `chats/chat_info_screen.dart`, `backend/modules/chats.dart` | ✅ |

**Сессия 5 итог (2026-07-04):** H16 закрыт полностью (декомпозиция `message_bubble` 2832→1225; 12 per-type бабблов в `bubbles/` + публичный `BubbleContext`; экстракция построчно перепроверена скептик-агентом против пред-экстракшн-снапшота — parity OK по всем 11 виджетам, включая photo-radius-логику и call-subtitle-интерполяцию); H14 закрыт полностью (типизированный `ChatInfo`, коэрция снята); H15 продвинут (шаг 3 часть 1 — `ChatController`-шов владеет message-state). Новых файлов: 12 (11 бабблов + `bubble_context`) + `chat_controller.dart` + `models/chat_info.dart`. `flutter analyze` — **0 ошибок, 0 новых предупреждений** (только 2 известных пред-существующих: dead push-код `_showMessageNotification`/`_showCallNotification`). Изменения в рабочем дереве, не закоммичены. Дальше (Сессия 6): H15 шаг 3 часть 2 — миграция history/pagination-**логики** (`_loadHistory`/`_loadMoreHistory`/`_loadOlderFromDb`/`_persistSessionCache`/`_applyMergedMessages`) и подписок в `ChatController` через коллбэки/хуки (onLoadingFinished/onMessagesChanged), затем `ChatComposer`/`ChatSearchOverlay`.

### Промпт для Сессии 6

```
Продолжаем рефакторинг Komet по AUDIT_REPORT.md (секция «Прогресс исправлений», Сессии 1–5 закрыты).
Работа НЕ закоммичена — пиши код, git-коммиты не делай. Flutter: /home/a/flutter/bin/flutter.
Норма: 0 errors, 0 новых warnings (известны 2 пред-существующих: dead push-код
_showMessageNotification/_showCallNotification в push_service.dart). Утилиты/модели ИСПОЛЬЗУЙ:
core/utils/{format,ids,debouncer,log_redact}.dart, core/config/persisted_setting.dart,
models/{contact_info,chat_info}.dart, widgets/attachment/bubbles/bubble_context.dart,
screens/chats/chat/{chat_controller,chat_prank_controller}.dart. Конвенции: без комментариев;
showCustomNotification (не SnackBar); правильный рефактор вместо хака. Метод: sonnet-агенты на
непересекающихся файлах — точные находки+локации+решение+рамки, потом сам ревьюь диффы и гоняй analyze.
Маленькие шаги.

Приоритеты:
1. H15 (шаг 3, часть 2) — перенести ЛОГИКУ истории/пагинации в ChatController(ChangeNotifier).
   Сейчас контроллер владеет только message-state (messages/messagesRev/hasMoreHistory/isLoadingMore/
   historyKickedOff) + bump()/prependOlder(); State делегирует через геттеры/сеттеры. Перенести чистые
   методы: _loadOlderFromDb (DB), _persistSessionCache (нужны myId+chatId), и переработать оркестраторы
   _loadHistory/_loadRemainingHistory/_loadMoreHistory/_maybeLoadMoreHistory/_applyMergedMessages так,
   чтобы данные-логика жила в контроллере, а UI-сайд-эффекты (setState/_onLoadingFinished/
   _loadForwardedSenderNames/_loadGroupSenderNames/_syncReactionNotifiersFromMessages/scroll) остались
   в State и вызывались через коллбэки контроллера (onLoadingFinished/onMessagesChanged/onError).
   ВНИМАНИЕ: _bumpMessages чистит _combinedItemsCache (State-концерн) + bump контроллера — не потерять
   инвалидацию кэша; _ChatMessageList слушает host._messagesRev; myId резолвится асинхронно в _loadHistory.
   Мелкими шагами, analyze после каждого.
2. H15 — вынести подписки (_uploadSub/_pushSub/_messageEventSub/_connSub/_voiceAmpSub) — оценить,
   что можно вынести без переноса UI-хендлеров (_onIncomingPush/_onMessageEvent — сильно UI-связаны).
3. H15 — ChatComposer (композер: текст/вложения/запись голоса/высота _composerHeight) и
   ChatSearchOverlay (поиск по сообщениям) — если хватит бюджета.

H16 и H14 закрыты. После каждого пункта обнови AUDIT_REPORT.md (✅/🔧) и добавь строку в «Сессию 6».
В конце — промпт для Сессии 7.
```

### Сессия 6 (2026-07-04) — H15 (шаг 3, часть 2): history/pagination-логика в контроллер

| Находка | Файлы | Статус |
|---------|-------|--------|
| H15 (шаг 3, часть 2): history/pagination-**логика** перенесена из `_ChatScreenState` в `ChatController`. Контроллер теперь владеет `chatId`/`myId` (State-геттеры `_myId`/`chatId` делегируют) + чистыми данными-методами: `loadInitialFromDb`/`loadOlderFromDb` (DB-страницы), `mergeMessages`+`_sameMessage` (dedup/merge/sort), `persistSessionCache`, и полным оркестратором пагинации `loadMoreHistory(onLoadingStarted/onLoaded/onError)`. UI-сайд-эффекты остались в State и вызываются через коллбэки: `_bumpMessages` (инвалидация `_combinedItemsCache` + rev), `_syncReactionNotifiersFromMessages`/`_pruneReactionNotifiers`, `_loadForwardedSenderNames`/`_loadGroupSenderNames`, `setState`/`_isLoading`/`_onLoadingFinished`. `_loadRemainingHistory`/`_loadHistory` остались тонкими State-оркестраторами (владеют `_previewChat`/`_isLoading`/preview-flow — виджет-концерны), делегируя данные-операции контроллеру. Кэш-инвалидация сохранена (rev-driven: `mergeMessages`/`prependOlder` бампят `messagesRev`, ключ `_buildCombinedItems` = hash(rev,length)). Константы `_historyPageSize`/`_historyInitialLimit` переехали в контроллер | `chat_screen.dart` (−~90 строк логики), `chats/chat/chat_controller.dart` (35→167 строк) | 🔧 |
| H15: оценка подписок (приоритет 2) — `_pushSub`→`_onIncomingPush`, `_messageEventSub`→`_onMessageEvent`, `_connSub`→`_recomputeHeaderStatus` неотделимы от сильно-UI-связанных хендлеров (mark/typing/delayed, header-статус); `_uploadSub`/`_voiceAmpSub` принадлежат будущему `ChatComposer` (upload-прогресс/запись голоса). Standalone-вынос `.listen()` без хендлеров — низкоценный churn; отложено к Composer-экстракции | `chat_screen.dart` | ⏭️ (оценено) |

**Сессия 6 итог (2026-07-04):** H15 продвинут (шаг 3 часть 2 — history/pagination-логика в `ChatController`; пагинация/merge/DB-загрузки/session-cache теперь тестируемы без виджета). Подписки оценены и отложены (неотделимы от UI-хендлеров или принадлежат Composer). Parity перепроверена скептик-агентом против **HEAD-бейзлайна** (`git show HEAD:…`, не рабочего дерева): регрессий нет по всем путям — guard/`mounted`-гейты сохранены, rev-driven инвалидация кэша достаточна, `logger.e` не дублируется, `fullDecoded.isNotEmpty`≡`fullRows.isNotEmpty` (`fromDbRowsAsync` мапит 1:1), `messagesRev` не диспозится дважды, геттер/сеттер-шимы не могут рассинхронить `_myId`/флаги/`_messages`. `flutter analyze` (полный проект) — **0 ошибок, 0 новых предупреждений** (только пред-существующие: 2 dead-push-warning + SDK-deprecation `cacheExtent`/`axisAlignment`, всё вне зоны правок). Изменения в рабочем дереве, не закоммичены. Дальше (Сессия 7): `ChatComposer` (текст/вложения/запись голоса/`_uploadSub`/`_voiceAmpSub`/`_composerHeight`) — самый крупный оставшийся кусок; затем `ChatSearchOverlay` (поиск — но `_searchAnim` вплетён в интерполяцию высоты хедера, `_openSearchResult` оркестрирует scroll+пагинацию — распутывать аккуратно).

### Сессия 7 (2026-07-04) — H15: декомпозиция ChatComposer по под-кускам

| Находка | Файлы | Статус |
|---------|-------|--------|
| H15 (ChatComposer, под-кусок 1 — запись голоса): state-машина записи голосовых вынесена из `_ChatScreenState` в `VoiceRecordController` (`chat/voice_record_controller.dart`, образец `ChatPrankController`: callbacks `contextOf`/`isMounted`/`myId`/`onRecorded`). Контроллер владеет `AudioRecorder`, 7 UI-нотифаерами (`isRecording`/`elapsedMs`/`cancelDrag`/`amplitude`/`waveRev`/`locked`/`lockDrag` — экспонированы как `ValueListenable`-геттеры + сырой `amps`), `Stopwatch`/`Timer`/`_ampSub`/`_path`/флаги, методами `start`/`handleDrag`/`handleEnd`/`stop`/`dispose` и энкодингом `_transcodeWavToOgg`. Пороги `minMs`/`cancelThreshold` — публичные статик-консты (переиспользуются note-хендлерами), `_lockThreshold` приватный. Send-путь (`_sendVoice`/`_buildWave`) остался в State (сильно связан с `_messages`/outbox/`_photoUploadProgress`/`_bumpMessages`) — контроллер отдаёт готовый файл через `onRecorded`. UI-методы (`_recordingButtonVisual`/`_voiceLockChip`/`_buildVoiceRecordingIndicator`) остались в State, читают нотифаеры через `_voiceRec.*`. Убраны неиспользуемые импорты `record`/`opus_ogg_encoder`/`path_provider` из `chat_screen`. Parity перепроверена скептик-агентом против HEAD — PARITY OK | `chat_screen.dart` (−~180 строк), `chats/chat/voice_record_controller.dart` (новый, 268 строк) | ✅ |
| H15 (ChatComposer, под-кусок 2 — видео-кружки): state-машина видео-заметок вынесена в `VideoNoteController` (`chat/video_note_controller.dart`; callbacks `contextOf`/`isMounted`/`onRecorded`/`formatElapsed`). Контроллер владеет `NativeVideoNoteRecorder`, 6 нотифаерами (`videoNoteMode`/`textureId`/`camReady`/`isRecording`/`elapsedMs`/`cancelDrag` — `videoNoteMode`/`camReady`/`isRecording` экспонированы как `ValueListenable`), `Stopwatch`/`Timer`/флаги/`OverlayEntry`, методами `toggleMode`/`_initCamera`/`_disposeCamera`/`start`/`handleDrag`/`handleEnd`/`stop`/`dispose` + оверлеем предпросмотра камеры (`_showOverlay`/`_hideOverlay`, `Texture` в `ClipOval`, вставка через `Overlay.of(rootOverlay)`). Пороги переиспользуют `VoiceRecordController.cancelThreshold`/`.minMs`. Send-путь `_sendVideoNote` остался в State (`_myId==0`-guard/`_messages`/outbox) — контроллер зовёт через `onRecorded`; `_formatVoiceElapsed` остался в State (общий с voice-индикатором), прокинут коллбэком `formatElapsed`. Убран неиспользуемый импорт `native_video_note_recorder` из `chat_screen`. Parity перепроверена скептик-агентом против HEAD — PARITY OK | `chat_screen.dart` (−~190 строк), `chats/chat/video_note_controller.dart` (новый, 243 строки) | ✅ |
| H15 (ChatComposer, под-кусок 3 — панель слэш-команд): логика саджест-панели команд вынесена в `CommandPanelController` (`chat/command_panel_controller.dart`; callbacks `vsync`/`textOf`/`onSelected`). Контроллер владеет `AnimationController anim` (200ms, экспонирован), `ValueNotifier<List<SlashCommand>> matches` (экспонирован), приватным `_visible`, чистым матчером `_matching` (== `_matchingCommands`: `/`-префикс, no-whitespace, exact-name→скрыть, startsWith-фильтр) и `update()` (== `_updateCommandPanel`: listEquals-гейт + visible-гейт → forward/reverse). Сам подписывается на `AppCommands.current` в конструкторе и отписывается в `dispose` (создаётся ЭАГЕРНО — `late final` без инициализатора, присваивается в `initState` на месте старого `addListener`, чтобы регистрация слушателя не отложилась). `_onCommandSelected` (мутация `_messageController`/focus) остался в State, зовётся через `onSelected`; `_buildCommandPanel` читает `_commandPanel.anim`/`.matches`/`.select`. Parity перепроверена скептик-агентом против HEAD — PARITY OK | `chat_screen.dart` (−~35 строк), `chats/chat/command_panel_controller.dart` (новый, 65 строк) | ✅ |
| H15 (ChatComposer): оценка оставшихся под-кусков — **attachment-панель** (`_showAttachmentPanel`/`_attachAnim`) — `_attachAnim` вплетён в композер-build в ~10 местах (интерливленные `AnimatedBuilder`/`_ButtonClipper`/`_HistoryStrip`), контроллер владел бы только `AnimationController`, который build всё равно читает → тонкий вынос, много точек касания, низкая ценность (как отложенные подписки в С6); **стикер-панель** (`_showStickerPanel`/`_stickerAnim`) — связана с typing-индикатором (`_stickerTypingTimer`/`_sendStickerTyping`/ghostMode), focus-интерплеем (`_onComposerFocusChanged`) и send-путём (`_sendSticker`→`_sendAttachMessage`); **upload** (`_uploadSub`/`fileUploader`/`_uploadStatus`/`_photoUploadProgress`) — `_photoUploadProgress` разделяется всеми send-путями (voice/photo/video/note) и завязан на outbox/`_bumpMessages` → принадлежит State. Отложено к отдельной оценке | `chat_screen.dart` | ⏭️ (оценено) |

**Сессия 7 итог (2026-07-04):** ChatComposer декомпозирован по трём автономным под-кускам: запись голоса (`VoiceRecordController`, 268 строк), видео-кружки (`VideoNoteController`, 243 строки), панель слэш-команд (`CommandPanelController`, 65 строк). Все три — по образцу `ChatPrankController` (callback-швы, send-путь остаётся в State). Каждый под-кусок: `flutter analyze` после экстракшна + parity скептик-агентом против **HEAD** (не рабочего дерева) — все три **PARITY OK** (методы verbatim, нотифаеры диспозятся ровно раз, порядок forward/reverse и listEquals-гейты сохранены, AppCommands-слушатель эагерный, send-пути байт-идентичны). Оставшиеся под-куски (attach/sticker-панели, upload) оценены как тонко-анимационный churn либо send/outbox-связанные → отложены. `flutter analyze` (весь проект) — **0 ошибок, 0 новых предупреждений** (только пред-существующие: 2 dead-push-warning + SDK-deprecation `cacheExtent`/`axisAlignment`, вне зоны). Изменения в рабочем дереве, не закоммичены. Новых файлов: 3 (`voice_record_controller`/`video_note_controller`/`command_panel_controller`). Дальше (Сессия 8): при желании — StickerPanelController (с typing-таймером через коллбэк), либо переход к приоритету 2 (`_loadHistory`/`_loadRemainingHistory` → контроллер) или 3 (`ChatSearchOverlay`, осторожно — `_searchAnim` в интерполяции высоты хедера).

### Промпт для Сессии 8

```
Продолжаем рефакторинг Komet по AUDIT_REPORT.md (секция «Прогресс исправлений», Сессии 1–7 закрыты).
Работа НЕ закоммичена — пиши код, git-коммиты не делай. Flutter: /home/a/flutter/bin/flutter.
Норма: 0 errors, 0 новых warnings (известны пред-существующие: dead push-код
_showMessageNotification/_showCallNotification в push_service.dart; SDK-deprecation cacheExtent/
axisAlignment в chat_screen.dart — НЕ трогать, вне зоны). Утилиты/модели ИСПОЛЬЗУЙ:
core/utils/{format,ids,debouncer,log_redact}.dart, core/config/persisted_setting.dart,
models/{contact_info,chat_info}.dart, widgets/attachment/bubbles/bubble_context.dart,
screens/chats/chat/{chat_controller,chat_prank_controller,voice_record_controller,
video_note_controller,command_panel_controller}.dart. Конвенции: без комментариев;
showCustomNotification (не SnackBar); правильный рефактор вместо хака. Метод: sonnet-агенты на
непересекающихся файлах — точные находки+локации+решение+рамки, потом сам ревьюь диффы и гоняй analyze.
Маленькие шаги, analyze после КАЖДОГО под-куска. Пиши минимум текста — только код и мысли.

Контекст: С7 вынесла из chat_screen три автономных под-контроллера композера (voice/video-note/
command-panel) по образцу ChatPrankController. send-пути (_sendVoice/_sendVideoNote/_sendSticker/
_sendMessage) и _photoUploadProgress ОСТАЛИСЬ в State (завязаны на _messages/outbox/_bumpMessages).

Приоритеты (по одному, analyze+parity-скептик против HEAD после каждого):
1. H15 — StickerPanelController: _showStickerPanel/_stickerAnim + typing-таймер (_stickerTypingTimer/
   _sendStickerTyping, ghostMode-гейт) + toggle-логика (_onStickerPanelToggle, focus-интерплей в
   _onComposerFocusChanged). Callbacks: vsync + onSendTyping (messagesModule.sendTyping через State).
   Экспонировать anim+showPanel для _buildStickerPanel. _sendSticker (send→_sendAttachMessage) ОСТАВИТЬ
   в State. ОЦЕНИ сначала focus-интерплей: _onComposerFocusChanged читает _showStickerPanel — если
   расплывётся в callback-суп, оставь панель в State и переходи к п.2/3.
2. H15 — attachment-панель: _showAttachmentPanel/_attachAnim + _onAttachPanelToggle. ВНИМАНИЕ: _attachAnim
   читается build-ом в ~10 местах (AnimatedBuilder/_ButtonClipper/_HistoryStrip/_recordingButtonVisual
   область) — контроллер владел бы только AnimationController, который build всё равно читает. Оценено в
   С7 как тонкий churn; делай ТОЛЬКО если найдёшь реальную логику сверх toggle (иначе пропусти).
3. H15 — ChatController: перенос _loadHistory/_loadRemainingHistory (тонкие State-оркестраторы; мешает
   владение _previewChat/_isLoading — отдать через applyMerged + onPreview/onLoadingFinished, ТОЛЬКО если
   не разрастётся callback-суп).
4. H15 — ChatSearchOverlay: _searchController/_searchResults/_runSearch/_openSearchResult. ВНИМАНИЕ:
   _searchAnim вплетён в интерполяцию высоты хедера (lerp _glossyHeaderHeight↔_glossySearchHeight) и
   _openSearchResult оркестрирует scroll+_loadMoreHistory. Распутывать осторожно или отложить.

H16 и H14 закрыты. После каждого под-куска обнови AUDIT_REPORT.md (✅/🔧) и добавь строку в «Сессию 8».
Parity перепроверяй скептик-агентом против HEAD (git show HEAD:…), а не рабочего дерева. В конце — промпт
для Сессии 9.
```

### Сессия 8 (2026-07-04) — H15: StickerPanelController + закрытие H15-логики

| Находка | Файлы | Статус |
|---------|-------|--------|
| H15 (ChatComposer, под-кусок 4 — стикер-панель): sticker-панель вынесена в `StickerPanelController` (`chat/sticker_panel_controller.dart`; callbacks `vsync`/`onSendTyping`). Контроллер владеет `AnimationController anim` (240/200, экспонирован), `ValueNotifier<bool> showPanel` (экспонирован), `double panelHeight` (300), `Timer? _typingTimer`. Сам подписывается на `showPanel` в конструкторе → `_onToggle` (== `_onStickerPanelToggle`: forward+`_sendTyping`+periodic(4s); else reverse+cancel). `_sendTyping` (== `_sendStickerTyping`: ghostMode-гейт → `onSendTyping`, прокинут `messagesModule.sendTyping(chatId,'STICKER')`) и `hide()` инкапсулированы. Focus-интерплей **оценён и оставлен тонким в State**: `_toggleStickerPanel` (keyboard-инсет/`FocusManager`/`requestFocus`) и `_onComposerFocusChanged` (читают `_stickers.showPanel.value`) — фокус-операции = виджет-концерн, не расплылись в callback-суп. `_sendSticker` (send→`_sendAttachMessage`) остался в State, зовёт `_stickers.hide()`. `_buildStickerPanel` читает `_stickers.anim`/`.panelHeight`. Parity перепроверена построчно против HEAD (`git show HEAD:…`) — PARITY OK (поля/длительности/toggle/focus/typing/send/build эквивалентны; teardown-шаги все по разу) | `chat_screen.dart` (−~40 строк), `chats/chat/sticker_panel_controller.dart` (новый, 54 строки) | ✅ |
| H15 (приоритет 2 — initial-load-оркестратор): `_loadRemainingHistory` (58 строк реальной оркестрации: DB-инит-загрузка → `wasHistoryFetched`-shortcut → preview/`ensureChatCached`/`subscribeChat`/`fetchHistory`/`markHistoryFetched`/`reconcileDeleted`/re-load/`reconcileLastMessage` + обработка ошибок) перенесён в `ChatController.loadRemainingHistory` — сиблинг уже-мигрированного `loadMoreHistory`, тот же callback-шов. 4 коллбэка (по образцу `loadMoreHistory`×3): `onApplyMerged` (→ State `_applyMergedMessages`: setState+reaction-нотифаеры+`persistSessionCache` — UI-концерн), `onLoadingFinished` (→ `setState(_isLoading=false; _onLoadingFinished())`), `onPreview` (→ `_previewChat=true`), `onSenderNames` (→ `_loadForwardedSenderNames`+`_loadGroupSenderNames`). `mounted`-гейты → `isMounted()`. `_loadHistory` оставлен тонким State-оркестратором (myId-резолв + presence(DIALOG) + scheduled-count — виджет-flow), делегирует данные. Parity против HEAD — PARITY OK (каждая ветка 1:1; `fullDecoded.isNotEmpty≡fullRows.isNotEmpty` через 1:1 `fromDbRowsAsync`; `historyInitialLimit`==50; `onApplyMerged`-tearoff сохраняет дефолт `markLoaded:false`) | `chat_screen.dart` (−~50 строк), `chats/chat/chat_controller.dart` (+~52 строки) | ✅ |
| H15 (приоритет 3 — ChatSearchOverlay, слой (а): чистая логика поиска): данные-логика поиска вынесена в `ChatSearchController` (`chat/chat_search_controller.dart`; callbacks `chatId`/`isMounted`). Контроллер владеет `searchController`(TextEditingController)/`searchMode`/`results`/`loading`/`performed`(нотифаеры, экспонированы)/`_debounce`/`_seq`, сам подписывается на `searchController`→`_onTextChanged` (== `_onSearchTextChanged`: trim/cancel/empty→seq++reset/else debounce 300ms→runSearch), `runSearch` (== `_runSearch`: seq-guard `isMounted()&&seq==_seq`, try/catch/`logger.e`, map→`MessageSearchResult`), `submit` (cancel+run, для onSubmitted/search-кнопки), `reset` (close-time сбросы). `_MessageSearchResult`→публичный `MessageSearchResult` (`chat/message_search_result.dart`, `fromRaw` байт-идентичен). **Слой (б): `_searchAnim`/`_openSearchResult` ОСТАВЛЕНЫ в State** — `_searchAnim` вплетён в lerp высоты хедера (`_glossyHeaderHeight`↔`_glossySearchHeight`, `_buildAppBar`) + ещё ~6 build-сайтов; `_openSearchResult` оркеструет scroll+`_loadMoreHistory`+`_messages`-guard-цикл. `_openSearch`/`_closeSearch` тоже в State (владеют `_searchAnim`+`_searchFocusNode`), делегируют данные (`_search.searchMode`/`.reset()`). Parity против HEAD — PARITY OK (`_closeSearch`-reorder: `unfocus`/`anim.reverse` подняты выше сбросов — нет data-зависимости; `searchController.clear()` re-entry в живой листенер сохранён на той же относительной позиции; `_seq` инкрементится ровно 2× как в HEAD; teardown-шаги все по разу). `logger`-импорт удалён из `chat_screen` (последние два `logger.e` уехали в контроллеры) | `chat_screen.dart` (−~75 строк), `chats/chat/chat_search_controller.dart` (новый, 92 строки), `chats/chat/message_search_result.dart` (новый, 35 строк) | ✅ |
| H15 (приоритет 4 — attach-панель + upload): **оценено, оставлено в State** (закрывает H15-**логику**). `_onAttachPanelToggle` — чистый forward/reverse `_attachAnim` без сайд-эффектов (в отличие от sticker: нет typing-таймера/ghostMode), `_attachAnim` читается build-ом в ~8 местах (интерливленные `AnimatedBuilder`/клипперы) — контроллер владел бы только `AnimationController`, логики сверх toggle НЕТ → вынос = чистый churn. Upload: `_photoUploadProgress` (Map по outbox-`tempId`) пишется ВСЕМИ send-путями (photo/voice/video-note), читается message-list, чистится на send-complete/dispose; `_uploadSub`/`_uploadStatus` привязаны к photo-send-flow → send/outbox-связаны, принадлежат State | `chat_screen.dart` | ⏭️ (оценено, оставить) |

**Сессия 8 итог (2026-07-04):** **H15 по ЛОГИКЕ закрыт.** Вынесены последние два автономных под-контроллера композера/поиска: `StickerPanelController` (54 строки — anim+showPanel+typing-таймер с ghostMode-гейтом; focus-интерплей оставлен тонким в State) и `ChatSearchController` (92 строки — вся данные-логика поиска: debounce/seq/notifiers/runSearch/submit/reset; `_searchAnim`+`_openSearchResult`+`_openSearch`/`_closeSearch` оставлены в State по слою (б), т.к. `_searchAnim` вплетён в lerp высоты хедера, а `_openSearchResult` оркеструет scroll+пагинацию). `_MessageSearchResult`→публичный `MessageSearchResult` (отдельный файл). Плюс `ChatController.loadRemainingHistory` (initial-load-оркестратор, сиблинг `loadMoreHistory`). attach-панель (чистый toggle-anim, логики сверх toggle нет) и upload (`_photoUploadProgress`/`_uploadSub` — send/outbox-связаны) **оценены и обоснованно оставлены в State**. Вся отделимая логика H15 либо вынесена, либо обоснованно оставлена в State → **H15-логика завершена**. Каждый под-кусок: `flutter analyze` после экстракшна; parity скептик-агентом против **HEAD** (`git show HEAD:…`) — все PARITY OK (sticker: поля/длительности/teardown; initial-load: каждая ветка 1:1, `fullDecoded.isNotEmpty≡fullRows.isNotEmpty`; search: `_closeSearch`-reorder без data-зависимости, `clear()`-re-entry сохранён, `_seq` 2× как в HEAD). `flutter analyze` (весь проект) — **0 ошибок, 0 новых предупреждений** (только пред-существующие: 2 dead-push + SDK-deprecation cacheExtent/axisAlignment + unnecessary_underscores/token_storage вне зоны). Изменения в рабочем дереве, не закоммичены. Новых файлов: 3 (`sticker_panel_controller`/`chat_search_controller`/`message_search_result`). H16/H14 закрыты ранее. **Остаётся только H15b (низкий приоритет, косметика размера):** «тонкая композиция» — перенос build-дерева (композер/поиск/selection/call-UI) из `_ChatScreenState` (~6940 строк) в виджет-файлы; это UI-build, не логика, и send-пути (`_sendVoice`/`_sendVideoNote`/`_sendSticker`/`_sendMessage`) с `_photoUploadProgress` остаются в State.

### Промпт для Сессии 9

```
Продолжаем рефакторинг Komet по AUDIT_REPORT.md (секция «Прогресс исправлений», Сессии 1–8 закрыты).
Работа НЕ закоммичена — пиши код, git-коммиты не делай. Flutter: /home/a/flutter/bin/flutter.
Пиши АБСОЛЮТНЫЙ МИНИМУМ текста — только код и мысли.
Норма: 0 errors, 0 новых warnings (известны пред-существующие, НЕ трогать: dead push-код
_showMessageNotification/_showCallNotification в push_service.dart; SDK-deprecation cacheExtent/
axisAlignment в chat_screen.dart и connection_status.dart; unnecessary_underscores в
registration_screen/login_success_screen/theme_reveal; token_storage encryptedSharedPreferences).
Утилиты/модели/контроллеры ИСПОЛЬЗУЙ (не дублируй): core/utils/{format,ids,debouncer,log_redact}.dart,
core/config/persisted_setting.dart, models/{contact_info,chat_info,message_search_result}.dart,
widgets/attachment/bubbles/bubble_context.dart, screens/chats/chat/{chat_controller,
chat_prank_controller,voice_record_controller,video_note_controller,command_panel_controller,
sticker_panel_controller,chat_search_controller,message_search_result}.dart. Конвенции: без
комментариев; showCustomNotification (не SnackBar); правильный рефактор вместо хака.
Метод (ВАЖНО — эта сессия БОЛЬШАЯ, работай агрессивно и параллельно): активно используй sonnet-агентов
на НЕПЕРЕСЕКАЮЩИХСЯ регионах/файлах, запускай их ПАЧКАМИ в одном сообщении (несколько под-виджетов сразу).
Каждому агенту: точные находки+локации+решение+рамки. Потом САМ ревьюй все диффы и гоняй analyze.
Маленькие атомарные под-куски, analyze после КАЖДОГО. Parity перепроверяй скептик-агентом против HEAD
(git show HEAD:…), а не рабочего дерева. ЦЕЛЬ СЕССИИ: закрыть H15b ПОЛНОСТЬЮ (не «если захочешь»), и если
останется контекст — начать H17. Не мельчи и не откладывай: план на всю сессию сразу, потом исполняй.

СТАТУС H15: ЛОГИКА ЗАКРЫТА (Сессии 3–8). chat_screen ещё ~6940 строк — это UI-build-дерево. send-пути
(_sendVoice/_sendVideoNote/_sendSticker/_sendMessage/_sendAttachMessage) и _photoUploadProgress/_uploadSub
ОСТАЮТСЯ в State (завязаны на _messages/outbox/_bumpMessages). Контроллеры уже готовы (см. список выше) —
виджеты принимают их как параметры + сайд-эффекты через колбэки. Ничего из ЛОГИКИ больше не двигаем.

════════ ГЛАВНАЯ ЦЕЛЬ: H15b — «тонкая композиция» build-дерева chat_screen → виджет-файлы ════════
Задача: снять с _ChatScreenState тысячи строк build-кода, вынеся крупные под-деревья в отдельные
StatelessWidget/StatefulWidget в screens/chats/chat/view/ (новая папка). Логика/state НЕ переезжает —
переезжает ТОЛЬКО build. Виджет получает: нужные контроллеры/нотифаеры/анимации как параметры + колбэки
на действия (send/open/close/tap). Риск parity низкий, но churn высокий → строгая дисциплина: атомарно,
analyze+parity-скептик против HEAD после КАЖДОГО под-виджета (скептик сверяет build verbatim: те же
виджеты/параметры/порядок/условия/ключи, те же нотифаеры-инстансы).

Порядок (от изолированного к связанному; параллель агентов ВНУТРИ пункта где регионы не пересекаются):
1. SEARCH-VIEW: _searchTopBar/_buildSearchResultsContent/_buildSearchResultTile → SearchView-виджет.
   Принимает: ChatSearchController _search, ColorScheme, Animation _searchAnim (как Listenable-параметр,
   он остаётся в State — lerp хедера), колбэки onOpenResult(_openSearchResult)/onClose(_closeSearch).
   Самый изолированный (данные уже в контроллере). ОЦЕНИ header-lerp: если _searchAnim переплетётся с
   _buildAppBar так, что не расщепляется — вынеси только results-content, top-bar оставь. Делай ПЕРВЫМ.
2. COMPOSER-VIEW: _buildComposer + под-панели (_buildAttachmentPanel/_buildStickerPanel/_buildCommandPanel/
   voice-recording-indicator/video-note-кнопка). Дели на ПОД-ВИДЖЕТЫ (attachment-panel/sticker-panel/
   command-panel/composer-bar — отдельные файлы, параллельные агенты). Каждый принимает готовый контроллер
   (_stickers/_commandPanel/_voiceRec/_videoNote) + _attachAnim (Listenable-параметр, остаётся в State,
   вплетён в ~8 build-сайтов) + send-колбэки (onSendText/onSendSticker/onSendVoice/onSendVideoNote/onAttach*).
   Самый крупный кусок — большинство строк тут.
3. SELECTION-BAR: selection-topbar/действия (reply/forward/delete/copy/...) → SelectionBar-виджет.
   Принимает _selectedIds/_selectionAnim + колбэки действий. State держит сами действия.
4. CALL/HEADER-UI: _buildAppBar (осторожно — там _searchAnim/_selectionAnim/glossy-lerp высоты) +
   header-статус/presence + call-кнопки. Оцени переплетение анимаций; если _buildAppBar не расщепляется
   чисто — оставь его в State, вынеси только автономные под-виджеты хедера.
После каждого: обнови «Сводную таблицу» (H15b-строка) и добавь строку в «Сессию 9» с parity-вердиктом.
Веди счётчик: сколько строк ушло из chat_screen (цель — существенно ниже 6940; фиксируй факт).

════════ ЕСЛИ ОСТАЛСЯ КОНТЕКСТ ПОСЛЕ H15b: начни H17 ════════
H17: ChatsModule (статический god-модуль) → инстанцируемый repository. Крупный. СНАЧАЛА разведка
агентом (карта: все статические поля/методы ChatsModule, все вызыватели, глобальное состояние/кэши),
потом план миграции (интерфейс репозитория + инстанс в main.dart + постепенная замена вызовов), потом
по слоям. НЕ начинай кодить H17 без карты и плана в отчёте.

ЗАПАСНОЙ ФРОНТ (если H15b упрётся или для параллельных лёгких побед): «Топ-10 приоритетов» и «Все
находки по темам» в AUDIT_REPORT.md — H6 CustomFontService legacy UA (нужна проверка на устройстве —
пометь и спроси), прочие medium/low дубли/костыли. Сначала перечитай статистику и топ-приоритеты.

После каждого под-куска обнови AUDIT_REPORT.md (✅/🔧/⏭️) + строка в «Сессию 9». В конце — промпт для Сессии 10.
```

### Сессия 9 (2026-07-04) — H15b: тонкая композиция build-дерева chat_screen → виджет-файлы

Новая папка `screens/chats/chat/view/`. Логика/state НЕ переезжали — только build-деревья; виджеты
принимают контроллеры/нотифаеры/анимации как параметры + сайд-эффекты через колбэки (send/open/close/tap).
Каждый под-виджет: `flutter analyze` после экстракшна + parity-скептик против HEAD.

| Находка | Файлы | Статус |
|---------|-------|--------|
| H15b (1 — SEARCH-VIEW): `_searchTopBar`+`_buildSearchOverlay`+`_buildSearchResultsContent`+`_buildSearchResultTile`+`_buildHighlightedText` → `SearchTopBar`+`SearchOverlay` (`view/search_view.dart`). `SearchTopBar` (search/focusNode/glossy/onClose) остаётся под-виджетом внутри `_buildAppBar` (header-lerp `_searchAnim` не тронут — вынесен только контент top-bar). `SearchOverlay` (search/searchAnim/onOpenResult/senderName/senderAvatar). Нотифаеры-инстансы те же (`_search.*`/`_searchAnim`); `_searchSenderName`/`_searchSenderAvatar`/`_openSearchResult`/`_closeSearch` остались в State, прокинуты колбэками. Убраны 3 неиспользуемых импорта (`animated_lottie_icon`/`app_animations`/`komet_avatar`). Parity скептиком против HEAD — **PARITY OK** (5 деревьев byte-identical modulo renames; `search.submit`≡HEAD inline cancel+run) | `chat_screen.dart` (−226), `view/search_view.dart` (333) | ✅ |
| H15b (2 — COMPOSER): `_buildInputArea`+`_buildReplyPreview`+`_buildVoiceRecordingIndicator`+`_recordingButtonVisual`+`_voiceLockChip` → `ComposerInputBar` (`view/composer_input.dart`, 19 параметров: контроллеры `_voiceRec`/`_note`, нотифаеры `_replyTo`/`_hasText`/`_uploadStatus`, `_attachAnim`, `_messageController`/`_messageFocusNode`, send-колбэки `onSendText`/`onScheduleMessage`/`onOpenAttach*`/`onSendHistory`/`onToggleStickerPanel`/`onCancelReply`, `formatElapsed`/`contextMenuBuilder`). Приватные виджеты `_AttachButton`/`_HistoryStrip`/`_ButtonClipper`/`_RecordingDot`/`_LiveWavePainter` + top-level `_labelForEntry`/`_iconForFilename` переехали в тот же файл. `_UploadStatus`→публичный `UploadStatus` (`chat/upload_status.dart`) — нужен обеим сторонам (`_AttachButton` + State-хендлеры upload). `_formatContextMenu`/`_sendMessage`/send-пути остались в State. Убраны импорты `sticker_panel`/`rich_message_controller`… (см. ниже) | `chat_screen.dart`, `view/composer_input.dart` (1042), `chat/upload_status.dart` (11) | ✅ |
| H15b (3 — SELECTION-BAR): `_selectionTopBar` → `SelectionTopBar` (copyMsg/editMsg вычисляются в State через `_singleCopyableText`/`_singleEditable` и прокидываются параметрами — вычисление только внутри `if (t>0)`); `_buildSelectionBottomBar`+`_selectionActionPill` → `SelectionBottomBar`+`_pill` (`view/selection_bar.dart`). Действия (`_clearSelection`/`_copySelected`/`_editSelected`/`_deleteSelected`/`_replySelected`/`_forwardSelected`) остались в State, прокинуты колбэками | `chat_screen.dart`, `view/selection_bar.dart` (238) | ✅ |
| H15b (4 — HEADER): `_glossyHeaderRow`+`_materialHeaderRow`+`_withOnlineDot`+`_backWithBadge`+`_backUnreadBadge`+`_RollingCount` → `ChatHeaderRow` (`view/chat_header.dart`, `build => glossy ? _glossyRow : _materialRow`). `_buildAppBar` ОСТАЛСЯ в State (переплетение `_searchAnim`/`_selectionAnim`/glossy-lerp высоты не расщепляется) — заменён только вызов `glossy ? _glossyHeaderRow : _materialHeaderRow` на `ChatHeaderRow(...)`. Навигация (`ChatInfoScreen`/`Navigator.pop`/`_openChatMenu`/`_openScheduledMessages`/`_startCall`) прокинута колбэками; `isOfficial`=`chat?.isOfficial??false`, статус/счётчики — `ValueListenable`-параметры | `chat_screen.dart`, `view/chat_header.dart` (475) | ✅ |
| H15b (5 — command/sticker панели): `_buildCommandPanel` → `CommandPanelView(commandPanel)` (`view/command_panel_view.dart`); `_buildStickerPanel` → `StickerPanelView(stickers, onStickerTap)` (`view/sticker_panel_view.dart`). Тривиальные обёртки над `_commandPanel`/`_stickers`-контроллерами; `_sendSticker` остался в State | `chat_screen.dart`, `view/command_panel_view.dart` (36), `view/sticker_panel_view.dart` (40) | ✅ |
| H15b (6 — shimmer-заглушка): `_buildShimmerLoading` (93 строки placeholder-списка на `_shimmerController`) → `ShimmerLoading(shimmer)` (`view/shimmer_loading.dart`). Полностью автономна (только `_shimmerController` + `Theme.of`); 2 сайта `_isLoading && _messages.isEmpty ? … : _buildMessagesList()` | `chat_screen.dart`, `view/shimmer_loading.dart` (105) | ✅ |

**Сессия 9 итог (2026-07-04):** **H15b закрыт.** С `_ChatScreenState` снято build-дерево композера/поиска/
selection/header/shimmer в 8 виджет-файлов под `screens/chats/chat/view/` + `UploadStatus`-модель. `chat_screen.dart`
**6770 → 4815 строк** (−1955, −29%; от исходных ~6940 — −31%). Вынесены только build-деревья: логика/state/
send-пути (`_sendVoice`/`_sendVideoNote`/`_sendSticker`/`_sendMessage`/`_sendAttachMessage`/`_photoUploadProgress`/
`_uploadSub`) остались в State, виджеты получают контроллеры/нотифаеры/анимации параметрами + сайд-эффекты
колбэками. `_buildAppBar` и `_buildComposerArea` (оркестраторы анимаций хедера/композера) обоснованно оставлены
в State — только их крупные под-деревья вынесены; message-list уже изолирован (`_ChatMessageList` host-виджет).
`flutter analyze` (весь проект) — **0 ошибок, 0 новых предупреждений** (пред-существующие: 2 dead-push +
cacheExtent/axisAlignment + unnecessary_underscores/token_storage + 2 curly_braces в нетронутом
`_resolveCurrentPosition`). Изменения в рабочем дереве, не закоммичены. Новых файлов: 9 —
`view/{search,composer_input,selection_bar,chat_header,command_panel,sticker_panel,shimmer_loading}.dart`
(вернее `*_view.dart`/`chat_header.dart`/`composer_input.dart`/`shimmer_loading.dart`/`selection_bar.dart`)
+ `chat/upload_status.dart`. **Parity — все скептик-проверки против HEAD (с учётом session-1–8 renames)
PARITY OK:** SearchView (5 деревьев byte-identical; `search.submit`≡inline cancel+run); composer (все 19
аргументов + внутренние деревья byte-consistent, ни одной опечатки-константы, все методы/классы удалены из
chat_screen); header+selection (обе byte-faithful к HEAD-деревьям под rename-map; `SelectionTopBar`-хелперы
`_single*` вычисляются только внутри `if (t>0)`; RollingCount/badge/avatar-константы совпадают). Метод: 2 файла
(selection_bar/chat_header) авторились параллельными sonnet-агентами по verbatim-спеке + ревью диффа + скептик;
остальные — вручную. dart format прогнан.

**H17 — разведка проведена в конце С9 (карта + план ниже).** Кодинг H17 — на С10.

### Сессия 10 (2026-07-04) — H17: ChatsModule → инстанцируемый репозиторий (закрыт)

| Находка | Файлы | Статус |
|---------|-------|--------|
| H17 Шаг 1 (додел): чистый parse-кластер вынесен из `ChatsModule` в top-level-функции нового файла `chat_parsing.dart` — `parseChatRow`(`_parseChat`)/`buildContactsMap`/`parseSearchResult`/`parseMessageResult`/`sameChatContent`(`_sameContent`) + приватные `_otherParticipantId`/`_nameFromContact`. `_parseParticipants`→публичная `parseParticipants` осталась в chats.dart (нужна `CachedChat.fromDbRow` + `parseChatRow`). 6 внутренних сайтов переименованы; 0 внешних вызывателей. Циклический импорт chats↔chat_parsing (нужен `CachedChat`) — легален в Dart. Parity: тела byte-identical к HEAD (скептик). | `backend/modules/chat_parsing.dart` (254), `chats.dart` (−≈195) | ✅ |
| H17 Шаги 2–5 (ядро) ОДНИМ координированным разрезом: `ChatsModule` → инстанцируемый класс с приватным ctor `ChatsModule._()` и единственным глобалом `final chats = ChatsModule._()` (в chats.dart, рядом-по-смыслу с `api`; НЕ в main.dart — иначе backend импортировал бы entry-point = нарушение слоёв + цикл). Все `static`-члены (методы + реактивное состояние `chatsChanged`/`_messageEventsController`/`_historyFetched`/contact-flush/push-subs) стали ИНСТАНС-членами одного синглтона; константы `muteOff`/`muteForever`/`lastMsgPlaceholder`/`_contactFlushDelay` остались `static const`. Введён реальный `dispose()` (cancel subs/timer, close controller, dispose notifier — раньше отсутствовал). Все 14 файлов-вызывателей переведены `ChatsModule.<m>` → `chats.<m>` (кроме 3 констант в chat_list). Локальные переменные `chats` переименованы во избежание shadow: cloud_storage_screen→`cachedChats`, search_screen→`localChats`, chat_list_screen→`loadedChats`. | `chats.dart`, `main.dart`, `chat_controller.dart`, `chat_screen.dart`, `chat_list_screen.dart`, `search_screen.dart`, `cloud_storage_screen.dart`, `create_group_flow.dart`, `max_link_handler.dart`, `debug_menu_screen.dart`, `settings_tab.dart`, `account.dart`, `outbox.dart`, `messages.dart`, `cloud_storage.dart` | ✅ |

**Отклонение от буквы плана (обосновано):** план С9 предполагал переходный «статик-фасад» `static X => chats.X` внутри `ChatsModule`. В Dart это НЕВОЗМОЖНО — класс не может иметь одноимённые static- и instance-члены (коллизия). Поэтому вместо промежуточного фасада сделан прямой координированный разрез в один заход (внутренняя инстанс-конверсия + миграция всех вызывателей + оба реактивных подписчика), что и есть целевое состояние Шага 5 без выбрасываемых делегаторов. Риск silent-break реактивного ядра снят тем, что синглтон РОВНО один: все писатели (`_bump`/`_messageEventsController.add` на инстансе) и читатели (`chats.chatsChanged`/`chats.messageEvents`) ссылаются на один объект.

**Сессия 10 итог (2026-07-04):** **H17 закрыт полностью.** `ChatsModule` из статического god-модуля стал инстанцируемым репозиторием `chats` (единственный приватно-сконструированный синглтон) + чистый parse-кластер вынесен в `chat_parsing.dart`. `flutter analyze` — **0 ошибок, 19 issues = бейзлайн** (без новых). `dart format` прогнан по всем 16 затронутым файлам. Изменения в рабочем дереве, не закоммичены. **Parity — скептик-агент против `HEAD` (все 6 проверок PASS):** тела parse-кластера line-by-line ≡ HEAD; `parseParticipants` ≡ HEAD; ровно один `ChatsModule._()`, ноль вторых конструкций/мёртвых статик-вызовов; add/remove подписчиков (`chat_list`/`chat_screen`) на одном и том же инстансе (симметрия listener'ов); 3 локальных ренейма полны; `dispose()` нигде не вызывается (не рвёт живой синглтон). Осталось из крупного: H6 (CustomFontService legacy UA — нужна проверка на устройстве) + medium/low дубли.

### H17 — карта ChatsModule + план миграции (разведка, С9)

`lib/backend/modules/chats.dart` (1739 строк, класс `ChatsModule` L249–1739; помимо него в файле — модели
`CachedChat`/`ChatSearchHit`/`MessageSearchHit` и sealed `MessageEvent`, они мигрируют/остаются независимо).

**Ключевой вывод:** `ChatsModule` — почти **stateless-фасад над `AppDatabase` (SQLite)** + один реактивный
`ValueNotifier chatsChanged` + один broadcast-`Stream messageEvents`. Реальное состояние чатов живёт в SQLite,
не в модуле. Поэтому большинство методов инстансируются тривиально; вся запутанность сосредоточена в **4 стат.
полях**: `chatsChanged`, `_messageEventsController`, push-подписки (`_globalPushSub`/`_globalStateSub`+`_pushQueue`),
contact-flush (`_pendingContactUpdates`/`_contactFlushTimer`/`_contactFlushFuture`) + мягко `_historyFetched`.

**Глобальное мутабельное состояние (8 полей):**
- `chatsChanged` (**public** `ValueNotifier<int>`, L455) — реактивный клей; `_bump()` зовут ~18 мутирующих методов
  + косвенно внешние (`outbox.applyOutgoing`, `account.syncFromLoginPayload`, push). Слушают `chat_list_screen`
  (L543) и `chat_screen` (L333). **Писатели и подписчики в разных файлах — встречаются только через статик-синглтон.**
- `_messageEventsController` (broadcast, L358) — эмитят push-хендлеры + `outbox.emitMessageSent`; слушают
  `chat_list_screen` (L549, typing) и `chat_screen` (L381). Никогда не закрывается (нет `dispose`).
- `_historyFetched` (`Set<int>`, L462) — пишет/читает `chat_controller`; чистят `resetForAccountSwitch`
  (`account.dart`/`settings_tab.dart`) и `_handleSessionState` (disconnect).
- `_globalPushSub`/`_globalStateSub` (L458/459) — создаются в `attachGlobalPushHandlers(api)` (идемпотентно),
  вызов единожды `main.dart:123`; живут весь app-lifetime, не отменяются.
- `_pushQueue` (`Future`-цепочка, L460) — сериализация push-обработки.
- `_pendingContactUpdates`/`_contactFlushTimer`/`_contactFlushFuture` (L901–903) — дебаунс контакт-апдейтов;
  кормится извне из `messages.applyContactUpdate` (L1833/1895).

**Классификация ~59 методов:** ~12 `[PURE]` (preview/parse-хелперы + константы `muteOff`/`muteForever`/
`lastMsgPlaceholder`), ~17 чисто `[IO]` (DB/пакет, без `_bump`), остальные `[STATE]`/`[SUB]` (пишут
`chatsChanged`/`_messageEventsController` или владеют подписками/таймером). `Api` **не глобален внутри** — передаётся
параметром в каждый IO-метод (только `attachGlobalPushHandlers` захватывает `api.pushStream/stateStream`).

**Вызыватели (15 файлов):** backend — `main.dart` (attach, 1×), `account.dart` (reset/sync), `outbox.dart`
(emitMessageSent/applyOutgoing), `messages.dart` (applyContactUpdate), `cloud_storage.dart` (setChatOptions/
createGroupChat/setChatTitle); frontend — `chat_controller.dart` (reconcile*/wasHistoryFetched/ensureChatCached/
subscribeChat/markHistoryFetched), `chat_screen.dart` (chatsChanged/messageEvents/getChatInfo/getChat/markRead/
markUnread/subscribeChat/applyOutgoing×8/ensureChatCached/reconcileLastMessage/clearHistory/deleteChat/
reconcileDeletedFromFetch/refreshChats), `chat_list_screen.dart` (togglePin/mute-const/setChatMute/refreshChats/
deleteChat/chatsChanged/messageEvents/getChats/lastMsgPlaceholder), `create_group_flow.dart` (createGroupChat/
requestChatPhotoUploadUrl/setChatPhoto), `search_screen.dart` (searchMessages/searchPublic), `max_link_handler.dart`
(cacheServerChat), `cloud_storage_screen.dart` (getChat/getChats/deleteChat/leaveChat), `settings_tab.dart`
(resetForAccountSwitch), `debug_menu_screen.dart` (searchById).

**Соседние статик-модули** (тот же паттерн): Contacts/Folders/WebApp/DigitalId/Calls/Messages/Complaints/
Stickers/CloudStorage/Account — все статические. `ChatsModule` можно инстансировать **в одиночку**: единственный
исходящий модуль-вызов — в `FoldersModule` (leaf, обратно не зовёт). `messages`/`outbox`/`account`/`cloud_storage`
зовут В `ChatsModule`, но не наоборот → это вызыватели-на-миграцию, не co-dependencies. Сегодня класс НИКОГДА не
конструируется (`grep "ChatsModule("` пусто), нет `dispose`.

**План миграции (strangler-фасад, порядок от низкого риска):**
1. **Pure-хелперы + константы** (механически, 0 churn у вызывателей): 12 `[PURE]` → инстанс-методы/свободные
   функции; `muteOff`/`muteForever`/`lastMsgPlaceholder` оставить статик-const (нужны `CachedChat.isMuted` L110 +
   `chat_list_screen`).
2. **Инстанс + статик-фасад:** создать инстансируемый класс с 4 стат-полями; один инстанс `chats` рядом с `api`
   в `main.dart`; переписать `ChatsModule.<m>` как `static <m> => chats.<m>` (делегаторы) → все ~15 файлов
   компилируются без правок, поведение неизменно.
3. **Чистые IO-методы** (без shared state): getChats/getChat/clearCache/getChatInfo/searchById/searchMessages/
   searchPublic/subscribeChat/requestChatPhotoUploadUrl/setChatPhoto/setChatOptions/reconcileDeletedFromFetch/
   _reconcileLastMessage → перевести вызывателей (search_screen/cloud_storage*/create_group_flow/debug_menu/
   chat_controller) на `chats.` без порядковых забот.
4. **DB-mutate-and-bump + ДВА экрана-подписчика ОДНИМ шагом:** applyOutgoing/markRead/markUnread/cacheServerChat/
   reconcileLastMessage*/setChatTitle/Mute/togglePin/deleteChat/clearHistory/leaveChat/refreshChats/ensureChatCached/
   createGroupChat/syncFromLoginPayload — все через `chatsChanged`/`_bump`. Т.к. `chat_list_screen`/`chat_screen`
   делают `ChatsModule.chatsChanged.addListener`+`messageEvents.listen`, нотифаер+стрим становятся инстанс-членами,
   и оба экрана перенаправляются на `chats.chatsChanged`/`chats.messageEvents` **в том же шаге**, что и писатели
   (`outbox`/`account`/`messages.applyContactUpdate`). Единственный «координированный разрез» — делать целиком.
5. **Подписки/lifecycle последними + добавить `dispose()`:** attachGlobalPushHandlers + `_globalPushSub`/
   `_globalStateSub` + все `_handle*` + `_pushQueue` + contact-flush-таймер. Заменить `main.dart:123` на инстанс-init.
   Ввести реальный `dispose()` (закрыть контроллер, отменить subs/timer — сейчас его НЕТ); текущий
   `resetForAccountSwitch` свернуть в `reset()`.

**Итог risk:** ~30 из ~59 методов (`[PURE]`+чистые `[IO]`) двигаются тривиально; реальный риск — только 4 поля
(`chatsChanged`/`messageEvents`/push-subs/flush-timer) + их писатели + 2 экрана-подписчика в одном коммите.

**H17 Шаг 1 (частично) выполнен в С9:** preview-кластер (`attachPreviewLabel`/`_controlPreviewLabel`/
`messagePreviewText`/`_bodyPreviewText`/`messagePreviewElements`, 5 функций, 0 внешних вызывателей, зависимость
только `jsonEncode`) вынесен из `ChatsModule` в top-level-функции `lib/backend/modules/chat_preview.dart`.
Внутренние сайты (`_reconcileLastMessage`/`_handleNotifMessage`/`_parseChat`, строки 689/690/724/1195/1196) не
менялись — вызовы top-level безымянные. `chats.dart` 1739→1688. `flutter analyze` — 0 errors, 0 новых (19 =
бейзлайн). Остаток Шага 1 (parse-кластер `_parseChat`/`_buildContactsMap`/`_otherParticipantId`/`_nameFromContact`/
`_parseSearchResult`/`_parseMessageResult`/`_sameContent` — крупнее, тянут модели `CachedChat`/presence/contacts) и
Шаги 2–5 — на С10.

**✅ ВСЁ ВЫШЕ ЗАКРЫТО в С10** (см. раздел «Сессия 10» выше): parse-кластер → `chat_parsing.dart`; Шаги 2–5
сделаны одним координированным разрезом (статик-фасад в Dart невозможен из-за коллизии имён static/instance —
вместо него прямая миграция на единственный синглтон `chats = ChatsModule._()`). Parity — скептик против HEAD, 6/6 PASS.

### Сессия 11 (2026-07-04) — большой батч medium/low: ФРОНТ A (цвета) + ФРОНТ D (изолир. виджеты) + ФРОНТ F (проверка)

**Карта OPEN vs DONE** (сверено с кодом + С1–10):
- **ФРОНТ A** «Hardcoded theming/color literals» (7): ✅ #1 бренд/статус-хексы (007AFF/4FC3F7/34C759/2F8FFF), ✅ #2 mutedText α0.6 ×8, ✅ #5 avatar-thumb 144 ×4; ⏭️ #3 hairline, #4 frosted-pill alphaBlend, #6 drop-shadows, #7 bubble tint/opacity (риск виз-сдвига / chat_screen-heavy → С12).
- **ФРОНТ D** «Duplicated UI widgets» (25): ✅ PersistedSetting (ранее), ✅ ErrorView ×3, ✅ showTextInputDialog (devices/font), ✅ SmallSpinner/BusyOverlay ×4, ✅ confirm-dialog chat_screen→shared, ✅ KometAvatar create_group; ⏭️ WebApp/DigitalId-dup(HIGH), settings-rows/cards ×3, DebugToggleTile ×11, RadioTile ×3, PrimaryLoadingButton ×5, reconnect-helper, LabeledField, upload-flows ×5, header-row, contact-card, kSheetShape-инлайны, messageStatusVisual, overlay-popup, swipe-dedup, edit-sheet, avatar_hero, edit_profile-avatar, password_entry/photo_editor prompt (→ С12).
- **ФРОНТ F** «formatters18/l10n6/snackbar4»: ✅ SnackBar (spoof) и debug-логи (VOICE/FLIP) закрыты ранее; ✅ ядро-форматтеров (С1–2); ⏭️ хардкод-l10n строки (крупно, нужны ARB-ключи), остаток форматтеров (→ С12).
- **ФРОНТ B** (backend parsing 22): ✅ только arch-parse (ранее); ⏭️ остальное (→ С12).
- **ФРОНТ C** (layering 7): ⏭️ всё (→ С12). **ФРОНТ E** (lifecycle 14): ⏭️ всё (→ С12).

**Новые файлы:** `core/config/app_colors.dart` (extension `ColorScheme.mutedText`; consts `kAvatarThumbSize/kReadReceiptBlue/kOnlineGreen/kEditorAccent`); `widgets/error_view.dart` (`ErrorView`); `widgets/prompt_dialog.dart` (`showTextInputDialog`, слот `description`, владеет controller+dispose); `widgets/small_spinner.dart` (`SmallSpinner`+`BusyOverlay`).
**Адаптация (17 файлов, disjoint):** цвета — chat_info(007AFF→`cs.primary` ×5, акцент пропагируется), chat_list(4FC3F7→kReadReceiptBlue + 144→kAvatarThumbSize ×4), sticker/voice/bubble_context(4FC3F7), settings_tab/traffic_monitor/photo_editor(34C759→kOnlineGreen), photo_editor+media_preview(2F8FFF→kEditorAccent, локальные `_kAccent` удалены), mutedText→`cs.mutedText` (settings_tab/security/devices/server/proxy/composer_input/chat_screen); виджеты — ErrorView(web_app/digital_id_web/digital_id, локальные `_ErrorView` удалены), showTextInputDialog(devices/font_settings — **+закрыт leak контроллера** в font), SmallSpinner/BusyOverlay(sticker_panel/sticker_pack_sheet/photo_editor ×2), confirm-dialog(chat_screen `_showConfirmDialog` удалён→`showConfirmDialog`), KometAvatar(create_group `_Avatar` удалён + memCache-фикс + снят неисп. cached_network_image import).
**Метод:** 9 sonnet-агентов ПАРАЛЛЕЛЬНО на непересекающихся файлах (verbatim-спеки: точные строки+интерфейс+рамки); общие файлы (chat_screen/composer_input/security_screen) — серийно сам. Все свопы value-equal (нулевой виз-сдвиг), кроме двух намеренных: `007AFF→cs.primary` (link/action теперь следует акценту) и confirm-dialog→shared (FilledButton.tonal errorContainer вместо TextButton cs.error). Поведенческие сайты (chat_info ×5; create_group avatar — KometAvatar теряет initials-во-время-загрузки и w600→bold, inherent) перепроверены построчно. `dart format` по всем затронутым. Residual-grep после: 007AFF/4FC3F7/34C759/2F8FFF/`α0.6` = **0**. `flutter analyze` — **0 ошибок, 19 issues = бейзлайн** (dart format однажды перенёс пред-существующий однострочный `if` в chat_info:202 на 2 строки → curly-braces-lint; починил скобками → снова 19). Изменения не закоммичены.

**Сессия 11 итог:** ✅ ФРОНТ A (цветовые токены — 3/7 находок; ВСЕ бренд-хексы+mutedText+avatar-thumb закрыты, residual=0), ✅ ФРОНТ D изолированные виджеты (ErrorView/prompt/spinner+overlay/confirm/KometAvatar — 6 находок), ✅ ФРОНТ F проверен-закрыт (SnackBar/debug/ядро-форматтеров уже были готовы). B/C/E, тяжёлый хвост D, l10n и остаток A → **Сессия 12** (промпт ниже).

### Промпт для Сессии 12 (продолжение хвоста medium/low)

```
Продолжаем рефакторинг Komet по AUDIT_REPORT.md (секция «Прогресс исправлений», Сессии 1–11 закрыты).
Работа НЕ закоммичена — пиши код, git-коммиты не делай. Flutter: /home/a/flutter/bin/flutter.
Пиши АБСОЛЮТНЫЙ МИНИМУМ текста — только код и мысли.

Норма: 0 errors, 0 новых warnings, ровно 19 issues бейзлайна (те же, что в С11: 2 dead-push, cacheExtent×1
+ axisAlignment×2 chat_screen/connection_status, curly×2 chat_screen `_resolveCurrentPosition`,
unnecessary_underscores registration×7/login_success×3/theme_reveal×1, token_storage encryptedSharedPreferences).
После правок счётчик != 19 → внёс новое, чини. ВНИМАНИЕ: `dart format` может перенести пред-существующий
однострочный `if`/`for` без скобок на 2 строки → curly_braces-lint; если счётчик вырос из-за этого — оберни в {}.

ИСПОЛЬЗУЙ уже созданное (не дублируй): core/config/{persisted_setting,app_colors}.dart (extension `cs.mutedText`,
consts kAvatarThumbSize/kReadReceiptBlue/kOnlineGreen/kEditorAccent), core/utils/{format,ids,debouncer,log_redact},
widgets/{error_view(ErrorView),prompt_dialog(showTextInputDialog + description-слот),small_spinner(SmallSpinner,
BusyOverlay),confirm_dialog(showConfirmDialog),komet_avatar,sheet_helpers(kSheetShape)}.dart, инстанс `chats`,
models/{contact_info,chat_info,message_search_result}, bubbles/bubble_context, chat_preview/chat_parsing.
Конвенции: без комментариев; showCustomNotification; правильный рефактор; quality over quantity.

Метод (как в С11, сработал чисто): sonnet-агенты ПАРАЛЛЕЛЬНО на непересекающихся НОВЫХ+consumer файлах (partition
по файлам, чтобы 0 конфликтов; verbatim-спеки), foundation-файлы и общие (chat_screen/messages/chats/account/main/
message_bubble) — серийно сам. После каждого куска: САМ ревью diff + `flutter analyze` (сверь 19) + `dart format`.
Value-equal свопы → analyze==19 достаточно; поведенческие/extractions → доп. построчная сверка. Маленькие атомарные куски.

ОСТАВШИЕСЯ ФРОНТЫ (бери столько, сколько влезет; крупные декомпозиции все позади — это чистый хвост):
  ФРОНТ B — Backend parsing/model дубли (22, @«Backend parsing and model duplication»): CachedMessage attach/
    FORWARD/CONTROL хелпер (messages.dart 3 пути, СЕРИЙНО сам); CachedChat.copyWith + _updateChat (chats.dart ~6
    методов, СЕРИЙНО); _decodePayload + messagePreviewElements реюз (chats.dart); folders _parseIntList/_parseFolderList;
    PerChatJsonStore<T> (draft_store+chat_wallpaper_store); countries ru-blob усушка; rasterPictureToJpegFile
    (photo_editor ×3); dispatcher _PendingRequest merge; calls _parseCallerEndpoint; stickers _fetchAndCache<T>;
    api _handleConnectFailure; cloud_storage _toCloudFile; file_uploader _syntheticFilename/_multipartBoundary/UA-const;
    enumFromName<T> (6 settings); rich_message _toFormatRanges; message_bubble _multiPhotoCornerRadius; CountryName.displayName;
    Poll._merge. Многие — по 1 независимому файлу → агенты.
  ФРОНТ C — Layering (7, @«Layering violations…»): типизир. push-сеттеры account.dart + notifications_screen(50-70/
    132-205); AccountModule.logout() (settings_tab дублирует teardown + теряет spoof-clear); push_service _handleReply→
    login()/_buildLoginPayload; (СОМНИТ: read-mark в ChatsModule, spoof-login-метод, ContactCache-ChangeNotifier — оценить).
  ФРОНТ E — Lifecycle/dispose/caches (14, @«Lifecycle, dispose, and unbounded caches»): media_cache _inFlight-dedup;
    video_player _loadGeneration-guard; MessageSessionCache LRU; ContactCache→per-row (или bound); temp-файлы
    attachment_sheet(track+cleanup); UploadManager subscription API; recording-stop на pause (chat_screen);
    _highlightTimer cancelable (chat_screen); complaints.clear(); MediaDownloadProgress.release; _messageKeys prune;
    performance_screen mounted-guard.
  ФРОНТ D-хвост — крупные виджет-дубли (@«Duplicated UI widgets»): SettingsCard/SettingsToggleTile/SettingsNavTile
    (settings_tab/notifications/komet_settings), SettingsRow (security ×4 builders), _DebugToggleTile (debug_menu ×11),
    SettingsRadioTile (theme/message_actions/app_icon ×3), PrimaryLoadingButton (password_entry ×5), ErrorView уже
    есть — но WebApp/DigitalIdWeb-dup(HIGH) hooks-параметризация; reconnect-helper+LabeledField (proxy/server sheets);
    kSheetShape-инлайны (~10 сайтов); messageStatusVisual (sticker_bubble+voice_bubble); contact-card (message_bubble
    2 метода); optimistic-upload flow ×5 (chat_screen, СЕРИЙНО); overlay-popup mixin; edit_profile→KometAvatar.
  ФРОНТ A-остаток: hairline `cs.hairline` getter (α-разнобой, но виз-сдвиг — реши каноничную α), frosted-pill helper,
    drop-shadow→GlossyDecor, message_bubble tint-геттеры. Все затрагивают chat_screen/security — серийно, аккуратно.
  ФРОНТ F-l10n: вынести хардкод-RU строки в ARB (message_bubble/message_actions_overlay, password_2fa/web_qr_login,
    packet.dart typed-error, chats preview-kind enum) — крупно, дели по экранам; auth describeAuthError-хелпер.

H6 (CustomFontService legacy UA) — ЕДИНСТВЕННЫЙ незакрытый high; нужна проверка шрифта на устройстве (woff2 vs
sfnt/TTF). САМ НЕ ТРОГАЙ вслепую — СПРОСИ пользователя, готов ли проверить после правки UA.

После каждого фронта — строка в «Сессию 12» + ✅/🔧/⏭️. В конце — промпт для Сессии 13.
```

### Сессия 12 (2026-07-05) — большой батч B/C/E/D-хвост (2 волны параллельных агентов + серийные foundation-файлы)

**ФРОНТ B (backend parsing/model, 22) — почти весь закрыт:**
- ✅ B1 `CachedMessage.parseAttachments(map)→(attachments, isControl)` — 3 конструктора (`fromDbRow`/`_parseMessage`/`fromPushPayload`) унифицированы; FORWARD и control-детект теперь везде (fix: push раньше не обрабатывал FORWARD/не ставил isControl; fromDbRow получил `whereType<Map>`-guard). empty attaches→`[]` в push (доказано безопасно — все консьюмеры трактуют null≡[]).
- ✅ B2 `CachedChat.copyWith` (sentinel `_keep` для nullable) + `_updateChat(accountId,chatId,mutate)` → `markUnread`/`applyOutgoing`/`setChatTitle`/`setChatMute`. Overlay `Map.from(row)..addAll(toDbRow())` сохраняет `in_list` (saveChats — partial ON CONFLICT UPDATE). `markRead`/`_handleNotifMessage`/`_reconcileLastMessage` обоснованно оставлены (interleaved API / multi-save / принимают chatRow).
- ✅ B3 `_decodePayload(raw)` ×3 (EDITED-merge/`_reconcileLastMessage`/reactions) + `messagePreviewElements(payload)` реюз в `_reconcileLastMessage` (guard `payload['text']` провабли-недостижим: text≡payload['text'] на всех write-путях).
- ✅ B4 `_parseIntList`/`_parseFolderList(json,{lenient})` (folders/chat_folder; loadFolders swallow-all vs applyPayload skip-bad сохранены через lenient-флаг).
- ✅ B5 `PerChatJsonStore<T>` (draft_store/chat_wallpaper_store тонкие сабклассы; `_deleteImage`→`onBeforeWrite`).
- ✅ B7 `rasterPictureToJpegFile(...,{prefix})` (core/media/raster.dart; 3× photo_editor `_bake`; `onPictureDisposed`-хук для adjust-editor's curved.dispose ordering).
- ✅ B8 dispatcher `_PendingRequest{completer,sentAt}` (2 карты→1).
- ✅ B10 calls `_parseCallerEndpoint` (joinByLink external-id намеренно НЕ тронут — пред-существующая дивергенция).
- ✅ B11 stickers `_fetchAndCache<T>`. ✅ B12 api `_handleConnectFailure({phase,disconnectSocket})` (B13 arch-хелпер уже был). ✅ B14 cloud_storage `_cloudFilesFrom` (sync*). ✅ B15 file_uploader `_syntheticFilename`/`_multipartBoundary` (UA-const уже был; `_okCdnRequest` UA намеренно не тронут). ✅ B16 `enumFromName<T>` (persisted_setting + 6 settings, все свопы value-equal). ✅ B17 rich_message `_toFormatRanges`. ✅ B18 photo_bubble `_multiPhotoCornerRadius` (single-photo не тронут — иная формула). ✅ B19 `CountryName.displayName`. ✅ B20 Poll `_buildFromState` (без Map round-trip).
- ⏭️ B6 countries ru-blob (риск данных), B9 opcode enum (крупно), B21 `_MessageKind` (SOMNIT).

**ФРОНТ C (layering, 7):** ✅ C1 типизир. push-сеттеры (`setChatsPushNotification`/`setMessagePreview`/`setNotificationSound`/`setCallNotifications`/`setNewContacts`) в account.dart; notifications_screen `_apply(v, action, assign)` через thunk (wire-ключи ушли из UI). ✅ C2 `AccountModule.logout()` (disconnect+removeAccount+cache-clear); settings_tab `_doLogout` делегирует (spoof-clear уже был; снято 4 неисп. импорта). ✅ C3 push_service `_handleReply` → `AccountModule(api).buildLoginPayload(token, interactive:false)` (магbytes/fingerprint дедуп; interactive:false сохранён). ⏭️ read-mark в ChatsModule / spoof-login-метод / ContactCache-ChangeNotifier (SOMNIT/крупно).

**ФРОНТ E (lifecycle, 14):** ✅ E1 media_cache `_inFlight`-dedup; ✅ E2 video_player `_loadGeneration`-guard; ✅ E3 MessageSessionCache LRU(24, LinkedHashMap); ✅ E5 attachment_sheet temp-track (`_tempFiles`/`_sentFiles`, dispose-cleanup, снята prefix-связка); ✅ E7 recording-stop на pause (chat_screen didChangeAppLifecycleState); ✅ E8 `_highlightTimer` cancelable + mounted-guard; ✅ E9 `ComplaintsModule.clear()` в 4 cache-reset-сайтах; ✅ E11 `_messageKeys` prune (в `_pruneReactionNotifiers`) + clear в dispose; ✅ E12 performance_screen mounted-guard ×2. ⏭️ E4 ContactCache→per-row (крупно), E6 UploadManager subscription (SOMNIT/risk), E10 MediaDownloadProgress.release (нет безопасной точки — listener активен на set-null), gallery-cache (SOMNIT).

**ФРОНТ D-хвост:** ✅ `_DebugToggleTile` ×11; ✅ `SettingsRadioTile` ×3 (theme reveal onTapDown сохранён); ✅ `PrimaryLoadingButton` ×5 (+`foreground` для remove-2fa; `_promptPassword` НЕ делегирован — trim-дивергенция); ✅ WebApp/DigitalIdWeb hooks (**HIGH** — DigitalIdWebScreen→тонкий StatelessWidget поверх WebAppScreen); ✅ `LabeledSettingsField`; ✅ security_screen `_settingsRow` (4 билдера→1) + `_showHiddenStatusSheet`→`_showOptionSheet` + 20→24 kSheetShape; ✅ kSheetShape-инлайны ×6 (2 BoxDecoration-случая оставлены); ✅ `SettingsCard`/`SettingsToggleTile`/`SettingsNavTile` ×3 (komet_settings получил disabled-state; notifications thunks сохранены); ✅ `messageStatusVisual` ×2 (voice НЕ унифицирован — разный dim: white54 vs theme-alpha); ✅ contact-card `buildContactCard` + memCache-фикс forwarded; ✅ edit_profile avatar→KometAvatar; ✅ `AnimatedOverlayPopup`-mixin (account_switcher/chat_menu). ⏭️ optimistic-upload flow ×5 (chat_screen, СЕРИЙНО, крупно), edit-message-sheet, reconnect-helper (viz/behavior-change), swipe-dedup, avatar_hero.

**ФРОНТ A-остаток / F-l10n / H6:** ⏭️ A (frosted-pill literal исчез пост-рефактора; hairline — нужна каноничная α / viz-shift; drop-shadow; systemTint — spread-thin, LOW); F-l10n (крупно, ARB-ключи; describeAuthError; message_bubble/overlay RU); H6 (CustomFontService UA — **спросить пользователя**, нужна проверка шрифта на устройстве).

**Метод/верификация:** 2 волны sonnet-агентов ПАРАЛЛЕЛЬНО (16 + 11) на непересекающихся файлах (partition, verbatim-спеки) + foundation (messages/chats/account/push_service/chat_screen/notifications_screen/settings_tab) серийно сам. **Parity: skeptic-агент против HEAD — все OK** (in_list сохранён; copyWith-sentinel корректен; B3-guard недостижим; PerChatJsonStore API-совместим; video-gen chain-of-custody; LRU/folders-lenient/media-cache верны). Агенты приняли безопасные решения (не делегировали при реальной дивергенции): `_promptPassword`(trim), voice-status(dim), `_okCdnRequest` UA, joinByLink external-id, 2 BoxDecoration kSheetShape. `flutter analyze` — **0 ошибок, 19 issues = бейзлайн** (случайный `dart format lib/` перенёс пред-существующие однострочные `if` → +2 curly; откатил 23 format-only-файла token-identical к HEAD). Не закоммичено. **Новые файлы:** `core/storage/per_chat_json_store.dart`, `core/media/raster.dart`, `widgets/{settings_radio_tile,primary_loading_button,labeled_settings_field,settings_card,animated_overlay_popup}.dart`.

### Промпт для Сессии 13

```
Продолжаем рефакторинг Komet по AUDIT_REPORT.md (секция «Прогресс исправлений», Сессии 1–12 закрыты).
Работа НЕ закоммичена — пиши код, git-коммиты не делай. Flutter: /home/a/flutter/bin/flutter, dart: /home/a/flutter/bin/dart.
Пиши АБСОЛЮТНЫЙ МИНИМУМ текста — только код и мысли.

НОРМА: 0 errors, 0 новых warnings, ровно 19 issues бейзлайна (2 dead-push push_service, cacheExtent×1
+ curly×2 chat_screen, axisAlignment chat_screen/connection_status, unnecessary_underscores registration×7/
login_success×3/theme_reveal×1, token_storage encryptedSharedPreferences). Счётчик !=19 → чини.
ВНИМАНИЕ: НЕ запускай `dart format lib/` (весь дерево) — только `dart format <затронутые файлы>`; блэнкет-формат
переносит пред-существующие однострочные `if`/`for` без скобок на 2 строки → curly-lint и тащит format-churn в
несвязанные файлы. Если curly вырос — оберни в {} ИЛИ откати format-only файлы (token-identical к HEAD).

ИСПОЛЬЗУЙ созданное (не дублируй): core/config/{persisted_setting(+`enumFromName<T>`),app_colors}, core/storage/
per_chat_json_store, core/media/raster(`rasterPictureToJpegFile`), core/utils/{format,ids,debouncer,log_redact},
widgets/{error_view,prompt_dialog(`showTextInputDialog`),small_spinner,confirm_dialog,komet_avatar,sheet_helpers
(kSheetShape),settings_radio_tile,primary_loading_button,labeled_settings_field,settings_card(`SettingsCard`/
`SettingsToggleTile`/`SettingsNavTile`),animated_overlay_popup(mixin)}, bubbles/{bubble_context(`messageStatusVisual`),
contact_bubble(`buildContactCard`)}, инстанс `chats`, `CachedChat.copyWith`+`_updateChat`, `CachedMessage.parseAttachments`,
`AccountModule.{logout,buildLoginPayload,setChatsPushNotification/...}`, `ComplaintsModule.clear`.
Конвенции: без комментариев; showCustomNotification; правильный рефактор; quality over quantity.

Метод (сработал в С10–12): sonnet-агенты ПАРАЛЛЕЛЬНО на непересекающихся НОВЫХ+consumer файлах (partition,
verbatim-спеки, каждый агент сам `dart format`+`dart analyze` СВОИХ файлов до 0 issues); foundation/god-файлы
(chat_screen/messages/chats/account/message_bubble/main) — серийно сам. После — skeptic-агент parity против HEAD
(`git show HEAD:…`). ШАГ 0: сверь карту OPEN/DONE выше — НЕ переделывай С1–12.

ПРИОРИТЕТ: сначала настоящие БАГИ (G), потом дедупы бэкенда (H — легко параллелятся), логгинг (I),
затем крупные декомпозиции (J), потом cosmetic/l10n/SOMNIT-хвост (A/F/K). Бери сколько влезет; НЕ обязан всё.
Многие находки в аудите ПОВТОРЯЮТСЯ между разделами и часть уже сделана в С1–12 — на ШАГЕ 0 сверь каждую с кодом.

═══ ФРОНТ G — НАСТОЯЩИЕ БАГИ / dead-affordances (@«Broken or dead UI», @«Robustness», @«Silent failures») ═══
  G1 [HIGH, real] popUntil route-name никогда не совпадает → выкидывает в корень вместо SecurityScreen. password_entry_
     screen ×4 (~633/1001/1187/1359: `route.settings.name=='SecurityScreen'` — имя нигде не задано). Фикс: задать
     `settings: const RouteSettings(name:'SecurityScreen')` в settings_tab (~388 push) + `ModalRoute.withName`, ЛИБО
     захватить Navigator до push и попать по callback. Изолированно (password_entry+settings_tab).
  G2 [MED, data-loss] `_loadForwardedSenderNames` (chat_screen ~3718) ручная реконструкция CachedMessage теряет
     isControl/deleted/editHistory → `msg.copyWith(attachments: newAttaches)` (copyWith уже всё несёт). chat_screen СЕРИЙНО.
  G3 [MED, mislabel] ForwardedMessageAttachment/UnknownAttachment хардкодят `type:photo` → в previewText(messages
     ~315) и _attachLabel(scheduled_messages ~287) forward/unknown = «Фото». Фикс: добавить `AttachmentType.{forward,
     unknown}`, конструировать ими, обработать в 2 switch (forward→text/«Переслано», unknown→«Вложение»). attachment.dart
     + messages + scheduled_messages (СЕРИЙНО — messages foundation).
  G4 [MED, robustness] dispatcher.dispatch push-хендлер без try/catch (~119) → один бросивший хендлер роняет весь батч
     пакетов из одного read (api ~394 loop). Обернуть вызов в try/catch с `logger.w(Opcode.name+error)`, continue. dispatcher.
  G5 [MED, robustness] receiver overflow (`_maxBufferSize`=2MB, ~13/25/29): при переполнении reset()+`const []` молча,
     сокет жив → десинк. Пробросить hard-error в transport-owner (dispatcher error-stream) → форс reconnect. receiver+api.
  G6 [MED] outbox.flush (~44) `pending.payload != null → continue` навсегда: attachment/poll/location pending-строки
     не восстанавливаются. Либо ре-инвок типизир. сендера по payload-типу, либо помечать 'failed' по таймауту. СНАЧАЛА
     проверь, создаются ли вообще 'pending'-строки для аттачей (если нет — ⏭️/downgrade). outbox.
  G7 [MED] calls_tab (~277/470) delete-анимация: parent `Future.delayed(260ms)` + отдельная `Duration(260ms)` в
     контроллере — рассинхрон-magic. Убрать parent-delay, `onDismissed`-callback из `AnimationStatus.dismissed`. calls_tab.
  G8 [MED, latency] sendFileMessage слепой `Future.delayed(3s)` до первой попытки (messages ~1171) — избыточно с
     not.ready-retry-loop. Убрать (сделать в связке с H2). messages СЕРИЙНО.
  G9 [MED] chat_screen dead-UI no-op `onTap:(){}`: пункт «Уведомления»/«Видеозвонок» в `_openChatMenu` (~2875) и
     полноширинный «Отключить уведомления» GlossyPill в CHANNEL-композере (~5620). Либо реализовать (setChatMute уже есть!),
     либо скрыть. chat_screen СЕРИЙНО.
  G10 [MED] `_parseChat` (chats ~1146-1278) один catch-all на ~130 строк молча дропает чат при любой ошибке. Разбить на
     `_resolveTitleAndIcon/_resolveLastMessage/_resolveMuteAndFavorite/_resolvePresence/_resolveAdmins`, каждый defensive.
     chats СЕРИЙНО, аккуратно (login-sync + push путь).
  G11 [MED, race] `_refreshAfterCall` (chat_screen ~3093) `Future.delayed(700ms)` перед рефетчем — заменить на
     событие call-ended/history-updated из ChatsModule-стрима. chat_screen СЕРИЙНО (LOW-приоритет внутри G).

═══ ФРОНТ H — ДЕДУП send/request-boilerplate (@«Duplicated request/response and send-path», 12) — легко параллелится ═══
  H1 [HIGH] file_uploader `_sendHttpRequest(uri,method,headers,body,{onProgress})` + `withProgress`-трансформер: 5
     upload-путей (~71/163/259/312/386) дублируют socket+headers+progress. ⚠️ЧАСТИЧНО СДЕЛАНО в пред-сессии
     (`_sendHttpRequest`/`_buildUploadHeaders`/`_buildMultipartHeaders` уже есть) — СВЕРЬ, доделай остаток/`_okCdnRequest`. file_uploader.
  H2 [MED] messages `_sendWithNotReadyRetry<T>({payload,maxAttempts,retryDelay,initialDelay,onOk})`: 5-7 send*Message
     (~1199/1249/1326/1416/1499 + location/poll/sticker) байт-идентичные not.ready-retry-циклы. + `_sendAttachedMessage`
     обёртка (payload-construct + retry + unwrap). Учти G8 (убрать 3s). messages СЕРИЙНО, parity построчно (sendFileMessage
     возвращает bool — адаптировать).
  H3 [MED] account `_requireMapPayload(packet,method)`→PacketError (не голый Exception): ~15 сайтов
     (~474/496/628/669/723/876/1153/1462) `_checkPacketError`+`if(data is! Map) throw`. Плюс `sendRequestOrThrow` на Api
     (унифицировать `_checkPacketError` account+folders — folders ~199/241 роняет SessionExpired-кейс). account+folders+api СЕРИЙНО.
  H4 [MED] account `_applyProfileResponse(packet)`: updateProfileName/Avatar/removeProfilePhoto (~551/572/608) идентичный
     хвост profile→contact→ProfileData→saveProfile. Реюз и в `_processProfileUpdate`/`_processLoginResponse`. account СЕРИЙНО.
  H5 [MED] Api-хелперы (api.dart ~316): `sendRequestMap(op,payload)→Map?` (~50 сайтов guard `!isOk||payload is!Map`),
     `sendRequestOk(op,payload)→bool` (7 toggle-методов calls/messages/chats). Раздать call-сайты агентам ПО МОДУЛЯМ
     (calls/stickers/folders изолированы; messages/chats/account — серийно). api foundation.
  H6d [MED] messages `_sendAndExtractMessageId(payload,defaultError)` + типизир. `MessageSendException`: sendMessage/
     forwardMessage (~798/847) дублируют error-extract+id-extract (различие лишь fallback-строка). messages СЕРИЙНО.

═══ ФРОНТ I — ЛОГГИНГ проглоченных ошибок (@«Silent failures», 16) — тривиально, параллельно по файлам ═══
  I1 bare `catch(_){}` → `catch(e){logger.w('...: $e');}` (logger уже есть/добавь import): app_database `_migrateLegacyDb`
     (~183); chat_wallpaper_store (~114/186); draft_store (~32); spoofing_service (~187); polls fetch/vote (~55/87);
     CallBridge-методы (call bridge — см. раздел). Каждый файл изолирован → раздать агентам.
  I2 message_bubble/bubbles playback/transcription catch без лога (voice_bubble `_togglePlay`, `_requestTranscription`,
     video_note_bubble `_toggle`) — залогировать (release=obfuscate → иначе недиагностируемо). bubbles/ изолированы.
  I3 main.dart reconnect-login `catch(_){}` (~297-307) — различить «нет аккаунта/токена» (return) от неожид. (лог). main СЕРИЙНО.

═══ ФРОНТ J — ДЕДУП утилит/форматтеров (@«Duplicated formatting and shared-utility gaps», 18) — параллельно ═══
  J1 [MED, bug] `formatLastSeen` (core/utils/format.dart уже есть, с «Был(-а)»-префиксом): chat_info_screen локальный
     `_formatLastSeen` (~1157) без глагола → member-tile (~818) кажет «N мин назад» без «Был(-а)». Удалить локальный,
     звать shared, снять ручной «был(-а) »-префикс на ~307 (иначе дубль). chat_info изолирован.
  J2 [MED, bug] `parseIntOrNull(v)`/`parseIntList(v)` в core/utils (list: tryParse+whereType, БЕЗ `?? 0`): attachment.dart
     ×5 (~361/451/452/480/525/613) — сейчас `?? 0` фабрикует фейковый id 0 в userIds/contactIds. Фикс дропает невалидные. attachment.
  J3 [MED] `pluralRu(n,one,few,many)` в format.dart: chat_info `_pluralCount` (~1167), call_screen (~719), sticker_pack
     (~337), poll_view (~373) — 4 копии mod10/mod100. Раздать. (ЛИБО ICU-plural в ARB — но это F.)
  J4 [MED] mm:ss: `formatDurationHms` (hour-aware) + `formatVoiceElapsed(ms)` (децисекунда) в format.dart: video_player
     `_fmt` (~101), chat_screen `_formatVoiceElapsed` (~5407, сайты 5372/5535). video_player изолирован; chat_screen серийно.
  J5 [LOW] экспонировать `_two`→public `pad2` в format.dart; убрать локальные копии/inline padLeft: schedule_time_picker
     (~17), traffic_monitor (~83/479), debug_menu (~111), info_screen (~279), app_theme_schedule (~59). Параллельно.
  J6 [LOW] `randomUuidV4()`/`randomHex(n)` (Random.secure) в core/utils/random_id.dart: device_identity (~33-48),
     spoofing_service (~244-259) — байт-идентичны; calls `_uuidV4` (~182) юзает НЕ-secure Random() → фикс. Изолированно.
  J7 [LOW] `int? intFrom(Object?)` (+wrapper для u123/g456 composite) в core/utils: call_controller `_asInt` (~142),
     call_session `_participantIdFrom`/`_externalId` (~290/414), nfc_exchange `_decodeEvent` (~63). Изолированно (core/calls+nfc).
  J8 [LOW] `displayName(first,last,{fallback})` в core/utils: search_screen `_contactName` (~127, fallback +phone),
     create_group `_displayName` (~180, без fallback). J9 `_fileStamp(DateTime)` дубль: debug_menu (~110)+traffic_monitor
     (~82) → core/utils. J10 info_screen `_w`/`_d` (~283) мёртвые plural-ветки (все возвращают одно) → убрать ветвление.

═══ ФРОНТ K — magic/stringly-typed + мелкие дедупы (@«Robustness», @«Uncategorized») ═══
  K1 [LOW] poll settings bitmask (messages ~1562 `(anon?4:0)|(mult?1:0)`) → именованные `_pollAnonymousFlag=4/_pollMultipleFlag=1`.
  K2 [MED] DIALOG peer-id `chatId ^ _myId` инлайн ×5 (chat_screen ~2158/2170/2180/3065/3119) → уже есть `_resolveOtherId`
     (~3440); заменить все. chat_screen СЕРИЙНО.
  K3 [MED] session-stale миксин: code_confirmation + password_2fa (~47/24) дублируют `_epoch/_recovering/_sessionStale/
     _stateSub/_recoverStaleSession`. Вынести миксин с per-screen recovery-callback. Изолированно (2 auth-экрана).
  K4 [LOW] lastMsgPlaceholder magic-строка (chats ~255/748/767) — типизировать состояние «нет last-msg» (низкий; ⏭️ ок).
  K5 [MED, WebRTC-риск] VP8 SDP-regex `_forceVp8` (call_session ~857/874) → `getCapabilities`+`setCodecPreferences`.
     ⚠️НЕ вслепую — WebRTC, нужна проверка звонка; вероятно ⏭️/спросить.
  K6 [MED, migration-риск] participants LIKE-scan (`findDialogChatByParticipant`, app_database ~578) → нормализ. таблица
     `chat_participants(chat_id,account_id,user_id,role)` + индекс + schema-migration (v16→17). ⚠️Крупно/рискованно — ⏭️/оцени.

═══ ФРОНТ J2/no-comments (@«No-comments», 5) — тривиально, параллельно ═══
  L1 снять комменты (конвенция «без комментариев»): call_screen (~867 garbled TODO), calls_tab (~151), contacts_tab
     (~107), chat_screen (~4350 TODO Локализация/Склонения, ~1332), chat_list_screen (~207/1182/1555), chat_info_screen
     (~67/75/222/298/323 banner-комменты), settings_tab `_SpoilerPainter` (~868/877/880). chat_screen серийно; остальное параллельно.

═══ ФРОНТ M — крупные декомпозиции god-файлов (@«God-files», СОМНИТ, серийно/осторожно) ═══
  M1 dead Dart push-код (~260 строк, push_service ~41-293): `_showMessageNotification/_showCallNotification/_backgroundHandler/
     _appendHistory/_isActive/_avatarBytes/_initialsAvatar/_downloadBytes/_initialsOf/_avatarPalette/_NotifMessage` — мёртвые
     (живёт нативный KometFcmService.kt). Удалить (ОСТАВИТЬ `_clearHistory/_onNotificationResponse/_handleReply/_handleCall
     Decline/clearChatNotification`). ⚠️ЭТО УБИРАЕТ 2 dead-push из бейзлайна → НОРМА станет 17! Обнови счётчик-норму.
  M2 AccountModule facade-split → backend/modules/account/{auth,profile,privacy,two_factor,sessions}_module.dart + модели
     рядом. Крупно, серийно, осторожно (facade сохранить). ⏭️/оцени.
  M3 chat_list_screen (2888стр): StoriesBar(promote inline `_StoriesUi`→widgets/stories_bar.dart)/FolderTabsView/
     PinnedChatsHeader/ChatListTile/DockedBottomNav. Также K7 identityHashCode-memoization (`_getChatsBody`/`_chatsForPageIndex`
     ~207/810) → реальные виджеты + Flutter-diffing. Крупно, серийно.
  M4 debug_menu (~1300стр build) → секции в lib/frontend/debug/ (DebugNetworkSection/DebugCacheSection/... по образцу
     `_SyncProbeCard`). Изолированно (debug_menu). M5 CachedMessage/CachedChat → lib/models/{message,chat}.dart (+типизир.
     ReactionInfo вместо `payload['reactionInfo']`-индексинга в bubbles/). Крупно, много импортов — серийно.

═══ УНАСЛЕДОВАННЫЙ ХВОСТ из С12 (дожать при желании) ═══
  D-серийно: optimistic-upload flow ×5 (chat_screen `_sendVoice/_sendVideoNote/_sendPhotos/_sendVideo/_sendScheduledPhotos`
    → расширить `_sendAttachMessage` upload-шагом; покрыть upload+progress-dispose+temp-cleanup). Разбить на атомы, parity.
  A-остаток (cosmetic, ЕСТЬ viz-shift — согласуй α): `cs.hairline` getter (outlineVariant α 0.3/0.35/0.4/0.5 → одна);
    `systemTint` getter на BubbleContext (onPrimaryContainer α0.12 ×7 в bubbles/); drop-shadow→GlossyDecor.dropShadow.
  F-l10n (крупно, ARB app_en/app_ru + gen-l10n, ⚠️gen-l10n может добавить issues — маленькими порциями по экрану):
    message_bubble/message_actions_overlay RU-строки; packet.dart typed-error (`isSessionStateError` по коду не substring);
    chats preview-kind enum (attachPreviewLabel/_controlPreviewLabel → тег+резолв в UI); auth `describeAuthError(e,l10n)`+AuthException.
  C-SOMNIT: read-mark→ChatsModule (K2-related); ContactCache→ChangeNotifier (reactive contact-name, крупно); token_login
    spoof-login-метод `loginWithTokenAndSpoof` на account.
  E-SOMNIT: UploadManager subscription-API (E6, risk); ContactCache→per-row SQLite (E4, крупно); MediaDownloadProgress.release
    (E10 — НЕТ безопасной точки, listener активен → вероятно ⏭️); attachment_sheet gallery-cache→GallerySource (SOMNIT).
  B-остаток LOW: B6 countries ru-blob усушка (риск данных — скриптом+сверка); B9 opcode enhanced-enum (~140 сайтов, крупно);
    B21 `_MessageKind` (message_bubble, SOMNIT).
  D-остаток: edit-message-sheet (chat_screen+scheduled_messages); reconnect-helper (proxy/server sheets — behavior-change:
    unify на stateStream+timeout); swipe-dedup (swipe_route/swipe_to_pop threshold-хелпер); avatar_hero shared-content.
  H6-font (CustomFontService legacy UA, custom_font_service ~11/113): Chrome/120 UA → Google отдаёт woff2, а код ждёт ttf
    (regex+`_isSfnt`) → добавление шрифта молча no-op. Фикс: старый UA (Google отдаст ttf) ЛИБО woff2→sfnt-декод (FontLoader
    только sfnt). ⚠️СПРОСИ пользователя — нужна проверка шрифта на устройстве ПОСЛЕ правки. САМ НЕ ТРОГАЙ вслепую.

РЕКОМЕНД. ПОРЯДОК ВОЛН: (в1) параллельно G1/G4/G5/G7 + I1/I2 + J1/J2/J5/J6/J7/J8/J9 + K3 + L(параллельная часть) +
M4 — все изолированные; (серийно сам, между волнами) messages-кластер (G3/G8/H2/H6d/H5-messages), account-кластер
(H3/H4/H5-account), chats (G10/K4), chat_screen (G2/G9/G11/K2/J4-chat/D-upload/L-chat), M1(push)/I3(main). (в2) H1 file_uploader
+ J3/J4-video + K5?/K6? по решению. После каждого куска: САМ diff-ревью + `dart analyze`(сверь норму) + `dart format`
ТОЛЬКО затронутых. В конце — skeptic-агент parity против HEAD по foundation-файлам.

После каждого фронта — строка в «Сессию 13» + ✅/🔧/⏭️. В конце — промпт для Сессии 14.
```

### Сессия 13 (2026-07-05) — большой батч G/H/I/J/K/L/M1 (11+2 параллельных агентов + серийные foundation)

**⚠️ НОРМА ИЗМЕНИЛАСЬ: 19 → 17 issues.** M1 удалил мёртвый Dart push-код (push_service 552→273 строк), сняв 2 бейзлайн-варнинга `unused_element` (`_showMessageNotification`/`_showCallNotification`). Новый бейзлайн = **17 issues** (chat_screen: cacheExtent×1 + curly×2 + axisAlignment×1; connection_status axisAlignment×1; registration unnecessary_underscores×7; login_success×3; theme_reveal×1; token_storage encryptedSharedPreferences×1).

**⚠️ НОВАЯ КОНВЕНЦИЯ (запрос пользователя): БЕЗ КОММЕНТАРИЕВ ВООБЩЕ** — не только «self-documenting», а физически удалять комменты в затрагиваемых файлах и никогда не писать новые (в т.ч. `///` doc-комменты). Осторожно с `// ignore:`-директивами анализатора — их НЕ удалять (в затронутых файлах их не было). Полностью очищены: format/parse/names/messages/attachment/file_uploader; агенты чистили свои файлы. Полный tree-purge НЕ делался (риск сноса `// ignore:` и format-churn) — делать точечно по мере касания.

**Созданные утилиты (core/utils):** `format.dart`+`pad2`/`pluralRu`/`formatVoiceElapsed`; `parse.dart` (`parseIntOrNull`/`parseIntList` — без `?? 0`-фабрикации); `names.dart` (`displayName`). `ids.dart` (`uuidV4`/`randomHex`, secure) уже был.

**ФРОНТ G (баги):** ✅ G1 (popUntil→`ModalRoute.withName('SecurityScreen')`; RouteSettings.name уже был в settings_tab — предикат был реальным фиксом; SecurityScreen пушится из 1 места, всегда в стеке под PasswordEntry). ✅ G2 (уже сделано — `_loadForwardedSenderNames` уже юзал `copyWith`). ✅ G3 (`AttachmentType.{forward,unknown}`; Forwarded/Unknown super `photo`→`forward`/`unknown`; previewText+`_attachLabel`→«Переслано»/«Вложение»; skeptic: рендер не ломается — диспатч по `is`, фото-грид по `is PhotoAttachment`). ✅ G4 (dispatcher push-хендлер try/catch — уже был, выровнен на `logger.w`). ✅ G7 (calls_tab delete-анимация: убран parent `Future.delayed`, removal через `AnimationStatus.dismissed` status-listener). ⏭️ G8 (3s-delay в sendFileMessage НЕ существует в текущем коде — уже убран/стале-реф). ⬜ G5 (receiver+api hard-error), G6 (outbox pending), G9 (dead-UI no-op), G10 (`_parseChat` split), G11 (`_refreshAfterCall`) — Сессия 14.

**ФРОНТ H (дедуп send/request):** ✅ H1 (file_uploader — уже завершён в пред-сессии; агент подтвердил, `_okCdnRequest` UA-дивергенция намеренно оставлена). ✅ H2 (`_sendWithNotReadyRetry<T>` + `_sentMessageMap` — 5 retry-циклов File/Photo/Video/Audio/VideoNote + 3 single-shot Location/Poll/Sticker; skeptic PARITY OK, дефолты maxAttempts/retryDelay не поплыли). ✅ H4 (`_applyProfileResponse(Packet)` — updateProfileName/Avatar/removeProfilePhoto; `_processProfileUpdate` НЕ тронут — иной non-throwing контракт). ✅ H6d (`_sendAndExtractMessageId(payload, defaultError)` — sendMessage/forwardMessage; typed `MessageSendException` НЕ вводил — риск toString-парити ради маргинального выигрыша). ✅ H3 (`_requireMapPayload(packet, method)` — 12 сайтов через precise regex, method-name в `_checkPacketError`≡throw-message; варианты `payload != null && is! Map` и `data['error']` НЕ тронуты). ⬜ H5 (Api `sendRequestMap`/`sendRequestOk` + унификация `_checkPacketError` account+folders) — Сессия 14.

**ФРОНТ I (логгинг):** ✅ I1 (app_database/chat_wallpaper_store/spoofing_service — 3 silent catch залогированы; draft_store/polls уже логировали). ✅ I2 (voice_bubble `_togglePlay`/`_requestTranscription`, video_note_bubble `_toggle`). ✅ I3 (main reconnect-login `catch(_){}` → `logger.w`; null-account/token уже гейтились `if`).

**ФРОНТ J (дедуп утилит):** ✅ J1 (уже сделано — chat_info уже юзал shared `formatLastSeen`, дубль-префикса нет). ✅ J2 (attachment userIds/contactIds → `parseIntList`, дропает невалидные вместо id 0). ✅ J3 (`pluralRu`×4: chat_info участник/подписчик, call_screen участник, sticker_pack стикер, poll_view голос). ✅ J4 (chat_screen `_formatVoiceElapsed`→shared `formatVoiceElapsed`). ✅ J5 (`pad2`: schedule_time_picker/traffic_monitor/info_screen/app_theme_schedule). ✅ J6 (уже сделано — device_identity/calls уже на shared `ids.dart`). ✅ J7 (`parseIntOrNull`: call_controller `_asInt`, call_session `_externalId`, nfc; `_participantIdFrom` composite оставлен). ✅ J8 (`displayName`: search_screen+phone-fallback, create_group). ✅ J9 (уже сделано — traffic_monitor на `formatFileStamp`). ✅ J10 (info_screen мёртвые plural-ветки `_w`/`_d` схлопнуты). ⬜ J4-video (video_player_screen `_fmt`) — Сессия 14.

**ФРОНТ K:** ✅ K1 (poll bitmask → `_pollAnonymousFlag=4`/`_pollMultipleFlag=1`). 🔧 K2 (2 из 4 `chatId ^ _myId` → `_resolveOtherId()`: `_onPresenceChanged`+`_seedPresenceFromChat` — семантика идентична; `_loadOtherPresence`+call-path НЕ тронуты — там нет DIALOG-гейта, замена = behavior-change). ✅ K3 (миксин `SessionStaleRecovery` — code_confirmation+password_2fa; drop-текст стал 2-м хуком `connectionDroppedMessage`, разошёлся между экранами). ⬜ K4/K5/K6.

**ФРОНТ L:** ✅ комменты сняты: calls_tab, contacts_tab, chat_list_screen, chat_info_screen (12 баннеров), call_screen (garbled TODO), settings_tab (`_SpoilerPainter`). + вычищены полностью messages/attachment/file_uploader/format/parse/names.

**ФРОНТ M:** ✅ M1 (dead push-код удалён, −2 варнинга, норма→17; оставлены `_clearHistory`/`_onNotificationResponse`/`_handleReply`/`_handleCallDecline`/`clearChatNotification`; снесены 3 осиротевших импорта). ⬜ M2/M3/M4/M5.

**Метод/верификация:** 11 sonnet-агентов волной 1 (изолированные файлы, partition, каждый сам format+analyze до 0) + 2 агента волны 2 (M1/H1) + foundation серийно сам (messages/attachment/account/main/chat_screen/scheduled). Skeptic-агент против HEAD: messages send-path/G3/J2 — **PARITY OK** (дефолты не поплыли, рендер не ломается; J2 caveat: `num`→toInt даёт `2` вместо `0` для дробных — неактуально для msgpack-int id). `dart analyze` — **0 errors, 17 issues = новый бейзлайн**. `dart format` только затронутых. Не закоммичено.

### Промпт для Сессии 14

```
Продолжаем рефакторинг Komet по AUDIT_REPORT.md (секция «Прогресс исправлений», Сессии 1–13 закрыты).
Работа НЕ закоммичена — пиши код, git-коммиты не делай. Flutter: /home/a/flutter/bin/flutter, dart: /home/a/flutter/bin/dart.
Пиши АБСОЛЮТНЫЙ МИНИМУМ текста — только код и мысли.

НОРМА: 0 errors, 0 новых warnings, ровно 17 issues бейзлайна (cacheExtent×1 + curly×2 + axisAlignment×1 chat_screen;
axisAlignment×1 connection_status; unnecessary_underscores registration×7/login_success×3/theme_reveal×1;
token_storage encryptedSharedPreferences×1). Счётчик !=17 → чини. (Было 19 до С13; M1 снёс 2 dead-push.)
ВНИМАНИЕ: НЕ `dart format lib/` (весь tree) — только затронутые файлы (иначе curly-churn в несвязанных).

⚠️ КОНВЕНЦИЯ (С13): БЕЗ КОММЕНТАРИЕВ — физически удалять в затрагиваемых файлах, не писать новые (вкл. `///`).
НО: `// ignore:`-директивы анализатора НЕ удалять. Полный tree-purge НЕ делать разом (риск format-churn + сноса ignore).

ИСПОЛЬЗУЙ созданное (не дублируй): core/utils/{format(pad2/pluralRu/formatVoiceElapsed/formatFileStamp/formatLastSeen/
formatDurationClock),parse(parseIntOrNull/parseIntList),names(displayName),ids(uuidV4/randomHex)}, + всё из С1–12
(persisted_setting/app_colors/per_chat_json_store/raster/debouncer/ids/log_redact, widgets/*, bubbles/*). В messages:
`_sendWithNotReadyRetry<T>`/`_sentMessageMap`/`_sendAndExtractMessageId`. В account: `_requireMapPayload`/`_applyProfileResponse`.

ШАГ 0: сверь карту С1–13 (НЕ переделывай сделанное — многие находки уже ✅, часть «уже сделано в пред-сессии»).

ОБЪЁМ: бери БОЛЬШОЙ кусок — цель закрыть ВСЁ из G + H5 + J4 + M4 + F-l10n(первые экраны) и продвинуть M2/M3/M5
хотя бы на шаг. НЕ останавливайся на 3–4 пунктах: гони волнами по 10–16 агентов, между волнами сам делай foundation.
Токен-бюджет не жалей (пользователь просил heavy multi-agent). Это ~3–4 волны, а не одна.

═══ ВОЛНА 1 (параллельно, изолированные файлы — раздать ~12–16 sonnet-агентам, партиция без пересечений) ═══
  • J4-video: video_player_screen `_fmt` → shared `formatDurationClock` (h-aware) / `formatVoiceElapsed`. Изолир.
  • M4: debug_menu ~1300стр build → секции в lib/frontend/debug/ (DebugNetworkSection/DebugCacheSection/DebugSyncSection/
    DebugStorageSection/... по образцу существующего `_SyncProbeCard`). Изолир., ОДИН агент целиком владеет debug_menu.
    Каждая секция — отдельный виджет-файл; debug_menu становится тонким композитором. Parity: build-дерево 1:1.
  • H5-модули (ПОСЛЕ ШАГА 1): агент-A calls.dart, агент-B stickers.dart, агент-C folders.dart — каждый переводит свои
    guard-сайты `!isOk||payload is!Map` на НОВЫЕ Api-хелперы `sendRequestMap`/`sendRequestOk` (уже добавленные в api.dart).
  • F-l10n порциями: агент на ОДИН экран за раз (message_bubble RU-строки; message_actions_overlay RU) — вынести хардкод-
    строки в app_en.arb/app_ru.arb, прогнать gen-l10n, заменить на AppLocalizations. ⚠️gen-l10n может добавить issues —
    если >0 новых, откати порцию. Маленькими порциями (1 экран = 1 агент), НЕ весь UI разом.
  • A-остаток (косметика, изолир.): `cs.hairline` getter (outlineVariant α разнобой→одна); `systemTint` getter на
    BubbleContext (onPrimaryContainer α0.12 ×7 в bubbles/). ⚠️есть viz-shift — выбери каноничную α, отметь.
  • G11 `_refreshAfterCall`: если событие call-ended уже есть в ChatsModule-стриме — замени 700ms-delay; иначе ⏭️.

═══ ШАГ 1 (foundation, СЕРИЙНО сам, ДО раздачи H5-модулей) ═══
  H5-ядро в api.dart: добавь `Future<Map<String,dynamic>?> sendRequestMap(int op, Map payload)` (guard `!isOk||payload
  is!Map`→null) и `Future<bool> sendRequestOk(int op, Map payload)` (→isOk). Плюс `sendRequestOrThrow`/унификация
  `_checkPacketError` для account+folders (folders ~199/241 сейчас роняет SessionExpired-кейс — почини по образцу account).
  Потом переведи messages/chats/account toggle-сайты сам (серийно), а calls/stickers/folders отдай агентам (волна 1).

═══ ВОЛНА 2 (foundation, СЕРИЙНО сам — между/после агентов) ═══
  • G5 receiver overflow (2MB reset молча, сокет жив → десинк): пробрось hard-error в transport-owner (dispatcher
    error-stream) → форс reconnect. receiver+api+dispatcher. ⚠️behavior-change — аккуратно, парити по happy-path.
  • G6 outbox.flush `pending.payload!=null continue` навсегда: СНАЧАЛА grep insert-путей outbox — создаются ли
    'pending'-строки для аттачей. Если да — ре-инвок типизир. сендера по payload-типу ИЛИ 'failed'-по-таймауту.
    Если 'pending' для аттачей не создаётся — ⏭️/downgrade, отметь.
  • G9 chat_screen dead-UI: no-op `onTap:(){}` «Уведомления»/«Видеозвонок» в `_openChatMenu` + полноширинный
    «Отключить уведомления» GlossyPill в CHANNEL-композере. setChatMute уже есть → реализуй ИЛИ скрой.
  • G10 chats `_parseChat` ~130-строчный catch-all → split на `_resolveTitleAndIcon/_resolveLastMessage/
    _resolveMuteAndFavorite/_resolvePresence/_resolveAdmins`, каждый defensive. ⚠️login-sync + push путь — парити.
  • H5-хвост: messages/chats/account toggle-сайты на sendRequestOk/sendRequestMap.

═══ ВОЛНА 3 (крупные декомпозиции — серийно, атомизируй + skeptic после каждой) ═══
  • M4 добить если агент не закрыл. • M3 chat_list_screen 2888стр → StoriesBar(promote `_StoriesUi`)/FolderTabsView/
    PinnedChatsHeader/ChatListTile/DockedBottomNav + K7 identityHashCode-memoization→реальные виджеты+Flutter-diffing.
    Разбей на атомы, parity каждого. • M5 CachedMessage/CachedChat → lib/models/{message,chat}.dart + типизир.
    `ReactionInfo` (вместо `payload['reactionInfo']`-индексинга в bubbles/). Много импортов — серийно, по одному классу.
  • M2 AccountModule facade-split → backend/modules/account/{auth,profile,privacy,two_factor,sessions}_module.dart
    (facade `AccountModule` сохранить как делегатор). Крупно — если не влезает, продвинь частично (1–2 под-модуля).

═══ СПРОСИ ПЕРЕД (не трогай вслепую) ═══
  K5 (VP8 SDP-regex `_forceVp8`→getCapabilities+setCodecPreferences — WebRTC, проверка звонка на устройстве);
  K6 (participants LIKE-scan→таблица chat_participants+миграция v16→17 — риск данных); H6-font (custom_font_service UA —
  проверка шрифта на устройстве). По каждой: краткий план + вопрос пользователю, реализуй только после «да».

═══ ХВОСТ (если останется бюджет) ═══
  D-остаток: optimistic-upload flow ×5 chat_screen (`_sendVoice/_sendVideoNote/_sendPhotos/_sendVideo/_sendScheduledPhotos`
  → расширить `_sendAttachMessage` upload-шагом; атомы, parity); edit-message-sheet (chat_screen+scheduled); reconnect-
  helper (proxy/server sheets — behavior-change); swipe-dedup; avatar_hero. B-остаток: B9 opcode enhanced-enum (~140
  сайтов, крупно); K4 lastMsgPlaceholder типизация.

МЕТОД: волнами по 10–16 sonnet-агентов ПАРАЛЛЕЛЬНО на непересекающихся файлах (строгая партиция — каждый файл ровно
одному агенту; foundation-файлы что правишь сам НЕ отдавай; verbatim-спеки с номерами строк + сигнатуры shared-функций;
каждый агент сам `dart format`+`dart analyze` СВОИХ файлов до 0 issues и репортит parity). Foundation/god (chat_screen/
messages/chats/account/api/message_bubble/main/dispatcher/receiver) — серийно сам. После КАЖДОЙ foundation-правки:
сам diff-ревью + `dart analyze`(норма 17) + `dart format` ТОЛЬКО затронутых. В конце волны — skeptic-агент parity
против HEAD (`git show HEAD:…`) по всем foundation-файлам. Проверяй норму 17 после каждой волны; !=17 → чини сразу.

После каждого фронта — строка в «Сессию 14» + ✅/🔧/⏭️. В конце — промпт для Сессии 15 (столь же подробный).
```

### Сессия 14 (2026-07-05) — G-баги + H5 + M4 + F-l10n(1 экран) + A-systemTint (Волна 1: 5 агентов + серийные foundation)

**ШАГ 1 foundation (H5-ядро):** ✅ `packet.dart`: `isSessionExpiredPayload(payload)` + `throwIfPacketError(packet)` (SessionExpired→PacketError). ✅ `api.dart`: `sendRequestMap(op,payload)` (→null при `!isOk||payload is!Map`), `sendRequestOk` (→isOk), `sendRequestOrThrow`. `_onDataReceived` SessionExpired-детект через `isSessionExpiredPayload` (parity). ✅ account `_checkPacketError`→делегатор `throwIfPacketError` (унификация; `method` param оставлен для 8 call-сайтов, `SessionExpiredException` больше не юзается в account но не unused-import). ✅ folders 2 сайта (`setFolderFavorites`/`syncFromServer`) `if(isError)throw PacketError`→`throwIfPacketError` — **FIX: теперь ловит SessionExpired-кейс** (был баг ~199/241).

**ФРОНТ H5:** ✅ calls.dart (агент): 5 сайтов (videoChatStartActive/linkInfo/videoChatJoinByLink/videoChatHistory→sendRequestMap, videoChatDeleteHistory→sendRequestOk). ✅ stickers.dart (агент): 7 сайтов (assetsUpdate×2/assetsGet/assetsGetByIds/linkInfo/assetsAdd/assetsRemove→sendRequestMap). ✅ messages toggle (сам): 4×`return _api.sendRequestOk` (msgSend/msgEdit×2/msgDelete). ✅ chats toggle (сам): 2×`api.sendRequestOk` (setChatPhoto/setChatOptions). Оба агента + skeptic: PARITY OK (sendRequestMap null ⟺ `!isOk||payload is!Map`; error-ветки/return-значения byte-identical).

**ФРОНТ G (баги):** ✅ **G5** (receiver overflow): `ReceiverOverflowException` вместо молчаливого reset(); `api._onDataReceived` ловит → `_forceReconnect()` (happy-path не тронут, throw только при >2MB pending). ✅ **G6** (outbox pending навсегда): grep показал — 'pending' с payload это ТЕКСТ с reply/elements (НЕ аттачи; аттачи 'pending'-строк не создают). Снят `payload!=null continue`; `_replyIdFromPayload`/`_elementsFromPayload` реконструируют reply/elements из payload → `sendMessage(replyToMessageId,elements)`; `sent`+`applyOutgoing` сохраняют payload/elements. ✅ **G9** (dead-UI): «Уведомления» no-op→`_toggleChatMute` (mute/unmute через `chats.setChatMute`, лейбл+иконка по `chat.isMuted`); «Видеозвонок» no-op **удалён** (call-инфра+device-test вне скоупа); CHANNEL-композер `composer_input.dart` полноширинный pill `onTap:(){}`→`onToggleMute` (+`isMuted`/`onToggleMute` params, проброшены из chat_screen). ✅ **G10** (`parseChatRow` ~130стр): split на `_resolveTitleAndIcon/_resolveLastMessage/_resolveMuteAndFavorite/_resolvePresence/_resolveAdmins` (record-возвраты, каждый defensive, outer try/catch сохранён; `otherId` поднят в тело для title+presence). 🔧 **G11** (`_refreshAfterCall`): 700ms-delay-своп → ⏭️ (`CallController.callEnded` фаерится на teardown, НЕ на server-summary-ready → преждевременный fetch = регрессия; нет подходящего события). Хвостовой `catch(_){}`→`logger.w` (silent-failure закрыт).

**ФРОНТ M:** ✅ **M4** (агент): debug_menu_screen 1670→302стр, build декомпозирован на 8 файлов `lib/frontend/debug/` (DebugHeader/QuickActions/Network/FeatureToggles/Cache/Previews/IdSearch/SyncProbe + shared DebugToggleTile); 2 ренейма типов для visibility (`_SearchHit`→`SearchHit`, `_HitKind`→`HitKind`); parity 1:1 render-order, 0 issues. 🔧 **M5-шаг** (сам): типизир. `ReactionInfo`+`ReactionCounter` в `lib/models/reaction_info.dart` (`fromMap`); message_bubble `_buildReactionChipsFor(Map?)`→`(ReactionInfo?)`, 2 сайта оборачивают `ReactionInfo.fromMap(...)` (BubbleContext.reactionInfo остаётся Map? — без ripple; убран `info['counters']`/`c['reaction']`-индексинг). Полный M5 (CachedMessage/CachedChat→models) → С15. 🔧 **M3-шаг** (сам): chat_list_screen 2897→2805стр, shimmer-билдеры (`_buildChatShimmer`/`_buildFolderStripShimmer`/`_folderShimmerPill`) → `chat/view/chat_list_shimmer.dart` (`ChatShimmerTile`/`FolderStripShimmer`, param `Animation<double> shimmer`); 2 call-сайта. Остальная декомпозиция (StoriesBar/FolderTabs/ChatListTile/DockedNav+K7) → С15. 🔧 **M2-шаг** (сам): account.dart 1510→1084стр — 13 дата-классов (PrivacyConfig/BlockedContact/TwoFactorDetails/SessionInfo/LoginResult/LoginSyncParams/… + enums) → `account/account_models.dart` (423стр), account.dart `import`+`export` (re-export → ноль import-churn у внешних потребителей, ноль behavior-change). Facade-split методов (auth/profile/privacy/2fa/sessions) → С15 (coupling `_ensureOnline`/`_checkPacketError`/profile-хелперов).

**ФРОНТ F-l10n (5 экранов):** ✅ message_actions_overlay (13 ключей `msgActions*`, вкл. интерполяцию `currentVersionWithDate({date})`), ✅ notifications_screen (18 `notifications*`), ✅ devices_screen (15 `devices*`; skip 4×`'Unknown'` ip-api — English), ✅ theme_settings_screen (14 `themeSettings*`), ✅ appearance_screen (29 `appearance*`; агент переписал `static const`-списки лейблов на `_labelFor/_messagesFor(l10n)`). Все — отдельными агентами (арб — single-owner на волну). gen-l10n чисто; whole-project analyze=17 после каждого, 0 новых, без rollback. Остаток l10n (chat_info/security/password_entry/call_screen/… + `AppThemeMode.label()`/`AppBubbleShape.label()` дубли-энумы) → С15.

**ФРОНТ K/H6 (ask-before, одобрено пользователем «делать»):** ✅ **H6-font** (custom_font_service) — **фикс уточнён после теста на Linux** (первая попытка MSIE6 не сработала): эмпирически проверил ответы Google Fonts css2 — Chrome/120→woff2 (regex `.ttf` мимо); MSIE6→`url(.../l/font?kit=...)` TTF-контент но БЕЗ `.ttf`-суффикса (regex тоже мимо); **Android 4.4 UA→чистый `url(...v51/....ttf)`** (magic `00010000`, валидный TrueType). Итог: (1) UA→Android 4.4; (2) regex `url((https://[^)]+))` + `_isSfnt`-валидация (робастно к любому формату, woff2 отсеивается); (3) варианты `?family=X` regular-first; (4) **`addFamily` больше НЕ бросает** (весь I/O в try/catch→null — чинит красный экран); (5) кэш-файл ревалидируется `_isSfnt`; (6) response-таймауты 20/30с (чинит зависание/«не реагирует»); (7) UI `_adding` сбрасывается в `finally` (чинит застревание кнопки «Загрузка…»). Ввод URL `fonts.google.com/specimen/X` уже парсился (`familyFromInput`). ✅ проверено: "Yuyu" — реальный шрифт, качается. ✅ **K5** (call_session VP8): SDP-munging `_forceVp8` (regex, только offer, desktop) удалён → `_preferVp8Codecs(pc)` через `getRtpSenderCapabilities('video')`+`setCodecPreferences([vp8,rtx])` на всех transceiver'ах (audio бросают→catch→skip), desktop-gated. ⚠️behavior: теперь префает VP8 и в offer, И в answer (было только offer); mobile-путь byte-identical; нужна проверка десктоп-звонком. ✅ **K6** (app_database): `participants LIKE '%"id":%'` full-scan → нормализ. таблица `chat_participants`(PK+FK CASCADE, индекс account_id/participant_id/chat_id) + миграция **v16→17** (create+index+backfill из JSON) + sync в `saveChats` (delete+reinsert в той же txn после upsert, только для строк с ключом participants — все идут через full toDbRow, drift невозможен); `findDialogChatByParticipant`→JOIN (индекс). chat_participants ведётся ТОЛЬКО для DIALOG (единственный потребитель фильтрует `type='DIALOG'` → устранён write-amp на больших группах, lookup идентичен). **Skeptic #2 PASS (эмпирически): sqlite3-симуляция query-equivalence (вкл. коллизию `"2"`/`"12"` — JSON-кавычки исключают ложное совпадение), FK-cascade, migration-atomicity (s.qflite onUpgrade в транзакции → version bump только при успехе → отсутствие IF NOT EXISTS безопасно).** ⚠️миграция данных — device-verify.

**ФРОНТ A:** ✅ systemTint (агент): `BubbleContext.systemTint` getter (`onPrimaryContainer @0.12`); 5 сайтов bubbles/ (contact/location/call/file×2) → `ctx.systemTint` (pure dedup, 0 viz-shift). A-hairline (`cs.hairline`, outlineVariant α разнобой) → отложен (viz-shift + partition-hostile, много файлов).

**ФРОНТ J:** ✅ J4-video (уже сделано в пред-сессии — video_player_screen на `formatDurationClock`, `_fmt` отсутствует).

**Метод/верификация:** 3 волны агентов. Волна1 = 5 sonnet-агентов ПАРАЛЛЕЛЬНО (M4/H5-calls/H5-stickers/A-systemTint/l10n-actions). Волна2 = 2 (l10n notif+devices; skeptic-parity). Волна3 = 1 (l10n theme+appearance) + K6/K5-skeptic. Foundation серийно сам (packet/api/account/folders/messages/chats/receiver/outbox/chat_parsing/chat_screen/composer_input/message_bubble/chat_list_screen/app_database/call_session/custom_font_service + M5/M2/M3-steps + H6/K5/K6). **Skeptic #1 (read-only, `git show HEAD:…`): G5/G6/G10/H5 — ВСЕ 4 PASS, регрессий нет.** **Skeptic #2: K6-миграция/K5-codec — оба PASS** (K6 эмпирически sqlite3; K5 mobile byte-identical, API компилится на flutter_webrtc 1.5.2, behavior-note: VP8-pref теперь и в answer — обосновано). `dart analyze` (весь проект) — **0 errors, 17 issues = бейзлайн** (без новых) после каждой волны и каждой foundation-правки. `dart format` только затронутых. Не закоммичено.

**Итог С14:** ✅ ВСЕ primary-цели (M4, F-l10n первые экраны×5, весь фронт G кроме G11-delay-⏭️, H5 полностью). ✅ M2/M3/M5 продвинуты на шаг каждый. ✅ Все 3 ask-before (H6/K5/K6) реализованы после «да» пользователя (нужна device-проверка шрифта+десктоп-звонка). Открыто для С15: полный M2 (facade-split методов) / M3 (StoriesBar/FolderTabs/ChatListTile/DockedNav+K7) / M5 (CachedMessage/CachedChat→models); A-hairline; остаток l10n; B9 opcode-enum; K4; D-остаток; J-хвост. **⚠️ device-verify: H6 (загрузка custom-шрифта), K5 (десктоп видеозвонок VP8), K6 (миграция БД v16→17 на реальных данных).**

### Сессия 15 (2026-07-05) — багфиксы по фидбеку + продолжение M2/K4 + l10n

**Багфиксы (по тесту пользователя на Linux):**
- ✅ **H6-font добит** (после провала MSIE6): эмпирически — Google Fonts css2 отдаёт woff2 (Chrome UA) / `/l/font?kit=` без `.ttf` (MSIE6) / чистый `.ttf` (Android 4.4). Итог UA→**Android 4.4**, regex→`url((https://[^)]+))`+`_isSfnt`, варианты regular-first, `addFamily` НЕ бросает (try/catch), кэш ревалидируется, response-таймауты 20/30с, UI `_adding` в `finally`. Шрифты РАБОТАЮТ (проверено пользователем).
- ✅ **Пересланные стикеры** (не отображались): `ForwardedGenericBubble` рендерил только `FileAttachment` → стикер = `SizedBox.shrink()`. Добавлен `ForwardedStickerBubble` (header + StickerBubble) + диспатч в `_buildAttachmentContent` (`originalAttachments.whereType<StickerAttachment>()`) + StickerAttachment-ветка в generic. Персист OK (reload ре-парсит из `payload`).
- ✅ **Обрезка пересланного длинного текста**: `_buildForwardedInlineText` убран `maxLines: 2`+ellipsis → полный текст.
- ✅ **K5 (звонок с Linux)** — подтверждён рабочим пользователем.

**Продолжение backlog:**
- ✅ **K4** (lastMsgPlaceholder типизация): getter `CachedChat.isLastMsgDeleted` инкапсулирует string-sentinel; заменены 3 сайта (chat_list×2, chats internal). Без DB-миграции (backward-compat).
- 🔧 **M2 (facade-split продвинут)**: `AccountApiBase` (shared `ensureOnline`/`checkPacketError`/`requireMapPayload`) + вынесены `SessionsModule` (getSessions/terminate/authorizeWebQrLogin) и `PrivacyModule` (10 методов: privacy config/blocked/push-настройки/токены). AccountModule — facade-делегатор. **account.dart 1510→997** (модели С14 + sessions + privacy). Auth/profile/2fa кластеры оставлены (coupling `_processProfileUpdate`/`_applyProfileResponse`) → С16.
- ✅ **l10n +5 экранов** (агент): call_screen(54 ключа)/komet_hub(20)/scheduled_messages(18)/contact_profile(16)/nfc_exchange(17) = **125 новых ключей** (арб 379×2, идентичные наборы). gen-l10n чисто, full-project analyze=17, 0 rollback. Всего l10n за С14+С15 = **10 экранов**. Остаток: chat_info/security/password_entry/cloud_storage/digital_id/attachment_sheet/photo_editor/font_settings + enum-labels → С16.
- **Верификация С15:** `dart analyze` (весь проект) — **0 errors, 17 issues = бейзлайн** после всех правок (l10n + M2 + K4 + багфиксы сосуществуют чисто). `dart format` только затронутых. Не закоммичено.

**Продолжение С15 (по запросу «делай, продолжай»):**
- ✅ **M2 facade-split ПОЧТИ ЗАВЕРШЁН**: вынесены ещё `ProfileModule` (updateProfileName/Avatar/getAvatarUploadUrl/removeProfilePhoto + `_applyProfileResponse` + публичный `processProfileUpdate`) и `TwoFactorModule` (12 методов 2fa; юзает `_profile.processProfileUpdate`, тот же инстанс). **account.dart 1510→783** (5 под-модулей: sessions/privacy/profile/two_factor + models + base; в фасаде остался только auth: requestCode/verifyCode/login/completeRegistration/beginAddAccount). **Skeptic против HEAD: PASS все 6 секций** (byte-equivalent modulo renames; `processProfileUpdate` timing сохранён — запрос отправляется до подписки на push, как в HEAD; единственный ProfileModule-инстанс; все 26 делегаторов совпадают по сигнатурам). M2-хвост (auth) оставлен (риск логина) → С16.
- 🔧 **M3-шаг**: `_AnimatedChatTile`+`_ActivitySubtitle` (самодостаточные StatefulWidget'ы) → `chat/view/chat_list_tile.dart` (публичные `AnimatedChatTile`/`ActivitySubtitle`). **chat_list_screen 2897→2644** (С14 shimmer + С15 tile). DockedBottomNav/StoriesBar/K7 — coupled с nav-машинерией State → С16 (аккуратно).
- ✅ **l10n — фронт практически закрыт: 18 экранов** (арб 429→**615 ключей**×2). С14: message_actions/notifications/devices/theme/appearance (5). С15: call/hub/scheduled/contact_profile/nfc (5). С15-прод: chat_info/security/password_entry (3) + cloud_storage/digital_id/attachment_sheet/photo_editor/font_settings (5). Все агентами (арб — single-owner на волну), per-screen gen-l10n+analyze, 0 rollback, норма 17 держится. Остаток l10n: enum-лейблы (`AppThemeMode/AppBubbleShape/AppBubbleBehavior/AppFonts.label()` в core/config — нужен проброс context/l10n в вызовы) + мелочь → С16.

**⚠️ Осознанно НЕ сделано (риск/низкая ценность, требуют отдельной аккуратной сессии):** M2-хвост (auth/login — риск), M3 DockedBottomNav/StoriesBar+K7 (nav-машинерия вплетена в State, K7-мемоизация — hot-path, риск перф-регрессий), M5 (CachedMessage/CachedChat уже типизированы — остаётся лишь file-move, coupling со статиками ChatsModule), B9 (~140 сайтов opcode-enum, churn, низкая баг-ценность), A-hairline (α 0.18–0.5 намеренно разные — design-change, не dedup — ждёт решения пользователя). Делать по одному со skeptic-верификацией.

**⚠️ Крупные рефакторы НЕ тронуты вслепую (риск сломать критичные пути):** M2-хвост (auth/profile/2fa), M3-полная декомпозиция + K7 (nav-машинерия State — deeply coupled, риск перф/регрессий), M5 (CachedMessage/CachedChat — coupling с ChatsModule-статиками/parse-хелперами), B9 (~140 сайтов opcode, churn), A-hairline (α 0.18–0.5 намеренно разные → design-change, не dedup). Делать по одному с skeptic-верификацией.

### Промпт для Сессии 15

```
Продолжаем рефакторинг Komet по AUDIT_REPORT.md (секция «Прогресс исправлений», Сессии 1–14 закрыты).
Работа НЕ закоммичена — пиши код, git-коммиты не делай. Flutter: /home/a/flutter/bin/flutter, dart: /home/a/flutter/bin/dart.
Пиши АБСОЛЮТНЫЙ МИНИМУМ текста — только код и мысли.

НОРМА: 0 errors, 0 новых warnings, ровно 17 issues бейзлайна (cacheExtent×1 + curly×2 + axisAlignment×1 chat_screen;
axisAlignment×1 connection_status; unnecessary_underscores registration×7/login_success×3/theme_reveal×1;
token_storage encryptedSharedPreferences×1). Счётчик !=17 → чини.
ВНИМАНИЕ: НЕ `dart format lib/` (весь tree) — только затронутые файлы.
⚠️ КОНВЕНЦИЯ: БЕЗ КОММЕНТАРИЕВ — физически удалять в затрагиваемых файлах, не писать новые (вкл. `///`). `// ignore:` НЕ трогать.

ИСПОЛЬЗУЙ созданное (не дублируй): core/utils/{format,parse,names,ids,debouncer,log_redact}; persisted_setting; app_colors;
models/{contact_info,chat_info,attachment,reaction_info,message_search_result}; widgets/{attachment/bubbles/*,bubble_context};
Api-хелперы `sendRequestMap`/`sendRequestOk`/`sendRequestOrThrow` + packet `throwIfPacketError`/`isSessionExpiredPayload`;
messages `_sendWithNotReadyRetry`/`_sentMessageMap`/`_sendAndExtractMessageId`; account `_requireMapPayload`/`_applyProfileResponse`;
account/account_models.dart (13 дата-классов, re-export через account.dart); chat_parsing `_resolve*`-кластер;
frontend/debug/* (8 секций debug_menu); chat/view/{composer_input,chat_list_shimmer,...}. BubbleContext.systemTint getter.

ШАГ 0: сверь карту С1–14 (НЕ переделывай — H6/K5/K6/G/H5/M4 закрыты; M2/M3/M5 сделаны на 1 шаг; 5 l10n-экранов готовы).

═══ ВОЛНА 1 (l10n порциями — 1 агент = 1-2 изолир. экрана, арб single-owner на волну; параллельно НЕ два l10n) ═══
  Остаток hardcoded-RU (по убыванию): chat_info_screen(93), password_entry_screen(62), security_screen(56),
  call_screen(48), digital_id_screen(39), cloud_storage_screen(27), attachment_sheet(25), scheduled_messages(19),
  komet_hub(18), contact_profile(16), nfc_exchange_sheet(15), font_settings(17), + enum-дубли
  AppThemeMode.label()/AppBubbleShape.label()/AppBubbleBehavior.label() (core/config — их лейблы дублируют экраны).
  Метод как С14: агент выносит строки в app_en/ru.arb (same key set, LAST key без запятой, placeholder-мета только в en),
  gen-l10n, замена на AppLocalizations.of(context)!; если >0 новых issues — rollback порции. chat_screen/chat_list — сам.

═══ ВОЛНА 2 (параллельно, изолир.) ═══
  • A-hairline: `ColorScheme`-extension getter `hairline` (outlineVariant α разнобой→ОДНА каноничная, посчитай моду α);
    замени `cs.outlineVariant.withValues(alpha: X)` по frontend. ⚠️viz-shift — выбери каноничную α, отметь дельты.
  • B9 opcode → enhanced-enum: ~140 сайтов `Opcode.xxx` (int-константы) → enum со `.code`. КРУПНО, изолир. на opcode_map.dart
    + переводи потребителей волнами (grep call-сайтов; НЕ ломай `Opcode.name(op)`). Может дать issues — атомизируй.
  • K4: `ChatsModule.lastMsgPlaceholder` (String-sentinel) → типизир. (enum/nullable). Изолир. в chats + потребители.

═══ ВОЛНА 3 / серийно сам (крупные god-декомпозиции — атомизируй + skeptic после каждой) ═══
  • M3 chat_list_screen 2805стр → StoriesBar(promote `_StoriesUi`)/FolderTabsView/PinnedChatsHeader/ChatListTile/
    DockedBottomNav (в chat/view/) + **K7**: `identityHashCode(_chats/_folders/_profile)`-мемоизация (стр ~210/807) → реальные
    виджеты + Flutter-diffing (перф-находка). Разбей на атомы, parity каждого против HEAD.
  • M5 CachedMessage(messages.dart)/CachedChat(chats.dart) → lib/models/{message,chat}.dart. МНОГО импортов — серийно,
    по одному классу, re-export как account_models (`export`), потом чистить импорты. ReactionInfo уже вынесен (С14).
  • M2 AccountModule facade-split → backend/modules/account/{auth,profile,privacy,two_factor,sessions}_module.dart
    (facade AccountModule делегирует). Модели уже вынесены (account_models.dart). Coupling: `_ensureOnline`/`_checkPacketError`
    (→throwIfPacketError)/`_requireMapPayload`/`_processProfileUpdate`/`_applyProfileResponse` — вынеси в shared base/mixin
    или top-level, чтобы под-модули брали только `Api`. Крупно — 1–2 под-модуля за раз, parity.

═══ ХВОСТ (если бюджет) ═══
  D-остаток: optimistic-upload ×5 chat_screen (`_sendVoice/_sendVideoNote/_sendPhotos/_sendVideo/_sendScheduledPhotos`
  → расширить `_sendAttachMessage` upload-шагом); edit-message-sheet; reconnect-helper (proxy/server sheets); swipe-dedup;
  avatar_hero. J-хвост. B-остаток.

═══ DEVICE-VERIFY (напомни пользователю — сделано в С14, нужна проверка на устройстве) ═══
  H6 (загрузка custom-шрифта из Google Fonts — MSIE6 UA должен вернуть TTF); K5 (десктоп видеозвонок — VP8 через
  setCodecPreferences, проверь что видео идёт в обе стороны); K6 (миграция БД v16→17 на реальном профиле — DIALOG-поиск
  по participant, backfill chat_participants). Если что-то сломалось — откат конкретного пункта.

МЕТОД: волнами по 10–16 sonnet-агентов ПАРАЛЛЕЛЬНО на непересекающихся файлах (строгая партиция; арб — 1 l10n-агент/волна;
foundation что правишь сам НЕ отдавай; verbatim-спеки + сигнатуры shared-функций; каждый агент сам format+analyze до 0).
Foundation/god (chat_screen/chat_list_screen/messages/chats/account/api/message_bubble/app_database/call_session/main/
dispatcher/receiver) — серийно сам. После КАЖДОЙ foundation-правки: diff-ревью + analyze(норма 17) + format затронутых.
В конце волны — skeptic-агент parity против HEAD (`git show HEAD:…`). Норма 17 после каждой волны; !=17 → чини сразу.

После каждого фронта — строка в «Сессию 15» + ✅/🔧/⏭️. В конце — промпт для Сессии 16.
```

### Промпт для Сессии 11–12 (большой батч medium/low) — АРХИВ (выполнялось в С11)

```
Продолжаем рефакторинг Komet по AUDIT_REPORT.md (секция «Прогресс исправлений», Сессии 1–10 закрыты).
Работа НЕ закоммичена — пиши код, git-коммиты не делай. Flutter: /home/a/flutter/bin/flutter.
Пиши АБСОЛЮТНЫЙ МИНИМУМ текста — только код и мысли.

Норма: 0 errors, 0 новых warnings. Пред-существующие, НЕ трогать (ровно 19 issues бейзлайна):
dead push-код _showMessageNotification/_showCallNotification (push_service.dart); SDK-deprecation
cacheExtent/axisAlignment (chat_screen.dart ×2, connection_status.dart); unnecessary_underscores
(registration_screen ×7, login_success_screen ×3, theme_reveal ×1); token_storage encryptedSharedPreferences;
2× curly_braces_in_flow_control в chat_screen `_resolveCurrentPosition` (нетронутый гео-код). Если после
правок issue-счётчик != 19 — ты внёс новое, чини.

Утилиты/модели/контроллеры/виджеты ИСПОЛЬЗУЙ (не дублируй): core/utils/{format,ids,debouncer,log_redact}.dart,
core/config/persisted_setting.dart, models/{contact_info,chat_info,message_search_result}.dart,
widgets/attachment/bubbles/bubble_context.dart, backend/modules/{chat_preview,chat_parsing}.dart,
инстанс-репозиторий `chats` (НЕ `ChatsModule.` — статик остались только константы muteOff/muteForever/
lastMsgPlaceholder), screens/chats/chat/{chat_controller,chat_prank_controller,voice_record_controller,
video_note_controller,command_panel_controller,sticker_panel_controller,chat_search_controller,
message_search_result,upload_status}.dart, screens/chats/chat/view/{search_view,composer_input,selection_bar,
chat_header,command_panel_view,sticker_panel_view,shimmer_loading}.dart. Конвенции: без комментариев;
showCustomNotification (не SnackBar); правильный рефактор вместо хака; quality over quantity.

Метод: sonnet-агенты ПАРАЛЛЕЛЬНО на непересекающихся НОВЫХ файлах (агент авторит по verbatim-спеке —
точные строки+интерфейс+рамки); правки одного общего файла делаешь СЕРИЙНО сам. После каждого под-куска —
САМ ревьюй дифф + `flutter analyze` (сверяй 19) + `dart format` затронутого. Parity перепроверяй скептик-
агентом против HEAD (`git show HEAD:…`), НЕ рабочего дерева. Маленькие атомарные куски. План на сессию сразу.
После каждого куска обнови AUDIT_REPORT.md (✅/🔧/⏭️) + строка в «Сессию 11». В конце — промпт для Сессии 12.

СТАТУС: ВСЕ high/крупные закрыты — H15/H15b (chat_screen 6770→4815 + 8 view-виджетов), H16 (message_bubble
2832→1225 + 12 бабблов), H17 (ChatsModule → инстанс-репозиторий `chats` + chat_parsing/chat_preview вынесены),
H14/H11/H3/H4 закрыты. Единственный незакрытый high — H6.

════════ ГЛАВНАЯ ЦЕЛЬ: БОЛЬШОЙ БАТЧ medium/low (дубли/костыли/layering) — рассчитан на 1–2 сессии (11–12) ════════
Крупные декомпозиции позади. Теперь агрессивно добиваем длинный хвост: дублирование (89), костыли (65),
оптимизация (40), сомнительные (37). НЕ мельчи — бери СРАЗУ несколько фронтов, тяжёлый параллельный фан-аут.

ШАГ 0 (обязательно): построй карту OPEN vs DONE. Многое уже закрыто в С1–10 (uuidV4, PersistedSetting<T>,
formatDuration/fileStamp/last-seen/Debouncer, ContactInfo/ChatInfo, HTTP-хелпер, batch-prefetch, ChatsModule→chats,
и т.д.). Пройди «Все находки по темам», отметь по каждой находке ✅/⬜ (сверяя с кодом и Сессиями 1–10), и НЕ
переделывай сделанное. Итог карты — коротко в отчёт.

Затем фан-аут по НЕПЕРЕСЕКАЮЩИМСЯ фронтам (sonnet-агенты параллельно; общий файл — серийно сам):
  ФРОНТ A — Цветовые литералы → AppAccent/тема (@«Hardcoded theming and color literals», 7): raw hex/Color(...)
    в chat_info_screen (480/511/521/564/791), chat_list_screen:2243, message_bubble (2438/2801/2963),
    traffic_monitor:224, settings_tab:671, media_preview_screen:12, photo_editor:1891 → семантические токены.
  ФРОНТ B — Backend parsing/model дубли (@«Backend parsing and model duplication», 22): attach/FORWARD/CONTROL
    парсинг в messages.dart (446-463/724-741/534-541) и JSON-decode-with-fallback → единые хелперы (по образцу
    chat_parsing.dart/chat_preview.dart). messages.dart — общий файл, правь СЕРИЙНО сам.
  ФРОНТ C — Layering violations (@«Layering violations from UI into transport/storage», 7): notifications_screen
    (50-70/132-205) + account.dart(496-521) сырые protocol-key мапы → типизированные сеттеры.
  ФРОНТ D — Дубли UI-виджетов (@«Duplicated UI widgets and layout», 25, минус уже сделанный PersistedSetting):
    общие confirm/prompt-диалоги, settings-rows, bottom-sheet chrome, avatar/spinner/header — в переиспользуемые
    виджеты. Много сайтов — дели на под-агентов по кластерам экранов.
  ФРОНТ E — Lifecycle/dispose/unbounded caches (@«Lifecycle, dispose, and unbounded caches», 14): нотифаеры/
    таймеры/temp-файлы/кеши без release/bound (в т.ч. ContactCache-blob messages.dart:15-108) → dispose/эвикция.
  ФРОНТ F — Остатки утилит/строк/уведомлений (@«Duplicated formatting…» 18 + «Hardcoded Russian strings/l10n» 6
    + «SnackBar convention» 4): добить оставшиеся копии форматтеров, вынести хардкод-строки, SnackBar→
    showCustomNotification там, где ещё не переведено.

Бери столько фронтов, сколько влезает в контекст (цель — максимум за сессию; остаток и не начатые фронты —
в промпт следующей сессии). Каждый вынос: analyze==19 + dart format + parity скептиком против HEAD.

H6 (CustomFontService legacy UA) — ЕДИНСТВЕННЫЙ незакрытый high, требует проверки на устройстве
(woff2 vs sfnt/TTF от Google Fonts). САМ НЕ ТРОГАЙ вслепую — СПРОСИ пользователя, готов ли проверить шрифт
на устройстве после правки UA; только тогда правь.

После каждого фронта — строка в «Сессию 11/12» + ✅/🔧/⏭️. В конце — промпт для следующей сессии.
```

## Статистика

- Всего находок: **231** — 🔴 high: **17**, 🟠 medium: **124**, 🟡 low: **90**
- По типу: дублирование **89**, костыли **65**, оптимизация **40**, сомнительные решения **37**

**Горячие файлы** (по числу привязок находок):

- `lib/frontend/screens/chats/chat_screen.dart` — 88
- `lib/frontend/widgets/message_bubble.dart` — 59
- `lib/backend/modules/messages.dart` — 41
- `lib/backend/modules/account.dart` — 37
- `lib/frontend/screens/chats/chat_list_screen.dart` — 33
- `lib/backend/modules/chats.dart` — 31
- `lib/frontend/screens/chats/chat_info_screen.dart` — 25
- `lib/frontend/screens/profile/security_screen.dart` — 19
- `lib/backend/modules/file_uploader.dart` — 17
- `lib/frontend/widgets/attachment/photo_editor.dart` — 15
- `lib/frontend/screens/profile/debug_menu_screen.dart` — 14
- `lib/backend/modules/calls.dart` — 13

## Итог одним абзацем

> Komet is a functional, feature-rich Flutter messaging client, but the audit reveals a codebase under sustained schedule pressure where "make it work" has repeatedly won over structural hygiene. The dominant systemic problems are massive god-files (chat_screen.dart at 7568 lines, message_bubble.dart at 3476, chat_list_screen.dart at 2888, plus 1500+ line all-static backend modules) that fuse a dozen unrelated responsibilities and are effectively untestable. Pervasive duplication is the second theme: the same request/response guard, send-with-retry loop, formatting helpers (mm:ss, zero-pad, last-seen, Russian plurals), settings rows, confirm dialogs, avatar widgets, and color literals are re-implemented dozens of times, and several copies have already drifted into inconsistent behavior. A recurring architectural violation is untyped Map<String,dynamic> wire data flowing straight into widgets, forcing four screens to hand-parse contact names with different rules and producing different names on different screens. There is a real cluster of security/privacy defects (plaintext proxy credentials, a drifted debug-log redactor that leaks device IDs into shareable exports, spoofable cloud-storage identity, plaintext IP geolocation) and several silent failures where bare catch blocks swallow connect, upload, and outbox errors with no logging. Performance hot paths suffer from full-list rebuilds on trivial events, per-contact network fan-out where a batched call exists, and synchronous I/O on the UI isolate. Finally there are outright broken affordances: a navigation popUntil that always ejects the user to app root, a custom-font feature that can never succeed due to a User-Agent mismatch, and multiple no-op buttons presented as working features. None of these are catastrophic individually, but the density of duplication and the god-files make every future change slower and riskier.

## 🎯 Топ-10 приоритетов (максимум эффекта на усилие)

### 1. Fix the popUntil route-name that always ejects users to app root
**Почему:** After 2FA setup, password change, email change, and account removal, all four success flows pop the entire navigation stack to the app root instead of returning to SecurityScreen, because the matched route name is never set and the predicate silently degrades to route.isFirst. This is a live, user-visible navigation bug on high-value security flows, and the fix is small.

**Что сделать:** Either set settings: const RouteSettings(name: 'SecurityScreen') at the single push site in settings_tab.dart and use ModalRoute.withName, or capture Navigator.of(context) before pushing the nested flow and pop a known number of routes / pass an explicit return callback.

### 2. Move proxy credentials into secure storage and fix the debug-log redactor leak
**Почему:** Two independent high-severity privacy defects: SOCKS5/HTTP proxy username and password are stored in plaintext SharedPreferences even though TokenStorage/FlutterSecureStorage already exists for exactly this, and the DebugSessionLog uses a private redactor that has drifted from the shared allowlist, so device IDs (and likely OTP/QR/codes) are written in cleartext into the support export the user is told is safe to share.

**Что сделать:** Route proxy username/password through TokenStorage.writeSecure/readSecure/deleteSecure (keep only host/port/type in prefs), and delete DebugSessionLog's private redactor to route recordRequest/recordResponse through the shared redactForLog allowlist; fix the false doc comment.

### 3. Restore the custom-font feature by sending a legacy User-Agent
**Почему:** CustomFontService sends a Chrome/120 UA to Google Fonts (which then serves woff2) but only accepts a legacy TTF response via regex and _isSfnt, so adding any Google font silently fails for every user, and the blanket catch leaves no diagnostic. A whole shipped feature is dead.

**Что сделать:** Send an older-browser User-Agent so Google Fonts serves the sfnt/TTF container the existing regex and _isSfnt gate expect (Flutter's FontLoader cannot decode woff2), and propagate the failure so the settings caller can surface showCustomNotification instead of a silent no-op.

### 4. Stop swallowing connect/upload/outbox failures that report success
**Почему:** switchAccount does try{connect()}catch(_){} and returns a profile even when the app is left disconnected; the file-upload path fabricates status 0 on a 1s timeout and treats it identically to a real 200; OutboxService.flush breaks the entire pending loop on the first per-message error and discards it unlogged. Each silently converts a failure into apparent success, corrupting delivery and account state with zero diagnostics.

**Что сделать:** In switchAccount verify api.state == online after connect and rethrow otherwise (mirroring loginWithToken); model upload as confirmed-success/confirmed-failure/unknown instead of folding timeout into success; change outbox to catch per-row, log via logger, and continue rather than break.

### 5. Batch the chat-list contact prefetch instead of one request per contact
**Почему:** _prefetchContactsForChats loops and calls searchContactById per unknown id, each firing its own contactInfo packet, and it runs on every chatsChanged/draft-change/login. The module already exposes ensureContactNames which batches all missing ids into one request and is used correctly elsewhere. This is a high-severity perf win with an essentially one-line change.

**Что сделать:** Replace the per-id loop with await messagesModule.ensureContactNames(ids); _scheduleContactRebuild(); and drop the now-redundant _inflightContactIds bookkeeping.

### 6. Stop gating the whole message ListView on composer-height and read-time notifiers
**Почему:** The ListView.builder is wrapped in ListenableBuilder(merge([_otherReadTime, _composerHeight])), so ordinary composer interactions (multi-line wrap, reply preview, panel toggle) and every read receipt rebuild all visible MessageBubbles including status recomputation — a systemic frame-cost multiplier on the busiest screen.

**Что сделать:** Keep the delegate/list stable: reserve bottom padding via a separate SliverPadding/spacer and move the read/seen checkmark into a per-message ValueListenableBuilder inside MessageBubble so only the last own message reacts to _otherReadTime.

### 7. Introduce typed ContactInfo/ChatInfo models at the fetch boundary
**Почему:** ContactInfo arrives as raw Map and four screens (call, contact profile, NFC, contacts tab) each re-extract the display name with genuinely different priority rules, so the same contact renders different names on different screens. This is a correctness inconsistency and a layering violation, and it recurs for chat-info participant/admin key coercion.

**Что сделать:** Parse ContactInfo/ChatInfo/PresenceInfo once in the backend contacts/chats module into typed models with a canonical displayName getter (normalizing int/String keys there), have all UI consume the model, and delete the hand-rolled extractors.

### 8. Extract shared sendRequest guard and send-with-retry helpers
**Почему:** The 'validate isOk + require Map payload' guard is copy-pasted across ~50 methods and the 'not.ready' retry loop across all 7 media senders, with copies already drifted (folders drops SessionExpiredException, sendFileMessage has an extra blind 3s delay). This is the single largest source of backend duplication and future drift.

**Что сделать:** Add sendRequestMap/sendRequestOk/sendRequestOrThrow helpers on Api and one private _sendAttachedMessage(...) owning payload construction + the retry loop + response unwrap; collapse the ~50 guards and 7 senders onto them, and drop the redundant sendFileMessage initial sleep.

### 9. Introduce a generic PersistedSetting/PersistedEnum for the ~17 config classes
**Почему:** Every persisted setting hand-rolls key + ValueNotifier + load + save with an inconsistent contract: most rely on main.dart to assign current.value in a matching pair of ~18 load and ~18 assign lines, so forgetting one pairing silently keeps a toggle at its default forever with no signal. High duplication plus a real latent bug class.

**Что сделать:** Create PersistedSetting<T> and PersistedEnum<T extends Enum> whose load() always self-assigns current.value, replace each ad hoc class body with a one-line instance, and make load fire-and-forget so the main.dart pairing disappears by construction.

### 10. Begin decomposing the god-files, starting with the message list and MessageBubble dispatch
**Почему:** chat_screen.dart (7568 lines, 151 methods), message_bubble.dart (3476 lines), and the all-static ChatsModule are untestable, block parallel work, and directly cause the whole-list rebuild problem. Splitting the message list into its own widget simultaneously fixes the highest-impact perf finding.

**Что сделать:** Extract the message list into its own widget so ancestor setState stops cascading into it; split MessageBubble into per-type bubble widgets under attachment/bubbles/ keyed on the already-typed attachment models; and move ChatsModule toward an instantiable ChatRepository/ChatPushHandler split with chatsChanged on a real notifier.

## ⚡ Быстрые победы (мелкие, безопасные, ценные)

- Fix the popUntil route-name predicate so security-flow success screens return to SecurityScreen instead of the app root.
- Replace the spoof_screen ScaffoldMessenger/SnackBar with showCustomNotification — the only SnackBar in the codebase and a direct convention violation.
- Delete the leftover debug logging that ships in release: the [FLIP] debugPrint in chat_list_screen, the per-voice-message hex/ascii file introspection in _sendVoice, and the print('PUSHDBG'/'REPLYDBG') calls in push_service.
- Move proxy username/password to TokenStorage.writeSecure/readSecure/deleteSecure, keeping only host/port/type in SharedPreferences.
- Route DebugSessionLog record paths through the shared redactForLog allowlist and delete its drifted private redactor.
- Swap the per-contact searchContactById loop in the chat-list prefetch for the existing batched ensureContactNames call.
- Delete chat_info_screen's local _formatLastSeen and call the shared formatLastSeen (this also fixes the missing 'Был(-а)' verb on member tiles and requires removing the doubled prefix at line 307).
- Replace the manual CachedMessage constructor in _loadForwardedSenderNames with msg.copyWith(attachments: newAttaches) to stop silently dropping isControl/deleted/editHistory.
- Change PollView.initState to fetch(force: false) so the module cache and in-flight dedup actually apply on scroll-back.
- Guard tz.initializeTimeZones() with a one-time static flag so it does not re-parse the full IANA database on every reconnect.
- Rename the private _two zero-pad helper in format.dart to a public pad2 and delete the local closures/inline padLeft copies; likewise hoist _fileStamp to a shared formatFileStamp.
- Extract a single Random.secure()-backed Uuid.v4()/randomHex utility so calls.dart stops using a non-secure RNG for conversationId.
- Add pause()/resume() to SelfCheckService and wire it into the existing didChangeAppLifecycleState handler so it stops forcing 10s network round-trips while backgrounded.
- Merge the four separate chatUpdate calls in cloud-storage _configurePrivacy into one setChatOptions(options: {...}) for atomicity and 4x fewer round-trips.
- Wrap the push-handler invocation in PacketDispatcher.dispatch() in a try/catch that logs the opcode, so one throwing handler cannot drop the rest of a decoded batch.
- Add per-row logging (and continue instead of break) to OutboxService.flush, and add logging to the bare catch blocks in PollsModule, CallBridge, and the sticker/photo-editor paths.
- Use the existing shared showConfirmDialog and kSheetShape constant at the chat_screen and security_screen sites that re-typed their own copies (including security_screen's divergent 20px sheet radius).
- Remove the no-comments-convention violations: the // TODO markers in chat_screen.build(), the banner/inline comments in chat_info_screen, and the garbled TODO in call_screen.

## 📋 Все находки по темам

Легенда: {'optimization': 'ОПТ', 'duplication': 'ДУБЛЬ', 'crutch': 'КОСТЫЛЬ', 'questionable': 'СОМНИТ'} | 🔴 HIGH / 🟠 MED / 🟡 LOW | усилие S/M/L


### God-files and missing decomposition  (9 — 3 high)

_A handful of enormous classes own many unrelated responsibilities, blocking isolated testing and guaranteeing merge conflicts. The documented layered architecture (models/, state/) is not actually realized._

<details>
<summary><b>🔴 HIGH · СОМНИТ · [L]</b> — chat_screen.dart is a 7568-line god-file mixing ~10 unrelated responsibilities</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:326 (_ChatScreenState declaration)`, `lib/frontend/screens/chats/chat_screen.dart:730 (_loadHistory / pagination / persistence)`, `lib/frontend/screens/chats/chat_screen.dart:1217 (_checkPrankTrigger easter egg)`, `lib/frontend/screens/chats/chat_screen.dart:1366 (_enterSelection multi-select bulk actions)`, `lib/frontend/screens/chats/chat_screen.dart:3044 (_startCall call initiation/teardown)`, `lib/frontend/screens/chats/chat_screen.dart:3815 (_openSearch in-chat search overlay)`, `lib/frontend/screens/chats/chat_screen.dart:4860 (_startVoiceRecording voice/video-note state machines)`, `lib/frontend/screens/chats/chat_screen.dart:6107 (_openAttachmentSheet composer send logic)`


**Проблема:** Confirmed: one StatefulWidget State class (_ChatScreenState with TickerProviderStateMixin, WidgetsBindingObserver) owns 151 private methods (audit said '130+') spanning message-list rendering/pagination, DB persistence, text/voice/video-note/photo/video/file/sticker/poll/location composer logic, in-chat search, multi-select bulk actions, typing/read-receipt/presence tracking, call initiation, and an unrelated prank/easter-egg feature. All cited locations verified. This makes any single concern untestable in isolation and guarantees merge conflicts when two devs touch different chat features.


**Решение:** Split into lib/frontend/screens/chats/chat/ with: a ChatController (ChangeNotifier owning history/pagination/persistence + message-event/presence subscriptions), a ChatComposer widget+controller (text/voice/video-note/attachment sending), a ChatSearchOverlay, and a ChatSelectionBar. Move _checkPrankTrigger/_runPrankReveal into core/config/app_pranks.dart alongside the existing AppPranks config. ChatScreen becomes a thin composition. No comments; proper rewrite over hack per project conventions.

</details>

<details>
<summary><b>🔴 HIGH · СОМНИТ · [L]</b> — MessageBubble (3476 lines) renders every attachment type and two stateful media players in one widget</summary>


**Где:** `lib/frontend/widgets/message_bubble.dart:793 (_buildContent switch dispatch)`, `lib/frontend/widgets/message_bubble.dart:1214-2450 (per-attachment builders: photo/poll/share/file/call/location/video/sticker/contact + forwarded variants)`, `lib/frontend/widgets/message_bubble.dart:2814 (_VoiceMessageBubble stateful player embedded in same file)`, `lib/frontend/widgets/message_bubble.dart:3291 (_VideoNoteBubble stateful player embedded in same file)`, `lib/frontend/widgets/message_bubble.dart:716 (_openMiniApp WebView launcher embedded in bubble)`


**Проблема:** Confirmed, with one correction: the file is 3476 lines, not 2988 as the audit title claimed. One class contains ~12 distinct _build*Attachment/_build*Content methods (one per type, plus forwarded variants) plus two fully independent stateful player widgets (_VoiceMessageBubble at 2814, _VideoNoteBubble at 3291) and a mini-app WebView launcher (_openMiniApp at 716). Typed attachment models (PhotoAttachment, PollAttachment, ShareAttachment, LocationAttachment, VideoAttachment) already exist in models/attachment.dart, so there is no obstacle to per-type splitting.


**Решение:** Create lib/frontend/widgets/attachment/bubbles/ with one file per type (photo_bubble, file_bubble, call_bubble, location_bubble, contact_bubble, poll_bubble, share_bubble, voice_bubble, video_note_bubble), each taking the already-typed attachment model and _BubbleCtx. MessageBubble becomes a dispatcher keyed on AttachmentType, mirroring the existing attachment/ folder (photo_editor.dart, attachment_sheet.dart).

</details>

<details>
<summary><b>🔴 HIGH · СОМНИТ · [L]</b> — ChatsModule is a 1739-line all-static namespace mixing push dispatch, DB parsing, CRUD, and text formatting behind shared mutable static state</summary>


**Где:** `lib/backend/modules/chats.dart:249 (class ChatsModule — 74 static members, 0 instance methods)`, `lib/backend/modules/chats.dart:455 (static final ValueNotifier<int> chatsChanged — shared global mutable state; _bump at 456)`, `lib/backend/modules/chats.dart:460 (static Future _pushQueue serialized chain) and :462 (static Set _historyFetched)`, `lib/backend/modules/chats.dart:499-878 (_handleGlobalPush/_handlePresence/_handleNotifMessage/_handleNotifMsgDelete/_handleNotifMsgReactionsChanged/_handleNotifMark)`, `lib/backend/modules/chats.dart:974-1195 (cacheServerChat/_parseChat DB row parsing)`, `lib/backend/modules/chats.dart:1540 (togglePin) and CRUD/settings commands following`, `lib/backend/modules/chats.dart:257-347 (attachPreviewLabel/messagePreviewText pure text-formatting helpers)`, `lib/backend/modules/chats.dart:34 (CachedChat domain model defined inside the module file)`


**Проблема:** Confirmed, with correction: the file is 1739 lines, not 1490 as the audit title claimed. Every one of the ~74 members is static (grep found 0 instance methods in the class body), and cross-cutting mutable state (chatsChanged ValueNotifier at 455, serialized _pushQueue Future at 460, _historyFetched Set at 462) lives as static fields. This is a global singleton in disguise: it cannot be mocked/faked for testing screens that depend on it, and it conflates server-push handling, local DB caching/parsing, chat command RPCs, and pure preview-text formatting. Kept at high because the concern is genuine testability/global-state hazard, not merely file size.


**Решение:** Convert to an instantiable, injectable design: ChatRepository (DB caching/parsing: cacheServerChat/_parseChat/getChats), ChatPushHandler (the _handleNotif*/_handlePresence dispatch, subscribed once from api.dart), ChatCommands (pin/mute/delete/leave/photo/title RPCs), and a stateless ChatPreviewFormatter for attachPreviewLabel/messagePreviewText. Move chatsChanged onto a real per-repository ChangeNotifier instead of a static ValueNotifier.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [L]</b> — CLAUDE.md's documented 'state/' ChangeNotifier layer does not exist — state is ad hoc StreamSubscription + setState duplicated per screen</summary>


**Где:** `lib/main.dart:71 (global singleton `final api = Api();`, with accountModule/messagesModule singletons following, used directly by screens instead of DI)`, `lib/frontend/screens/chats/chat_screen.dart:532-542 (manual StreamSubscription wiring: _onIncomingPush, ChatsModule.messageEvents, api.stateStream, ChatActivityStore listenable)`, `lib/frontend/screens/chats/chat_list_screen.dart:553-645 (separate, independently-implemented subscriptions to the same push/message-event sources)`, `lib/backend/modules/chats.dart:358-361 (static StreamController<MessageEvent> broadcast used as de facto pub/sub bus)`, `lib/backend/modules/account.dart:450-459 (separate StreamController<LoginStatus> broadcast, a second ad hoc bus)`, `lib/frontend/widgets/message_actions_overlay.dart:18, lib/frontend/widgets/account_switcher_overlay.dart:12, lib/frontend/screens/chats/chat_list_screen.dart:2722, lib/backend/modules/polls.dart:7, lib/core/transport/traffic_monitor.dart:106 (the only 5 ChangeNotifier classes in the whole codebase, none under a state/ layer)`


**Проблема:** Confirmed. There is no lib/state/ directory despite CLAUDE.md documenting 'state/ — ChangeNotifier state classes consumed by the UI'. Only 5 ChangeNotifier classes exist and they are scattered (an overlay controller, an account switcher, a private _StoriesUi embedded in chat_list_screen.dart, the polls module, a traffic monitor) rather than forming a UI-facing layer. The real pattern is a global api singleton (main.dart:71) plus per-screen StreamSubscriptions to independent static StreamControllers (messageEvents in chats.dart:358, loginStatusStream in account.dart:450, raw push packets), each manually listened and setState-ed; chat_screen.dart and chat_list_screen.dart both independently subscribe to the same MessageEvent stream and reimplement similar reload logic.


**Решение:** Either (a) fix CLAUDE.md to describe the actual singleton+stream pattern, or (b) build the documented layer: wrap the module event streams in ChangeNotifier classes under lib/state/ (ChatListState, ChatState, AccountState) that screens obtain via a single InheritedNotifier/Provider at the app root, eliminating the duplicated StreamSubscription/dispose boilerplate.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [L]</b> — Core domain models (CachedMessage, CachedChat) live inside backend/modules instead of models/, and Map<String, dynamic> stands in for typed models across the codebase</summary>


**Где:** `lib/backend/modules/messages.dart:358 (CachedMessage — the actual message model; payload: Map<String, dynamic>? at line 366, editHistory: List<Map<String, dynamic>>? at line 370)`, `lib/backend/modules/chats.dart:34 (CachedChat — the actual chat model, defined in the module file, not in lib/models/)`, `lib/backend/modules/messages.dart (49 occurrences of Map<String, dynamic>; all 7 send*Message methods return raw Map<String, dynamic>? — see finding on send-method duplication)`, `lib/frontend/widgets/message_bubble.dart:807 (`message.payload?['reactionInfo']`) and 822-830 (raw Map indexing: info['counters'], info['yourReaction'], c['reaction'], c['count'])`


**Проблема:** Confirmed, with correction to the scale figures: Map<String, dynamic> appears ~304 times across ~38 files (audit claimed '303 occurrences across 63 files' — the file count is overstated). The substantive claim holds: lib/models/ contains only 5 files, yet the two most-used domain types — CachedMessage (messages.dart:358) and CachedChat (chats.dart:34) — are defined inside backend/modules, contradicting the layering CLAUDE.md documents. CachedMessage itself falls back to payload: Map<String, dynamic>? for reaction/control data, forcing message_bubble.dart to do untyped key-indexing (info['counters'], info['yourReaction']) with no compile-time safety.


**Решение:** Move CachedMessage/CachedChat (and sibling small types) into lib/models/message.dart and lib/models/chat.dart so models/ holds the domain types the modules operate on, per the documented layering. Introduce typed result classes (e.g. SendMessageResult) to replace the Map<String, dynamic>? returns from the send*Message family, and add a typed ReactionInfo class parsed once in CachedMessage to replace ad hoc payload?['reactionInfo'] indexing in message_bubble.dart.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [L]</b> — Monolithic ~7200-line State class couples unrelated setState calls to the message list</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:326`, `lib/frontend/screens/chats/chat_screen.dart:4356`, `lib/frontend/screens/chats/chat_screen.dart:4519-4522`


**Проблема:** `_ChatScreenState` is a single ~7200-line class (lines 326-7568) combining message rendering, search, selection, voice/video recording, sticker/attachment panels, wallpaper, forwarding and an easter egg under one `build()` (returns a `ListenableBuilder` at 4356). Its 24 raw `setState` calls (confirmed) rebuild that subtree, which recreates `_buildMessagesList`'s ValueListenableBuilder and the `ListView.builder`, re-invoking `itemBuilder` for every visible message even for changes unrelated to message content. The primary cost here is maintainability; the perf angle mostly overlaps finding #1 and only bites on the less-frequent setState paths (pagination flag, wallpaper load, metadata arrival).


**Решение:** Split the message list into its own widget so ancestor setState calls stop cascading into it (this also resolves finding #1's rebuild scope), and follow the ValueNotifier/ListenableBuilder pattern already used in this file (`_headerStatusNotifier`, `_scheduledCount`) for the remaining plain fields (`chat`, `_wallpaper`, `_isLoadingMore`, `_participantsCount`).

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [L]</b> — chat_list_screen.dart (2888 lines) fuses stories UI, folder paging, pinned header, chat tiles, and bottom nav into one screen</summary>


**Где:** `lib/frontend/screens/chats/chat_list_screen.dart:1006 (_onStoriesRevealTick reveal/close animation state machine)`, `lib/frontend/screens/chats/chat_list_screen.dart:2722 (_StoriesUi ChangeNotifier defined inline in the screen file)`, `lib/frontend/screens/chats/chat_list_screen.dart:843 (_syncFolderChatScrollControllers folder paging + per-folder scroll sync)`, `lib/frontend/screens/chats/chat_list_screen.dart:1209 (_buildPinnedChatsHeader)`, `lib/frontend/screens/chats/chat_list_screen.dart:1718 (_buildDockedBottomNav docked nav + FAB)`


**Проблема:** Confirmed. One 2888-line State class owns six largely independent subsystems (stories carousel with its own inline animation-driven _StoriesUi ChangeNotifier at 2722, folder tab paging with per-folder ScrollControllers, pinned-chats header, chat tile + swipe actions, account-switcher trigger, docked bottom nav/FAB), with 17 setState call sites. Each subsystem carries its own listeners/animation controllers/timers wired and disposed in one giant State, blocking partial reuse (e.g. reusing the chat tile in a forwarding picker). Severity lowered from high to medium: this is a size/organization split with no correctness or perf impact.


**Решение:** Extract StoriesBar (promote the inline _StoriesUi to lib/frontend/widgets/stories_bar.dart), FolderTabsView, PinnedChatsHeader, ChatListTile, and DockedBottomNav as standalone widgets under frontend/widgets/, each owning its own controller/animation lifecycle. ChatListScreen keeps only cross-cutting orchestration (selected folder, chat feed).

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [M]</b> — debug_menu_screen.dart has a single ~1300-line build() method stitching together a dozen unrelated debug tools</summary>


**Где:** `lib/frontend/screens/profile/debug_menu_screen.dart:251 (Widget build, runs unbroken to ~1576 where _SyncProbeCard class begins — ~1320 lines)`, `lib/frontend/screens/profile/debug_menu_screen.dart:1550 (_SearchResultCard used inside build)`, `lib/frontend/screens/profile/debug_menu_screen.dart:1566 (_SyncProbeCard used inside build)`, `lib/frontend/screens/profile/debug_menu_screen.dart:1577 (_SyncProbeCard model to follow for extraction)`


**Проблема:** Confirmed: a single build() spans line 251 through ~1576 (the first sibling class _SyncProbeCard starts at 1577), ~1320 lines, inlining roughly a dozen independent debug sections (FPS overlay, VPN/TLS bypass toggles, traffic monitor, WebView cache reset, stories/commands/link-preview feature flags, media cache management, call-screen preview, ID-search probe, sync probe) as nested widget trees. The lib/frontend/debug/ directory already exists (currently only fps_overlay_layer.dart), so there is an established home for extracted sections.


**Решение:** Break each toggle/section into a small widget under lib/frontend/debug/ (DebugNetworkSection, DebugCacheSection, DebugFeatureFlagsSection, DebugSearchProbeSection — the existing _SyncProbeCard/_SearchResultCard are the pattern to follow) and have build() lay out a ListView of these section widgets.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [L]</b> — AccountModule (1524 lines) bundles auth, profile, privacy, 2FA, and multi-session management into one class</summary>


**Где:** `lib/backend/modules/account.dart:448 (class AccountModule — instantiable, takes final Api _api)`, `lib/backend/modules/account.dart:465-628 (getPrivacyConfig/blocklist/profile-name/avatar/photo updates)`, `lib/backend/modules/account.dart:628-840 (create2faTrack..remove2fa — 13 two-factor methods)`, `lib/backend/modules/account.dart:876-1039 (requestCode/resendCode/verifyCode/completeRegistration/login)`, `lib/backend/modules/account.dart:1040-1153 (getSessions/terminateOtherSessions/beginAddAccount — session + multi-account)`


**Проблема:** Confirmed. One module answers for privacy/blocklist (465-628), profile editing (551-628), two-factor auth (628-840, 13 methods not 15 as claimed), auth/registration (876-1039), and session/multi-account management (1040+), with all request/response models (PrivacyConfig, BlockedContact, TwoFactorDetails, SessionInfo, LoginResult, VerifyCodeResult, etc.) declared at the top of the same file. It is instantiable (not static), so a facade split is clean. Severity set to medium: 1524 lines with already-clear domain groupings is a moderate maintainability concern, not high.


**Решение:** Split into backend/modules/account/ with auth_module.dart, profile_module.dart, privacy_module.dart, two_factor_module.dart, and sessions_module.dart, moving the corresponding model classes alongside each. Keep AccountModule as a thin facade if call sites need one entry point.

</details>


### Duplicated request/response and send-path boilerplate  (12 — 1 high)

_The core backend idioms — validate a packet, require a Map payload, send-with-not-ready-retry, extract a message id — are copy-pasted across dozens of methods and five media senders, and several copies have already drifted._

<details>
<summary><b>🔴 HIGH · ДУБЛЬ · [L]</b> — Raw HTTP upload/response machinery is reimplemented across five upload paths</summary>


**Где:** `lib/backend/modules/file_uploader.dart:71-155`, `lib/backend/modules/file_uploader.dart:163-221`, `lib/backend/modules/file_uploader.dart:259-310`, `lib/backend/modules/file_uploader.dart:312-377`, `lib/backend/modules/file_uploader.dart:386-506`


**Проблема:** upload(), uploadMediaFile(), uploadImage(), uploadPhoto() and uploadVideoFile()/_okCdnRequest() each hand-roll the same sequence: open a socket via _openSocket, build raw HTTP headers with a StringBuffer, stream the body, read the response, destroy the socket in try/catch, log/swallow errors. The chunk.map stopwatch-throttled progress pattern is byte-for-byte identical in three places (97-104, 189-196, 342-349), and there are three separate header builders (_writeHeaders, _writeImageHeaders, and the inline builder in _okCdnRequest at 477-489) duplicating Host/Content-Type/Content-Length/Connection boilerplate. Any protocol change (proxy handling, TLS pinning, header ordering, adding the missing User-Agent to _okCdnRequest) must be applied in up to five places and will drift.


**Решение:** Extract a single low-level helper _sendHttpRequest(uri, method, headers: Map<String,String>, body: Stream<List<int>> | Uint8List, {onProgress, timeout}) -> (int status, String body) that owns socket lifecycle (open/destroy/catch) and serializes headers from a map. Extract the progress-throttle map() into a reusable transformer withProgress(src, cb, throttle, total). Reimplement all five paths on these two primitives so header/socket logic lives in one place.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Five near-identical msgSend 'not.ready' retry loops duplicated across upload senders</summary>


**Где:** `lib/backend/modules/messages.dart:1199-1213`, `lib/backend/modules/messages.dart:1249-1268`, `lib/backend/modules/messages.dart:1326-1345`, `lib/backend/modules/messages.dart:1416-1435`, `lib/backend/modules/messages.dart:1499-1518`


**Проблема:** sendFileMessage, sendPhotoMessage, sendVideoMessage, sendAudioMessage and sendVideoNoteMessage each hand-roll the identical for-loop: sendRequest(Opcode.msgSend, payload), catch PacketError, rethrow (with a logger.w) unless errorKey contains 'not.ready', await retryDelay, give up after maxAttempts. Any change (backoff, extra error keys, cancellation) must be applied five times and will drift. sendFileMessage already diverges: it returns bool (true/false) and skips the data['message'] extraction the other four share.


**Решение:** Extract a private helper Future<Map<String,dynamic>?> _sendMsgWithRetry(Map payload, {int maxAttempts, Duration retryDelay}) owning the loop, PacketError handling/logging and the data['message'] extraction; the four Map-returning senders call it directly, and sendFileMessage adapts (non-null => true).

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — 'check packet error then require Map payload' idiom copy-pasted across ~15 request methods</summary>


**Где:** `lib/backend/modules/account.dart:474-494`, `lib/backend/modules/account.dart:496-521`, `lib/backend/modules/account.dart:628-643`, `lib/backend/modules/account.dart:669-701`, `lib/backend/modules/account.dart:723-759`, `lib/backend/modules/account.dart:876-920`, `lib/backend/modules/account.dart:1153-1201`, `lib/backend/modules/account.dart:1462-1503`


**Проблема:** Nearly every request method in AccountModule repeats the same idiom: call _checkPacketError(packet, tag), then `final data = packet.payload; if (data is! Map) throw Exception('<method>: неожиданный тип payload: ${data.runtimeType}')`, then cast. It recurs in getBlockedContacts, updatePrivacyConfig, create2faTrack, enter2faPanel, get2faDetails, verify2faEmail, verify2faCode, verifyCode, completeRegistration, login, checkPassword, _requestCodeInternal, etc. Besides the boilerplate, the 'not a Map' path throws an untyped generic Exception while other errors in the same file throw the typed PacketError, so callers cannot catch payload-shape failures consistently.


**Решение:** Extract one private helper, e.g. `Map<dynamic, dynamic> _requireMapPayload(Packet packet, String method) { _checkPacketError(packet, method); final data = packet.payload; if (data is! Map) throw PacketError('$method: unexpected payload type ${data.runtimeType}'); return data.cast<dynamic, dynamic>(); }`, and have each method call `final data = _requireMapPayload(packet, 'methodName');`. Removes the duplicated boilerplate and gives all payload-shape failures the same typed PacketError callers already handle.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — updateProfileName / updateProfileAvatar / removeProfilePhoto duplicate the entire response-parse-and-persist body</summary>


**Где:** `lib/backend/modules/account.dart:551-570`, `lib/backend/modules/account.dart:572-590`, `lib/backend/modules/account.dart:608-625`


**Проблема:** After their differing request, all three methods run an identical body: check packet.isError, cast payload to Map, drill 'profile' -> 'contact', build ProfileData.fromServerMap(contact), call AppDatabase.saveProfile(newProfile, isActive: true), and return newProfile. Only the outgoing sendRequest differs.


**Решение:** Factor out `Future<ProfileData> _applyProfileResponse(Packet packet)` that performs the shared error-check/extract/persist/return sequence, and have the three methods await their own request then `return _applyProfileResponse(packet);`. (This is also the same profile->contact extraction done in _processProfileUpdate and _processLoginResponse, so the helper can be reused there.)

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — The "sendRequest -> validate isOk/Map -> extract or bail" guard is copy-pasted across ~50 module methods with no shared helper</summary>


**Где:** `lib/backend/modules/calls.dart:90-93`, `lib/backend/modules/calls.dart:132-134`, `lib/backend/modules/calls.dart:155-158`, `lib/backend/modules/calls.dart:199-201`, `lib/backend/modules/stickers.dart:54-55`, `lib/backend/modules/stickers.dart:75-76`, `lib/backend/modules/stickers.dart:99-101`, `lib/backend/modules/stickers.dart:127-128`, `lib/backend/modules/stickers.dart:146-147`, `lib/backend/modules/stickers.dart:171-172`, `lib/backend/modules/messages.dart:987-993`, `lib/backend/modules/account.dart:481-488`, `lib/backend/modules/account.dart:503-511`


**Проблема:** Nearly every module method that talks to the server repeats the same skeleton: send a request, then guard with some equivalent of `if (!response.isOk || response.payload is! Map) return <null/[]/false/const {}>;` before casting `response.payload as Map` and pulling a field. The guard is written several ways (`!response.isOk`, `!response.isOk || response.payload is! Map`, `response.isOk && response.payload is Map`), so the same intent is spelled differently in every file. Note: this is a maintainability/readability issue only, not a correctness bug — the `!isOk`-only variants re-check `is Map` on the following lines, so behaviour is consistent; the original finding's claim that a bug 'already happened' from a drifted variant is not supported by the code.


**Решение:** Add a thin helper next to `sendRequest` in api.dart (around line 316): `Future<Map<dynamic, dynamic>?> sendRequestMap(int opcode, Map<dynamic, dynamic> payload) async { final r = await sendRequest(opcode, payload); return (r.isOk && r.payload is Map) ? r.payload as Map<dynamic, dynamic> : null; }`. Each call site collapses to `final data = await _api.sendRequestMap(Opcode.X, payload); if (data == null) return ...;`. Works for both the instance-`_api` modules and the static `Api api` modules (chats/folders). Keep the follow-on field extraction at each site — only the guard is shared.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Packet error-check (_checkPacketError) is reimplemented per-module and the folders.dart copy drops the SessionExpiredException case</summary>


**Где:** `lib/backend/api.dart:386-393`, `lib/backend/modules/account.dart:1513-1523`, `lib/backend/modules/account.dart:481-487`, `lib/backend/modules/account.dart:504-510`, `lib/backend/modules/folders.dart:199-201`, `lib/backend/modules/folders.dart:241-243`


**Проблема:** account.dart defines `_checkPacketError(Packet, String method)` (1513-1523) that maps FAIL_LOGIN_TOKEN/FAIL_WRONG_PASSWORD to SessionExpiredException and otherwise throws PacketError; it is called ~21 times, with many sites (e.g. 481-487, 504-510) also repeating the identical `if (data is! Map) throw Exception('$method: неожиданный тип payload: ...')` block verbatim. folders.dart independently reimplements a weaker check (199-201, 241-243: `if (packet.isError) throw PacketError(...)`) that omits the SessionExpiredException special-case. Correction to the original claim: the practical impact is smaller than stated — the transport layer at api.dart:386-393 already pushes SessionExpiredException into `_sessionExpiredController` for ANY module when the server returns those codes, so global session-expiry handling still fires for folders. The only real divergence is the exception *type* thrown to the immediate caller (PacketError vs SessionExpiredException). The value here is deduplication and consistency, not fixing a broken session flow.


**Решение:** Move the check onto Api as `Future<Map<dynamic, dynamic>> sendRequestOrThrow(int opcode, Map payload, String method)` that runs sendRequest, applies the FAIL_LOGIN_TOKEN/FAIL_WRONG_PASSWORD -> SessionExpiredException / else PacketError logic, then asserts the payload is a Map (throwing the `неожиданный тип payload` Exception otherwise) and returns it. Delete account.dart's `_checkPacketError` plus the repeated is-Map blocks and folders.dart's two inline copies, and route all three through the shared method so folders gains the same thrown-exception behaviour.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — updateProfileName / updateProfileAvatar / removeProfilePhoto share an identical response-unwrap-and-persist tail</summary>


**Где:** `lib/backend/modules/account.dart:551-570`, `lib/backend/modules/account.dart:572-590`, `lib/backend/modules/account.dart:608-625`


**Проблема:** All three methods send an Opcode.profile-family request with different payloads, then run a byte-for-byte identical tail: throw on `packet.isError`, cast `payload as Map?` (throw if null), pull `data['profile'] as Map?` (throw if null), pull `profile['contact'] as Map?` (throw if null), build `ProfileData.fromServerMap(contact.cast())`, `AppDatabase.saveProfile(newProfile, isActive: true)`, and return it. Any change to profile-response parsing must be made in three places. (The nearby `getAvatarUploadUrl` at 592-606 is correctly NOT part of this — it returns a url, not a ProfileData.)


**Решение:** Extract a private `Future<ProfileData> _applyProfileResponse(Packet packet)` that performs the shared throw/unwrap/save/return, then have all three methods `return _applyProfileResponse(await _api.sendRequest(Opcode.X, payload));`. No comments, matches existing style.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — sendMessage and forwardMessage duplicate the send-error + message-id-extraction block verbatim</summary>


**Где:** `lib/backend/modules/messages.dart:798-815`, `lib/backend/modules/messages.dart:847-864`


**Проблема:** Both methods send via Opcode.msgSend and then run the same block: if `!response.isOk`, pull `localizedMessage`/`message` from the error payload (falling back to a hardcoded default) and throw; otherwise dig into `response.payload['message']['id']` and return it as a String, or `''` if absent. The only difference between the two copies is the fallback string ('Ошибка отправки' vs 'Ошибка пересылки').


**Решение:** Factor out `Future<String> _sendAndExtractMessageId(Map payload, String defaultError)` on the messages module that sends Opcode.msgSend, throws the localized error on failure, and returns the extracted id (or ''). Call it from both sendMessage and forwardMessage with their payload and default-error text.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Identical 'attachment.not.ready' retry-with-delay loop copy-pasted across 5 send*Message methods</summary>


**Где:** `lib/backend/modules/messages.dart:1199`, `lib/backend/modules/messages.dart:1249`, `lib/backend/modules/messages.dart:1326`, `lib/backend/modules/messages.dart:1416`, `lib/backend/modules/messages.dart:1499`


**Проблема:** sendFileMessage (1199), sendPhotoMessage (1249), sendVideoMessage (1326), sendAudioMessage (1416) and sendVideoNoteMessage (1499) each contain their own copy of the `for (var attempt = 0; attempt < maxAttempts; attempt++) { try { ...sendRequest(Opcode.msgSend, payload)... } on PacketError catch (e) { if (!(e.errorKey?.contains('not.ready') ?? false)) { logger.w(...); rethrow; } if (attempt == maxAttempts - 1) return null/false; await Future.delayed(retryDelay); } }` block. Only the onOk mapping (bool vs extracting data['message'] into Map) and return type differ. Any change to the retry/backoff policy must be made in 5 places, and it has already drifted: initialDelay + a leading `await Future.delayed(initialDelay)` exists only on sendFileMessage.


**Решение:** Extract a private generic helper e.g. `Future<T?> _sendWithNotReadyRetry<T>({required Map payload, required int maxAttempts, required Duration retryDelay, Duration? initialDelay, required T? Function(SendResponse) onOk})` in messages.dart and have all 5 send*Message methods build their payload and delegate the retry loop to it. This also lets initialDelay be applied uniformly instead of ad-hoc.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Every per-media-type send method in MessagesModule duplicates the same construct-payload + retry-on-not-ready loop</summary>


**Где:** `lib/backend/modules/messages.dart:1224 (sendPhotoMessage)`, `lib/backend/modules/messages.dart:1299 (sendVideoMessage)`, `lib/backend/modules/messages.dart:1384 (sendAudioMessage)`, `lib/backend/modules/messages.dart:1471 (sendVideoNoteMessage)`, `lib/backend/modules/messages.dart:1521 (sendLocationMessage)`, `lib/backend/modules/messages.dart:1554 (sendPollMessage)`, `lib/backend/modules/messages.dart:1602 (sendStickerMessage)`


**Проблема:** Confirmed by direct diff. sendPhotoMessage (1249-1268) and sendAudioMessage (1416-1435) contain byte-for-byte identical retry loops (for attempt in 0..maxAttempts { sendRequest(Opcode.msgSend, payload); on PacketError catch e { if !errorKey.contains('not.ready') { logger.w; rethrow } else if last attempt return null else delay } }), plus identical response-unwrap blocks. The same pattern repeats across all 7 send*Message methods (all return Map<String, dynamic>?), differing only in the type-specific 'attaches'/extra message fields. Each copy is an independent bug target (e.g. one method omitting the not.ready check would silently diverge under server backpressure).


**Решение:** Extract one private helper Future<Map<String, dynamic>?> _sendAttachedMessage(int chatId, List<Map<String,dynamic>> attaches, {String? caption, bool notify, int? scheduledTime, int maxAttempts, Duration retryDelay, Map<String,dynamic>? extraMessageFields}) that owns payload construction, the retry loop, and response unwrap. All 7 public methods build only their type-specific attaches/extra fields and delegate.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — Server error-message extraction duplicated verbatim in sendMessage and forwardMessage as untyped Map access + bare Exception</summary>


**Где:** `lib/backend/modules/messages.dart:799-806`, `lib/backend/modules/messages.dart:848-855`


**Проблема:** Both methods repeat the identical (response.payload is Map) ? (response.payload['localizedMessage'] ?? response.payload['message'] ?? 'Ошибка ...') : 'Ошибка ...' pattern and throw a bare Exception(String), so the UI can only string-match to distinguish error kinds.


**Решение:** Extract String _extractErrorMessage(PacketResponse, String fallback) and throw a small typed exception (e.g. MessageSendException) so callers can catch it specifically.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Trivial 'fire request, return isOk' one-liners repeated across modules</summary>


**Где:** `lib/backend/modules/calls.dart:233-236`, `lib/backend/modules/messages.dart:963`, `lib/backend/modules/messages.dart:1035`, `lib/backend/modules/messages.dart:1062`, `lib/backend/modules/messages.dart:1085`, `lib/backend/modules/chats.dart:1503`, `lib/backend/modules/chats.dart:1515`


**Проблема:** Seven toggle-style methods do nothing but `final response = await _api.sendRequest(Opcode.X, payload); return response.isOk;` (delete history, edit message, edit scheduled message, delete messages, set chat photo, set chat options). Minor, but it is one more request/response shape inconsistent with the Map-returning variants nearby.


**Решение:** Add `Future<bool> sendRequestOk(int opcode, Map<dynamic, dynamic> payload) async => (await sendRequest(opcode, payload)).isOk;` to Api and have these sites return it directly. Low priority — bundle with the sendRequestMap helper from finding 1 since it is the same class of change.

</details>


### Duplicated formatting and shared-utility gaps  (18 — 0 high)

_Time, date, phone, plural, zero-pad, filename-timestamp and UUID helpers are re-implemented across many files instead of living once in core/utils, and the private helpers that do exist are not exposed._

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — _uuidV4 reimplemented three times, with calls.dart using a non-secure RNG</summary>


**Где:** `lib/backend/modules/calls.dart:182-191`, `lib/core/storage/device_identity.dart:41-48`, `lib/core/storage/spoofing_service.dart:252-259`


**Проблема:** The same UUID v4 algorithm is copy-pasted in three places. device_identity.dart:42 and spoofing_service.dart:253 both seed from a shared Random.secure() (_rng), but calls.dart:183 uses a plain, non-cryptographic Random() to build the call conversationId sent to the server. The RNG inconsistency exists only because the logic was duplicated instead of shared. (Security impact of a guessable conversationId is minor since calls are server-authenticated, but the DRY violation and the divergent RNG are both real.)


**Решение:** Extract a single Uuid.v4() utility backed by Random.secure() (e.g. lib/core/utils/uuid.dart) and have device_identity.dart, spoofing_service.dart, and calls.dart all call it.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — Local _formatLastSeen omits the 'Был(-а)' verb, producing a bare 'N мин назад' on member tiles while every other last-seen surface prefixes it</summary>


**Где:** `lib/frontend/screens/chats/chat_info_screen.dart:1157-1165`, `lib/frontend/screens/chats/chat_info_screen.dart:307`, `lib/frontend/screens/chats/chat_info_screen.dart:818`, `lib/frontend/screens/chats/chat_info_screen.dart:1167-1174`, `lib/core/utils/format.dart:63-71`


**Проблема:** core/utils/format.dart already exports formatLastSeen(int) returning a fully-formed 'Был(-а) ...' string (reused by contact_profile_screen.dart / chat_screen.dart). chat_info_screen.dart instead defines a private _formatLastSeen with different thresholds and no leading verb, then manually prepends 'был(-а) ' at the dialog subtitle (line 307) but NOT at the member-tile call site (line 818: `sublabel = _formatLastSeen(member.seenTime!)`), so group members display a bare 'N мин назад' with no verb, inconsistent with the rest of the app. Separately, _pluralCount (lines 1167-1174) reimplements Russian plural-form selection that already exists as functional variants in call_screen.dart:719-726, sticker_pack_sheet.dart:337, and poll_view.dart:375.


**Решение:** Delete _formatLastSeen and call the shared formatLastSeen from core/utils/format.dart, removing the manual 'был(-а) ' prefix at line 307 (which fixes the missing-verb bug at line 818 for free). Extract the Russian plural logic into one shared helper (e.g. String pluralRu(int n, String one, String few, String many) in core/utils/format.dart) and route this file plus call_screen, sticker_pack_sheet, and poll_view through it.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — Duplicated dynamic-to-int parsing with an inconsistent '?? 0' fallback that fabricates a fake id</summary>


**Где:** `lib/models/attachment.dart:361`, `lib/models/attachment.dart:451`, `lib/models/attachment.dart:452`, `lib/models/attachment.dart:480`, `lib/models/attachment.dart:525-528`, `lib/models/attachment.dart:613-615`


**Проблема:** The idiom `v is int ? v : int.tryParse(v?.toString() ?? '')` is reimplemented five times (ContactAttachment.contactId:361, ControlAttachment.userIds:451 / userId:452, PollAttachment.pollId:480, CallAttachment.contactIds:525-528, InlineKeyboardButton.contactId:613-615) with three different fallbacks (null, 0, dropped). Two of them — ControlAttachment.userIds (451) and CallAttachment.contactIds (525-528) — use `... ?? 0` inside a list map, so an unparseable element is turned into a fabricated id `0` rather than dropped. Downstream code resolving those ids to contacts/names cannot tell a real id 0 from a parse failure, so a malformed server payload can silently attribute a control/call event to the wrong (or a nonexistent) contact. Impact is limited to malformed payloads, but the fabricated-id semantics is a genuine latent correctness issue, and the duplication is how the inconsistency arose.


**Решение:** Extract two top-level helpers, `int? parseIntOrNull(dynamic v)` and `List<int> parseIntList(dynamic v)` (the list helper using `int.tryParse` + `whereType<int>()` to drop invalid entries rather than coalescing to 0), and have every factory in the file call them. This removes the five copies and, critically, changes userIds/contactIds to drop unparseable entries instead of inserting a fake id 0.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — "Last seen" relative-time text re-derived from scratch instead of calling shared formatLastSeen</summary>


**Где:** `lib/frontend/screens/chats/chat_info_screen.dart:1157-1165`, `lib/frontend/screens/chats/chat_info_screen.dart:307`, `lib/frontend/screens/chats/chat_info_screen.dart:818`, `lib/core/utils/format.dart:62-71`


**Проблема:** chat_info_screen.dart defines its own `String _formatLastSeen(int secondsSinceEpoch)` (lines 1157-1165) that recomputes the same just-now / minutes / hours / days buckets that `formatLastSeen()` in core/utils/format.dart:63-71 already implements — while chat_screen.dart:3147 and contact_profile_screen.dart:102 both correctly call the shared version. The local copy has genuinely diverged: it uses raw millisecond thresholds (60000/3600000/...) instead of Duration fields, its cutoffs differ (shared uses `inMinutes < 2` = 120s for 'только что', local uses `< 60000` = 60s), and after 7 days it falls back to the literal string 'давно' whereas the shared function returns a full date ('5 мая 2024'). Result: the chat-info panel and member list show different last-seen wording/date behavior than the chat header and contact profile, and threshold tweaks must be made twice.


**Решение:** Delete the local `_formatLastSeen` and call the shared `formatLastSeen(secondsSinceEpoch)` from core/utils/format.dart. Note the shared function already returns a capitalized 'Был(-а) ...' prefix, so at line 818 use its return directly, and at line 307 remove the existing lowercase 'был(-а) ' prefix (currently `return 'был(-а) ${_formatLastSeen(_seenTime!)}';`) to avoid a doubled 'был(-а) Был(-а)'. This matches the call pattern in chat_screen.dart:3147 and contact_profile_screen.dart:102.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — mm:ss duration formatting hand-rolled in video player and voice-message recorder instead of reusing formatSecondsMmSs/formatDurationMmSs</summary>


**Где:** `lib/frontend/widgets/video_player_screen.dart:101-111`, `lib/frontend/screens/chats/chat_screen.dart:5407-5413`, `lib/frontend/screens/chats/chat_screen.dart:5372`, `lib/frontend/screens/chats/chat_screen.dart:5535`, `lib/core/utils/format.dart:30-39`


**Проблема:** core/utils/format.dart already provides `formatDurationMmSs`/`formatSecondsMmSs`, correctly reused in message_bubble.dart (lines 1885, 2132, 3079). But video_player_screen.dart's static `_fmt(Duration d)` recomputes seconds/minutes with manual `~/`, `%`, and `padLeft(2,'0')` (adding an hour branch the shared helper lacks), and chat_screen.dart's `_formatVoiceElapsed(int ms)` (used at lines 5372 and 5535 for the recording timer) does the same manual mm:ss computation plus an extra decisecond digit. Both re-derive the core padding/division logic that already lives in the shared util rather than composing it.


**Решение:** Extend the shared util with an hour-aware variant (e.g. `formatDurationHms`) and a decisecond variant (e.g. `formatVoiceElapsed(int ms)`), composed from the existing `formatDurationMmSs`/`_two` helpers, and have video_player_screen.dart:101-111 and chat_screen.dart:5407-5413 call those instead of reimplementing the arithmetic.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — Hand-rolled cancel-and-restart debounce timer duplicated across 5 files with no shared Debouncer utility</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:421`, `lib/frontend/screens/chats/chat_screen.dart:3847`, `lib/frontend/screens/chats/search_screen.dart:25`, `lib/frontend/screens/chats/search_screen.dart:74`, `lib/frontend/screens/profile/appearance_screen.dart:33`, `lib/frontend/screens/profile/appearance_screen.dart:58`, `lib/frontend/screens/chats/chat_list_screen.dart:799`, `lib/backend/modules/messages.dart:79`


**Проблема:** The same `Timer? _x; _x?.cancel(); _x = Timer(duration, callback);` debounce idiom is independently reimplemented in at least 5 places: chat_screen search debounce (field 421, timer 3847), search_screen search debounce (field 25, cancel 57, timer 74), appearance_screen accent-persist debounce (field 33, cancel 57, timer 58), chat_list_screen `_scheduleContactRebuild` (799-804), and messages.dart NameCache `_scheduleSave` (79-81). There is no Debouncer/Throttler helper anywhere in lib/core/utils/ (verified: the directory has 14 util files, none of them a debouncer), so every feature that needs debouncing re-derives the pattern and each site has to independently remember to cancel the pending timer in dispose (they currently do, but nothing enforces it).


**Решение:** Add a small `lib/core/utils/debouncer.dart` with a `Debouncer` class (`Debouncer(duration).run(callback)` + `dispose()` that cancels the pending timer). Replace the ad-hoc Timer fields in chat_screen.dart, search_screen.dart, appearance_screen.dart, chat_list_screen.dart, and messages.dart with it. Keep it comment-free per the codebase convention.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — Dead pluralization branches in info_screen week/day formatters</summary>


**Где:** `lib/frontend/screens/profile/info_screen.dart:283-295`


**Проблема:** `_w(int n)` and `_d(int n)` each have three branches based on Russian declension rules, but every branch returns the exact same literal ('нед' / 'дн'). The conditional logic is entirely inert dead code — an abandoned attempt at full-word declension that misleads maintainers into thinking the form varies.


**Решение:** If the abbreviation is intentionally invariant, delete the branching and return the constant. If real declension was intended, implement the three forms (неделя/недели/недель, день/дня/дней) and return them per branch.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — Shared 2-digit zero-pad helper is library-private, forcing every caller to re-pad by hand</summary>


**Где:** `lib/core/utils/format.dart:19`, `lib/frontend/widgets/schedule_time_picker.dart:17`, `lib/frontend/screens/profile/traffic_monitor_screen.dart:83`, `lib/frontend/screens/profile/traffic_monitor_screen.dart:479`, `lib/frontend/screens/profile/debug_menu_screen.dart:111`, `lib/frontend/screens/profile/info_screen.dart:279-280`, `lib/core/config/app_theme_schedule.dart:59-60`


**Проблема:** `String _two(int n) => n.toString().padLeft(2, '0')` in format.dart:19 is underscore-private, so it can't be imported. schedule_time_picker.dart imports format.dart (line 4) yet still redeclares its own top-level `_two` (line 17). traffic_monitor_screen.dart (lines 83, 479) and debug_menu_screen.dart (line 111) redeclare a local `two()` closure, while info_screen.dart:279-280 and app_theme_schedule.dart:59-60 inline `.padLeft(2,'0')` repeatedly — all because the one canonical padder isn't exposed. (Note: the original finding overstated this as all files redeclaring a `two` closure; two of them use inline padLeft rather than a closure, but the root cause is the same.)


**Решение:** Rename `_two` to a public `pad2` in core/utils/format.dart and update these call sites to import and use it, removing the local closures and inline padLeft. This also makes the format.dart-based fixes for the other duplication findings cheaper.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Dynamic-to-int coercion reimplemented in four places with divergent edge cases</summary>


**Где:** `lib/core/calls/call_controller.dart:142-147`, `lib/core/calls/call_session.dart:290-305`, `lib/core/calls/call_session.dart:414-420`, `lib/core/nfc/nfc_exchange_service.dart:63-66`


**Проблема:** CallController._asInt (int/num/String), CallSession._participantIdFrom (adds u/g/d composite-id prefix stripping), CallSession._externalId (map['id'] then int/String), and the inline parse in NfcExchangeService._decodeEvent (int/num only, no String) each reimplement 'coerce a dynamic JSON/platform-channel value to int', with subtly different coverage — e.g. the NFC inline version and _externalId omit cases the others handle. Being private, none can reuse another, so any fix must be applied in up to four spots.


**Решение:** Extract a single int? intFrom(Object? value) utility in lib/core/utils/, plus a thin wrapper for the u123/g456 composite participant-id format, and have all four call sites delegate to them.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — UUID/hex id generation duplicated verbatim between DeviceIdentity and SpoofingService</summary>


**Где:** `lib/core/storage/device_identity.dart:9`, `lib/core/storage/device_identity.dart:33-48`, `lib/core/storage/spoofing_service.dart:35`, `lib/core/storage/spoofing_service.dart:244-259`


**Проблема:** `_hex(int bytes)` and `_uuidV4()`, plus a private `static final Random _rng = Random.secure()`, are implemented identically byte-for-byte in both DeviceIdentity and SpoofingService.


**Решение:** Extract both helpers and the shared Random.secure() into one `lib/core/utils/random_id.dart` exposing `randomHex(int bytes)` / `randomUuidV4()`, and have both classes call it.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [M]</b> — Contact display-name concatenation duplicated across search_screen and create_group_flow with inconsistent empty-name fallback</summary>


**Где:** `lib/frontend/screens/chats/search_screen.dart:127-132`, `lib/frontend/screens/chats/create_group_flow.dart:180-183`


**Проблема:** Both files independently build a 'first last'.trim() display name from raw contact fields: search_screen._contactName falls back to '+phone' when the combined name is empty, while create_group_flow._displayName has no fallback. The two operate on different shapes (a SQLite Map row vs. a CachedContact), so the concatenation-plus-fallback rule is reimplemented rather than shared.


**Решение:** Add a single helper such as displayName(String first, String? last, {String? fallback}) in core/utils and route both call sites (and, over time, other reimplementations in the codebase) through it so fallback behavior is consistent.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Russian pluralization logic hand-rolled twice instead of using the l10n pipeline</summary>


**Где:** `lib/frontend/widgets/sticker_pack_sheet.dart:337`, `lib/frontend/widgets/poll_view.dart:373`


**Проблема:** _pluralStickers (sticker_pack_sheet.dart:337) and _votesLabel (poll_view.dart:373) each independently reimplement the Russian mod10/mod100 plural algorithm. Both implementations are actually correct — they only differ in how they order the branches — so there is no live bug, but the algorithm and the Russian words are duplicated and hardcoded in widget code instead of going through lib/l10n, which already exists and supports ICU plurals. Any future change must be made in two places.


**Решение:** Move these strings into app_ru.arb/app_en.arb using ICU plural syntax (supported by flutter gen-l10n), or at minimum extract one shared `String pluralizeRu(int n, {required String one, required String few, required String many})` utility used by both call sites.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Identical _fileStamp helper copy-pasted across two screens</summary>


**Где:** `lib/frontend/screens/profile/debug_menu_screen.dart:110-114`, `lib/frontend/screens/profile/traffic_monitor_screen.dart:82-86`


**Проблема:** Both files define a byte-for-byte identical private String _fileStamp(DateTime t) that builds a yyyyMMdd_HHmmss filename suffix for exported logs/captures. Confirmed identical.


**Решение:** Move it to core/utils/format.dart (which exists) as a shared formatFileTimestamp(DateTime t) and delete both local copies.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Smart relative-date formatting reimplemented independently in two screens</summary>


**Где:** `lib/frontend/screens/profile/settings_tab.dart:635-646`, `lib/frontend/screens/profile/devices_screen.dart:198-214`


**Проблема:** `_formatSelfSeen` (settings_tab) and `_formatTime` (devices_screen) both implement the same today/same-year/else branching over the shared formatClock/kRuMonthsShort/formatDateNumeric primitives, but the branching is copy-pasted rather than shared and the two have already diverged in output (one appends the clock time and builds the year via a manual ternary, the other calls formatDateNumeric and omits the time).


**Решение:** Add one shared helper to core/utils/format.dart, e.g. `String formatSmartDate(DateTime dt, {bool withTime = false})`, encapsulating the today/same-year/else logic, and have both screens call it.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Duplicated hand-rolled debounce for VPN-bypass and server-error notifications</summary>


**Где:** `lib/main.dart:361-380`, `lib/main.dart:382-395`


**Проблема:** The _vpnBypassSub (361-380) and _serverErrorSub (382-395) listeners each independently implement the same 'skip if identical to the last shown message within N seconds' debounce against their own _lastX/_lastXAt pair, differing only in the stored fields and a magic-number window (10s vs 3s).


**Решение:** Extract a small reusable debouncer (e.g. a _MessageDebouncer holding lastMessage/lastShownAt with a `shouldShow(message, window)` method) and use one instance per notification source instead of duplicating the comparison. Keep using showCustomNotificationOnOverlay for display.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Compact file-timestamp (yyyyMMdd_HHmmss) generator duplicated byte-for-byte in two screens</summary>


**Где:** `lib/frontend/screens/profile/debug_menu_screen.dart:110-114`, `lib/frontend/screens/profile/traffic_monitor_screen.dart:82-86`


**Проблема:** Both files define a verbatim-identical private `String _fileStamp(DateTime t)` with the same inner `two(int n) => n.toString().padLeft(2, '0')` closure, producing `${year}${MM}${dd}_${HH}${mm}${ss}` for export filenames. Same variable names, same structure — a straight copy. Any change to the export filename convention must be applied in both places.


**Решение:** Add a public `String formatFileStamp(DateTime t)` to lib/core/utils/format.dart (built on the module's existing `_two` padding helper) and have both screens call it instead of their local copies.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — "HH:mm:ss.mmm" clock-with-milliseconds formatting duplicated in logger and traffic monitor</summary>


**Где:** `lib/core/utils/logger.dart:116-117`, `lib/frontend/screens/profile/traffic_monitor_screen.dart:478-482`


**Проблема:** logger.dart builds `HH:mm:ss.mmm` inline via chained `.padLeft(2,'0')`/`.padLeft(3,'0')` calls, and traffic_monitor_screen.dart's `_formatTime` builds the same HH:mm:ss.mmm shape with its own local `two()` closure plus a manual millisecond pad. The shared `formatClock()` in format.dart supports an HH:mm / HH:mm:ss toggle but has no millisecond option, so both call sites drop back to raw padLeft arithmetic instead of using the shared formatter.


**Решение:** Extend `formatClock()` in format.dart with a `withMillis` flag (or add a small `formatClockMs(DateTime)` built on top of it and the existing `_two`), and switch both logger.dart:116-117 and traffic_monitor_screen.dart:478-482 to it.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — formatPhone compiles a fresh RegExp on every call</summary>


**Где:** `lib/core/utils/format.dart:80`


**Проблема:** `formatPhone` (called per contact/message-header/profile row that renders a phone) does `raw.replaceAll(RegExp(r'[^0-9]'), '')`, constructing and compiling a new RegExp each invocation. This is inconsistent with the codebase's own convention — max_link.dart hoists its patterns to `static final RegExp`. A contacts/chat list with hundreds of entries recompiles the same trivial pattern many times per rebuild. Minor but free to fix.


**Решение:** Hoist to a top-level `final RegExp _nonDigits = RegExp(r'[^0-9]');` and reuse it in formatPhone.

</details>


### Untyped Map wire data reaching the UI  (11 — 2 high)

_Protocol payloads flow into widgets as raw Map<String,dynamic>, so screens hand-parse the same shapes with divergent rules and no compile-time safety, violating the UI -> module -> transport layering._

<details>
<summary><b>🔴 HIGH · КОСТЫЛЬ · [M]</b> — Typed attachment models bypassed with `as dynamic` casts</summary>


**Где:** `lib/frontend/widgets/message_bubble.dart:2063`, `lib/frontend/widgets/message_bubble.dart:2064`, `lib/frontend/widgets/message_bubble.dart:2071`, `lib/frontend/widgets/message_bubble.dart:2072`, `lib/frontend/widgets/message_bubble.dart:2187`, `lib/frontend/widgets/message_bubble.dart:2188`, `lib/frontend/widgets/message_bubble.dart:2220`, `lib/frontend/widgets/message_bubble.dart:2221`, `lib/frontend/widgets/message_bubble.dart:2223`, `lib/frontend/widgets/message_bubble.dart:2655`


**Проблема:** `_buildVideoAttachment`, `_playVideo`, `_buildFileAttachment` and `_downloadFile` take a generic `MessageAttachment` and reach into it via `(video as dynamic).thumbnail/.duration/.width/.height/.videoId/.videoToken` and `(file as dynamic).name/.size/.fileId`, even though `VideoAttachment` (models/attachment.dart:122) and `FileAttachment` (models/attachment.dart:236) already declare every one of these fields with proper static types. The concrete type is already known at the dispatch point, and `_buildVideoAttachment` even does `video is VideoAttachment` at line 2047 before falling back to `as dynamic`. The dynamic casts buy nothing except erasing compile-time safety: a future field rename becomes a runtime NoSuchMethodError instead of a compile error, and IDE refactoring can't track the usages. This directly violates the project's 'proper rewrite over hack' convention.


**Решение:** Change the signatures to the concrete types (`_buildVideoAttachment(_BubbleCtx ctx, VideoAttachment video)`, `_buildFileAttachment(_BubbleCtx ctx, FileAttachment file, {bool fill})`, and pass the typed instance into `_playVideo`/`_downloadFile`), narrowing once at the `_buildGenericAttachment` dispatch point with `if (attachment is VideoAttachment)` / `is FileAttachment`. Removes all ten `dynamic` casts and restores full static checking.

</details>

<details>
<summary><b>🔴 HIGH · КОСТЫЛЬ · [M]</b> — Contact display-name parsing is duplicated four times over an untyped Map<String,dynamic>, giving inconsistent results per screen</summary>


**Где:** `lib/frontend/screens/calls/call_screen.dart:149-166`, `lib/frontend/screens/contacts/contact_profile_screen.dart:66-83`, `lib/frontend/screens/contacts/nfc_exchange_sheet.dart:128-145`, `lib/frontend/screens/contacts/contacts_tab.dart:326-332`


**Проблема:** ContactInfo packets are exposed to the UI as raw Map<String,dynamic>, so four screens each re-implement display-name extraction from info['names'] with genuinely different priority rules: call_screen._contactName prefers the entry with type=='ONEME' and builds firstName+lastName; contact_profile_screen._displayName reads only names.first (name, then firstName/lastName); nfc_exchange_sheet._peerName loops all entries taking the first non-empty name; contacts_tab reads only names.first['name']. The same contact can therefore render a different name on different screens, and the UI directly parses the wire payload shape, violating the UI -> backend module -> transport layering. All four call sites confirmed.


**Решение:** Introduce a typed ContactInfo model parsed once in the backend contacts module, exposing a single canonical displayName getter, and have all four call sites consume contact.displayName instead of hand-rolling extraction from the raw Map.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — Chat-folder filter matching relies on untyped dynamic values with duplicated magic-number/string comparisons</summary>


**Где:** `lib/backend/modules/folders.dart:61-89`


**Проблема:** ChatFolder.filters is List<dynamic> because the server sends filter values inconsistently as ints (8, 9, 0) or strings ('CONTACT', 'NOT_CONTACT', 'UNREAD'). chatMatchesFolder compensates with triple-OR comparisons (f == 9 || f == '9' || f == 'CONTACT') and does so twice — once to compute hasContact/hasNotContact (67-72), then again inside the main filter loop (79-87) — duplicating the same magic-number/string logic in two places that can drift apart.


**Решение:** Normalize filter values into a typed enum (e.g. enum ChatFolderFilter { unread, contact, notContact }) once in ChatFolder.fromJson, mapping both int and string server representations to the enum. chatMatchesFolder can then switch on enum values with no repeated raw-value comparisons.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [L]</b> — ws2 signaling parsed as untyped Map<String,dynamic> with duplicated field parsing</summary>


**Где:** `lib/core/calls/call_session.dart:226-282`, `lib/core/calls/call_session.dart:380-412`, `lib/core/calls/call_session.dart:1174-1192`, `lib/core/calls/ws2_signaling.dart:126-173`


**Проблема:** Every ws2 notification arrives as a raw Map<String,dynamic> and is dispatched by a string switch on msg['notification'] (call_session.dart:232-281). Each handler re-implements ad-hoc dynamic casts on the same shapes. Concretely, the same mediaSettings/isAudioEnabled/isVideoEnabled parsing is duplicated: _upsertParticipant reads mediaSettings/muteStates at 394-409, while _applyConnectionInfo re-derives _peerMuted/_peerVideo from the same mediaSettings map inline at 1185-1189, and _applyPeerMedia does it a third time at 1215-1229. There is no single source of truth for the wire schema, so a server field rename or a participantId type change (already special-cased in _participantIdFrom) silently breaks a handler with no compile-time signal.


**Решение:** Introduce a small typed decode layer for the ws2 protocol under models/ or core/calls: named-field classes (or a sealed Ws2Notification hierarchy keyed off the notification string) built once via factory constructors from the decoded JSON, plus a single shared MediaSettings/MuteStates parser reused by _upsertParticipant, _applyConnectionInfo, and _applyPeerMedia. This removes the repeated dynamic-cast boilerplate and consolidates protocol changes into one file.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [L]</b> — ChatInfoScreen fetches info via core/cache singletons returning untyped Maps, forcing the UI to hand-parse key-ambiguous protocol data</summary>


**Где:** `lib/frontend/screens/chats/chat_info_screen.dart:138`, `lib/frontend/screens/chats/chat_info_screen.dart:145-152`, `lib/frontend/screens/chats/chat_info_screen.dart:156-169`, `lib/frontend/screens/chats/chat_info_screen.dart:180-183`, `lib/frontend/screens/chats/chat_info_screen.dart:195-196`, `lib/core/cache/info_cache.dart:110-123`, `lib/core/cache/info_cache.dart:246-259`


**Проблема:** ChatInfoScreen._load() calls ChatInfoFetch.get / ContactInfoFetch.get / PresenceFetch.get(getMany) directly. These live in core/cache/info_cache.dart, call api.sendRequest(Opcode.xxx) themselves, and return raw Map<String,dynamic> straight off the wire, so the widget layer does protocol-response handling instead of the documented UI -> backend module -> api flow. Because the payload is untyped, participant/admin keys arrive as either int or String and the screen must defensively check both forms in several places: `k is int ? k : int.tryParse(k.toString())` (lines 147 and 181) and `admins.containsKey(id.toString()) || admins.containsKey(id)` (line 196). The same int/String key ambiguity is re-handled inside info_cache.dart itself (primeAll line 163, _fetchBatch line 223). Any opcode/shape change means editing every ad hoc call site rather than one parsing boundary.


**Решение:** Introduce typed models (ChatInfo, ContactInfo, PresenceInfo) produced once at the fetch boundary, normalizing participant/admin keys to int during that single parse. Have the fetch layer (ideally surfaced through backend/modules/chats.dart / contacts.dart) return the typed model instead of Map<String,dynamic>, and have ChatInfoScreen consume the model so the defensive key-coercion disappears from the UI.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [L]</b> — Contact display-name extraction re-implemented on raw dynamic Maps in two places</summary>


**Где:** `lib/frontend/widgets/max_link_handler.dart:145-157`, `lib/frontend/commands/info_command.dart:42-51`


**Проблема:** `_contactName` (max_link_handler.dart:145-157) and `_nick` (info_command.dart:42-51) are near-verbatim copies of the same logic: pull `names` (a List of Maps) off a raw payload, take `names.first['name']`, else join `firstName`+`lastName`. Both operate on untyped `Map<dynamic,dynamic>`/`Map<String,dynamic>` handed straight to the UI/command layer by `LinkModule.resolve` and `ContactInfoFetch.get` (e.g. `ResolvedUser.contact` is a raw Map; `_openResolvedChat` also digs `chat['participants']`, `chat['access']`, etc. out of a raw Map). This ad hoc JSON parsing in widgets and slash commands is exactly the fragile, no-compile-time-safety pattern the layered architecture (models/ = typed data classes) is meant to avoid: a server field rename fails silently deep in UI code instead of at the backend-module boundary. Confirmed both helpers exist and match.


**Решение:** Minimum: extract one shared `displayNameFromNames(List names)` helper so the parsing lives in one place. Proper fix (aligned with the layered architecture): give `LinkModule.resolve`/`ContactInfoFetch` typed return models (e.g. `ResolvedContact`/`ContactInfo` in models/ with a `displayName` getter) so the UI never touches raw Maps, and delete both dynamic-parsing helpers.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Three hand-rolled 'prefer ONEME name' implementations with inconsistent no-ONEME fallback</summary>


**Где:** `lib/backend/modules/account.dart:197-221`, `lib/backend/modules/contacts.dart:171-195`, `lib/backend/modules/contacts.dart:217-237`


**Проблема:** BlockedContact.fromMap loops over `names`, overwriting firstName/lastName each iteration and only `break`ing on type=='ONEME', so when no ONEME entry exists it keeps the LAST map entry. ContactsModule._primeContactCache and _parseContact instead use `firstWhere(type=='ONEME', orElse: firstWhere(is Map))`, which falls back to the FIRST entry. Same concept, three copies, two mutually inconsistent fallbacks — an edge-case divergence where the same contact could resolve to a different name depending on which code path handled it.


**Решение:** Extract one shared helper (e.g. returning a firstName/lastName record) taking `List? names` with a single documented fallback rule (first Map entry, matching the two contacts.dart call sites), and use it from BlockedContact.fromMap, _primeContactCache and _parseContact so all paths agree.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [M]</b> — Cache layer bypasses backend/modules and calls Api/Opcode directly; UI calls it straight from widgets</summary>


**Где:** `lib/core/cache/info_cache.dart:8-12`, `lib/core/cache/info_cache.dart:110-123`, `lib/core/cache/info_cache.dart:209-229`, `lib/core/cache/info_cache.dart:246-259`, `lib/main.dart:122`, `lib/frontend/screens/contacts/contact_profile_screen.dart:46-47`, `lib/frontend/screens/chats/chat_info_screen.dart:138`, `lib/frontend/screens/calls/call_screen.dart:134`, `lib/frontend/commands/info_command.dart:20`


**Проблема:** core/cache/info_cache.dart holds a module-level mutable `Api? _api` (wired once via attachInfoCacheApi from main.dart:122) and ContactInfoFetch/ChatInfoFetch/PresenceFetch call `api.sendRequest(Opcode.contactInfo/chatInfo/contactPresence, ...)` directly, skipping backend/modules entirely. UI screens (contact_profile_screen, chat_info_screen, call_screen, info_command, nfc_exchange_sheet) call these caches straight from widget code, so a widget triggers a protocol-level round trip with no backend module in between. This breaks the documented UI -> backend module -> api.dart -> transport layering, couples UI-adjacent and cache code to Opcode wire details, and makes the cache untestable without a live/mocked Api. Confirmed real: the modules already reference these caches (chats.dart calls ContactInfoFetch.clear/PresenceFetch.apply/ChatInfoFetch.get) and send the same Opcodes elsewhere (contacts.dart, chats.dart:1303/1705, calls.dart:214, messages.dart), so the wire logic is duplicated across layers.


**Решение:** Keep core/cache/info_cache.dart as the pure generic `InfoCache<T>` primitive (it already takes a fetcher callback). Move the Opcode round-trip logic into the owning backend modules (contacts.dart / chats.dart already send these Opcodes), expose e.g. `ContactsModule.contactInfo(id)` / `presence(ids)` that internally use a cache, and have UI call the module. Delete attachInfoCacheApi/_api so the cache no longer imports Api/Opcode, restoring the intended layering.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [M]</b> — UI screen subscribes to and decodes raw protocol packets directly</summary>


**Где:** `lib/frontend/screens/chats/chat_list_screen.dart:34-35`, `lib/frontend/screens/chats/chat_list_screen.dart:546-548`, `lib/frontend/screens/chats/chat_list_screen.dart:553-565`


**Проблема:** Confirmed. `_ChatListScreenState` imports `core/protocol/opcode_map.dart` and `core/protocol/packet.dart` (34-35), subscribes to `api.pushStream.where((p) => p.opcode == Opcode.notifTyping)` (546-548), and manually pulls `chatId`/`userId`/`type` out of the raw decoded `Map` payload in `_onTypingPush` (553-565). CLAUDE.md's layered architecture states packet/opcode decoding belongs in a backend module; every other typed event the screen consumes (`ChatsModule.messageEvents`, `ChatsModule.chatsChanged`) already goes through a module abstraction. (Downgraded from high: single localized handler, not a systemic break.)


**Решение:** Move typing-packet decoding into a backend module (e.g. a `ChatsModule.typingEvents` stream next to `messageEvents`) that listens to `api.pushStream`, validates the payload, and emits a typed event; the screen consumes only that typed stream and drops the two `core/protocol` imports.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — info_screen guesses timestamp fields by integer magnitude and threads a raw dynamic JSON map through the UI</summary>


**Где:** `lib/frontend/screens/profile/info_screen.dart:254-274`, `lib/frontend/screens/profile/info_screen.dart:82-116`


**Проблема:** `_info` is a raw `Map<String, dynamic>?` from jsonDecode, navigated with string-literal keys across two ad-hoc key/label tables plus manual `as Map<String, dynamic>?` casts. `_formatValue` guesses field semantics at runtime: `if (value is int && value > 1000000000000) return _formatTs(value)` renders any sufficiently large integer as a millisecond date, with a separate special-case for `key == 'edit-timeout'`. A legitimately large non-timestamp integer field would be silently mis-rendered as a date. Note this is a diagnostic Info screen gated behind extra-info mode, so impact is limited to that debug view.


**Решение:** Since this is a diagnostic screen, a full typed model is likely overkill; the minimal fix is to make _formatValue key-driven — match against an explicit allowlist of known timestamp/duration keys instead of guessing from the integer's magnitude. If the screen grows, introduce a small typed model in lib/models/ parsed once in _loadData().

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [M]</b> — Debug screen issues raw protocol requests directly from UI, bypassing backend modules</summary>


**Где:** `lib/frontend/screens/profile/debug_menu_screen.dart:194-223`, `lib/frontend/screens/profile/debug_menu_screen.dart:1597-1624`


**Проблема:** DebugMenuScreen._search() and _SyncProbeCardState._send() call api.sendRequest(Opcode.contactInfo/chatInfo/sync, {...}) and catch PacketError directly, with the screen importing core/protocol/opcode_map.dart and core/protocol/packet.dart. This breaks the documented UI -> backend module -> api -> transport layering, and line 222 already shows the intended pattern (ChatsModule.searchById). Severity is low because this is a developer-only diagnostic probe screen whose purpose is raw protocol inspection, so the layering cost is limited.


**Решение:** If kept, wrap these in a thin backend/modules/debug_probes.dart exposing typed methods (lookupContactInfo(id), lookupChatInfo(id), syncContact(phone, name)) that own the sendRequest/PacketError handling, so the screen stops importing Opcode/PacketError directly.

</details>


### Security and privacy defects  (7 — 2 high)

_Secrets and identity checks rely on plaintext storage, drifted redaction, spoofable client-side heuristics, and plaintext third-party requests._

<details>
<summary><b>🔴 HIGH · КОСТЫЛЬ · [S]</b> — Proxy username/password stored in plaintext SharedPreferences instead of the project's own secure storage</summary>


**Где:** `lib/core/config/proxy_config.dart:36-67`


**Проблема:** `ProxyConfig.save`/`load` persist `ProxySettings.username`/`password` (SOCKS5/HTTP-CONNECT proxy credentials) via plain `SharedPreferences.setString`/`getString` (proxy_config.dart:57-64, 41-42). The codebase already has `TokenStorage` (lib/core/storage/token_storage.dart) built on `FlutterSecureStorage` with `encryptedSharedPreferences: true` and exposing `writeSecure`/`readSecure`/`deleteSecure` specifically to avoid storing secrets in plaintext prefs, and uses it for auth tokens. Proxy credentials get no such protection, so on a rooted/compromised device or a shared-prefs backup they are readable in the clear.


**Решение:** Route `username`/`password` through `TokenStorage.writeSecure`/`readSecure`/`deleteSecure` (already used elsewhere for exactly this purpose) and keep only `type`/`host`/`port` in plain SharedPreferences. Mirror the same in `ProxyConfig.clear` so `deleteSecure` runs for the credential keys.

</details>

<details>
<summary><b>🔴 HIGH · ДУБЛЬ · [S]</b> — Debug session log uses a weaker private redactor than the app's shared allowlist, leaking device IDs (and likely OTP/QR/codes) into the shared export</summary>


**Где:** `lib/core/utils/debug_session_log.dart:333-365`, `lib/core/utils/log_redact.dart:5-51`, `lib/backend/api.dart:305-318`


**Проблема:** DebugSessionLog has its own ad-hoc redactor (`_isTokenKey`, `_isPhoneKey`, `_maskPhone`, `_redact`, lines 333-365) that only masks keys containing 'token' and 'phone'/'msisdn'. Every request/response payload sent through `Api.sendRequest` is recorded via this path (api.dart:318 recordRequest, 328 recordResponse) and persisted to `debug_sessions/*.json`, then assembled by `buildExport()` into a text file the user shares with support. The codebase already has a canonical, broader allowlist in log_redact.dart (`redactForLog`, covering 'auth','secret','code','otp','pin','qrlink','deviceid','mt_instanceid','instanceid','webappdata', etc.) — the same one traffic_monitor.dart:145 relies on precisely because 'файлом можно делиться'. None of those extra keys are masked by debug_session_log's private copy. Concretely verified: the sessionInit payload (api.dart:305-310) carries `mt_instanceid` and `deviceId` in cleartext, and any flow sending verification codes/QR-login links would also pass through unmasked. The class doc comment (lines 91-92) explicitly claims secrets never hit disk, which is false. Two redaction implementations that must stay in sync but have already drifted.


**Решение:** Delete the private `_isTokenKey`/`_isPhoneKey`/`_maskPhone`/`_redact` and route recordRequest/recordResponse through the shared `redactForLog` from log_redact.dart (adding the first-3-chars phone behavior to that shared helper if it must be preserved), so the live logger, traffic monitor, and persistent debug log are all governed by one allowlist. Also fix the now-inaccurate doc comment.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — print() debug statements left in the live notification reply / call-decline path</summary>


**Где:** `lib/core/push/push_service.dart:296-298`, `lib/core/push/push_service.dart:332-334`, `lib/core/push/push_service.dart:354`, `lib/core/push/push_service.dart:369`, `lib/core/push/push_service.dart:378-401`


**Проблема:** `_onNotificationResponse`, `_handleCallDecline` and `_handleReply` — live code invoked from the native reply/decline actions — contain multiple `print('REPLYDBG ...')` / `print('PUSHDBG ...')` calls that emit action inputs, account/chat IDs and internal state. Unlike the file's own `logger` (used via `logger.w`/`logger.i`, which is level-filtered and release-gated), `print()` is NOT stripped in Flutter release builds, so this diagnostic output runs unconditionally in production and writes to stdout/logcat. (The original finding's 'readable by any app with logcat access' claim is overstated — READ_LOGS has been a system-only permission since Android 4.1 — but unfiltered debug output shipping in release, reachable via adb/same-uid, plus the inconsistency with the project's logger convention, is a real hygiene defect.)


**Решение:** Remove these debug prints (the feature is stable), or replace them with `logger.d(...)`/`logger.w(...)` consistent with the rest of push_service.dart so they are level-filtered and release-gated. Deleting the dead-code prints (line 69) is subsumed by the dead-code cleanup finding.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — ESIA/Gosuslugi callback redirect can build a malformed double-'?' URL</summary>


**Где:** `lib/frontend/screens/digital_id/digital_id_web_screen.dart:318-331`


**Проблема:** shouldOverrideUrlLoading rebuilds the redirect target as '$base?$query$frag' (line 326), where base is _launch.url truncated at the first '#'. If the launch URL already contains a '?' before the '#' (e.g. https://.../start?flow=x#/hash), the rebuilt target becomes '.../start?flow=x?<query>#/hash' with two '?' segments, breaking the callback forward. The default fallback 'https://digital-id.max.ru' has no query, so this only triggers when the server-supplied _launch.url carries a query string, hence medium rather than high.


**Решение:** Build the target with Uri.parse(base).replace(queryParameters: {...existing, ...callbackParams}) so an existing query string is correctly merged with the callback's query instead of concatenated.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — Regex-based account-ownership check in the injected JS bridge can leak one account's cached WebView session into another</summary>


**Где:** `lib/frontend/screens/digital_id/digital_id_web_screen.dart:50-76`


**Проблема:** The injected userId() JS function scrapes location.hash with two regexes, swallows all failures via bare try/catch, and falls back to the literal 'anon'. komet_did_owner in localStorage is compared only against this guessed id to decide whether to wipe localStorage/sessionStorage/indexedDB. If the hash shape ever changes so the regexes stop matching, every account resolves to 'anon', the storage wipe never fires on account switch, and account B can read account A's cached Digital ID session data including the locally generated biometric token (bioToken at line 82-93). Confirmed. Trigger is conditional on an upstream URL-shape change, hence medium.


**Решение:** Do not infer the owning account from scraped URL text inside injected JS. Pass the authoritative accountId (known in Dart at the webAppModule.fetchDigitalId() call site) into the page via an initial user script argument, and key/clear storage off that value.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [L]</b> — Cloud-storage env-group identity relies on a spoofable client-side checksum of the chat title</summary>


**Где:** `lib/backend/modules/cloud_storage.dart:36-46`, `lib/backend/modules/cloud_storage.dart:48-56`, `lib/backend/modules/cloud_storage.dart:65-66`


**Проблема:** _computeSpecialNumber derives a 'signature' from the group id with a trivial transform (double it if <4 digits, else sum of first-4 and last-4 digits), and isCloudStorageGroup/findOrphanGroups trust any chat whose title is 'CLST<that number>' (or the literal 'Облачное хранилище') as the user's private cloud-storage container. Because the transform is deterministic and derived solely from the publicly-visible chat id, any peer who can invite the victim into an attacker-controlled group with the matching title can make this client treat that group as the user's private storage — where the client then reads/writes private files.


**Решение:** Prefer the locally-cached, previously-verified id (getCachedEnvGroupId) as the authoritative identifier, and when the cache is empty fall back to setupEnv to (re)create the group rather than trusting a forgeable title. Note the title-scan currently exists to re-discover the group across devices with no server-authoritative marker; the real fix is a server-side/owner-verified marker for the env group — do not simply delete the scan without providing an equivalent cross-device bootstrap, or duplicate groups will proliferate.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [M]</b> — IP geolocation lookup done via raw plaintext HTTP directly from the UI widget</summary>


**Где:** `lib/frontend/screens/profile/devices_screen.dart:152-196`


**Проблема:** _lookupIp builds an HttpClient inline in the State and GETs http://ip-api.com/json/$ip?... over plaintext, decoding into an untyped Map<String,dynamic> stored in _ipDetails. This bypasses the app's transport/backend layering, sends the user's own session/login IP addresses to a third party unencrypted (visible to any on-path observer), and stores an ad-hoc dynamic map instead of a typed model. Confirmed. Severity medium (not high): the data is the user's own already-known session IPs and ip-api's free tier is HTTP-only, so it is a genuine privacy/layering smell rather than a critical leak.


**Решение:** Move to a backend module (e.g. backend/modules/geo_lookup.dart) that centralizes the HttpClient lifecycle/timeout/error handling and returns a typed IpGeoInfo model; prefer an HTTPS-capable geolocation endpoint so session IPs are not sent in cleartext.

</details>


### Silent failures and swallowed errors  (16 — 2 high)

_Bare catch blocks discard exceptions on connect, upload, outbox, poll, and platform-channel paths with no logging, making production failures undiagnosable and sometimes reporting failure as success._

<details>
<summary><b>🔴 HIGH · КОСТЫЛЬ · [S]</b> — OutboxService.flush aborts the whole pending loop on the first per-message failure and swallows all errors unlogged</summary>


**Где:** `lib/backend/modules/outbox.dart:41-80`


**Проблема:** The per-row catch (_) { break; } (73-75) stops processing ALL remaining pending rows across every chat as soon as one sendMessage throws for any reason (bad text, server validation), and the outer catch (_) {} (77-78) discards the exception with no logging (this file has no logger usage, unlike messages.dart). One message-specific failure silently blocks delivery of every other unrelated pending message until the next online transition, with zero diagnostics. The connection-loss case is already handled separately by the api.state check at line 42.


**Решение:** Catch per-row, log via logger.e/logger.w (as messages.dart does), and continue to the next pending row instead of break; reserve aborting the loop for connection-level failures only.

</details>

<details>
<summary><b>🔴 HIGH · КОСТЫЛЬ · [M]</b> — switchAccount swallows connect() failures and returns success anyway</summary>


**Где:** `lib/backend/modules/account.dart:1112-1140`


**Проблема:** switchAccount tears down the old session, sets the new active account, clears caches, then does `try { await _api.connect(); } catch (_) {}` (lines 1134-1136) and unconditionally returns the loaded `profile`. If connect() throws (network down, handshake/spoof failure) the caller receives a ProfileData and believes the switch succeeded, while the app is left disconnected with no error surfaced. Note this is specific to switchAccount: loginWithToken (1093-1109) correctly guards with a post-connect `if (_api.state != SessionState.online) throw` and beginAddAccount never connects, so those disconnect() swallows are legitimate best-effort teardown.


**Решение:** Do not swallow the connect() failure in switchAccount. After `await _api.connect()`, verify `_api.state == SessionState.online` (mirroring loginWithToken) and rethrow / return a typed failure otherwise, so the UI layer can call showCustomNotification(context, ...) and let the user retry instead of silently pretending the account switch worked. Leave the disconnect() swallows as-is.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — Fixed 300ms delay papers over a race before authQrApprove</summary>


**Где:** `lib/backend/modules/account.dart:1058-1072`


**Проблема:** authorizeWebQrLogin sends ping, then sessionsInfo (both awaited), then blindly `await Future<void>.delayed(const Duration(milliseconds: 300))` before sending authQrApprove. It is a magic constant: potentially too short on a slow connection (approve races/fails) and needlessly slow on a fast one, with no indication of what condition is actually being awaited.


**Решение:** Drop the bare literal in favor of the awaited signal that actually gates approval — rely on the sessionsInfo response completing, or await the specific push/response that indicates the session is ready before sending authQrApprove. If a server-side settle really is required, drive it from a named, documented constant rather than an inline 300ms sleep.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — resolveContacts silently swallows all errors, mislabeling failed lookups as group calls</summary>


**Где:** `lib/backend/modules/calls.dart:213-227`


**Проблема:** resolveContacts wraps the whole request in try { ... } catch (_) {} (calls.dart:213/227), discarding any exception (timeout, disconnect, malformed payload) with no log, returning whatever partial map was built. In parseHistoryPayload, an empty fetched map for a peerId falls through to name = 'Групповой звонок' with isGroup = true (calls.dart:324-326), so a 1:1 call whose name-lookup merely failed gets rendered as a group call.


**Решение:** Log the caught exception via the existing logger before returning, and let genuine failures set a distinct 'unresolved' state (or propagate) so fetchHistory can retry or surface a different UI state instead of a wrong group-call label.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — 1-second 'no response' timeout is silently collapsed into the upload-success code path</summary>


**Где:** `lib/backend/modules/file_uploader.dart:56`, `lib/backend/modules/file_uploader.dart:685`, `lib/backend/modules/file_uploader.dart:120`


**Проблема:** _readResponse races Timer(autoForceAfter /* default 1s */, () => finish(0)) against the real socket read (line 685). If the CDN has not answered within 1s of the body being flushed, the code fabricates status 0, and the caller's guard `if (statusCode != 200 && statusCode != 0)` (line 120) treats 0 identically to a real 200, proceeding to messages.sendFileMessage as if the upload were confirmed. This conflates 'we do not know yet' with 'it worked': a slow-but-failing upload, or one whose ack loses the race, is reported to the server/UI as successful with no real confirmation.


**Решение:** Model three outcomes (confirmed success, confirmed failure, unknown/ack-pending) instead of folding timeout into the success code. Either await the real response with a generous timeout and treat a timeout as a genuine UploadError, or, if the CDN is known to sometimes not ack, surface the 'unknown' state explicitly so sendFileMessage can be retried/verified rather than assumed. If the 1s no-ack behavior is intentional CDN protocol, document why via self-explanatory code (a named outcome enum), not a magic status 0.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — Server error responses detected by raw substring search instead of parsing JSON</summary>


**Где:** `lib/backend/modules/file_uploader.dart:211-213`


**Проблема:** uploadMediaFile decides success/failure with `respBody.contains('error_msg') || respBody.contains('error_code')` — a raw string search over the whole response body rather than parsing JSON. It will misfire on any success payload that happens to contain those substrings (e.g. in an echoed field) and gives no access to the actual error reason for logging or UI.


**Решение:** Parse the response with jsonDecode and test well-defined fields (e.g. response['error_code'] != null), surfacing the real error message where available, instead of substring containment. (The nearby _parsePhotoToken already does typed jsonDecode traversal and is acceptable as-is.)

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — Chat/folder load failures and account-switch failures are silently swallowed</summary>


**Где:** `lib/frontend/screens/chats/chat_list_screen.dart:722-731`, `lib/frontend/screens/chats/chat_list_screen.dart:2598-2600`


**Проблема:** Confirmed. `_reloadChatsAndFolders`'s outer `catch (_)` (722) swallows every exception from `ChatsModule.getChats`/`FoldersModule.loadFolders` and just resets folders to empty with `_isInitialLoading = false` — no `showCustomNotification`, no logging — leaving the user with a silently empty chat list. `try { await accountModule.beginAddAccount(); } catch (_) {}` (2598-2600) discards any add-account failure and proceeds to the login screen regardless. The codebase already uses a `logger` elsewhere (messages.dart:1846,1907).


**Решение:** Log the caught exception via the existing `logger`, and surface `showCustomNotification(context, ...)` when the failure is not simply 'not connected yet', instead of a bare `catch (_)`.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — Silent catch-and-discard blocks with no logging across sticker/photo-editor code</summary>


**Где:** `lib/frontend/widgets/sticker_lottie.dart:172`, `lib/frontend/widgets/attachment/photo_editor.dart:96`, `lib/frontend/widgets/attachment/photo_editor.dart:394`, `lib/frontend/widgets/attachment/photo_editor.dart:1021`, `lib/frontend/widgets/attachment/photo_editor.dart:1973`, `lib/frontend/widgets/attachment/photo_editor.dart:2341`


**Проблема:** Six `catch (_)` blocks discard the exception entirely with no logging. sticker_lottie.dart:172 returns null (blank sticker); photo_editor.dart:96 and :1973 pop the editor with no explanation on image-decode failure; :394/:1021/:2341 return null from _bake. A `logger` already exists (core/utils/logger.dart) and is used in backend/modules/stickers.dart, so a corrupt codec, malformed Lottie, or JPEG-encode failure is invisible in production diagnostics even though the same project logs elsewhere.


**Решение:** Replace each bare `catch (_)` with `catch (e, st) { logger.e('...', error: e, stackTrace: st); }` (matching backend/modules/stickers.dart) before the existing UI fallback, so failures stay silent to the user but visible in logs.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — Fixed-delay animation-completion hack plus silently-dropped fire-and-forget cleanup calls</summary>


**Где:** `lib/frontend/screens/profile/cloud_storage_screen.dart:193-208`, `lib/frontend/screens/profile/cloud_storage_screen.dart:143-150`, `lib/frontend/screens/profile/cloud_storage_screen.dart:162-181`


**Проблема:** _prependFile uses Future.delayed(800ms, () { if (mounted) setState(_animateNewCard=false); }) to guess when the entry animation has finished instead of listening to the animation. Separately, _deleteOrLeave and _handleOrphansBackground are declared void async (they await ChatsModule.deleteChat/leaveChat internally) and are invoked without await at lines 144, 149 and 165; any thrown error becomes an unhandled async error — a failed orphan delete/leave is silently dropped with no retry, feedback, or logging, so orphan cloud-storage groups can persist. Confirmed.


**Решение:** Drive _animateNewCard off the entry animation's AnimationStatusListener (status == completed) rather than a fixed timer. Change _deleteOrLeave/_handleOrphansBackground to return Future<void> and either await them or explicitly unawaited(...) with a .catchError that logs via the existing logger, so failures are observable.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [S]</b> — WebView session-reset helpers live in a screen file, are imported by four unrelated screens, and swallow all failures</summary>


**Где:** `lib/frontend/screens/digital_id/digital_id_web_screen.dart:14-26`


**Проблема:** resetDigitalIdWebData()/resetDigitalIdSession() reach directly into CookieManager/WebStorageManager and digitalIdModule.reset() — backend/service logic, not screen UI — yet they are defined in digital_id_web_screen.dart and imported by settings_tab.dart:26/213, debug_menu_screen.dart:35/913, chat_list_screen.dart:29/2597/2610, and login_screen.dart:17/66, none of which otherwise depend on this screen. Both functions also swallow every failure with bare catch (_) {} (lines 18, 25), so a failed cookie/storage wipe during logout or account switch is invisible and undiagnosable.


**Решение:** Move this logic into backend/modules/digital_id.dart (alongside digitalIdModule) or a small core/storage service, matching the UI -> backend module layering, and log the caught exceptions instead of discarding them.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — CallBridge swallows every platform-channel exception with no diagnostics</summary>


**Где:** `lib/core/calls/call_bridge.dart:34-37`, `lib/core/calls/call_bridge.dart:67-70`, `lib/core/calls/call_bridge.dart:73-76`, `lib/core/calls/call_bridge.dart:80-84`, `lib/core/calls/call_bridge.dart:87-93`, `lib/core/calls/call_bridge.dart:96-100`


**Проблема:** Every native call into the ru.komet.app/calls MethodChannel (consumeInitialCall, notifyAccepted, notifyEnded, cancelIncoming, canUseFullScreenIntent, openFullScreenIntentSettings) is wrapped in try { ... } catch (_) {}, discarding the exception without even logging it. A failure in notifyEnded/cancelIncoming (native service crash, channel not registered) leaves the incoming-call system notification undismissed with zero log trail, unlike the media bridges (e.g. OpusOggEncoder.ensureAvailable at opus_ogg_encoder.dart:46) which log via logger.w.


**Решение:** Replace the bare catch (_) {} blocks with catch (e) { logger.w('CallBridge.<method>: $e'); } (add the core/utils/logger import), matching the logger.w pattern already used elsewhere, so platform-channel failures are observable.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — Migration/parse failures swallowed silently, inconsistent with logging used elsewhere in the same files</summary>


**Где:** `lib/core/storage/app_database.dart:183`, `lib/core/storage/chat_wallpaper_store.dart:114`, `lib/core/storage/chat_wallpaper_store.dart:186-189`, `lib/core/storage/draft_store.dart:32`, `lib/core/storage/spoofing_service.dart:187`


**Проблема:** Several `catch (_) {}` blocks discard the exception entirely: legacy DB migration (_migrateLegacyDb), wallpaper/draft JSON hydration in load(), wallpaper file deletion, and spoof-profile JSON decoding. AppDatabase logs other failures via logger.e (e.g. saveChats at :538), so a corrupted chat_drafts/chat_wallpapers blob or failed legacy-db copy fails completely silently with nothing to diagnose a user report of lost drafts/wallpapers.


**Решение:** Replace each bare `catch (_) {}` with `catch (e) { logger.w('...: $e'); }` (a logger is already imported/available in app_database.dart; add the import where needed), matching the existing logging pattern so failures stay observable while still degrading gracefully.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [M]</b> — Future.delayed(700ms) papers over a post-call server-sync race</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:3093`


**Проблема:** _refreshAfterCall does `await Future.delayed(const Duration(milliseconds: 700))` before re-fetching chat history, evidently to let the server persist the call-ended system message first. This is a wall-clock guess, not a guarantee — under load or a slow connection the fetch can still race ahead of the server write and miss the call message until the next unrelated refresh.


**Решение:** Replace the fixed delay with an authoritative trigger: refetch when the server's own call-ended / history-updated event arrives (via the existing ChatsModule event / push stream) rather than guessing a delay.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — Broad catch blocks discard the exception with no diagnostics</summary>


**Где:** `lib/frontend/widgets/message_bubble.dart:2917`, `lib/frontend/widgets/message_bubble.dart:3213`, `lib/frontend/widgets/message_bubble.dart:3383`


**Проблема:** `_VoiceMessageBubbleState._togglePlay` (catch e -> generic 'Ошибка воспроизведения'), `_requestTranscription` (catch e -> 'ошибка транскрибации'), and `_VideoNoteBubbleState._toggle` (catch _ -> sets error flag) all discard the caught exception without logging it. Since release builds use `--obfuscate` per the project's build commands, throwing away the exception at the only place it is caught makes real playback/transcription failures undiagnosable in production. Note: the codebase already has `core/utils/logger.dart`. (The `catch (_) {}` at message_actions_overlay.dart:490 was excluded — it wraps `_animController.reverse()` on close and is a genuinely benign disposed-controller case.)


**Решение:** Route the caught exception through the existing logger (guarded by kDebugMode where appropriate) before showing the user-facing notification, so failures are traceable in obfuscated builds.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — Reconnect-login failures are swallowed by an empty catch block</summary>


**Где:** `lib/main.dart:297-307`


**Проблема:** api.setReconnectCallback wraps the entire auto-relogin flow (getActiveAccountId, readToken, accountModule.login) in `try { ... } catch (_) {}`. Any failure — corrupted token storage, network error, unexpected exception from login — is discarded with no logging and no user feedback, so if auto-reconnect silently stops there is nothing to diagnose it. Verified the empty catch at lines 306.


**Решение:** Do not swallow silently: at minimum log the caught exception (the app has DebugSessionLog wired at main.dart:150, though its API is request/response/error-oriented — `recordError(seq, error)` — so a plain debugPrint or a dedicated diagnostic log line may fit better here). Preferably distinguish expected cases (no active account / missing token -> just return) from unexpected exceptions, and log or surface the latter rather than catching everything.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [S]</b> — PollsModule swallows all exceptions with no logging, unlike the rest of the backend layer</summary>


**Где:** `lib/backend/modules/polls.dart:55`, `lib/backend/modules/polls.dart:87`


**Проблема:** fetch() and vote() use bare catch (_) {} / catch (_) { return false; } with no logging, whereas messages.dart consistently logs failures via logger.e/logger.w. A malformed poll payload (e.g. a bug in Poll.fromServerMap) or a genuine network error becomes invisible in production.


**Решение:** Log the caught exception via the project logger before returning, so poll fetch/vote failures are diagnosable.

</details>


### Broken or dead UI affordances  (9 — 2 high)

_Several controls render as working but do nothing, and one feature is structurally impossible to succeed._

<details>
<summary><b>🔴 HIGH · КОСТЫЛЬ · [M]</b> — CustomFontService requests a modern-browser UA but only accepts a legacy TTF response, so adding any Google font silently fails</summary>


**Где:** `lib/core/config/custom_font_service.dart:11`, `lib/core/config/custom_font_service.dart:75-91`, `lib/core/config/custom_font_service.dart:102-125`


**Проблема:** `_fetchText`/`_fetchBytes` always send the hardcoded UA `'Mozilla/5.0 (X11; Linux x86_64) Chrome/120'` (line 11) to Google Fonts' css2 endpoint, then `_download` scans the CSS for a font URL with `RegExp(r'url\((https://[^)]+\.ttf)\)')` (line 113) and the bytes are further gated by `_isSfnt` (75-91), which only accepts sfnt magic (ttf/otf/ttc/true) and rejects woff2. Google's css2 selects the served container by UA: a Chrome/120 UA is served woff2, not ttf (the well-known trick to get ttf from Google Fonts is to send an OLD/limited UA). So the ttf regex never matches, `ttfUrl` stays null, both variant iterations exhaust, and `_download` returns null — `addFamily` (32-51) fails for effectively any font, and the blanket `catch (_) { return null; }` (120-121, 45-48) leaves no diagnostic.


**Решение:** Send a User-Agent that Google Fonts serves the sfnt/TTF container for (e.g. an older browser UA), so the existing `.ttf` regex and `_isSfnt` gate keep working. Note that simply accepting the woff2 URL will NOT work: Flutter's `FontLoader` only decodes sfnt (ttf/otf) bytes and cannot load woff2 directly, so either keep TTF end-to-end or add a woff2->sfnt decode step. Also stop swallowing the failure silently — propagate the error so the settings caller can surface it via `showCustomNotification(context, ...)` instead of the add-font action looking like a no-op.

</details>

<details>
<summary><b>🔴 HIGH · КОСТЫЛЬ · [S]</b> — popUntil route-name match never fires, ejecting user to app root instead of SecurityScreen</summary>


**Где:** `lib/frontend/screens/profile/password_entry_screen.dart:633-636`, `lib/frontend/screens/profile/password_entry_screen.dart:1001-1003`, `lib/frontend/screens/profile/password_entry_screen.dart:1187-1190`, `lib/frontend/screens/profile/password_entry_screen.dart:1359-1361`


**Проблема:** After 2FA setup / password change / email change / removal, all four flows call Navigator.popUntil(context, (route) => route.isFirst || route.settings.name == 'SecurityScreen'). Verified that SecurityScreen is pushed at settings_tab.dart:386-391 with a plain MaterialPageRoute and no settings: RouteSettings(name: 'SecurityScreen'), so route.settings.name is always null and the name half of the predicate can never match. The predicate silently degrades to route.isFirst, so each of these four success flows pops the entire stack back to the app root instead of returning to SecurityScreen.


**Решение:** Do not match routes by string name (a magic constant that has already rotted). Either name the SecurityScreen route explicitly at its single push site (settings_tab.dart:388) with settings: const RouteSettings(name: 'SecurityScreen') and switch to ModalRoute.withName, or better: capture Navigator.of(context) before pushing the nested flow and pop back a known number of routes / pass an explicit return callback, so the return target is not coupled to a stringly-typed name.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — ~260 lines of Dart push notification-display code are dead; the live path is the native Kotlin FCM service</summary>


**Где:** `lib/core/push/push_service.dart:31`, `lib/core/push/push_service.dart:41-293`, `android/app/src/main/kotlin/ru/komet/app/KometFcmService.kt`


**Проблема:** `_backgroundHandler`, `_showMessageNotification`, `_showCallNotification`, `_appendHistory`, `_isActive`, `_avatarBytes`, `_initialsAvatar`, `_downloadBytes`, `_initialsOf`, `_avatarPalette` and `_NotifMessage` are defined but never referenced (grep-confirmed: only their definitions match). `PushService.init()` only wires token lifecycle and the notification-response callback — `FirebaseMessaging.onMessage`/`onBackgroundMessage` are never registered to any of these. Actual notification rendering is implemented natively in KometFcmService.kt (12KB, present) with its own history/avatar/messaging-style logic, and the two have already drifted. A future engineer could waste time 'fixing' a bug in the dead Dart copy that never runs. (`_clearHistory` and the `_on*Response`/`_handle*` reply/decline handlers are live and must be kept.)


**Решение:** Delete the unreachable Dart notification-rendering functions and `_backgroundHandler`, keeping only the token lifecycle and the reply/decline handlers (`_onNotificationResponse`, `_handleReply`, `_handleCallDecline`, `_clearHistory`, `clearChatNotification`) that the native side dispatches into.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — Menu items and channel mute button are dead UI (no-op onTap)</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:2875-2886`, `lib/frontend/screens/chats/chat_screen.dart:5620-5646`


**Проблема:** `_openChatMenu` wires the `Symbols.volume_up` 'Уведомления' item and the `Symbols.videocam` 'Видеозвонок' item to `onTap: () {}`, and the CHANNEL composer renders a full-width 'Отключить уведомления' `GlossyPill` with `onTap: () {}`. These render as enabled, tappable controls that silently do nothing, which reads to the user as a bug rather than a missing feature.


**Решение:** Either implement the real behavior via the appropriate backend module (mute/notifications, video call) or omit the control until the feature exists, rather than shipping a convincing but non-functional affordance.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [S]</b> — Wallpaper 'theme' picker is permanently empty — kChatWallpaperThemes is always []</summary>


**Где:** `lib/core/config/chat_wallpaper_themes.dart:17-36`, `lib/frontend/widgets/chat_wallpaper_sheet.dart:104-110`


**Проблема:** `kChatWallpaperThemes` is `const <ChatWallpaperTheme>[]` with no seed data (chat_wallpaper_themes.dart:28), so `chatWallpaperThemeById` can never resolve anything and the `for (final theme in kChatWallpaperThemes)` loop that builds theme tiles (chat_wallpaper_sheet.dart:104) never renders a tile beyond the 'None' option — a whole UI section is dead in production. The class also has `buildBackground()` and `buildPreview()` (17-25) with byte-for-byte identical bodies.


**Решение:** Either finish the feature by populating `kChatWallpaperThemes` with real gradient presets (and collapse `buildBackground`/`buildPreview` into one method), or remove `ChatWallpaperTheme`, `chatWallpaperThemeById`, and the theme-row UI path together until it is implemented, instead of shipping unreachable scaffolding.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [M]</b> — Non-functional 'Sign in with QR' and 'Sign in with session file' menu entries</summary>


**Где:** `lib/frontend/screens/auth/login_screen.dart:657-670`, `lib/frontend/screens/auth/login_screen.dart:693-706`


**Проблема:** In `_showOtherLoginMethods`, the ListTiles for `l10n.loginSignInWithQr` and `l10n.loginSignInWithSessionFile` have `onTap` handlers that only call `Navigator.pop(context)` — they navigate nowhere and call no backend module (contrast with the adjacent 'Sign in with token' tile at 671-691 which pushes `TokenLoginScreen`). A user opens 'Other sign-in methods', taps QR or session-file, and the sheet just closes with no error, no navigation, nothing — a dead affordance presented as a real feature. (The existing `web_qr_login.dart` flow is a different use case: authorizing a new session from an already-logged-in device, not scanning a QR to log in here.)


**Решение:** Either implement the missing flows behind backend module calls (scan/parse a login QR, or pick+parse a session file), or remove/disable these tiles and surface `showCustomNotification(context, ...)` until implemented, so the UI never presents an unimplemented feature as functional.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [M]</b> — Several fully-styled interactive controls are wired to no-ops, presenting unimplemented features as working</summary>


**Где:** `lib/frontend/screens/calls/calls_tab.dart:149-152`, `lib/frontend/screens/calls/calls_tab.dart:385-407`, `lib/frontend/screens/contacts/contact_profile_screen.dart:210-215`


**Проблема:** Tapping a call-history row does nothing (InkWell.onTap is an empty body with a placeholder comment, lines 150-152), the prominent 'Создать групповой звонок' row's InkWell.onTap is a bare () {} (line 386), and the contact-profile 'Звук'/'Звонок' quick actions are permanently onTap: null (lines 213-214) with no disabled visual treatment. Users see normal-looking tappable controls that silently do nothing. All confirmed.


**Решение:** Either finish wiring these (the row tap can reuse the existing _callBack/menu logic; group-call creation should call into CallsModule) or visibly disable/hide the controls until implemented, rather than shipping dead taps.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [S]</b> — Attachment panel ships a raw fileId send-bypass to every user unconditionally</summary>


**Где:** `lib/frontend/widgets/attachment_panel.dart:69-92`, `lib/frontend/screens/chats/chat_screen.dart:1714-1718`


**Проблема:** `AttachmentPanel` always renders an 'Отправить по id' button plus a numeric TextField (lines 69-92); typing any integer and tapping it calls `onSendById`, sending whatever file that id resolves to and bypassing the normal pick-a-file flow. It is wired unconditionally into the main chat screen's attach panel (chat_screen.dart:1714-1718 → `_sendFileById`) with no debug/feature flag, so it ships to every user and flavor. It reads like a developer testing shortcut promoted straight into production UI. Confirmed present and always-rendered.


**Решение:** Remove the raw fileId field from the shipped UI, or gate it behind an explicit kDebugMode / feature flag. If re-sending a known attachment by id is a genuine product need, expose it as a typed action (e.g. re-share from message history) rather than a free-form numeric input.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — LinkText widget is dead code duplicating FormattedMessageText's auto-link handling</summary>


**Где:** `lib/frontend/widgets/link_text.dart:11`, `lib/frontend/widgets/formatted_message_text.dart:70`


**Проблема:** The `LinkText` widget and `_LinkTextState` are never instantiated anywhere (grep for `LinkText(` finds only the constructor declaration). Only the static `LinkText.hasLinks` and the top-level `linkPattern` regex are used, exclusively from `FormattedMessageText`. `_LinkTextState.build` (link_text.dart:44-60) reimplements the exact 'find URL, prefix www. with https://' logic — plus its own TapGestureRecognizer list and dispose bookkeeping — that `FormattedMessageText._withAutoLinks` (formatted_message_text.dart:70-87) already contains. About 50 lines of unreachable widget code with duplicated recognizer lifecycle.


**Решение:** Delete the `LinkText` widget/state, keeping only `linkPattern` and a plain top-level `bool hasLinks(String? text)` (optionally moved to `core/utils/text_format.dart`, which `FormattedMessageText` already imports).

</details>


### Performance: over-broad rebuilds and wasteful hot paths  (34 — 3 high)

_Cheap events trigger whole-list rebuilds, per-item network fan-out replaces existing batch calls, and blocking work runs on the UI isolate._

<details>
<summary><b>🔴 HIGH · ОПТ · [M]</b> — Entire visible message list rebuilds on every composer-height or read-receipt change</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:4580`, `lib/frontend/screens/chats/chat_screen.dart:4485`, `lib/frontend/screens/chats/chat_screen.dart:4525`


**Проблема:** The ListView.builder rendering all visible bubbles is wrapped in ListenableBuilder(listenable: Listenable.merge([_otherReadTime, _composerHeight])). _composerHeight is pushed by _MeasureSize (line 4485) whenever the composer's rendered height changes (text wrapping to a new line, reply-preview appearing, attach/sticker panel toggling), and _otherReadTime changes on each read receipt. Every such change reconstructs the ListView.builder with a fresh itemBuilder closure, and SliverChildBuilderDelegate.shouldRebuild returns true, so all currently-built MessageBubbles are rebuilt — including _effectiveStatus recomputation, _reactionNotifierFor lookups and swipe-to-reply wrappers — even though only the list bottom padding (_composerHeight, used in _messagesListPadding) and a single sender-side read indicator (_otherReadTime) actually depend on these values. This is on top of the outer _messagesRev ValueListenableBuilder that already rebuilds the list on message changes.


**Решение:** Stop gating the whole ListView on these notifiers. Feed _otherReadTime into MessageBubble and let a small ValueListenableBuilder inside the status indicator react to it, rather than recomputing _effectiveStatus for every bubble at list-build time. For padding, avoid rebuilding the delegate on height changes (e.g. apply the composer offset outside the ListView or via a stable SliverPadding) so a composer resize does not invalidate all built children.

</details>

<details>
<summary><b>🔴 HIGH · ОПТ · [M]</b> — Whole message ListView is gated on composer-height and read-time notifiers</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:4580-4584`, `lib/frontend/screens/chats/chat_screen.dart:4590-4628`, `lib/frontend/screens/chats/chat_screen.dart:4525-4534`, `lib/frontend/screens/chats/chat_screen.dart:4484-4489`


**Проблема:** `_buildMessagesListContent()` wraps the whole `ListView.builder` in `ListenableBuilder(listenable: Listenable.merge([_otherReadTime, _composerHeight]))`. When that builder reruns it reconstructs the `ListView.builder` with a fresh `SliverChildBuilderDelegate` (whose default `shouldRebuild` is true), so on the next layout `itemBuilder` is re-invoked for every mounted row and every visible `MessageBubble` is rebuilt. `_composerHeight` is written from `_MeasureSize.onHeight` (line 4485) and changes on any composer size change (mode switch, multi-line wrap while typing, keyboard reserve). `_otherReadTime` forces the same full rebuild just to move the checkmark on the single most-recent own message. So ordinary composer interactions trigger full visible-list rebuilds even though `_composerHeight` is only consumed for the list's bottom padding (line 4532).


**Решение:** Stop rebuilding the `ListView.builder` from these notifiers. Keep the delegate/list stable and reserve the bottom space with a separately animated sliver/spacer (or a `ValueListenableBuilder` wrapping only a `SliverPadding`/`Padding`, not the `ListView`). Move the read/seen checkmark into a per-message `ValueListenableBuilder<int>` inside `MessageBubble` so only the last own message reacts to `_otherReadTime`.

</details>

<details>
<summary><b>🔴 HIGH · ОПТ · [S]</b> — Chat-list contact prefetch fires one network request per unknown contact instead of the existing batched call</summary>


**Где:** `lib/frontend/screens/chats/chat_list_screen.dart:770-795`, `lib/backend/modules/messages.dart:1798-1849`, `lib/backend/modules/messages.dart:1851-1910`


**Проблема:** Confirmed. `_prefetchContactsForChats` loops over every unresolved id and calls `messagesModule.searchContactById(id)` (line 790). Verified in messages.dart:1805-1807 that each call sends its own `Opcode.contactInfo` request with a single-element `contactIds: [contactId]` list, i.e. one round trip per contact. The module already exposes `ensureContactNames(Iterable<int> ids)` (messages.dart:1851) which sends all missing ids in a single `contactInfo` request, and chat_screen.dart:3659 already uses it correctly for the same purpose. On an account with many dialogs this fires N concurrent packets on every reload, and `_runReload` runs on every `ChatsModule.chatsChanged`, draft change, and login.


**Решение:** Replace the per-id loop with a single `await messagesModule.ensureContactNames(ids); _scheduleContactRebuild();` using the already-computed `ids` set. `ensureContactNames` already filters ids whose name is cached, so `_inflightContactIds` can be dropped, or kept only as a coarse in-flight guard to avoid re-issuing the batch while one is pending.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [M]</b> — Every compressed incoming packet spawns and tears down a brand-new Isolate</summary>


**Где:** `lib/core/protocol/packet.dart:156`, `lib/core/protocol/packet.dart:160`, `lib/backend/api.dart:377`, `lib/backend/api.dart:380`


**Проблема:** unpackPacket() only decodes inline when `compFlag == 0 && slice.length < _isolateDecodeThreshold` (4096). Any compressed payload — regardless of size — takes the `await Isolate.run(() => _deserializePayload(owned, compFlag))` path (packet.dart:160), which spawns a fresh isolate (VM init + message-copy of the Uint8List) and kills it after a single decode. In api.dart's `_onDataReceived` the decoded packets are processed in a strict `for` loop with `await unpackPacket(raw)` per packet (api.dart:377-380), so a burst of compressed packets pays the spin-up/tear-down cost serially, adding latency and CPU/battery overhead to a hot, high-frequency path. Verified: a compressed 40-byte payload still incurs the full isolate round-trip even though decoding it inline would be cheaper than the copy alone.


**Решение:** Start one long-lived worker isolate (Isolate.spawn once at Connection/Api startup) that receives (bytes, compFlag) jobs over a SendPort/ReceivePort and returns decoded results, reused for the session lifetime instead of per-packet spin-up/tear-down. Additionally base the offload decision on actual slice size for both compressed and uncompressed payloads (e.g. `slice.length < threshold`), so tiny compressed payloads decode inline rather than paying the isolate round-trip.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [M]</b> — Network history parsed synchronously on the UI isolate with a Duration.zero micro-yield instead of compute() like the DB path</summary>


**Где:** `lib/backend/modules/messages.dart:597-609`, `lib/backend/modules/messages.dart:511-518`, `lib/backend/modules/messages.dart:997-1001`


**Проблема:** fetchHistory runs _parseMessage synchronously per message on the UI isolate and only awaits Future.delayed(Duration.zero) every 20 items — a microtask yield that keeps all CPU work (attachment objects, Map copies) on the UI isolate and merely interleaves it with frame callbacks. fetchDelayedMessages (backward:150) does the same synchronous loop with no yield at all. Meanwhile the equivalent local-DB work in fromDbRowsAsync already offloads to a background isolate via compute() once rows.length>=20, so identical work is treated inconsistently by data source.


**Решение:** Make map-to-CachedMessage parsing a top-level/static function (reused by fromDbRowsAsync) and route fetchHistory/fetchDelayedMessages through compute() once the batch is large enough, dropping the Duration.zero micro-yield which does not move the work off-thread.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [L]</b> — Every fine-grained event triggers a full chat-list reload and full reparse</summary>


**Где:** `lib/backend/modules/chats.dart:455-456`, `lib/backend/modules/chats.dart:1101-1110`


**Проблема:** chatsChanged is a single global ValueNotifier<int> bumped by virtually every event (new message, read receipt, reaction change, mute toggle, mark, rename...). Listeners react by calling getChats(accountId), which reloads every chat row from SQLite and re-runs CachedChat.fromDbRow for all of them. fromDbRow (lines 115-138) jsonDecodes participants (_parseParticipants) and CSV-splits options and admins (_decodeOptions/_decodeAdmins) per row. For an account with hundreds of chats, a single incoming message anywhere causes an O(all chats) DB read plus O(all chats) JSON/CSV decode, repeated on every subsequent unrelated event.


**Решение:** Emit which chat id(s) changed (chatsChanged could carry the changed id, or reuse the existing messageEvents-style broadcast stream) so listeners can patch just the affected CachedChat in their in-memory list instead of re-fetching and re-parsing the entire table on every bump.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [S]</b> — SelfCheckService polls every 10s forever with no app-lifecycle awareness</summary>


**Где:** `lib/backend/modules/self_check.dart:15-42`, `lib/main.dart:465-482`


**Проблема:** After init(api), Timer.periodic(10s) fires indefinitely and forces a network round trip via PresenceFetch.get(accountId, forceRefresh: true) (bypassing the cache TTL) regardless of whether the app is foregrounded, backgrounded, or the screen is off. main.dart already has a didChangeAppLifecycleState handler (lines 465-482, wiring CallController, api.wakeUp, DebugSessionLog) but SelfCheckService is never hooked in, so this periodic forced network work keeps draining battery/data while the app is paused/hidden/detached.


**Решение:** Give SelfCheckService pause()/resume() (or an AppLifecycleState observer) and call them from the existing didChangeAppLifecycleState handler: cancel the timer on paused/hidden/detached and restart it (with an immediate checkNow()) on resumed.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [S]</b> — Timezone database reinitialized on every connect/reconnect attempt</summary>


**Где:** `lib/backend/api.dart:209`


**Проблема:** tz.initializeTimeZones() runs synchronously inside sendHandshake(), which connect() calls on every attempt — including every auto-reconnect scheduled by _scheduleReconnect (delay 2-15s on a flaky link, api.dart:490-497). It re-parses the full embedded IANA timezone database on the calling isolate each time even though the data never changes after first load. Confirmed at api.dart:209, reached via connect()->sendHandshake() at api.dart:128.


**Решение:** Guard with a one-time static flag (if (!_tzInitialized) { tz.initializeTimeZones(); _tzInitialized = true; }) or initialize once at app startup before any Api instance is created, so reconnects never repeat the parse.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [S]</b> — Privacy setup issues four separate chatUpdate round-trips instead of one merged, atomic request</summary>


**Где:** `lib/backend/modules/cloud_storage.dart:84-91`


**Проблема:** _configurePrivacy calls ChatsModule.setChatOptions four times concurrently, each sending its own Opcode.chatUpdate packet for one boolean, even though setChatOptions already accepts a full options: Map<String,dynamic> (chats.dart:1506-1516, verified) that packs everything into one chatUpdate. This quadruples round-trips per group setup/repair, and because the four requests are independent, a partial failure leaves the group in an inconsistent privacy state (e.g. icon-lock applied but admin-only-call not) with no atomicity or rollback.


**Решение:** Merge all four into one call: setChatOptions(api, chatId: chatId, options: {'ONLY_OWNER_CAN_CHANGE_ICON_TITLE': true, 'ONLY_ADMIN_CAN_ADD_MEMBER': true, 'ALL_CAN_PIN_MESSAGE': false, 'ONLY_ADMIN_CAN_CALL': true}), dropping Future.wait and making the configuration atomic from the client's perspective.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [S]</b> — Desktop gallery listing does synchronous filesystem I/O on the calling isolate</summary>


**Где:** `lib/core/media/gallery_source.dart:131-147`, `lib/frontend/widgets/attachment/attachment_sheet.dart:120`


**Проблема:** _DesktopGallerySource.load calls dir.listSync(followLinks: false) and entity.statSync() for every entry synchronously (lines 136-138). It is awaited from AttachmentSheet at line 120 when the picker opens; for a Pictures folder with thousands of files this blocks the UI isolate's event loop for the whole scan (a blocking stat syscall per file), freezing the UI exactly when the user opens the attachment sheet.


**Решение:** Replace the synchronous scan with the async Directory.list() stream plus await FileSystemEntity.stat(), or move the entire walk into Isolate.run/compute. Since load is already async, this is a drop-in change with no caller-API impact.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [M]</b> — Opus/Ogg voice-note encoding runs synchronously on the UI isolate</summary>


**Где:** `lib/core/media/opus_ogg_encoder.dart:54-88`, `lib/frontend/screens/chats/chat_screen.dart:5025-5039`


**Проблема:** wavToOggOpus -> _encodePcm loops over every 20ms PCM frame making a blocking FFI encode call and then assembles the Ogg container, all synchronously. _transcodeWavToOgg (chat_screen.dart:5025) awaits it directly on the calling isolate with no offload, so for longer recordings the per-frame encode plus WAV parse stalls the UI thread and produces visible jank right after the user stops recording.


**Решение:** Move the encode into Isolate.run(() => ...). Note this is NOT a bare drop-in: opus_dart's initOpus is per-isolate global state, so the spawned isolate must itself call OpusOggEncoder.ensureAvailable()/initOpus before encoding (or use a long-lived worker isolate initialized once). Keep the WAV read on the main isolate and pass the bytes in.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [M]</b> — Global presence revision counter forces every listener to rebuild on any user's presence change</summary>


**Где:** `lib/core/cache/info_cache.dart:138`, `lib/core/cache/info_cache.dart:144-149`, `lib/core/cache/info_cache.dart:159-170`, `lib/frontend/widgets/online_dot.dart:23-26`, `lib/frontend/screens/chats/chat_screen.dart:543`, `lib/frontend/screens/chats/chat_screen.dart:1067`


**Проблема:** PresenceFetch.revision is a single ValueNotifier<int> bumped on every apply()/primeAll()/clear(). OnlineDot (one per row in chat/contact lists) subscribes to this one global notifier, so a presence packet for one unrelated user rebuilds every visible OnlineDot's ValueListenableBuilder subtree. ChatScreen registers a global _onPresenceChanged listener on the same notifier (line 543/1067) that recomputes header status on every system-wide presence event, not just the peer it cares about. Individual rebuilds are cheap (AnimatedScale + Container), but the fan-out to all rows on each event is unnecessary work.


**Решение:** Key notifications per user id, mirroring the existing keyed-listenable pattern already used in this codebase (e.g. ChatActivityStore.instance.listenable(chatId), used in the same chat_screen.dart). Store a keyed pub/sub (e.g. Map<int, ValueNotifier<bool>>) in PresenceFetch, have apply()/primeAll() notify only the ids that actually changed, and have OnlineDot/ChatScreen listen to `PresenceFetch.listenable(userId)` so only affected consumers rebuild.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [M]</b> — MediaCache eviction sorts by calling blocking statSync twice per comparison on the main isolate</summary>


**Где:** `lib/core/utils/media_cache.dart:169-170`


**Проблема:** `_enforceLimit` (run after a download that pushes the cache over its byte limit) sorts cache files with `a.statSync().modified.compareTo(b.statSync().modified)`. `statSync` is blocking synchronous disk I/O on the calling (UI) isolate, and the comparator re-stats both files on every comparison — O(n log n) synchronous stat calls, redundantly re-statting the same file many times. With a large cache (thousands of files) this blocks the UI isolate mid-sort and can cause a visible frame hitch right after a download. Note the surrounding methods deliberately use async `dir.list()`/`await entity.length()`, so this sync call is inconsistent with the file's own style.


**Решение:** While iterating `dir.list()`, `await entity.stat()` once per file into a list of `(File, DateTime)` pairs, then sort by the precomputed timestamp — eliminating both the synchronous call and the repeated per-comparison stats.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [M]</b> — Lottie sticker frames are rasterized synchronously (toImageSync) in the build/paint path</summary>


**Где:** `lib/frontend/widgets/sticker_lottie.dart:64`, `lib/frontend/widgets/sticker_lottie.dart:86`, `lib/frontend/widgets/sticker_lottie.dart:357`


**Проблема:** _StickerFrames.frameAt is called directly from the ValueListenableBuilder<int> builder in _StickerLottieState.build() (line 357). On a cache miss it synchronously does drawable.draw(...) then picture.toImageSync(pxSize, pxSize) (line 86) inline during build/paint. Each distinct frame index is a miss the first time the ticker reaches it (up to 30 fps), so every animated sticker bursts through this blocking raster path once per unique frame on its first loop. Impact is bounded — frames are cached after first render and StickerLoadGovernor drops to _lastImage under load — but the governor is a reactive workaround for jank that this synchronous call directly causes.


**Решение:** Decouple rasterization from build: pre-render frames ahead of the ticker on a scheduler/idle callback using the async picture.toImage() and have build() only ever read an already-rendered frame from _images, turning the governor into a true fallback instead of the primary defense.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [S]</b> — PollView force-refetches on every mount, defeating the module's cache and in-flight dedup</summary>


**Где:** `lib/frontend/widgets/poll_view.dart:61`


**Проблема:** initState calls pollsModule.fetch(chatId, messageId, pollId, force: true) unconditionally. PollsModule.fetch short-circuits on `_cache.containsKey(pollId) || _inFlight.contains(pollId)` only when force is false (polls.dart:24), and the post-vote refresh already passes force:true (polls.dart:84). Because poll bubbles live in a chat ListView.builder and are disposed/recreated as the user scrolls, every scroll-back-in triggers a fresh network round trip for data that is very likely already cached and unchanged.


**Решение:** Call fetch(...) with force:false on mount so the existing cache/in-flight guards apply; reserve force:true for the post-vote refresh path (already used in PollsModule.vote) or an explicit pull-to-refresh.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [S]</b> — Shimmer effect duplicated across two screens with an AnimationController that never stops</summary>


**Где:** `lib/frontend/screens/profile/security_screen.dart:34-45`, `lib/frontend/screens/profile/security_screen.dart:146-184`, `lib/frontend/screens/profile/devices_screen.dart:36-47`, `lib/frontend/screens/profile/devices_screen.dart:385-444`


**Проблема:** Both screens independently implement the same shimmer placeholder: AnimationController(...)..repeat() started unconditionally in initState, AnimatedBuilder with Opacity(0.3 + 0.2 * sin(controller.value * pi * 2)). Confirmed identical. In both, the controller is only stopped in dispose(), so repeat() keeps the ticker scheduling frames for the entire screen lifetime even after _isLoading flips false and the shimmer widgets are no longer built — continuous frame scheduling that prevents the engine from going idle.


**Решение:** Extract one shared ShimmerBox widget (owning its own controller) into frontend/widgets and call controller.stop() as soon as loading completes (or only run repeat() while the loading flag is true), reused by both screens.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [M]</b> — CallScreen calls setState on the whole widget tree on every audio-level info tick</summary>


**Где:** `lib/frontend/screens/calls/call_screen.dart:224-231`


**Проблема:** The infoUpdates listener bound in _bind() responds to every info tick (which fires on audio-level/speaking-set changes during an active call) by recomputing participants and calling an unconditional setState(() {}), rebuilding the entire CallScreen including any group-call GridView of participant tiles, just to move a speaking-highlight border. Confirmed at lines 224-231. Widget rebuilds of RTCVideoView are cheaper than a full re-render, so impact is moderate, but the whole-screen rebuild several times per second during a call is still wasteful.


**Решение:** Expose speaking/mute/video state via a ValueNotifier/ChangeNotifier keyed by participant and rebuild only the affected tile with ValueListenableBuilder, instead of setState on the whole screen on every info tick.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — PacketReceiver re-copies the whole pending buffer on every socket chunk</summary>


**Где:** `lib/core/transport/receiver.dart:57`, `lib/core/transport/receiver.dart:65`, `lib/core/transport/receiver.dart:66`, `lib/core/transport/receiver.dart:69`


**Проблема:** `_append` (receiver.dart:57-72) allocates a new Uint8List of exact size `pending + data.length` and copies both the previously-buffered unconsumed tail and the new chunk into it on every `feed()` call while a packet is still incomplete. For a packet spread across many TCP reads (large chatHistory/chatsList/foldersGet sync responses), this is an O(n^2) copy pattern. The file's own doc comment (receiver.dart:19-21) claims accumulation happens 'без перекопирования всего буфера на каждый чанк', but that only holds for the consumed prefix; the pending unconsumed tail is fully re-copied on each append. Absolute cost is modest (memmove, only on large syncs), hence low severity, but it contradicts the documented behavior and grows with payload size.


**Решение:** Grow the backing buffer with spare capacity (e.g. doubling) instead of an exact fit, mirroring the `ensure()` doubling helper already present in lz4_block.dart:13-16, and copy the unconsumed tail once per growth event rather than once per chunk — turning assembly of one large packet from O(n^2) into amortized O(n).

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — lastMsgFormatRanges getter re-parses JSON on every access with no memoization</summary>


**Где:** `lib/backend/modules/chats.dart:88-96`


**Проблема:** lastMsgFormatRanges is a getter that calls jsonDecode(raw) and parseFormatElements(...) fresh on every read. Any widget that accesses it more than once per build, or on every rebuild while the chat object is unchanged (e.g. in a scrolling ListView), repeats the JSON decode and format-range parse unnecessarily.


**Решение:** Memoize lazily rather than eagerly: use `late final List<FormatRange> lastMsgFormatRanges = _computeFormatRanges();` so the parse runs at most once per instance and only when actually accessed. Do NOT compute it eagerly in the constructor initializer list (unlike lastMsgTextOneLine), since that would parse format elements for every chat including off-screen ones and would worsen the bulk-reparse cost noted elsewhere.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Login persists 8 sync values via 8 sequential single-row inserts</summary>


**Где:** `lib/backend/modules/account.dart:1300-1324`, `lib/core/storage/app_database.dart:436-447`


**Проблема:** _saveSyncState awaits AppDatabase.setSyncValue(...) eight times in sequence on every login (serverTime, lastLogin, chatsSync, contactsSync, callsSync, draftsSync, bannersSync, presenceSync, plus optional configHash). Each call is its own `db.insert(...)` (confirmed at app_database.dart:436-447) — a separate platform-channel round trip and statement — serialized on the login path. Minor since login is infrequent, but trivially batchable.


**Решение:** Add `AppDatabase.setSyncValues(accountId, Map<String,String> values)` that wraps the rows in a single `db.batch()`/transaction, and have _saveSyncState build the map and call it once (the _persistEntryBannerApps loop just below can use the same batched API).

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [M]</b> — Response parser re-decodes the whole accumulated body as UTF-8 on every incoming chunk</summary>


**Где:** `lib/backend/modules/file_uploader.dart:557-584`, `lib/backend/modules/file_uploader.dart:586-591`


**Проблема:** _readFullResponse's tryParse() re-scans the entire accumulated buffer for the header terminator from index 0 and utf8.decodes both header and full body-so-far, and is invoked again on every chunk delivered by socket.listen (line 589), giving O(n^2) decode/allocation work to detect completion. In practice these are small CDN ack/JSON responses (typically one or two chunks), so the quadratic cost is negligible today — worth cleaning up but not urgent.


**Решение:** Cache the header-end offset once found instead of re-searching from 0, and track completion via raw byte checks (running content-length counter / chunked terminator on the new suffix), performing utf8.decode only once when the response is complete.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Every ws2 frame is JSON re-encoded for a trace log that is discarded in release</summary>


**Где:** `lib/core/calls/ws2_signaling.dart:151-155`


**Проблема:** _onFrame unconditionally calls jsonEncode(decoded) at line 151 and builds a truncated dump string before passing it to logger.t. In release builds the logger level is Level.info (core/utils/logger.dart:27-29), so the trace call is dropped, but the re-serialization still runs on every incoming signaling frame (including large SDP offer/answer frames). Volume is control-plane only, so cost is modest, but it is pure waste in production.


**Решение:** Pass a closure to the logger so serialization is lazy (the printer already supports a Function message via _stringifyMessage in logger.dart:137), e.g. logger.t(() => dump-building expression), or guard the encode with an explicit level check so the jsonEncode only runs when the trace sink is active.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [M]</b> — Desktop URL-scheme registration shells out to OS commands on every launch without checking current state</summary>


**Где:** `lib/core/links/desktop_url_scheme.dart:20-66`, `lib/core/links/deep_link_service.dart:26`


**Проблема:** `DesktopUrlScheme.register()` runs once per launch (deep_link_service.dart:26, guarded only by `_started`) and unconditionally spawns external processes: on Windows 3 `reg add` calls per scheme x 2 schemes = 6 processes; on Linux 2 `xdg-mime default` + 1 `update-desktop-database`. The `.desktop` file write is guarded by a content comparison (lines 58-59), but the `reg`/`xdg-mime`/`update-desktop-database` calls always run, re-asserting already-correct state and rewriting the Linux desktop-database index every launch. Minor startup overhead, desktop-only, best-effort.


**Решение:** Query current registration first (`reg query` on Windows, `xdg-mime query default` on Linux) and skip the mutating `Process.run` calls when it already points at the current executable/scheme.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Forwarded-sender names resolved with sequential awaited network calls</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:3680`


**Проблема:** _loadForwardedSenderNames resolves each unknown forwarded sender one at a time: `for (final id in forwardIds) { final name = await messagesModule.searchContactById(id); ... }`, so N unknown senders cost N sequential round trips. The sibling _loadGroupSenderNames, invoked on the same history-load paths, batches equivalent lookups via messagesModule.ensureContactNames(unknownIds) in a single call.


**Решение:** Batch with Future.wait, or add a plural searchContactsByIds module call analogous to ensureContactNames, so multiple forwarded senders resolve in one round trip.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [M]</b> — O(n) message lookups by id on every realtime/upload event</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:2129-2150`, `lib/frontend/screens/chats/chat_screen.dart:3376`, `lib/frontend/screens/chats/chat_screen.dart:6446`


**Проблема:** Incoming message/edit/delete/reaction/upload/send-confirmation events resolve their target via `_messages.indexWhere((m) => m.id == ...)` at 20 confirmed call sites — a full scan of the loaded message list per event. Real, but low materiality: the list is bounded to loaded history (hundreds, occasionally low thousands), a scan is microseconds, and the subsequent `_bumpMessages()`/rebuild dominates the cost. The suggested index map also adds sync burden across all 20 mutation sites.


**Решение:** Only if this measurably shows up: maintain an auxiliary `Map<String, int>` (id -> index) kept in sync with every `_messages` mutation, or use a `LinkedHashMap`-backed source of truth, to make id lookups O(1). Otherwise leave as-is; not worth the added invariant.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [M]</b> — Search-results list uses a non-virtualized ListView with children spread inline, eagerly building every result tile (and its avatar network load)</summary>


**Где:** `lib/frontend/screens/chats/search_screen.dart:238-286`


**Проблема:** _buildBody builds a plain ListView(children: [...]) with every section spread inline (for (final row in _contacts) ..., for (final hit in _messages) ..., etc.). All result tiles across every section are constructed and mounted immediately rather than on demand, and because each _ResultTile holds a KometAvatar (CachedNetworkImage), all avatar network loads are kicked off at once regardless of what is on screen.


**Решение:** Flatten the sections into a single index-based list and render with a builder-style list (ListView.builder or a CustomScrollView with SliverList.builder per section) so off-screen tiles and their avatar requests are deferred until scrolled into view.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Two independent info fetches in ChatInfoScreen._load() for a dialog run sequentially instead of in parallel</summary>


**Где:** `lib/frontend/screens/chats/chat_info_screen.dart:156-169`


**Проблема:** For a DIALOG chat, ContactInfoFetch.get(_otherId!) (line 156) is awaited to completion before PresenceFetch.get(_otherId!) (line 163) even starts, though the two are independent (profile info vs. presence) and neither depends on the other. This adds an unnecessary extra round-trip of latency to opening a dialog-info screen on a cold cache.


**Решение:** Fire both concurrently with Future.wait([...]) and destructure results, as search_screen.dart already does for its parallel searches in _runSearch. Note _isBot is derived from the contact result and used by _tabs, so keep that ordering intact after the join.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Contact picker re-filters and re-lowercases the whole list on every keystroke with no debounce or memoization</summary>


**Где:** `lib/frontend/screens/chats/create_group_flow.dart:230-235`, `lib/frontend/screens/chats/create_group_flow.dart:282`


**Проблема:** _buildPickerStep recomputes `_all.where((c) => _displayName(c).toLowerCase().contains(query)).toList()` from scratch on every build, and the search TextField's onChanged is `(_) => setState(() {})` with no debounce, so each character re-walks the full contact list and re-concatenates/re-lowercases every contact's display name even though those strings never change between keystrokes.


**Решение:** Precompute a lowercase display name once per contact when _all is loaded (store (contact, lowerName) pairs or a small wrapper) and filter against the cached strings. This is a minor cost for typical list sizes, so treat it as low priority.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Voice-message progress ticker keeps polling after playback pauses or ends</summary>


**Где:** `lib/frontend/widgets/message_bubble.dart:2912`, `lib/frontend/widgets/message_bubble.dart:2881`


**Проблема:** `_togglePlay` creates `_ticker = Timer.periodic(60ms, (_) => _onTick())` only on the first play (inside the `_player == null` branch); subsequent pause/resume take the early-return `_player != null` path and never touch `_ticker`, which is only cancelled in `dispose()`. So once any voice note has been played, its 60ms timer keeps firing for the widget's whole lifetime, calling `player.currentPosition` and running clamp math while paused/ended. (Impact is bounded: `_progress` is a ValueNotifier that dedupes equal writes, so a paused position does not trigger rebuilds — the cost is the wasted 60ms polling itself, scaling with how many voice bubbles have been played.)


**Решение:** Start the ticker in `_onPlayerState` when transitioning to `PlayerState.playing` and cancel it when transitioning away (pause/ended), recreating on the next play, instead of keeping one ticker alive for the widget's lifetime.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Sticker section always shows a loading shimmer even when every sticker is already cached</summary>


**Где:** `lib/frontend/widgets/sticker_panel.dart:307`, `lib/frontend/widgets/sticker_panel.dart:315`


**Проблема:** _StickerSectionState always initializes `_loaded = false` and awaits stickersModule.ensureStickers before flipping it, even when every id is already cached and ensureStickers does no network work. Because the vertical list is a virtualized ListView.builder, sections are disposed/recreated on scroll, so already-loaded sections re-enter the shimmer placeholder and pay an extra microtask/rebuild every time they scroll back into view, purely because the check is async rather than synchronous.


**Решение:** In initState, synchronously check whether every id already has stickersModule.cachedSticker(id) != null and set _loaded = true immediately in that case, falling back to the async ensureStickers await (and shimmer) only when something is actually missing.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Locale-splitting RegExp recompiled on every keystroke</summary>


**Где:** `lib/frontend/screens/profile/spoof_screen.dart:66`, `lib/frontend/screens/profile/spoof_screen.dart:276`


**Проблема:** _syncDeviceLocale is registered as a listener on _localeController (initState line 60) and therefore runs on every character typed into the locale field; it constructs a new RegExp(r'[-_]') each call (line 66). The same literal is re-constructed in _applyPreset (line 276). Confirmed. Minor allocation, but trivially avoidable.


**Решение:** Hoist a single static final _localeSplitter = RegExp(r'[-_]'); at class scope and reuse it in both _syncDeviceLocale and _applyPreset.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Regex recompiled on every phone-input keystroke, plus a vestigial empty if-branch</summary>


**Где:** `lib/frontend/screens/auth/login_screen.dart:892-895`, `lib/frontend/screens/auth/login_screen.dart:1079,1082`, `lib/frontend/screens/auth/login_screen.dart:1109-1110`


**Проблема:** The phone `TextField.onChanged` (892-895) and `_PhoneInputFormatter.formatEditUpdate` (1079, 1082, called by Flutter on every keystroke) each construct a fresh `RegExp(r'\D')` instead of reusing one compiled pattern — the formatter builds it twice per call. Additionally, lines 1109-1110 contain `if (digitIdx == text.length && i < country.phoneGroupSeparators.length - 1) {}` — an empty-bodied `if` with no effect, left over from an incomplete edit, which makes the group-separator loop harder to trust.


**Решение:** Hoist a single `static final RegExp _nonDigit = RegExp(r'\D');` and reuse it in both the formatter and the onChanged handler; delete the empty dead `if` statement.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Country search re-lowercases every country name on every keystroke</summary>


**Где:** `lib/frontend/screens/auth/select_country_screen.dart:37-50`


**Проблема:** `_filterCountries` runs `c.ru.toLowerCase()` and `c.en.toLowerCase()` for every country on every keystroke; these fields never change, so the same strings are lower-cased and reallocated repeatedly instead of once. Modest given the bounded country-list size, but it is wasted allocation on the search path that scales with list length times keystrokes.


**Решение:** Precompute lowercase `ru`/`en` (and phoneCode) once in `initState` into a cached search-key list, or cache them on `CountryName`, and filter against the cached keys.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Schedule-time picker eagerly materializes all 366 day items and rebuilds every wheel on any wheel's scroll</summary>


**Где:** `lib/frontend/widgets/schedule_time_picker.dart:217-241`, `lib/frontend/widgets/schedule_time_picker.dart:150-179`


**Проблема:** `_wheel` builds `CupertinoPicker(children: List.generate(count, ...))` with eagerly materialized widgets — 366 Align/Padding/Text for the day column (each computing `_dayLabel`). `onSelectedItemChanged` calls `setState(() => onChanged(i))` (line 226), which re-runs `_ScheduleSheetState.build()` and reconstructs all three wheels — including the full 366-item day list — every time the user crosses an item on any of the three wheels, not just the day wheel. The setState is needed to refresh the button label, but rebuilding the wheels' child lists is wasted. Confirmed. (Impact is real but bounded: it fires on discrete item changes, not per frame, and Text/Align construction is cheap — hence low.)


**Решение:** Switch `_wheel` to `CupertinoPicker.builder(itemBuilder: ..., childCount: count)` so items build lazily per visible index, and/or split each column into its own small stateful widget so scrolling one wheel doesn't rebuild the others' item lists.

</details>


### Lifecycle, dispose, and unbounded caches  (14 — 0 high)

_Notifiers, timers, temp files and in-memory caches are created but never released or bounded, leaking for the life of the process or the screen._

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [L]</b> — ContactCache persists the entire cache as one SharedPreferences JSON blob with no eviction, bypassing the SQLite layer</summary>


**Где:** `lib/backend/modules/messages.dart:15-108`


**Проблема:** ContactCache holds three static Maps that grow with every distinct contact id for the process lifetime with no eviction (unlike FileHistoryCache in the same file, capped at _maxEntries=50 at lines 183/217). _save() unions all ids across all three maps and JSON-encodes the whole thing to a single prefs key on every 3s-debounced change, so the write cost grows O(n) with contact count, even though the app already has AppDatabase used for everything else message-related.


**Решение:** Back ContactCache with an AppDatabase table (contact_id, name, avatar, options) doing per-row upserts instead of a monolithic JSON blob, consistent with how CachedMessage persists; add an LRU cap or accept the bound of real contact count once persisted per-row.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — MediaCache.getOrDownload has no in-flight de-duplication; concurrent requests for the same key race on a shared .part file</summary>


**Где:** `lib/core/utils/media_cache.dart:58-104`


**Проблема:** `getOrDownload` checks `existing(name)`, and if absent downloads to a fixed `<name>.part` path (line 67) then `part.rename(file.path)` (line 85). There is no tracking keyed by `name`, so two concurrent callers for the same cache key (e.g. the same image attachment shown as both a reply preview and the message itself, or a rebuild re-triggering the fetch before the first completes) both open the same `.part` via `openWrite()`, interleave writes, and both rename the same file — producing a corrupted/partial cached file that later opens as broken media.


**Решение:** Maintain a `static final Map<String, Future<File?>> _inFlight` keyed by cache name; when a download for the same name is already running, return the existing Future instead of starting a second write to the shared .part path.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — VideoPlayerScreen quality switch lacks a generation guard, racing controller state on rapid switches</summary>


**Где:** `lib/frontend/widgets/video_player_screen.dart:36`, `lib/frontend/widgets/video_player_screen.dart:47`, `lib/frontend/widgets/video_player_screen.dart:56`, `lib/frontend/widgets/video_player_screen.dart:67`


**Проблема:** _load() captures `final old = _controller`, sets `_controller = controller`, then `await controller.initialize()` before mutating state. There is no `controller == _controller` (or monotonic token) check after the await. If _switchQuality runs twice in quick succession, the second call overwrites _controller while the first is still initializing; when the first resumes it calls seekTo/addListener/play on a controller that is no longer _controller — which the second call may already have disposed via its own `old?.dispose()` — leaving either an orphaned playing controller or a thrown PlatformException swallowed by `catch (_) { setState(() => _error = true); }`, so the user sees a spurious playback error even though the newest controller is fine. Triggering it requires rapid successive quality selections, so probability is moderate, but the fix is the correct pattern regardless.


**Решение:** Add an incrementing `_loadGeneration` int; capture it at the start of _load and, after every await, `if (generation != _loadGeneration) { await controller.dispose(); return; }` before touching _controller or calling further controller methods. This makes stale loads a no-op and removes the fragile old/current juggling.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — Edited-photo temp files leak on sheet cancel; cleanup gated by a duplicated filename-prefix convention</summary>


**Где:** `lib/frontend/widgets/attachment/media_preview_screen.dart:105`, `lib/frontend/widgets/attachment/attachment_sheet.dart:73`, `lib/frontend/widgets/attachment/attachment_sheet.dart:100`, `lib/frontend/widgets/attachment/photo_editor.dart:389`, `lib/frontend/widgets/attachment/photo_editor.dart:1016`, `lib/frontend/widgets/attachment/photo_editor.dart:2336`


**Проблема:** Each _bake writes a JPEG into getTemporaryDirectory() named `komet_crop_/komet_edit_/komet_adj_<ts>.jpg`. `_disposeTemp` (media_preview_screen.dart:105) only deletes a file whose name starts with the hardcoded `'komet_'` and only when a *newer* edit supersedes an older one. If the user closes AttachmentSheet without sending, `_AttachmentSheetState.dispose()` (attachment_sheet.dart:100) never touches `_edits`, so every baked JPEG produced that session stays on disk until the OS clears the cache dir. The prefix string is also an implicit contract duplicated across three editors, so renaming a prefix in one silently disables its cleanup.


**Решение:** Track produced temp files explicitly instead of inferring ownership from a filename prefix: keep the baked File in a session-scoped Set in AttachmentSheet, and on dispose delete every tracked file that is not part of the final sent selection (the sent files are handed to onSend and must be preserved). This closes the cancel leak and removes the string-convention coupling.

</details>

<details>
<summary><b>🟠 MED · ОПТ · [S]</b> — In-memory caches never evict, growing for the life of the process (chiefly the message session cache)</summary>


**Где:** `lib/core/cache/info_cache.dart:25`, `lib/core/cache/info_cache.dart:137`, `lib/core/cache/message_session_cache.dart:11`, `lib/core/cache/message_session_cache.dart:18-29`


**Проблема:** InfoCache._entries (backing ContactInfoFetch/ChatInfoFetch/PresenceFetch) and PresenceFetch._live only grow via putIfAbsent/assignment; the only shrink path is a full clear() on logout. The material one is MessageSessionCache._store, which retains a full copied List<CachedMessage> (text, payload, attachments, edit history) per chat ever opened this session, uncapped. A long session browsing many chats accumulates full history for all of them. The InfoCache maps hold small maps so their growth is minor, but MessageSessionCache can be significant.


**Решение:** Bound MessageSessionCache with a simple LRU (access-order LinkedHashMap, evict oldest past a cap of ~20-30 recent chats). Optionally apply the same to InfoCache (~200 entries). This keeps memory bounded regardless of session length without changing call sites.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [M]</b> — UploadManager exposes raw mutable UI callbacks and drops errors on the stream-level onError path</summary>


**Где:** `lib/backend/modules/upload_manager.dart:17-19`, `lib/backend/modules/upload_manager.dart:91-95`


**Проблема:** onProgress/onDone/onError are plain mutable fields on a process-wide singleton, set by whichever screen is currently mounted, with nothing enforcing that a screen clears them on dispose — a closure left in onProgress/onDone keeps the disposed State reachable and can fire into an unmounted widget, and two concurrent observers silently clobber each other. Separately, the top-level `.listen(..., onError: (_) { _sub = null; UploadNotificationService.stop(); })` (lines 91-95) never calls the public onError callback, unlike the UploadError case just above it (line 88) — any failure reaching this branch is invisible to the UI.


**Решение:** Replace the mutable callback fields with a proper subscription API — a broadcast Stream<UploadEvent> the manager exposes, or a register-listener method returning a disposer — so screens subscribe/unsubscribe deterministically in initState/dispose. Route the top-level stream onError into the same UI-facing error path used by the UploadError case so no failure is silently dropped.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [M]</b> — App backgrounding does not stop active voice/video-note recording</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:988`, `lib/frontend/screens/chats/chat_screen.dart:5190`


**Проблема:** didChangeAppLifecycleState only calls _saveDraft on paused/inactive; it never checks _isRecordingVoice/_isRecordingNote nor stops the recorders. If the user is mid-recording (voice or video note) when the app is backgrounded (incoming call, notification shade, home button), the mic/camera session keeps running unmanaged and _isRecordingVoice/_isRecordingNote can desync from the native recorder on resume. Both _stopVoiceRecording({required bool cancel}) (4970) and _stopNoteRecording({required bool cancel}) (5243) already exist and release their resources.


**Решение:** In didChangeAppLifecycleState, on paused/inactive, forcibly stop any in-flight recording via _stopVoiceRecording(cancel: true) / _stopNoteRecording(cancel: true) (and dispose the note camera) so the native session and UI state stay consistent across the lifecycle transition.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [S]</b> — Fire-and-forget Future.delayed writes to _highlightMessageId after it can be disposed, with no cancellation guard</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:3802`, `lib/frontend/screens/chats/chat_screen.dart:3920`, `lib/frontend/screens/chats/chat_screen.dart:1099`


**Проблема:** _jumpToMessage (3802-3807) and _scrollToLoadedMessage (3920-3925) both do `_highlightMessageId.value = messageId; Future.delayed(Duration(ms: 1400/1600), () { if (_highlightMessageId.value == messageId) _highlightMessageId.value = null; });` as fire-and-forget. `_highlightMessageId` is disposed unconditionally at dispose() line 1099 with no cancellation of these pending futures and no mounted check inside the callbacks. If the user pops ChatScreen within the 1.4-1.6s window, dispose() disposes the notifier, then the delayed callback assigns `.value = null`, which triggers notifyListeners on a disposed ChangeNotifier and throws a debug assertion (`used after being disposed`). Note: this fails only in debug builds — in release, ChangeNotifier.dispose zeroes the listener count so notifyListeners silently no-ops — so it is a development-time crash rather than a production one, but still a real latent bug and inconsistent with how _floatingDateTimer/_shimmerStartTimer are handled (they are stored as cancelable Timer fields and cancelled in dispose).


**Решение:** Store the delayed operation as a cancelable `Timer` field (`_highlightTimer?.cancel(); _highlightTimer = Timer(duration, () { if (!mounted) return; ... });`) and cancel it in dispose() before `_highlightMessageId.dispose()`, mirroring the existing timer handling in the same file. A leading `if (!mounted) return;` in both callbacks is a minimal alternative but the Timer-field approach matches convention.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — ComplaintsModule cache is never cleared on account switch, unlike sibling caches</summary>


**Где:** `lib/backend/modules/complaints.dart:11-50`, `lib/backend/modules/account.dart:1086-1088`, `lib/backend/modules/account.dart:1099-1101`, `lib/backend/modules/account.dart:1129-1131`


**Проблема:** beginAddAccount, loginWithToken and switchAccount all clear ContactCache, TranscriptionCache and ChatsModule state on switch, but ComplaintsModule's static `_cache` is never touched and the class exposes no clear()/reset(). Once populated it is served for every subsequently switched-to account. Impact is small in practice (complaint reasons are almost certainly global/locale-level rather than account-scoped), so this is mainly a cache-lifecycle consistency gap.


**Решение:** Add `ComplaintsModule.clear()` (set `_cache = null`) and call it alongside the other cache resets in beginAddAccount, loginWithToken and switchAccount to keep cache lifecycle uniform across modules.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [M]</b> — MediaDownloadProgress ValueNotifiers are never disposed or evicted</summary>


**Где:** `lib/core/utils/download_progress.dart:7-14`, `lib/frontend/widgets/message_bubble.dart:2664-2674`


**Проблема:** `MediaDownloadProgress._notifiers` is a static `Map<String, ValueNotifier<double?>>` that only ever grows via `putIfAbsent` in `notifier()`; nothing removes entries or calls `dispose()`. Callers (message_bubble.dart) set the value back to `null` on completion (line 2674) but never release the notifier, so one entry accumulates per distinct cache key ever viewed. Over a long-lived session scrolling many attachments this grows unbounded. Impact is small (each entry is tiny), so low severity, but it is a genuine unbounded-growth pattern for objects only meaningful during an in-flight download.


**Решение:** Add a `MediaDownloadProgress.release(key)` that disposes the notifier and removes the map entry when it has no listeners, called from message_bubble after the download settles (alongside the existing `set(cacheName, null)`).

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — _messageKeys map grows without bound for the life of the screen</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:3810`, `lib/frontend/screens/chats/chat_screen.dart:4715`


**Проблема:** _keyForMessage lazily allocates and caches a GlobalKey per message id in _messageKeys, used as the KeyedSubtree key for every rendered bubble (call sites at 3791, 3933, 4715). Unlike _separatorKeys (pruned every _buildCombinedItems call at line 4228) or the reaction/upload notifiers (disposed on prune), _messageKeys is never pruned, cleared, or dropped in dispose(). Across a long session with repeated _loadMoreHistory pagination it accumulates one entry per message ever loaded. The leak is small per entry, but it is an unbounded, inconsistent-with-siblings growth.


**Решение:** Prune _messageKeys alongside the reaction-notifier prune (drop ids no longer in _messages), and clear it in dispose().

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — GlobalKey map for messages is never pruned</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:3810-3813`, `lib/frontend/screens/chats/chat_screen.dart:396-404`


**Проблема:** `_messageKeys` is only ever added to via `putIfAbsent` in `_keyForMessage`, never pruned — unlike `_reactionNotifiers`, which has a matching `_pruneReactionNotifiers()` (lines 396-404) removing ids no longer in `_messages`. Over a long session with deep pagination, cleared history or many deletions, the map keeps a `GlobalKey` for every id ever seen, e.g. after `_clearHistory` empties `_messages` the keys remain. Minor unbounded retention.


**Решение:** Prune `_messageKeys` the same way `_pruneReactionNotifiers()` does — drop entries whose id is no longer in `_messages` when the list changes, and at minimum on `_clearHistory`.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [M]</b> — Gallery items/permission cached as static mutable fields on a private widget State</summary>


**Где:** `lib/frontend/widgets/attachment/attachment_sheet.dart:68`, `lib/frontend/widgets/attachment/attachment_sheet.dart:69`, `lib/frontend/widgets/attachment/attachment_sheet.dart:122`


**Проблема:** _AttachmentSheetState declares `static List<GalleryItem>? _cachedItems` and `static GalleryPermission _cachedPermission`, a process-lifetime cache living inside a private widget State rather than in the media layer. It is refreshed (each open does a silent _loadGallery), so staleness is limited, but the cache is invisible to and unreusable by any other screen that wants gallery data, and its lifetime/invalidation belong architecturally in core/media/gallery_source.dart, not hanging off a widget's static state.


**Решение:** Move the cache into GallerySource (or a small dedicated repository) as an instance-level cache with explicit invalidate()/TTL, exposed the same way other core state is exposed to widgets, instead of static state on a widget's private State class.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [S]</b> — setState after awaiting a confirm dialog with no mounted check in PerformanceScreen</summary>


**Где:** `lib/frontend/screens/profile/performance_screen.dart:53`, `lib/frontend/screens/profile/performance_screen.dart:69`


**Проблема:** _onChangeEnd awaits a modal confirm dialog (`await _showWarning(...)`, which returns showConfirmDialog) and, when the user declines, calls `setState(() => _value = _preZoneValue);` directly at lines 53 and 69 with no mounted guard. The mounted-after-await convention is widespread across the profile screens (many use `if (!mounted) return;`), so these two sites are inconsistent. If the underlying route is popped while the dialog is still open, the eventual setState throws `setState() called after dispose()`. The realistic trigger is narrow because the dialog is modal and sits on top of the screen, so this is a defensive/consistency fix rather than a likely crash.


**Решение:** Guard both call sites with `if (!mounted) return;` before setState, matching the pattern already used across the profile screens.

</details>


### Duplicated UI widgets and layout  (25 — 2 high)

_Settings rows, confirm/prompt dialogs, bottom-sheet chrome, avatars, spinners, headers, and overlay lifecycles are re-implemented per screen instead of extracted, and copies have drifted._

<details>
<summary><b>🔴 HIGH · ДУБЛЬ · [M]</b> — Every persisted setting reimplements the same load/save/ValueNotifier boilerplate — and inconsistently</summary>


**Где:** `lib/core/config/app_amoled.dart:4-18`, `lib/core/config/app_bubble_shape.dart:6-22`, `lib/core/config/app_bubble_behavior.dart:6-22`, `lib/core/config/app_message_actions_style.dart:6-21`, `lib/core/config/app_theme_mode.dart:6-21`, `lib/core/config/app_visual_style.dart:6-25`, `lib/core/config/app_chat_chrome.dart:6-42`, `lib/core/config/app_icon.dart:19-52`, `lib/main.dart:131-196`


**Проблема:** ~17 config classes independently hand-roll the identical shape: a pref-key string, a `static final ValueNotifier<T> current`, a `static Future<T> load()` that reads SharedPreferences, and a `static Future<void> save(T)` that writes and flips `current.value`. The contract is inconsistent: `AppIconConfig.load()` (app_icon.dart:29-34) self-assigns `current.value`, but every other class's `load()` only returns the stored value and relies on main.dart to also assign it. Verified: main.dart:131-148 is ~18 near-identical `final xFuture = X.load()` lines and 179-196 is the matching ~18 `X.current.value = await xFuture` lines. Miss one of those pairs and that toggle silently keeps its default forever regardless of what the user saved, with no compiler or runtime signal.


**Решение:** Introduce one generic `PersistedSetting<T>` (bool/int/double via a getter/setter pair on SharedPreferences) and one `PersistedEnum<T extends Enum>` in core/config that own the key, default, ValueNotifier, and a `load()` that always self-assigns `current.value` before returning. Replace each ad hoc class body with a one-line instance, e.g. `final appAmoled = PersistedSetting<bool>('app_amoled', false);`. Load becomes fire-and-forget (`unawaited(appAmoled.load())`), removing the main.dart load/assign pairing and eliminating the 'forgot to sync current' failure mode by construction.

</details>

<details>
<summary><b>🔴 HIGH · ДУБЛЬ · [M]</b> — WebAppScreen and DigitalIdWebScreen are near-complete duplicates of the same WebView screen</summary>


**Где:** `lib/frontend/screens/webapp/web_app_screen.dart:24-143`, `lib/frontend/screens/digital_id/digital_id_web_screen.dart:175-343`


**Проблема:** _WebAppScreenState and _DigitalIdWebScreenState carry identical fields (_controller, _launch, _loadError, _userAgent, _progress) and identical _load()/_handleBack()/build()/PopScope/AppBar-with-progress-bar/InAppWebViewSettings/onProgressChanged/onReceivedError wiring. DigitalIdWebScreen only adds initialUserScripts, a closeWebApp JS handler, debug console/loadStart hooks, and a custom shouldOverrideUrlLoading. Confirmed verbatim in both files. Any future change to WebView setup (cookies, permission prompts, progress handling, back navigation) has to be applied twice and will drift.


**Решение:** Give WebAppScreen optional hook parameters (extraUserScripts, onWebViewCreated, shouldOverrideUrlLoading, onConsoleMessage/onLoadStart for debug) and have DigitalIdWebScreen construct a WebAppScreen with those hooks instead of re-implementing the whole screen.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Five near-identical optimistic-upload send flows duplicate the same lifecycle</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:5060`, `lib/frontend/screens/chats/chat_screen.dart:5272`, `lib/frontend/screens/chats/chat_screen.dart:6133`, `lib/frontend/screens/chats/chat_screen.dart:6239`, `lib/frontend/screens/chats/chat_screen.dart:6350`


**Проблема:** _sendVoice, _sendVideoNote, _sendPhotos, _sendVideo and _sendScheduledPhotos each reimplement the same control flow: allocate tempId, insert optimistic CachedMessage with a 'sending' status and an attachment, haptics + scroll-to-bottom, request an upload URL, upload with a progress ValueNotifier, call the module send method, swap the temp message for the real one via CachedMessage.fromPushPayload or mark it error, dispose the progress notifier, delete the local temp file. Only the attachment type, upload endpoint, and module call differ. Error/dispose handling is copy-pasted and has already drifted (e.g. _sendPhotos lacks the file.delete() cleanup the others have; scheduled variants diverge further). The generic _sendAttachMessage (line 6420) already owns the post-send replace/error lifecycle but does not cover the upload phase, so none of these five reuse it.


**Решение:** Extend the _sendAttachMessage-style helper to take an optional upload step (a Future<String?> Function(ValueNotifier<List<double>> progress) plus a List<MessageAttachment> Function(String token) builder) and route all five paths through it, so upload, progress-notifier disposal, temp-file cleanup and error marking live in one place and can't drift per media type.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Header row tree duplicated wholesale for glossy vs. material chrome</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:2427-2603`, `lib/frontend/screens/chats/chat_screen.dart:2605-2748`, `lib/frontend/screens/chats/chat_screen.dart:2357-2425`, `lib/frontend/screens/chats/chat_screen.dart:2750-2865`


**Проблема:** `_glossyHeaderRow` and `_materialHeaderRow` rebuild the identical structure — back button + unread badge, avatar + online dot, name + verified icon + status text, schedule/call/more-menu cluster — twice, differing only in whether each piece is wrapped in a `GlossyPill` and in paddings/sizes/icon weights. The same glossy/non-glossy duplication recurs in `_searchTopBar` and `_selectionTopBar`. Any header change (icon, badge, label) must be made in up to four places and will silently drift.


**Решение:** Extract one parameterized builder that constructs the row content once and takes a small style descriptor (e.g. a `Widget Function(Widget child)` chrome wrapper plus size/weight tokens), so glossy vs. material only changes how pieces are wrapped, not the whole tree. Apply the same pattern to the search and selection bars.

</details>

<details>
<summary><b>✅ ЗАКРЫТО С11 · 🟠 MED · ДУБЛЬ · [S]</b> — Bespoke _Avatar in create_group_flow.dart duplicates KometAvatar but drops its memCache sizing, decoding every contact avatar at full source resolution</summary>

_✅ С11: `_Avatar` удалён, оба сайта (40px/24px) → `KometAvatar` (memCache-фикс применён); снят неисп. cached_network_image import. Inherent: KometAvatar даёт bold-инициал и не показывает букву во время загрузки._


**Где:** `lib/frontend/screens/chats/create_group_flow.dart:507-553`, `lib/frontend/widgets/komet_avatar.dart:40-56`


**Проблема:** _Avatar (used for the 40px contact-list rows at line 319 and the 24px selected chips at line 580) re-implements CachedNetworkImage-with-initials-fallback that KometAvatar already provides, but without KometAvatar's memCacheWidth/memCacheHeight (which it sets to size*3). Every contact avatar in this sheet is therefore decoded and held in memory at full source resolution instead of the ~24-40px display size, multiplying memory/CPU cost across what is often a long contact list.


**Решение:** Delete _Avatar and use KometAvatar(name: _displayName(c), imageUrl: contact.baseUrl, size: ...) directly, as search_screen.dart already does via _ResultTile.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — Message-status icon mapping duplicated three times</summary>


**Где:** `lib/frontend/widgets/message_bubble.dart:2782`, `lib/frontend/widgets/message_bubble.dart:2419`, `lib/frontend/widgets/message_bubble.dart:2941`


**Проблема:** `MessageBubble._buildStatusIcon` (2782), `MessageBubble._buildStickerStatusIcon` (2419) and `_VoiceMessageBubbleState._buildStatusIcon` (2941) each re-implement the same switch over the status string (sending/pending -> schedule, sent/null -> check, delivered -> done_all dim, read -> done_all `0xFF4FC3F7`, error -> error/redAccent). Only the dim/read color source differs (ctx.dim vs Colors.white vs onPrimaryContainer alpha); the read color and error color are identical literals in all three. A new status value or semantic change must be edited in three places or the UI drifts between text bubbles, stickers and voice notes.


**Решение:** Extract one pure helper, e.g. `({IconData icon, Color color}) messageStatusVisual(String? status, {required Color dimColor, required Color readColor, required Color errorColor})`, and have all three call sites build their `Icon` from its result with their own dim color.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Contact-card rendering duplicated between direct and forwarded contacts, with an existing inconsistency</summary>


**Где:** `lib/frontend/widgets/message_bubble.dart:2450`, `lib/frontend/widgets/message_bubble.dart:2537`


**Проблема:** `_buildContactAttachment` (2450-2535) and `_buildForwardedContactContent` (2537-2637) are ~90 lines of near-identical code: same firstName/lastName/fallback name-building, same 48px avatar Container + ClipRRect + CachedNetworkImage with `Icon(Symbols.person)` fallback, same phone-number row. The only real difference is the forwarded variant prepends `_buildForwardedHeader`. The copy has already drifted: the direct variant sets `memCacheWidth: 144`/`memCacheHeight: 144` (lines 2487-2488) but the forwarded variant's CachedNetworkImage (2580-2583) omits them, so forwarded contact avatars decode at full resolution.


**Решение:** Factor out a single `_buildContactCard(_BubbleCtx ctx, {String? firstName, String? lastName, String? name, String? photoUrl, String? phoneNumber})` used by both, with the forwarded path wrapping it in a Column that prepends `_buildForwardedHeader`. This also fixes the missing memCache sizing.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Eleven near-identical inline toggle-row blocks in DebugMenuScreen.build()</summary>


**Где:** `lib/frontend/screens/profile/debug_menu_screen.dart:417-478`, `lib/frontend/screens/profile/debug_menu_screen.dart:479-542`, `lib/frontend/screens/profile/debug_menu_screen.dart:543-665`, `lib/frontend/screens/profile/debug_menu_screen.dart:731-903`, `lib/frontend/screens/profile/debug_menu_screen.dart:964-1200`


**Проблема:** Each toggle row (FPS overlay, VPN bypass, offline-test, TLS-insecure, swipe-back, pranks, digital-ID-native, stories, commands, link-preview, extra-info) is a ~50-line copy-pasted SliverToBoxAdapter > Padding > ValueListenableBuilder<bool> > GlossyPill > Row(Icon, title/subtitle Column, Switch) block differing only in icon, strings and the ValueListenable/setter. Verified the first two blocks are byte-for-byte structurally identical. This is a large, real maintenance-cost duplication (any styling change needs eleven edits). Note: the perf angle is minor since each row's ValueListenableBuilder already isolates its own switch state; the concern is duplication/maintainability, not rebuild cost.


**Решение:** Extract one reusable _DebugToggleTile({icon, title, subtitle, valueListenable, onChanged}) widget (or a data-driven list of tile descriptors rendered via .map) and replace all eleven call sites, removing several hundred lines of duplication.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Four parallel settings-row builder methods reimplement the same InkWell/Row/Divider layout</summary>


**Где:** `lib/frontend/screens/profile/security_screen.dart:842-930`, `lib/frontend/screens/profile/security_screen.dart:932-992`, `lib/frontend/screens/profile/security_screen.dart:994-1045`, `lib/frontend/screens/profile/security_screen.dart:1047-1097`


**Проблема:** _buildNavRow, _buildOptionRow, _buildSubRow and _buildSwitchRow all build the same Column > Material > InkWell > Padding > Row(icon?, label/subtitle Column, trailing/value/switch) > conditional Divider skeleton, differing only in which optional parts are present. Confirmed all four verbatim. The same skeleton is re-derived independently in the debug_menu toggle blocks.


**Решение:** Consolidate into one configurable SettingsRow widget under frontend/widgets/ taking optional icon, label, subtitle, trailingText, trailingWidget, isLast and onTap, and use it from all four call sites (and reuse from the debug/password screens).

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Loading-state FilledButton pattern duplicated five times in password_entry_screen</summary>


**Где:** `lib/frontend/screens/profile/password_entry_screen.dart:272-295`, `lib/frontend/screens/profile/password_entry_screen.dart:701-724`, `lib/frontend/screens/profile/password_entry_screen.dart:1095-1119`, `lib/frontend/screens/profile/password_entry_screen.dart:1298-1322`, `lib/frontend/screens/profile/password_entry_screen.dart:1432-1456`


**Проблема:** Each sub-screen repeats an identical ValueListenableBuilder<bool>(...) => FilledButton(onPressed: loading ? null : action, style: FilledButton.styleFrom(primary bg/onPrimary fg, vertical 16 padding, 12 radius), child: loading ? SizedBox(20x20 CircularProgressIndicator strokeWidth 2) : Text(...)) block, varying only in label and the loading ValueNotifier (first uses _isVerifying, rest _isLoading). Confirmed at the first two sites verbatim.


**Решение:** Extract a shared PrimaryLoadingButton({required ValueListenable<bool> loading, required VoidCallback? onPressed, required Widget child, Color? background}) under frontend/widgets and replace all five inline copies.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Settings card/divider/toggle-row layout is copy-pasted across three screens</summary>


**Где:** `lib/frontend/screens/profile/settings_tab.dart:693-771`, `lib/frontend/screens/profile/notifications_screen.dart:229-308`, `lib/frontend/screens/profile/komet_settings_screen.dart:107-181`


**Проблема:** settings_tab.dart (`_buildSection`/`_buildSettingsRow`), notifications_screen.dart (`_card`/`_divider`/`_toggleRow`) and komet_settings_screen.dart (`_card`/`_divider`/`_toggle`) each independently define the same GlossyPill-wrapped Column of InkWell rows with the identical 58px-inset divider and the same horizontal-20 padding. Any visual tweak must be applied in three places, and the copies have already diverged: notifications_screen's `enabled`/`AnimatedOpacity`/`IgnorePointer` disabled-state handling is missing from komet_settings_screen's otherwise-identical toggle.


**Решение:** Extract a shared widget set into frontend/widgets/ (e.g. `SettingsCard`, `SettingsToggleTile`, `SettingsNavTile`) parameterized by icon/leading, label, optional subtitle, trailing (chevron or Switch), enabled flag, and onTap/onChanged. Replace all three local implementations.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Selectable radio-tile widget is redefined near-identically in three customization screens</summary>


**Где:** `lib/frontend/screens/profile/theme_settings_screen.dart:103-162`, `lib/frontend/screens/profile/message_actions_screen.dart:106-174`, `lib/frontend/screens/profile/app_icon_screen.dart:113-170`


**Проблема:** `_ModeTile`, `_StyleTile` and `_IconTile` build the same pattern: a leading icon/image, a label (+ optional description) and a trailing `Symbols.radio_button_checked`/`unchecked` inside an InkWell with the same borderRadius(16) and padding(8,12). Only the leading widget and presence of a subtitle differ; `_ModeTile` is additionally stateful only to capture the tap position for the reveal animation.


**Решение:** Factor out a single `SettingsRadioTile` taking a `leading` widget, `label`, optional `description`, `selected`, and an `onTap`/`onTapDown` callback (to preserve theme_settings_screen's tap-position capture). Instantiate it in all three screens.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — Edit-profile avatar reimplements KometAvatar without caching or error fallback</summary>


**Где:** `lib/frontend/screens/profile/edit_profile_screen.dart:202-234`, `lib/frontend/widgets/komet_avatar.dart:1-58`, `lib/frontend/screens/profile/settings_tab.dart:574-590`


**Проблема:** edit_profile_screen.dart hand-builds the avatar-with-initials-fallback using a raw ClipOval + `Image.network(_avatarUrl!, fit: BoxFit.cover)`, duplicating what `KometAvatar` already does and what settings_tab.dart uses for the same profile picture (settings_tab.dart:584). Unlike KometAvatar, this copy has no CachedNetworkImage/memCacheWidth/memCacheHeight (re-downloads and re-decodes full-resolution on every rebuild instead of using the cache) and no errorWidget, so a failed load renders Flutter's default red error box instead of falling back to the initial-letter placeholder.


**Решение:** Replace the hand-rolled ClipOval/Image.network block with `KometAvatar(name: ..., imageUrl: _avatarUrl, size: 88, fontSize: 32)`, keeping only the camera-button overlay as screen-specific chrome.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Reconnect-and-report pattern duplicated four times across the two settings sheets, with drift</summary>


**Где:** `lib/frontend/screens/auth/proxy_settings_sheet.dart:44-98`, `lib/frontend/screens/auth/server_settings_sheet.dart:45-105`


**Проблема:** `_apply`/`_disable` in `ProxySettingsSheet` and `_apply`/`_resetToDefault` in `ServerSettingsSheet` each independently: set `_busy`, persist config, `api.disconnect()` then reconnect, then report success/failure via `l10n.xxxSettingsSaved`/`l10n.serverReconnectFailed`. The copies have drifted in how they observe the reconnect result: `ProxySettingsSheet` does `await api.connect()` and then immediately reads `api.state == SessionState.online`, whereas `ServerSettingsSheet` waits on `api.stateStream.firstWhere(...)` with a 15s timeout. If `api.connect()` returns before the session actually transitions to online, the proxy path reports success/failure from a premature `api.state` read while the server path reports the real outcome.


**Решение:** Extract one `Future<bool> applyConnectionChange(Future<void> Function() persist)` helper (in api.dart or a shared settings helper) that does persist/disconnect/connect/wait-on-stream-with-timeout/return-result once, and have all four call sites use it with only the persist step varying.

</details>

<details>
<summary><b>✅ ЗАКРЫТО С11 · 🟠 MED · ДУБЛЬ · [S]</b> — _ErrorView widget copy-pasted verbatim in three screens</summary>

_✅ С11: `widgets/error_view.dart` (`ErrorView`); три локальных `_ErrorView` удалены (web_app/digital_id_web/digital_id)._


**Где:** `lib/frontend/screens/webapp/web_app_screen.dart:145-177`, `lib/frontend/screens/digital_id/digital_id_web_screen.dart:346-375`, `lib/frontend/screens/digital_id/digital_id_screen.dart:508-540`


**Проблема:** The same private _ErrorView class (cloud_off icon, message text, 'Повторить' FilledButton, identical padding/typography) is defined three separate times with identical bodies. Confirmed identical in all three files.


**Решение:** Extract a single shared ErrorView widget into lib/frontend/widgets/ and have all three screens import it.

</details>

<details>
<summary><b>✅ ЗАКРЫТО С11 · 🟠 MED · ДУБЛЬ · [S]</b> — chat_screen.dart reimplements a confirm dialog instead of using the shared showConfirmDialog</summary>

_✅ С11: `_showConfirmDialog` удалён; `_clearHistory`/`_deleteChat` → `showConfirmDialog(..., destructive: true)`, `confirmed != true`→`!confirmed`. Импорт confirm_dialog.dart добавлен._


**Где:** `lib/frontend/screens/chats/chat_screen.dart:2968-2994 (_showConfirmDialog)`, `lib/frontend/screens/chats/chat_screen.dart:2997-3003 (_clearHistory call site)`, `lib/frontend/screens/chats/chat_screen.dart:3024-3028 (_deleteChat call site)`, `lib/frontend/widgets/confirm_dialog.dart:4-44 (existing showConfirmDialog)`


**Проблема:** chat_screen.dart does not import confirm_dialog.dart and instead defines a private `_showConfirmDialog({title, body, confirmLabel})` (2968-2994) that rebuilds the same AlertDialog structure the shared `showConfirmDialog` already provides. The two differ visually: the private one omits the shared 24px RoundedRectangleBorder shape and renders the destructive action as a plain TextButton tinted cs.error, whereas showConfirmDialog uses a FilledButton.tonal with errorContainer/onErrorContainer. Result is a second, subtly different confirm-dialog look for clear-history and delete-chat, out of step with every other screen.


**Решение:** Delete `_showConfirmDialog` and call the shared helper at both sites: `showConfirmDialog(context, title: ..., message: body, confirmLabel: ..., destructive: true)`. Note the shared param is `message` (not `body`) and it returns a non-null `bool`, so change the call sites from `confirmed != true` to `!confirmed`.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — security_screen.dart hand-rolls _showHiddenStatusSheet instead of reusing its own _showOptionSheet</summary>


**Где:** `lib/frontend/screens/profile/security_screen.dart:524-592 (_showOptionSheet generic helper)`, `lib/frontend/screens/profile/security_screen.dart:594-651 (_showHiddenStatusSheet)`


**Проблема:** `_showOptionSheet` (524-592) is a generic helper that takes title/currentValue/options/onSelect and renders the full showModalBottomSheet + SafeArea + Column + SheetGrabber + title + selectable rows sheet. `_showHiddenStatusSheet` (594-651), a few lines below, needs exactly a title + two selectable options with a checkmark, but re-implements the entire sheet chrome by hand (using per-row `_buildOptionSheetItem` calls) rather than delegating to `_showOptionSheet`. ~40-50 duplicated layout lines in one file.


**Решение:** Route `_showHiddenStatusSheet` through `_showOptionSheet` with `options: [('CONTACTS','Мои контакты'), ('NONE','Никто')]` and an `onSelect` that maps CONTACTS to `_updateSetting('HIDDEN', false)` and NONE to `_showHiddenStatusConfirmDialog`. onSelect fires after the sheet pops, so the confirm-dialog flow is preserved.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — Shared kSheetShape constant ignored — identical top-24px sheet shape re-typed at 7+ call sites (and a divergent 20px in security_screen)</summary>


**Где:** `lib/frontend/widgets/sheet_helpers.dart:4-6 (kSheetShape definition)`, `lib/frontend/screens/calls/komet_hub.dart:20`, `lib/frontend/screens/chats/scheduled_messages_screen.dart:88`, `lib/frontend/widgets/info_action_sheet.dart:51`, `lib/frontend/widgets/schedule_time_picker.dart:30`, `lib/frontend/widgets/web_qr_login.dart:12`, `lib/frontend/screens/chats/chat_screen.dart:1884`, `lib/frontend/screens/calls/call_screen.dart:402`, `lib/frontend/screens/profile/security_screen.dart:535 (20px variant)`, `lib/frontend/screens/profile/security_screen.dart:616 (20px variant)`


**Проблема:** kSheetShape exists to standardize the top-24px rounded bottom-sheet shape and is used correctly in ~8 screens (login_screen, settings_tab, poll_create_screen, contacts_tab, chat_list_screen, create_group_flow, debug_menu_screen). Yet the listed call sites re-type the identical literal `RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))`. web_qr_login.dart already imports sheet_helpers.dart (line 5, for SheetGrabber) but still inlines the shape on line 12. security_screen.dart also imports it (line 12) yet inlines a 20px variant at lines 535 and 616, producing a visibly different corner radius from the rest of the app. (sticker_pack_sheet.dart:144, chat_wallpaper_sheet.dart:51, and attachment_sheet.dart:199 inline it too, reinforcing the pattern.)


**Решение:** Use `shape: kSheetShape` at all listed 24px call sites. For security_screen's two 20px sheets, align to 24 (kSheetShape) unless a compact variant is intended — if it is, add a named `kCompactSheetShape` constant so the radius is still centrally defined rather than inlined.

</details>

<details>
<summary><b>🔧 ЧАСТИЧНО С11 · 🟠 MED · ДУБЛЬ · [M]</b> — Four hand-rolled single-line text-input AlertDialogs should share one prompt helper</summary>

_🔧 С11: `widgets/prompt_dialog.dart` (`showTextInputDialog`, слот `description`, владеет controller+dispose); devices `_showPasteQrDialog` и font_settings `_showAddFontDialog` делегированы (закрыт leak в font). ⏭️ Осталось: password_entry `_promptPassword`, photo_editor `_addText` (dark-themed — параметризовать) → С12._


**Где:** `lib/frontend/screens/profile/devices_screen.dart:66-113 (_showPasteQrDialog)`, `lib/frontend/screens/profile/password_entry_screen.dart:60-89 (_promptPassword)`, `lib/frontend/screens/profile/font_settings_screen.dart:79-135 (_showAddFontDialog)`, `lib/frontend/widgets/attachment/photo_editor.dart:900-934 (_addText)`


**Проблема:** Each independently builds a TextEditingController + showDialog<String> + AlertDialog with a title, one autofocus TextField (onSubmitted popping the value), a Cancel TextButton and a Confirm FilledButton/TextButton. Only labels/hints/styling vary. Three of the four dispose the controller in a finally block; font_settings_screen._showAddFontDialog (79-135) never disposes its controller at all — a real leak a shared helper would eliminate. photo_editor._addText additionally hardcodes a dark theme (Color(0xFF1E1E1E), Colors.white) instead of ColorScheme, which a themed helper could parameterize.


**Решение:** Add `Future<String?> showTextInputDialog(BuildContext context, {String? title, String? hint, String confirmLabel, String cancelLabel, bool obscureText, int maxLines})` alongside showConfirmDialog (or a new prompt_dialog.dart) that owns controller creation and disposal and returns the trimmed value, then delegate all four call sites to it. This also closes the font_settings_screen controller leak.

</details>

<details>
<summary><b>✅ ЗАКРЫТО С11 · 🟡 LOW · ДУБЛЬ · [S]</b> — Identical spinner and 'baking' overlay widgets duplicated verbatim across four screens</summary>

_✅ С11: `widgets/small_spinner.dart` (`SmallSpinner`+`BusyOverlay`); sticker_panel/sticker_pack_sheet → SmallSpinner; photo_editor ×2 baking-overlay → BusyOverlay._


**Где:** `lib/frontend/widgets/sticker_panel.dart:166`, `lib/frontend/widgets/sticker_pack_sheet.dart:166`, `lib/frontend/widgets/attachment/photo_editor.dart:1040`, `lib/frontend/widgets/attachment/photo_editor.dart:2377`


**Проблема:** The same `SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.primary))` appears verbatim in sticker_panel.dart and sticker_pack_sheet.dart, and the identical full-screen baking overlay `Positioned.fill(child: ColoredBox(color: Colors.black54, child: Center(child: CircularProgressIndicator(color: Colors.white))))` appears verbatim in PhotoDrawEditor (1040) and PhotoAdjustEditor (2377).


**Решение:** Extract a shared SmallSpinner({Color? color}) and a shared BusyOverlay({required bool visible}) widget used by all four call sites so any future visual tweak is made once.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Duplicated labeled-TextField builder between the two settings sheets</summary>


**Где:** `lib/frontend/screens/auth/proxy_settings_sheet.dart:246-294`, `lib/frontend/screens/auth/server_settings_sheet.dart:173-219`


**Проблема:** `_buildTextField` in both `_ProxySettingsSheetState` and `_ServerSettingsSheetState` is essentially identical: a label `Text`, then a `TextField` with the same `fillColor`, `OutlineInputBorder`, and `contentPadding` (proxy's only extra is an `obscureText` param). Any visual tweak to the settings-sheet input style has to be made twice, and a design change applied to one sheet is easily forgotten in the other.


**Решение:** Extract a shared `LabeledSettingsField` widget in frontend/widgets/ taking controller/label/hint/keyboardType/obscureText/inputFormatters, and use it from both sheets instead of two private copies.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [M]</b> — Overlay-popup lifecycle skeleton copy-pasted between account switcher and chat menu</summary>


**Где:** `lib/frontend/widgets/account_switcher_overlay.dart:119-135`, `lib/frontend/widgets/account_switcher_overlay.dart:233-241`, `lib/frontend/widgets/chat_menu_overlay.dart:70-100`


**Проблема:** `_AccountSwitcherLayerState` and `_ChatMenuLayerState` hand-roll the identical overlay-popup skeleton: an `AnimationController` + `CurvedAnimation` built in initState with the same easeOutCubic/easeInCubic pair and forward-on-mount, a `_closing` guard flag, and a `_close()` that does `try { await _animController.reverse(); } catch (_) {}` then calls `widget.onDismiss()`. The guarded reverse-then-dismiss (including the empty catch that swallows the reverse TickerFuture error on interruption/disposal) is duplicated verbatim, so a fix there needs doing twice and a third overlay will likely copy it again. Confirmed identical in both files. (The bodies otherwise differ substantially — pointer-routing/geometry vs tap items — so only the lifecycle skeleton is shared.)


**Решение:** Factor the shared lifecycle into an `AnimatedOverlayPopup` mixin/base StatefulWidget that owns the controller, the forward-on-mount, and the guarded reverse-then-dismiss, exposing a content builder and `onDismiss`. Both layers become thin subclasses supplying only their own content and hit-testing.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [M]</b> — Two drifting implementations of drag-to-dismiss with inconsistent velocity units</summary>


**Где:** `lib/frontend/widgets/swipe_route.dart:127-236`, `lib/frontend/widgets/swipe_to_pop.dart:53-90`


**Проблема:** `SwipeRoute`'s `_SwipeBackGestureDetector`/`_SwipeBackController` and the standalone `SwipeToPop` widget both re-implement the drag-to-dismiss decision tree: measure track width via `context.size`/`MediaQuery`, feed a `RightwardDragRecognizer`, accumulate `primaryDelta/width`, and on drag-end decide complete-vs-rewind from a distance/velocity threshold. The two already disagree on units: SwipeRoute normalizes velocity as `pixelsPerSecond.dx / width` and compares to `_kMinFlingVelocity = 1.0` (swipe_route.dart:145,197), while SwipeToPop compares the raw `pixelsPerSecond.dx` to `velocityThreshold = 700` (swipe_to_pop.dart:66-68), and the distance thresholds differ (0.5 vs 0.35). So the two swipe-back gestures already feel different and tuning must be done twice. Confirmed. (Note: they are structurally distinct — SwipeRoute drives the PageRoute's own controller, essentially reimplementing Flutter's private _CupertinoBackGestureController, while SwipeToPop owns its controller and Transform.translates a child — so a full merge is non-trivial.)


**Решение:** Extract a shared threshold/decision helper (width-normalized velocity + distance fling-vs-rewind rule) that both gestures call, so at minimum the units and thresholds can't diverge, even if the two keep their own animation sinks (route controller vs local controller).

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Avatar image + initials fallback duplicated with inconsistent cache sizing and no error fallback in hero flight</summary>


**Где:** `lib/frontend/widgets/komet_avatar.dart:40-56`, `lib/frontend/widgets/avatar_hero.dart:36-67`


**Проблема:** `KometAvatar` and `_AvatarHeroFlight` independently implement 'circular clip, network image, first-letter fallback'. `KometAvatar` caps decode resolution via `memCacheWidth/Height = (size*3).round()` and supplies an `errorWidget` initials fallback (komet_avatar.dart:41,51-53). `_AvatarHeroFlight` — which renders the same avatar mid-flight for a hero started from a `KometAvatar` — uses a bare `Image(image: CachedNetworkImageProvider(url))` with no memCache cap and no error fallback (avatar_hero.dart:47-51), so the resting and flying frames of the same avatar can decode at different resolutions and only the resting one recovers from a load error (a failed image shows a blank circle during flight). Confirmed.


**Решение:** Extract one shared avatar-content builder (network image with capped memCacheWidth/Height + initials placeholder + errorWidget) used by both `KometAvatar` and the hero flight shuttle, so caching and fallback can't diverge between resting and flying states.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [M]</b> — Near-identical 'edit message in a bottom sheet' layout duplicated across chat_screen and scheduled_messages_screen</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:1879-1933 (_startEditMessage sheet)`, `lib/frontend/screens/chats/scheduled_messages_screen.dart:83-150 (_edit sheet)`


**Проблема:** Both build `showModalBottomSheet<bool>` (isScrollControlled, surfaceContainerHigh, same inline 24px shape), the same title TextStyle (fontSize 18, w600, fontFamily 'Outfit'), the same filled TextField with surfaceContainerHighest fill and a 14px borderless OutlineInputBorder, and the same viewInsets-aware Padding. The only differences are maxLines (6 vs 5), chat_screen's contextMenuBuilder for format actions, and scheduled_messages' time-picker row.


**Решение:** Extract a shared 'edit text sheet' helper (styled title + TextField + save button, with an optional trailing child slot for the time picker and an optional contextMenuBuilder) that both screens call, collapsing ~70 lines of near-identical layout. Lower priority than the other findings since the two variants genuinely diverge.

</details>


### Hardcoded theming and color literals  (7 — 0 high)

_Semantic colors and shadows are re-typed as raw expressions or hex across many sites with inconsistent alpha, bypassing the app's accent-customization system._

<details>
<summary><b>✅ ЗАКРЫТО С11 · 🟠 MED · КОСТЫЛЬ · [M]</b> — Brand/status accent colors hardcoded as raw hex, bypassing the app's AppAccent customization and duplicating literals</summary>

_✅ С11: 007AFF→`cs.primary` (chat_info ×5); 4FC3F7→`kReadReceiptBlue`; 34C759→`kOnlineGreen`; 2F8FFF→`kEditorAccent` (core/config/app_colors.dart). Residual-grep всех четырёх = 0. Editor-chrome остаётся фикс-акцентом, но теперь через один const._


**Где:** `lib/frontend/screens/chats/chat_info_screen.dart:480`, `lib/frontend/screens/chats/chat_info_screen.dart:511`, `lib/frontend/screens/chats/chat_info_screen.dart:521`, `lib/frontend/screens/chats/chat_info_screen.dart:564`, `lib/frontend/screens/chats/chat_info_screen.dart:791`, `lib/frontend/screens/chats/chat_list_screen.dart:2243`, `lib/frontend/widgets/message_bubble.dart:2438`, `lib/frontend/widgets/message_bubble.dart:2801`, `lib/frontend/widgets/message_bubble.dart:2963`, `lib/frontend/screens/profile/traffic_monitor_screen.dart:224`, `lib/frontend/screens/profile/settings_tab.dart:671`, `lib/frontend/widgets/attachment/media_preview_screen.dart:12`, `lib/frontend/widgets/attachment/photo_editor.dart:1891`


**Проблема:** Despite the `AppAccent` seed-color system (lib/core/config/app_accent.dart) with per-user accent customization, brand accents are hardcoded as bare hex and duplicated: `0xFF007AFF` (iOS link blue) appears 5x in chat_info_screen.dart for link/action text and icons — these should track `cs.primary` so the user's chosen accent applies; `0xFF4FC3F7` appears 4x across chat_list_screen.dart and message_bubble.dart for the same indicator; `0xFF34C759` (green) appears 3x (traffic_monitor:224, settings_tab:671, photo_editor:1274); `0xFF2F8FFF` is defined as a separate `_kAccent` const in both media_preview_screen.dart:12 and photo_editor.dart:1891 and also inlined as a raw literal at photo_editor.dart 458/513/650/1276/1706. The photo-editor/media-viewer cases are dark-fixed editor chrome where a fixed accent is defensible, but the value is still duplicated rather than centralized.


**Решение:** Add named semantic constants to a central `AppColors` (`linkBlue`, `onlineGreen`, `editorAccent`) so each value exists once, and convert the chat_info_screen link/action colors and the message_bubble/chat_list indicator to `Theme.of(context).colorScheme.primary` (or a proper AppAccent token) so custom accent colors propagate instead of being overridden by a hardcoded blue.

</details>

<details>
<summary><b>✅ ЗАКРЫТО С11 · 🟠 MED · ДУБЛЬ · [M]</b> — Muted/secondary text color `cs.onSurfaceVariant.withValues(alpha: 0.6)` re-derived ad hoc in 8 call sites instead of one theme token</summary>

_✅ С11: extension `ColorScheme.mutedText` (app_colors.dart); все 8 сайтов → `cs.mutedText` (settings_tab ×2, security, devices, server/proxy sheets, composer_input, chat_screen). Residual-grep α0.6 = 0._


**Где:** `lib/frontend/screens/chats/chat_screen.dart:5602`, `lib/frontend/screens/chats/chat_screen.dart:7319`, `lib/frontend/screens/profile/devices_screen.dart:671`, `lib/frontend/screens/profile/security_screen.dart:718`, `lib/frontend/screens/profile/settings_tab.dart:626`, `lib/frontend/screens/profile/settings_tab.dart:672`, `lib/frontend/screens/auth/server_settings_sheet.dart:202`, `lib/frontend/screens/auth/proxy_settings_sheet.dart:277`


**Проблема:** The exact expression `cs.onSurfaceVariant.withValues(alpha: 0.6)` (the standard 'subtitle/secondary label' color) is retyped independently at 8 verified call sites across 6 files. There is no single source of truth, so a design tweak (e.g. bumping alpha for accessibility contrast) requires editing every copy, and new screens can silently drift (onSurfaceVariant is already used at 0.3/0.35/0.4/0.5/0.55/0.7/0.75/0.8/0.85 elsewhere for what is loosely the same intent). Note: the audit's 9th cited location (chat_list_screen.dart:1511) was mis-cited — that line uses `cs.onSurface.withValues(alpha: 0.6)` (a different base color), so it is excluded here.


**Решение:** Add a `ColorScheme` extension getter (or `AppColors.of(context).mutedText`) backed by `onSurfaceVariant.withValues(alpha: 0.6)` and route all 8 sites through it. Keep this consistent with the app's existing theme-token conventions (single source of truth in core/config).

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Hairline divider/border color duplicated with inconsistent alpha (0.3 / 0.35 / 0.4 / 0.5) across the app</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:1759`, `lib/frontend/screens/chats/chat_screen.dart:1849`, `lib/frontend/screens/chats/chat_screen.dart:2267`, `lib/frontend/screens/chats/chat_screen.dart:5630`, `lib/frontend/screens/chats/chat_screen.dart:5679`, `lib/frontend/screens/chats/chat_screen.dart:6916`, `lib/frontend/screens/chats/chat_screen.dart:6968`, `lib/frontend/screens/chats/chat_list_screen.dart:1531`, `lib/frontend/screens/profile/security_screen.dart:331`, `lib/frontend/screens/profile/security_screen.dart:396`, `lib/frontend/screens/profile/security_screen.dart:436`, `lib/frontend/screens/profile/security_screen.dart:705`, `lib/frontend/screens/profile/security_screen.dart:925`, `lib/frontend/screens/profile/security_screen.dart:987`, `lib/frontend/screens/profile/security_screen.dart:1039`, `lib/frontend/screens/profile/security_screen.dart:1092`


**Проблема:** Hairline dividers/borders are written inline as `cs.outlineVariant.withValues(alpha: X)` with X inconsistent across 37 total usages: security_screen.dart uses 0.35 (except line 705 which is 0.3), chat_screen.dart mixes 0.4/0.5 with a 0.3 at line 6916. Dividers in the security/settings pages render noticeably fainter than those in chat screens for no design reason — just because each author picked their own number. (The audit's `appearance_screen.dart:517`, `attachment_panel.dart:127`, `attachment_sheet.dart:263`, and `message_actions_overlay.dart:687` were not re-verified for exact alpha but the pattern is clearly file-wide.)


**Решение:** Introduce a single `cs.hairline` extension getter returning the canonical `outlineVariant.withValues(alpha: 0.4)` (or whatever design intends) and replace every inline computation so all dividers render identically and can be retuned in one place.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — Identical 'frosted pill surface' Color.alphaBlend block copy-pasted 5 times in chat_screen.dart</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:1842`, `lib/frontend/screens/chats/chat_screen.dart:5475`, `lib/frontend/screens/chats/chat_screen.dart:5511`, `lib/frontend/screens/chats/chat_screen.dart:5622`, `lib/frontend/screens/chats/chat_screen.dart:5672`


**Проблема:** The expression `Color.alphaBlend(cs.surfaceContainerHighest.withValues(alpha: 0.92), cs.surface)` is copy-pasted verbatim as the fill color for GlossyPill/Container surfaces at 4 locations, plus a 0.96 variant at line 5475. The same file also repeats a near-identical `_FrostedPanel(tint: cs.surfaceContainerHigh.withValues(alpha: 0.55), border: ... outlineVariant.withValues(alpha: 0.4))` config at lines 1755-1762 and 2263-2270 (these two differ only in top- vs bottom-BorderSide, so not strictly verbatim).


**Решение:** Extract a helper `Color appPillSurface(ColorScheme cs) => Color.alphaBlend(cs.surfaceContainerHighest.withValues(alpha: 0.92), cs.surface);` and a small widget wrapping the repeated `_FrostedPanel` chrome (parameterized by border edge), then reuse at all sites.

</details>

<details>
<summary><b>✅ ЗАКРЫТО С11 · 🟡 LOW · ДУБЛЬ · [S]</b> — Avatar thumbnail cache dimensions duplicated as a magic literal in four places</summary>

_✅ С11: `const kAvatarThumbSize = 144` (app_colors.dart); все 4 `maxWidth/maxHeight: 144` в chat_list_screen → `kAvatarThumbSize`._


**Где:** `lib/frontend/screens/chats/chat_list_screen.dart:2105-2107`, `lib/frontend/screens/chats/chat_list_screen.dart:2348`, `lib/frontend/screens/chats/chat_list_screen.dart:2387-2389`, `lib/frontend/screens/chats/chat_list_screen.dart:2711-2713`


**Проблема:** Confirmed. `CachedNetworkImageProvider(..., maxWidth: 144, maxHeight: 144)` is written four separate times (story avatar, chat-tile avatar, precache-on-tap, folded story). Since the resize size participates in the cache key, changing one literal without the others would cache the same URL under two keys, wasting memory and missing hits.


**Решение:** Introduce a single shared `const kAvatarThumbSize = 144;` (or an `avatarImageProvider(String url)` factory) in a shared utils/widgets file and use it at all four sites.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [M]</b> — Ad-hoc black drop-shadows reimplemented in several widgets despite an existing GlossyDecor.dropShadow helper</summary>


**Где:** `lib/frontend/screens/calls/call_screen.dart:980`, `lib/frontend/screens/chats/chat_list_screen.dart:2008`, `lib/frontend/widgets/connection_status.dart:170`, `lib/frontend/widgets/sliding_pill_nav.dart:122`, `lib/frontend/widgets/message_actions_overlay.dart:1085`, `lib/frontend/screens/chats/chat_screen.dart:5481`, `lib/frontend/widgets/glossy_pill.dart:72`


**Проблема:** `glossy_pill.dart:72` implements `GlossyDecor.dropShadow(base, depth)` mapping a depth scale to blur/spread/offset/alpha (and used at glossy_pill.dart:154), yet ~6 widgets hand-roll `BoxShadow(color: Colors.black.withValues(alpha: ...), blurRadius: ..., offset: ...)` for the same 'floating surface' shadow with alpha 0.1–0.5 and blur 6–24. Note: the audit's two `login_success_screen.dart` locations (222, 270) were mis-cited — they are `cs.primary`-colored glows, not black shadows, so they are excluded. Shadow values legitimately vary by context, so this is a minor consistency/reuse nit rather than a strong duplication.


**Решение:** Where these are genuinely the same 'soft floating surface' shadow, route them through `GlossyDecor.dropShadow` (or a small `AppShadows.soft({depth})` helper mapping an elevation-depth scale) so depth stays consistent and tunable in one place. Leave intentionally distinct shadows (colored glows, media-viewer scrims) as-is.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — message_bubble.dart re-derives the same tint/opacity expressions 6-7 times each within one file</summary>


**Где:** `lib/frontend/widgets/message_bubble.dart:1901`, `lib/frontend/widgets/message_bubble.dart:1997`, `lib/frontend/widgets/message_bubble.dart:2259`, `lib/frontend/widgets/message_bubble.dart:2319`, `lib/frontend/widgets/message_bubble.dart:2465`, `lib/frontend/widgets/message_bubble.dart:2555`, `lib/frontend/widgets/message_bubble.dart:3001`, `lib/frontend/widgets/message_bubble.dart:3055`, `lib/frontend/widgets/message_bubble.dart:3061`, `lib/frontend/widgets/message_bubble.dart:3114`, `lib/frontend/widgets/message_bubble.dart:3127`, `lib/frontend/widgets/message_bubble.dart:3143`, `lib/frontend/widgets/message_bubble.dart:3156`


**Проблема:** Within this single large file, `cs.onPrimaryContainer.withValues(alpha: 0.12)` (the tinted system-message background) is retyped at 7 verified locations, and `widget.textColor.withValues(alpha: 0.6)` (secondary/timestamp text on a bubble) at 6 more, as pure copy-paste with not even a shared local constant.


**Решение:** Hoist these into local getters on the widget/state class (e.g. `Color get _systemTint => cs.onPrimaryContainer.withValues(alpha: 0.12);` and `Color get _secondaryTextColor => widget.textColor.withValues(alpha: 0.6);`), or route the secondary-text one through the shared muted-text token proposed in finding 1.

</details>


### Hardcoded Russian strings / missing l10n  (6 — 0 high)

_Despite active English+Russian ARB support, user-facing strings are hardcoded in Russian in backend previews and many widgets/screens, so English users see Russian mid-flow._

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — Session/error classification uses free-text Russian substring matching, with a hardcoded Russian user-facing string baked into the protocol layer</summary>


**Где:** `lib/core/protocol/packet.dart:73`, `lib/core/protocol/packet.dart:86`, `lib/core/protocol/packet.dart:89`, `lib/backend/modules/account.dart:1519`, `lib/backend/modules/folders.dart:200`, `lib/frontend/screens/auth/login_screen.dart:498`


**Проблема:** `isSessionStateError` (packet.dart:86-93) lower-cases `error.toString()` and checks for Russian substrings ('состояние сессии', 'сессия не найдена', 'авторизационная сессия', 'сессия не онлайн') to gate auth-flow decisions in login/2FA/code-confirmation screens — this breaks the moment server wording changes or unrelated error text collides. `messageFromErrorPayload` (packet.dart:73) hardcodes a Russian user-facing sentence directly in the protocol layer, and that string is threaded through as display text across account, folders, and links modules. Since the app ships both `app_en.arb` and `app_ru.arb`, this hardcoded string always renders in Russian regardless of the user's chosen language (a real user-facing i18n defect), and UI copy is decided two layers below the UI, inverting the UI → backend → api → transport layering.


**Решение:** Return a typed/structured error from the protocol layer (the `errorKey` / `payload['error']` machine code already available at dispatcher.dart:104) instead of pre-baked display text or free-text detection. Map that typed code to a localized string in the backend/UI layer via `AppLocalizations`, and have `isSessionStateError` compare the typed code rather than parsing translated prose.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [L]</b> — Message-preview strings hardcoded in Russian, bypassing l10n</summary>


**Где:** `lib/backend/modules/chats.dart:257-304`, `lib/backend/modules/chats.dart:306-330`


**Проблема:** attachPreviewLabel and _controlPreviewLabel return literal Russian strings ('Фото', 'Видео', 'Голосовое сообщение', 'Системное сообщение', etc.) directly from the backend module. These strings feed CachedChat.lastMsgText / chat-list subtitles shown to every user. The project explicitly supports English and Russian via ARB files, but any non-plain-text last message (photo, video, sticker, call, system event) will always render in Russian regardless of device locale, so English users see Russian preview text in their chat list.


**Решение:** Do not bake final UI strings into the backend layer. Store a preview kind tag/enum (e.g. AttachKind.photo, ControlEventKind.pin) on CachedChat instead of a pre-rendered string, and resolve the localized label in the UI via AppLocalizations at render time (widgets already have BuildContext). This keeps chats.dart free of UI text and makes previews correctly localized.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — User-facing strings hardcoded in Russian, bypassing the project's active l10n system</summary>


**Где:** `lib/frontend/widgets/message_bubble.dart:2190`, `lib/frontend/widgets/message_bubble.dart:2203`, `lib/frontend/widgets/message_bubble.dart:2657`, `lib/frontend/widgets/message_bubble.dart:2906`, `lib/frontend/widgets/message_bubble.dart:2918`, `lib/frontend/widgets/message_actions_overlay.dart:385`, `lib/frontend/widgets/message_actions_overlay.dart:502`


**Проблема:** `AppLocalizations` is actively consumed in ~30 sites across the app (auth/profile screens, main.dart), yet these widgets hard-code Russian literals directly: video/file notifications ('Не удалось открыть видео', 'Не удалось получить видео', 'Не удалось определить файл'), audio errors ('Не удалось загрузить аудио', 'Ошибка воспроизведения'), and the action-menu label set ('Копировать', 'Изменить', 'Ответить', 'Переслать', 'Удалить', 'Скопировано'). English-locale users see Russian for all of these, and wording changes require hunting through widget code. This is an inconsistency with the app's own established pattern, not a systemic absence of l10n.


**Решение:** Move each literal into `app_en.arb`/`app_ru.arb` and reference via `AppLocalizations.of(context)!.xxx`, as the auth/profile screens already do.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — Raw exception text shown directly to end users in auth catch blocks</summary>


**Где:** `lib/frontend/screens/auth/login_screen.dart:497-501`, `lib/frontend/screens/auth/code_confirmation_screen.dart:151,314`, `lib/frontend/screens/auth/password_2fa_screen.dart:121`, `lib/frontend/screens/auth/registration_screen.dart:85`, `lib/frontend/widgets/web_qr_login.dart:110`


**Проблема:** Auth catch blocks fall back to `showCustomNotification(context, e.toString())` or string-interpolate `$e` into an otherwise-localized message (`'Неверный пароль: $e'`, `'Не удалось подтвердить вход: $e'`, `'Не удалось обновить код: $e'`) instead of mapping the error to a user-facing, localized message. `e.toString()` on a protocol/Dart exception typically carries a type prefix and internal detail that is neither translated nor meaningful to an end user, and gets appended to a notification meant to read cleanly.


**Решение:** Introduce a single error-to-message mapping (e.g. an `AuthException` hierarchy thrown from `backend/modules/account.dart` plus a shared `describeAuthError(Object e, AppLocalizations l10n)` helper) and have every catch block call it instead of interpolating `e.toString()` directly.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [M]</b> — Hardcoded Russian-only strings break English locale across the auth flow</summary>


**Где:** `lib/frontend/screens/auth/password_2fa_screen.dart:51,63,121,147,156,167,182`, `lib/frontend/widgets/web_qr_login.dart:26,35,50,59,104,110`, `lib/frontend/screens/auth/login_screen.dart:473,499-500,536`, `lib/frontend/screens/auth/code_confirmation_screen.dart:108,129,147,151`


**Проблема:** The project supports English and Russian via `AppLocalizations`/ARB files, and most auth screens use `l10n.xxx`. `Password2FAScreen` never imports `AppLocalizations` at all — every string is a hardcoded Russian literal ('Двухфакторная аутентификация', 'Введите пароль для завершения входа', 'Неверный пароль: $e', 'Пароль', etc.). `web_qr_login.dart` is the same ('Вход по QR', 'Отмена', 'Войти', 'Вход подтверждён', ...). Several connectivity/error messages in `login_screen.dart` (473, 499-500, 536) and `code_confirmation_screen.dart` (108, 129, 147, 151) are also hardcoded Russian even though the rest of those same screens use l10n. An English-locale user reaching 2FA or the QR-login sheet is shown Russian text mid-flow.


**Решение:** Move every hardcoded string in these files into `app_en.arb`/`app_ru.arb` and reference them through `AppLocalizations.of(context)!`, matching the pattern already used by `CodeConfirmationScreen`, `RegistrationScreen`, and the rest of `LoginScreen`.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [L]</b> — Screen is single-locale: hardcoded Russian strings, no AppLocalizations, TODO comments left in build()</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:4350-4351`, `lib/frontend/screens/chats/chat_screen.dart:693`, `lib/frontend/screens/chats/chat_screen.dart:2373`, `lib/frontend/screens/chats/chat_screen.dart:2754`


**Проблема:** The file has zero `AppLocalizations` references (confirmed) and leaves `// TODO: Локализация` / `// TODO: Cклонения` in `build()` at 4350-4351 — the latter also violating the project's no-comments convention. Every user-visible string (notifications, header labels, dialog text, menu items, composer/search hints) is a hardcoded Russian literal, so the screen is effectively single-locale despite the project building for English and Russian.


**Решение:** Route user-visible strings in this file through `AppLocalizations.of(context)`, add the missing keys to `app_en.arb`/`app_ru.arb`, and remove the TODO comments. Low priority but tracked debt.

</details>


### SnackBar and notification convention violations  (4 — 0 high)

_The mandated showCustomNotification is bypassed and stray debug logging ships in release, against project conventions._

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — Debug-only file introspection performs real I/O and logging on every voice-message send</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:5088`


**Проблема:** Inside _sendVoice, before each upload, the code opens the recorded file, reads its first 80 bytes, hex/ascii-encodes them and logs via logger.w('VOICE size=... hex=... ascii=...'), all wrapped in a swallowing catch(_){}. This is leftover debugging instrumentation running unconditionally in release on every voice message a user sends, adding file I/O and string building to the hot send path.


**Решение:** Remove the block, or gate it behind kDebugMode so it never executes in release builds.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — SnackBar used instead of showCustomNotification in spoof apply error path</summary>


**Где:** `lib/frontend/screens/profile/spoof_screen.dart:391-402`


**Проблема:** CLAUDE.md/AGENTS.md explicitly mandate showCustomNotification(context, 'text') for all user-facing notifications and forbid SnackBars. In _saveSpoofingSettings's catch block (after a failed disconnect/connect), the reconnect failure is reported via ScaffoldMessenger.of(context).showSnackBar(SnackBar(...)). Confirmed this is the only showSnackBar/ScaffoldMessenger call in the file; every other path in the screen family uses showCustomNotification.


**Решение:** Replace the ScaffoldMessenger/SnackBar block with showCustomNotification(context, AppLocalizations.of(context)!.spoofErrorApplyFailed(e.toString())), matching the rest of the file.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — spoof_screen.dart uses ScaffoldMessenger/SnackBar, the only violation of the mandated showCustomNotification convention</summary>


**Где:** `lib/frontend/screens/profile/spoof_screen.dart:391-402`


**Проблема:** CLAUDE.md/AGENTS.md mandates `showCustomNotification(context, 'text')` and forbids SnackBars. A repo-wide grep confirms this is the sole `ScaffoldMessenger.of(context).showSnackBar(...)` in lib/. It fires when re-applying a spoofed profile fails to reconnect (line 391-402) — precisely a spot a user is likely to hit — producing a Material SnackBar instead of the app's custom notification banner.


**Решение:** Replace the ScaffoldMessenger/SnackBar block with `showCustomNotification(context, AppLocalizations.of(context)!.spoofErrorApplyFailed(e.toString()))`, matching the localized string already used inside the SnackBar.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — Debug logging left in shipped list-reorder animation</summary>


**Где:** `lib/frontend/screens/chats/chat_list_screen.dart:2803`


**Проблема:** Confirmed. `_AnimatedChatTileState._runMove` unconditionally calls `debugPrint('[FLIP] move id=${widget.id} oldY=$oldY newY=$newY');` on every move. `debugPrint` is not stripped in release builds, so this does string interpolation on a hot UI path in production with a literal `[FLIP]` developer tag.


**Решение:** Delete the `debugPrint` call; it is leftover FLIP-development instrumentation with no product purpose.

</details>


### Layering violations from UI into transport/storage  (7 — 0 high)

_Widgets and push code reach directly into protocol opcodes, storage, and spoof-profile construction, inverting the documented data flow._

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — Notification toggles push raw protocol-key maps to the backend instead of typed setters</summary>


**Где:** `lib/frontend/screens/profile/notifications_screen.dart:50-70`, `lib/frontend/screens/profile/notifications_screen.dart:132-205`, `lib/backend/modules/account.dart:496-521`


**Проблема:** `NotificationsScreen._apply()` builds ad-hoc `Map<String, dynamic>` literals with server wire keys ('CHATS_PUSH_NOTIFICATION', 'PUSH_DETAILS', 'PUSH_SOUND', 'CHATS_PUSH_SOUND', 'M_CALL_PUSH_NOTIFICATION', 'PUSH_NEW_CONTACTS') in the UI layer and passes them to the generic `accountModule.updatePrivacyConfig(Map<String, dynamic>)`. `PrivacyConfig` is a fully typed model on the read path (`getPrivacyConfig()`), but the write path forces every call site to spell exact protocol strings, so a server rename or typo silently no-ops a setting with no compile-time check. This is inconsistent with komet_settings_screen, which drives typed methods like `setGhostMode`/`setAntiRead`.


**Решение:** Add typed setters on the account module (e.g. `setChatsPushNotification(bool)`, `setMessagePreview(bool)`, `setSound(bool)`, `setCallNotifications(bool)`, `setNewContacts(bool)`) that build the wire-format map internally in account.dart. notifications_screen.dart then calls `accountModule.setXxx(value)`, keeping its existing optimistic-update/rollback pattern.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Notification reply handler hand-builds a raw login packet, duplicating AccountModule.login()/_buildLoginPayload</summary>


**Где:** `lib/core/push/push_service.dart:379-397`, `lib/backend/modules/account.dart:978-1033`, `lib/backend/modules/account.dart:1203-1213`


**Проблема:** `_handleReply` builds a bare login request `api.sendRequest(Opcode.login, {...})` with a hand-copied payload, including the magic `Uint8List.fromList([0x0b, 0x32])` for `exp.chatsCountGroups` (push_service.dart:379-386). That exact payload is already produced by `AccountModule._buildLoginPayload` (account.dart:1203-1213), and `AccountModule.login()` wraps it with error checking, chatCacheFingerprint, token/account resolution and full response processing. This is core/push code reaching straight into the protocol layer instead of the backend module. If the login encoding changes (e.g. a new required field, or the fingerprint becomes mandatory), every other caller is updated via _buildLoginPayload while this hand-built copy silently goes stale, so background replies start failing while foreground login works. Note the copy also diverges today: it hardcodes `interactive: false` and omits `chatCacheFingerprint`.


**Решение:** Instantiate `AccountModule(api)` (already imported) and call `login(accountId: account, token: token)` — passing accountId explicitly so it does not resolve the wrong active account in the background isolate — reusing the shared payload build and response handling. If login()'s UI-facing side effects (status controller, _loggedIn) are undesirable in the background path, extract the shared `_buildLoginPayload` into something both callers use rather than re-copying the magic bytes.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Logout hand-rolls the account-teardown sequence and drops the spoof-clear step</summary>


**Где:** `lib/frontend/screens/profile/settings_tab.dart:200-223`, `lib/backend/modules/account.dart:1146-1151`


**Проблема:** `_SettingsTabState._doLogout()` drives `TokenStorage.deleteAccount`, `AppDatabase.deleteAccount`, `ContactCache.clear`, `TranscriptionCache.clear` and `ChatsModule.resetForAccountSwitch` directly from the widget, duplicating the delete-token+delete-db+clear-cache sequence that `AccountModule.removeAccount()`/`switchAccount()` already own. Because it is a hand-copy it has drifted: `removeAccount()` also calls `SpoofingService.clearAccountSpoof(accountId)`, but the logout path never does, so the device-spoofing profile for the logged-out account is left behind on disk. It also violates the UI -> backend-module layering by importing and driving core/storage and cache singletons from settings_tab.dart.


**Решение:** Add a single `Future<void> AccountModule.logout()` in account.dart that composes `removeAccount()` (which already clears spoof data) with disconnect, cache-clear and reconnect. `_doLogout()` then just does `await accountModule.logout()` and navigates. This removes the duplicated sequence, fixes the missing spoof-clear, and keeps storage/cache details out of the widget.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [S]</b> — Read-receipt handler mutates a shared cached chat model in place from the UI layer</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:3168-3182`


**Проблема:** `_onMessageRead` does `c.participants[userId] = mark` directly on the `chat` object obtained from `ChatsModule.getChat`, mutating a cached model in place from the UI layer instead of going through the backend module. If that instance/its participants map is shared with other consumers (chat list, chat info screen), the mutation propagates without notifying their listeners; if it isn't the same instance, state diverges. Either way it bypasses the layered UI -> backend module -> state architecture used elsewhere.


**Решение:** Route the read-mark update through `ChatsModule` (mirroring how `markRead`/`markUnread` work) so the participants map is updated in one authoritative place and listeners are notified, rather than reaching into the cached model from the chat screen.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [M]</b> — UI layer builds the device-spoof protocol struct and calls storage, bypassing the backend module layer</summary>


**Где:** `lib/frontend/screens/auth/token_login_screen.dart:4`, `lib/frontend/screens/auth/token_login_screen.dart:79-101`


**Проблема:** `TokenLoginScreen` imports `core/storage/spoofing_service.dart` directly, builds a full `SpoofProfile` (device name, OS version, arch, timezone, IDs, user agent, ...) inline in the widget, then calls `SpoofingService.saveProfile(...)` before `accountModule.loginWithToken`. This skips the `backend/modules` layer the architecture prescribes (UI -> backend module -> api.dart) — the UI talks straight to core/storage and assembles a protocol-shaped struct itself. If the on-wire device-profile shape or validation changes, the change lands inside this widget instead of one backend module, and any future spoof-login screen re-duplicates this construction.


**Решение:** Add a method on `accountModule` (e.g. `loginWithTokenAndSpoof(token, SpoofFields fields)`) that owns building the `SpoofProfile`, persisting it via `SpoofingService`, and performing the login; the screen should only collect raw field values and call one backend method.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [L]</b> — ContactCache is a static singleton read directly by UI widgets, non-reactive and bypassing the state/ layer</summary>


**Где:** `lib/backend/modules/messages.dart:15-77`


**Проблема:** ContactCache.get/getAvatar/getOptions are called directly from many widgets (message_bubble.dart, chat_list_screen.dart, chat_screen.dart, chat_info_screen.dart, call_screen.dart) rather than through a ChangeNotifier in state/ as the architecture prescribes. Because it is not observable, a widget that builds before a name resolves has no signal to rebuild when the name later arrives and only refreshes incidentally when something else rebuilds it, risking stale placeholder names.


**Решение:** Wrap ContactCache in a ChangeNotifier state class (mirroring PollsModule) that notifyListeners() on put/putAvatar/putOptions and have widgets consume it reactively instead of calling static getters during build.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [L]</b> — Contact name/avatar read from a non-reactive static cache during build</summary>


**Где:** `lib/frontend/widgets/message_bubble.dart:349`, `lib/frontend/widgets/message_bubble.dart:377`, `lib/frontend/widgets/message_bubble.dart:378`


**Проблема:** `ContactCache` (backend/modules/messages.dart:15) is a plain static class with in-memory Maps and no ChangeNotifier/listenable surface. `MessageBubble` (a StatelessWidget) reads `ContactCache.get(...)`/`getAvatar(...)` directly during build() for the sender header and leading avatar. Per the project's own layered architecture (`state/` holds ChangeNotifier classes the UI observes), contact data should reach the UI through a listenable. Because it doesn't, if a contact's name/avatar resolves after a bubble has already rendered, the bubble keeps showing the placeholder until some unrelated event rebuilds that row. (Impact is somewhat speculative — chat lists rebuild frequently on new messages/scroll — hence low severity.)


**Решение:** Route contact name/avatar lookups through a ValueNotifier/ChangeNotifier-backed contacts state (mirroring how `reactionsListenable` and `MediaDownloadProgress.notifier` are already used in this file) so bubbles rebuild when contact data arrives.

</details>


### Robustness, magic values, and stringly-typed state  (18 — 0 high)

_Sentinel strings, magic bitmasks, substring matching, and desync-on-overflow patterns encode important state without type safety or error signaling._

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — Buffer overflow silently discards bytes and desyncs the stream with no reconnect signal</summary>


**Где:** `lib/core/transport/receiver.dart:13`, `lib/core/transport/receiver.dart:25`, `lib/core/transport/receiver.dart:29`, `lib/backend/api.dart:376`


**Проблема:** The 24-bit payload-length field (`packedLen & 0xFFFFFF`, packet.dart:143 / receiver.dart:41) permits ~16 MB payloads on the wire, but `_maxBufferSize` is hardcoded to 2 MB (receiver.dart:13) with no stated relationship to the header format. If a single packet exceeds 2 MB before it is fully received, `feed()` logs an error and calls `reset()` (receiver.dart:25-30), discarding the buffered bytes and returning `const []` — while the connection stays open. `_onDataReceived` (api.dart:376) gets an empty list and continues as if nothing happened; there is no error signal from `feed()`/`reset()` to the caller. A too-large packet then thrashes (accumulate → overflow → reset → misaligned re-parse), leaving the session effectively dead until an unrelated reconnect. Note: the practical trigger is bounded because the client caps decompression at ~1 MB, but the missing error signal is a genuine robustness gap.


**Решение:** On overflow, surface a hard error to the transport owner — push onto the existing dispatcher error stream (or a dedicated receiver error signal) that Connection/Api listens to — so the caller forces an immediate disconnect+reconnect instead of silently feeding a desynced stream. Separately, size `_maxBufferSize` deliberately relative to the protocol's real maximum sync payload rather than an arbitrary constant.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [S]</b> — sendFileMessage blocks a hardcoded 3s before its first send attempt, redundant with its own retry loop</summary>


**Где:** `lib/backend/modules/messages.dart:1171-1197`


**Проблема:** await Future.delayed(initialDelay) (default 3s) runs unconditionally before even the first msgSend attempt. The method already has a not.ready retry loop immediately after (1199-1213) that handles server-side readiness, and the other four upload senders rely purely on that loop with no initial delay. The blind sleep adds a guaranteed 3s latency tax to every file send even when the server is ready, and still fails if readiness takes longer than 3s.


**Решение:** Remove the initial blind sleep and let the existing not.ready retry loop handle readiness, matching the other four senders and removing the fixed 3s latency.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — Catch-all try/catch around the entire chat parser silently drops chats</summary>


**Где:** `lib/backend/modules/chats.dart:1146-1278`


**Проблема:** _parseChat wraps ~130 lines of largely independent logic (title/icon resolution, options, last-message extraction, mute/favorite config, presence, participants, owner, admins) in one try/catch that logs and returns null on ANY exception. While most sub-steps are already individually defensive (as int?, tryParse, whereType), the broad catch means a single unexpected type/null in any one step aborts the whole parse and drops the chat from that sync with only a debug log — no partial recovery and nothing surfaced to the user. It runs on every login sync and every server push path.


**Решение:** Narrow the try/catch to the specific fallible conversions and let each fail safe with sensible per-field defaults rather than aborting the whole parse. Extract the function into smaller named steps (e.g. _resolveTitleAndIcon, _resolveLastMessage, _resolveMuteAndFavorite, _resolvePresence, _resolveAdmins), each independently defensive, so one bad field cannot take down the entire chat object.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — VP8 codec selection done via hand-written SDP regex surgery</summary>


**Где:** `lib/core/calls/call_session.dart:857`, `lib/core/calls/call_session.dart:874-927`


**Проблема:** _forceVp8 rewrites the freshly-created offer SDP with regexes to strip every payload type except VP8 and its RTX companion from the m=video line and its attribute block (desktop only, before setLocalDescription). It assumes a single video m= section and a specific a=fmtp:<pt> apt=<vp8> RTX shape, and silently returns the untouched SDP whenever a regex fails to match, with no signal that the intended codec restriction did not apply.


**Решение:** Use the WebRTC codec-preference API instead of text munging: after creating/obtaining the video transceiver, call getCapabilities('video') and transceiver.setCodecPreferences([...]) with VP8 ordered first before createOffer, letting the WebRTC stack emit a self-consistent SDP regardless of payload-type count or m-line layout.

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [L]</b> — Chat participants stored as a JSON-blob TEXT column, looked up via a LIKE substring scan instead of a normalized table</summary>


**Где:** `lib/core/storage/app_database.dart:351`, `lib/core/storage/app_database.dart:578-589`, `lib/backend/modules/chats.dart:173`


**Проблема:** chats_cache.participants stores the entire Map<int,int> (userId -> role) as a JSON string in one TEXT column. findDialogChatByParticipant locates an existing 1:1 dialog with `participants LIKE '%"$contactId":%'` (whereArgs `%"$contactId":%`) — a leading-% substring scan that cannot use any index, and whose correctness silently depends on the current JSON encoding quoting every key. Any future change to how participants are serialized breaks the match with no compiler- or query-level signal.


**Решение:** Add a normalized `chat_participants(chat_id, account_id, user_id, role)` table populated alongside chats_cache, indexed on (account_id, user_id). findDialogChatByParticipant becomes an indexed equality lookup instead of a string scan, and the table can serve future "which chats share contact X" queries without JSON parsing. Requires a schema migration (currently version 16).

</details>

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [M]</b> — Forwarded and unknown attachments are mistyped as AttachmentType.photo</summary>


**Где:** `lib/models/attachment.dart:3-16`, `lib/models/attachment.dart:698`, `lib/models/attachment.dart:767`, `lib/backend/modules/messages.dart:315-317`, `lib/frontend/screens/chats/scheduled_messages_screen.dart:287-289`


**Проблема:** ForwardedMessageAttachment (attachment.dart:698) and UnknownAttachment (attachment.dart:767) both hardcode `super(type: AttachmentType.photo)` because AttachmentType has no forward/unknown member. Verified that CachedMessage.previewText() (messages.dart:310-343) is an exhaustive switch over AttachmentType with no default, so a forward-only message returns 'Фото', and _attachLabel() (scheduled_messages_screen.dart:284-301) hits its photo case and also returns 'Фото'. message_bubble.dart correctly guards with `is ForwardedMessageAttachment`/`is UnknownAttachment` (lines 224, 237, 776, 927, 1209, 1221), but these two call sites don't, so every forwarded or unrecognized attachment is mislabeled as a photo in chat-list previews and the scheduled-messages list. Cosmetic/label impact only, not data loss, hence medium.


**Решение:** Add real `forward` and `unknown` members to AttachmentType and construct the two subclasses with them instead of reusing `photo` as a sentinel. Then handle the new cases explicitly in the two switch statements (forward -> original text or 'Переслано', unknown -> a generic 'Вложение' label), which also removes the need for every future caller to remember the `is` check before trusting `.type`.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — Manual CachedMessage reconstruction in _loadForwardedSenderNames drops isControl/deleted/editHistory</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:3718`


**Проблема:** When an unknown forwarded-sender name resolves, the message is rebuilt by hand-constructing a new CachedMessage(...) from a subset of the old one's fields, omitting isControl, deleted, and editHistory. CachedMessage.copyWith (backend/modules/messages.dart:387) already carries every field forward and already accepts an `attachments` override, and is used correctly elsewhere. Here an edited forwarded message (non-null editHistory) or a soft-deleted one silently resets those fields to their defaults during ordinary pagination — real silent data loss for the affected rows.


**Решение:** Replace the manual constructor with `msg.copyWith(attachments: newAttaches)`. copyWith already covers attachments, so all other fields (isControl, deleted, editHistory, payload) are preserved by construction and no future field can be silently dropped.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Session-stale recovery state machine duplicated across two auth screens</summary>


**Где:** `lib/frontend/screens/auth/code_confirmation_screen.dart:47-156`, `lib/frontend/screens/auth/password_2fa_screen.dart:24-66`


**Проблема:** Both `_CodeConfirmationScreenState` and `_Password2FAScreenState` independently reimplement the same session-epoch tracking: `_epoch`, `_recovering`, `_dropNotified`, an identical `_sessionStale` getter comparing `api.sessionEpoch`/`api.state`, a `_stateSub` listener calling `_onSessionState`, and a `_recoverStaleSession` handler. The two copies have already drifted (code_confirmation re-requests a fresh code and resumes; password_2fa just pops the screen). A future change to `SessionState`/`sessionEpoch` semantics in api.dart could be applied to one copy and missed in the other, leaving one auth step silently stuck instead of recovering after a reconnect.


**Решение:** Extract a reusable mixin or helper (in state/ or backend/) that owns `epoch`, `isStale`, the state-stream subscription, and a per-screen recovery callback (resend code vs. pop-and-notify), and have both screens compose it instead of copy-pasting the fields and methods.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — Call-history row removal animation duration is duplicated as an unlinked magic constant</summary>


**Где:** `lib/frontend/screens/calls/calls_tab.dart:271-283`, `lib/frontend/screens/calls/calls_tab.dart:466-472`


**Проблема:** _deleteCall awaits Future.delayed(const Duration(milliseconds: 260)) (line 277) before removing the entry from _calls, while _RemovableCallEntryState's AnimationController independently uses duration: const Duration(milliseconds: 260) (line 470) for the collapse/fade-out. The two constants must be kept in sync by hand; changing either desyncs list removal from the actual animation. Both confirmed.


**Решение:** Drop the parent-side delay and duplicated constant; have _RemovableCallEntry accept an onDismissed callback fired from an AnimationStatus.dismissed listener on its own controller, so real animation completion drives the list removal.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [S]</b> — No error boundary around push-handler dispatch; one throwing handler drops the rest of the batch</summary>


**Где:** `lib/core/transport/dispatcher.dart:119`, `lib/backend/api.dart:377`, `lib/backend/api.dart:394`


**Проблема:** `PacketDispatcher.dispatch()` invokes `_pushHandlers[packet.opcode]?.call(packet)` (dispatcher.dart:119) with no try/catch. `dispatch()` is called at api.dart:394 inside the `for` loop over every packet decoded from one socket read (api.dart:377), and only `unpackPacket` is guarded (api.dart:379-384) — the `dispatch()` call is not. If any single push handler throws (e.g. a bug reacting to a malformed notifChat/notifMessage payload), the exception propagates out of the loop, aborting processing of every other already-decoded packet in that batch and becoming an unhandled async error, with no log identifying the failing handler.


**Решение:** Wrap the handler invocation in `dispatch()` in a try/catch, log the opcode (via `Opcode.name`) and the error, and continue, so one misbehaving push handler cannot cascade into dropping unrelated packets (read receipts, typing indicators, other chats' updates) that arrived in the same TCP read.

</details>

<details>
<summary><b>🟠 MED · СОМНИТ · [M]</b> — Outbox flush only retries plain-text pending rows; attachment/poll/location sends left in 'pending' are never recovered</summary>


**Где:** `lib/backend/modules/outbox.dart:44-45`


**Проблема:** if (text == null || text.isEmpty || pending.payload != null) continue; skips any pending DB row carrying a payload (photo/video/audio/file/poll/location) on every flush, forever. Since flush() (triggered on reconnect) is the only generic recovery for 'pending' messages, an attachment send interrupted between local insert and server ack has no path back to being sent or surfaced as failed — it sits in the local DB indefinitely.


**Решение:** Either re-invoke the appropriate typed sender based on the stored payload's attachment type, or mark non-text pending rows 'failed' after a timeout so the UI can offer manual retry/delete instead of invisible limbo. (Verify attachment sends actually create 'pending' rows; if they never do, downgrade or drop.)

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — Poll settings encoded as an unexplained bitmask magic number</summary>


**Где:** `lib/backend/modules/messages.dart:1562`


**Проблема:** final settings = (anonymous ? 4 : 0) | (multiple ? 1 : 0); bakes the meaning of bits 4 and 1 into one call site with no named constants; adding or auditing a poll flag requires reverse-engineering the protocol from this line.


**Решение:** Define named bit constants (e.g. _pollAnonymousFlag = 4, _pollMultipleFlag = 1) and compose settings from them.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [M]</b> — Magic sentinel string encodes "no cached last message" state in the text column</summary>


**Где:** `lib/backend/modules/chats.dart:255`, `lib/backend/modules/chats.dart:748`, `lib/backend/modules/chats.dart:767`


**Проблема:** lastMsgPlaceholder ('__komet_lastmsg_placeholder__') is a magic string written into the same last_msg_text DB column that stores real message text (line 748), then detected via string equality (line 767) to decide whether to reconcile. This overloads the text column with a semantic 'unknown/placeholder' state, so every future consumer of lastMsgText must remember to special-case the sentinel. The state is deliberate and documented, so real-world risk is low, but it is not type-checked.


**Решение:** Add an explicit nullable/boolean field (e.g. lastMsgIsPlaceholder on CachedChat backed by a dedicated DB column) instead of overloading the text column with a sentinel value, so the placeholder state is explicit and type-checked rather than string-matched.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — Call-setup paths throw generic untyped Exceptions instead of a typed error</summary>


**Где:** `lib/backend/modules/calls.dart:91`, `lib/backend/modules/calls.dart:102`, `lib/backend/modules/calls.dart:156`, `lib/backend/modules/calls.dart:167`


**Проблема:** initiateCall/joinByLink throw plain Exception('initiateCall: bad response')-style strings on failure, unlike webapp.dart's WebAppUnavailable (webapp.dart:79-86), a proper typed exception carrying a user-facing message. Callers can only catch generic Exception and string-match to distinguish failure kinds, and there is an established typed-exception pattern in the same layer to follow.


**Решение:** Introduce a typed exception (e.g. CallSetupException with a reason/userMessage) thrown consistently from both methods, mirroring WebAppUnavailable, so UI code can branch on failure kind instead of matching message text.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [M]</b> — Peer-Komet detection uses an unversioned magic-string handshake mixed with JSON frames</summary>


**Где:** `lib/core/calls/call_session.dart:99-100`, `lib/core/calls/call_session.dart:571-615`


**Проблема:** Detecting whether the remote peer is also Komet is done by opening a 'komet' data channel and exchanging literal strings 'AreYouKomet?' / 'YesImKomet😎' (lines 99-100), matched by exact equality in _onProbeMessage (610-614) alongside the {'t':'chat'} / {'t':'game'} JSON envelope carried on the same channel. There is no version field, so any future edit to either string breaks detection for older peers with no fallback, and two message conventions (raw string vs JSON) share one wire.


**Решение:** Fold the capability probe into the existing JSON envelope, e.g. {'t':'probe','v':1} / {'t':'probe-ack','v':1}, so the channel carries one message format and a version number is available for future negotiation.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — profile_options persisted as a hand-rolled comma-joined string instead of JSON, with silent parse-failure fallback</summary>


**Где:** `lib/core/storage/app_database.dart:76-88`, `lib/core/storage/app_database.dart:116`


**Проблема:** ProfileData.profileOptions (List<int>) is serialized with `profileOptions?.join(',')` (toDbRow) and parsed back with `.split(',').map(int.parse)` inside a try/catch that swallows any failure and returns null, discarding the whole list. Every other structured column in the same schema (participants/admins/options, edit_history) uses jsonEncode/jsonDecode, so this one field uses a different, more fragile ad-hoc format for no apparent reason.


**Решение:** Store profile_options as `jsonEncode(profileOptions)` / read via `jsonDecode`, consistent with the other list/map columns, and drop the comma-split parser. Since existing rows hold the legacy comma format, either bump the schema version with a migration that rewrites the column, or make fromDbRow tolerate both formats during a transition.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — FLIP reorder measurement uses a bare catch-all and magic thresholds</summary>


**Где:** `lib/frontend/screens/chats/chat_list_screen.dart:2789-2797`, `lib/frontend/screens/chats/chat_list_screen.dart:2799-2811`


**Проблема:** Confirmed. `_measureContentY` wraps `RenderAbstractViewport.of(box).getOffsetToReveal(...)` in a bare `try { ... } catch (_) { return null; }` (2792-2796), swallowing any exception including genuine bugs, and `_runMove` discards deltas with unexplained magic thresholds `dy.abs() < 1.0 || dy.abs() > 2000` (2806). (Downgraded from medium and suggestion narrowed: the animation works and a wholesale rewrite to AnimatedList is disproportionate; the concrete defects are the blanket catch and the unnamed thresholds.)


**Решение:** Narrow the catch to the specific failure mode `getOffsetToReveal` can raise (or guard the precondition) so unexpected exceptions surface, and lift the `1.0`/`2000` thresholds into named constants so their intent is explicit rather than inline magic numbers.

</details>

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — TOS-read flag stored via a raw SharedPreferences magic-string key (with a typo) inline in the widget</summary>


**Где:** `lib/frontend/screens/auth/login_screen.dart:98-105`, `lib/frontend/screens/auth/login_screen.dart:123-131`


**Проблема:** `_checkTOS`/`_markTOSRead` call `SharedPreferences.getInstance()` directly from the widget and read/write the flag with the literal string `'IsReadeTOS'` (note the 'Reade' typo), with no shared constant — unlike `ServerConfig.prefHostKey`/`prefPortKey` used by the sibling settings sheets in the same directory. A future screen or refactor that re-types the key correctly ('IsReadTOS') silently creates a divergent key, so the read state is lost and the TOS prompt reappears.


**Решение:** Add a named constant (e.g. `TermsConfig.readFlagKey`) alongside the other config constants, or move this into a small `TermsService` in core/storage that owns the key and read/write methods, matching the server/proxy config pattern.

</details>


### Backend parsing and model duplication  (22 — 0 high)

_Attachment/message/chat/folder parsing and JSON decode-with-fallback logic are re-implemented across construction paths with divergent behavior._

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Attachment/FORWARD/CONTROL parsing duplicated across three CachedMessage construction paths with inconsistent behavior</summary>


**Где:** `lib/backend/modules/messages.dart:446-463`, `lib/backend/modules/messages.dart:724-741`, `lib/backend/modules/messages.dart:534-541`


**Проблема:** CachedMessage.fromDbRow, MessagesModule._parseMessage and CachedMessage.fromPushPayload each re-implement 'if link.type==FORWARD build ForwardedMessageAttachment, else map attaches to MessageAttachment.fromMap, else detect AttachmentType.control' with real divergences: fromPushPayload does NOT handle FORWARD links and never sets isControl, and fromDbRow omits the whereType<Map> guard the other two use. A fix in one copy silently misses the others.


**Решение:** Add a single static helper on CachedMessage returning (List<MessageAttachment>?, bool isControl) from a raw map, and call it from all three paths so FORWARD and control detection stay identical everywhere messages are built.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Read-mutate-save-bump boilerplate on untyped Map rows, repeated across ~6 methods</summary>


**Где:** `lib/backend/modules/chats.dart:367-394`, `lib/backend/modules/chats.dart:396-424`, `lib/backend/modules/chats.dart:426-453`, `lib/backend/modules/chats.dart:680-696`, `lib/backend/modules/chats.dart:1518-1538`, `lib/backend/modules/chats.dart:1596-1627`


**Проблема:** markRead, markUnread, applyOutgoing, _handleNotifMessage, setChatTitle and setChatMute each independently load chat rows via AppDatabase.loadChat, copy to a mutable Map<String,dynamic>, hand-edit string-keyed fields (row['last_msg_text'], row['unread_count'], row['dont_disturb_until']...), call AppDatabase.saveChats([row]) then _bump(). The DB column names are duplicated as raw string literals at every call site, so a typo silently no-ops instead of failing to compile, and a schema rename requires editing every occurrence by hand. Note CachedChat already has toDbRow() (used at line 897) but no copyWith().


**Решение:** Add CachedChat.copyWith(...) and a single private helper such as `static Future<void> _updateChat(accountId, chatId, CachedChat Function(CachedChat) mutate)` that loads the row, converts to CachedChat, applies a typed mutation via copyWith, converts back with toDbRow() once, saves, and bumps. Rewrite the call sites to use it, eliminating the repeated stringly-typed Map editing.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — JSON payload decode-with-fallback duplicated; manual re-implementation of messagePreviewElements</summary>


**Где:** `lib/backend/modules/chats.dart:623-634`, `lib/backend/modules/chats.dart:729-738`, `lib/backend/modules/chats.dart:842-851`


**Проблема:** The pattern `final raw = ...['payload']; if (raw is String && raw.isNotEmpty) { try { Map<String,dynamic>.from(jsonDecode(raw) as Map) } catch(_) { fallback } }` is written out separately in _handleNotifMessage edit-merge (623-634), _reconcileLastMessage (719-738), and _handleNotifMsgReactionsChanged (842-851). Additionally, _reconcileLastMessage at 729-738 re-implements inline exactly what the existing static helper messagePreviewElements(msg) already does (extract elements list and jsonEncode it when text is non-empty).


**Решение:** Extract a single `static Map<String, dynamic>? _decodePayload(dynamic raw)` helper used by all decode sites, and replace the manual element extraction in _reconcileLastMessage (729-738) with a direct call to the existing messagePreviewElements(payload) helper.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — Folder JSON parsing logic duplicated across ChatFolder and FoldersModule</summary>


**Где:** `lib/backend/models/chat_folder.dart:31-37`, `lib/backend/models/chat_folder.dart:60-66`, `lib/backend/models/chat_folder.dart:74-80`, `lib/backend/modules/folders.dart:96-104`, `lib/backend/modules/folders.dart:138-150`, `lib/backend/modules/folders.dart:167-179`, `lib/backend/modules/folders.dart:216-224`


**Проблема:** ChatFolder.fromJson repeats the identical int-list-parsing lambda (e is int ? e : (e is String ? int.tryParse(e) ?? 0 : 0)) verbatim for include, favorites and options. Separately, FoldersModule.loadFolders (96-104), applyPayload (138-150) and applyFromLoginConfig (167-179) each re-implement the same 'decode JSON list -> map to ChatFolder.fromJson (with per-item Map cast/try-catch) -> collect' block, and setFolderFavorites (216-224) re-decodes the raw sync snapshot into a folder list by hand instead of reusing loadFolders(accountId).


**Решение:** Add a private `static List<int> _parseIntList(dynamic raw)` used by include/favorites/options, a private `static List<ChatFolder> _parseFolderList(List<dynamic> json)` used by loadFolders/applyPayload/applyFromLoginConfig, and have setFolderFavorites call loadFolders(accountId) (noting it also sorts, which is harmless before re-persist) instead of duplicating the decode-and-parse logic.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — DraftStore and ChatWallpaperStore reimplement the same per-chat SharedPreferences-JSON store</summary>


**Где:** `lib/core/storage/draft_store.dart:6-57`, `lib/core/storage/chat_wallpaper_store.dart:85-191`


**Проблема:** Both classes independently implement the same shell: a `'$accountId/$chatId'` composite key, a `_loaded`-guarded in-memory map hydrated once from a single JSON blob in SharedPreferences (jsonDecode wrapped in silent try/catch), a `ValueNotifier<int> revision` bumped on every mutation, and a save path that re-serializes the whole map with jsonEncode. Verified byte-for-byte in structure; the only real differences are the value type (String vs ChatWallpaper) and the wallpaper store's extra file bookkeeping (_deleteImage).


**Решение:** Factor the common shell into a generic `abstract class PerChatJsonStore<T>` owning `_key`, `_loaded`, `revision`, `load()` and the persist path, parameterized by `T? Function(Object?) fromJson` / `Object? Function(T) toJson`. DraftStore and ChatWallpaperStore become thin subclasses supplying (de)serialization and any side effects (file cleanup for wallpapers). No code comments per conventions.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — countries.dart parses and discards a full duplicate phone-metadata table for every country</summary>


**Где:** `lib/core/config/countries.dart:62-89`, `lib/core/config/countries.dart:287-288`


**Проблема:** `_countriesRuJson` (declared at line 287) is a full ~195-entry JSON blob carrying `phoneCode`, `phoneDigits`, `phoneMask`, `phoneGroupSizes` and `phoneGroupSeparators` for every country — a structural duplicate of `_countriesEnJson`. But `_buildCountries()` only reads `item['alpha2']` and `item['name']` from `ruList` (countries.dart:68-71) to build `ruByCode`; all the phone fields in the Russian blob are decoded by `jsonDecode` and then thrown away. Maintaining two full phone tables means any mask/group-size fix must be applied twice or the tables silently drift apart.


**Решение:** Shrink `_countriesRuJson` to just `{alpha2, name}` pairs, or better, merge into one dataset shaped `[{alpha2, en, ru, phoneCode, phoneDigits, phoneMask, phoneGroupSizes, phoneGroupSeparators}]` so there is a single source of truth per country instead of two lists that must be kept in sync by hand.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [M]</b> — The render-to-JPEG-file pipeline is copy-pasted across all three photo editors</summary>


**Где:** `lib/frontend/widgets/attachment/photo_editor.dart:376`, `lib/frontend/widgets/attachment/photo_editor.dart:998`, `lib/frontend/widgets/attachment/photo_editor.dart:2322`


**Проблема:** PhotoCropEditor._bake, PhotoDrawEditor._bake and PhotoAdjustEditor._bake each independently repeat the identical tail: picture.toImage(w,h) -> picture.dispose() -> toByteData(rawRgba) -> image.dispose() -> null-check -> encodeRgbaToJpeg -> null-check -> getTemporaryDirectory() -> build a `komet_<name>_<ts>.jpg` path -> writeAsBytes. Any change to JPEG quality, the bd==null handling, temp naming, or EXIF orientation must be made in three places.


**Решение:** Extract a single `Future<File?> rasterPictureToJpegFile(ui.Picture picture, int width, int height, {required String prefix})` helper in a core/media utility that performs toImage -> toByteData -> encodeRgbaToJpeg -> write-temp-file once, called by all three editors with their own prefix and computed dimensions.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Pending-request bookkeeping is split across two maps keyed by the same seq</summary>


**Где:** `lib/core/transport/dispatcher.dart:15`, `lib/core/transport/dispatcher.dart:16`, `lib/core/transport/dispatcher.dart:55`, `lib/core/transport/dispatcher.dart:56`, `lib/core/transport/dispatcher.dart:91`, `lib/core/transport/dispatcher.dart:134`


**Проблема:** `_pendingRequests` (Completer per seq, dispatcher.dart:15) and `_requestTimestamps` (DateTime per seq, dispatcher.dart:16) are two separate maps kept in lockstep by hand at every call site: `registerPending` inserts into both (55-56), `dispatch()` removes from both (91-92), `_cleanupStaleRequests` removes from both (134-135), `clearPending` clears both (149-150). Every future change must remember to touch both maps, and any missed pairing silently leaks or desynchronizes entries.


**Решение:** Merge into a single `Map<int, _PendingRequest>` where `_PendingRequest` holds `{Completer<Packet> completer, DateTime sentAt}`, halving map operations on every register/complete/timeout/clear path and removing the risk of the two maps disagreeing.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [L]</b> — Opcode numeric values and their human-readable names are hand-duplicated in two parallel structures</summary>


**Где:** `lib/core/protocol/opcode_map.dart:9`, `lib/core/protocol/opcode_map.dart:204`, `lib/core/protocol/opcode_map.dart:207`, `lib/core/protocol/opcode_map.dart:209`


**Проблема:** Each of the ~140 opcode constants (opcode_map.dart:9-204) has an independently hand-typed entry in the `_names` map (209-365) mapping the same value to a label. Nothing enforces the two stay in sync; a new/renamed opcode missing from `_names` falls back to `'UNKNOWN($opcode)'` (line 207) silently. The failure mode is purely cosmetic (log labels), hence low severity, but it is genuine duplication across ~140 entries.


**Решение:** Model this as a single source of truth, e.g. a Dart enhanced enum `enum Opcode { ping(1, 'PING'), debug(2, 'DEBUG'), ... }` carrying both wire value and label, with a lookup-by-value helper for decoding, making code/name drift structurally impossible. Note this is a large change because `Opcode.<name>` is used as a raw int at many call sites; if that migration is too costly, a lighter alternative is an assertion/test that verifies every declared opcode has a `_names` entry.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — initiateCall and joinByLink duplicate internal-params parsing</summary>


**Где:** `lib/backend/modules/calls.dart:95-108`, `lib/backend/modules/calls.dart:160-171`


**Проблема:** Both methods independently JSON-decode a string field (internalCallerParams vs internalParams), extract endpoint with identical null-throw handling, and dig id['internal'] for callsUserId. Any protocol fix must be applied twice and is easy to miss in one path (e.g. joinByLink never extracts peerExternalId the way initiateCall does at line 107-108).


**Решение:** Extract a private helper such as _parseCallerEndpoint(Map payload, String key) returning endpoint/callsUserId/external, used by both methods, throwing one typed exception on a missing endpoint.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [M]</b> — Sticker set/item batch-fetch-and-cache logic duplicated</summary>


**Где:** `lib/backend/modules/stickers.dart:120-137`, `lib/backend/modules/stickers.dart:139-160`


**Проблема:** _ensureSetMetas and ensureStickers are structurally identical: filter already-cached ids, chunk by 100, call Opcode.assetsGetByIds, guard on isOk/payload shape, iterate the response list, and populate a cache map — differing only in the 'type' string, the response list key ('stickerSets' vs 'stickers'), and the model factory (StickerSet.fromMap vs StickerItem.fromMap). A protocol change to this fetch shape must be edited in both.


**Решение:** Factor out a generic _fetchAndCache<T>({required String type, required List<int> ids, required String listKey, required T Function(Map) fromMap, required Map<int, T> cache}) used by both methods.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [M]</b> — connect() duplicates its failure-cleanup sequence across two catch blocks</summary>


**Где:** `lib/backend/api.dart:113-122`, `lib/backend/api.dart:152-163`


**Проблема:** The connect-failure catch (113-122) and the handshake-failure catch (152-163) repeat nearly the same sequence: _cleanup(), _setSessionState(disconnected), _armBypassIfPossible(...), _scheduleReconnect() — the handshake path additionally awaits _connection.disconnect(). Adding a new failure path means re-deriving this sequence by hand, which is easy to get subtly wrong.


**Решение:** Extract a shared private _handleConnectFailure(Object error, {required String phase}) that performs the cleanup/bypass-arming/reconnect-scheduling once (with socket disconnect where needed), and call it from both catch blocks.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Architecture-from-Platform.version parsing duplicated verbatim for Linux/Windows</summary>


**Где:** `lib/backend/api.dart:222-225`, `lib/backend/api.dart:238-241`


**Проблема:** The identical fragile substring parse of Platform.version (substring(indexOf('_') + 1, length - 1)) to extract CPU architecture is repeated verbatim in the Linux and Windows branches of sendHandshake.


**Решение:** Extract a small _archFromPlatformVersion() helper called from both branches so the fragile parsing exists in one place.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Attachment-to-CloudFile extraction loop duplicated between fetchFiles and fetchLatestFile</summary>


**Где:** `lib/backend/modules/cloud_storage.dart:116-140`, `lib/backend/modules/cloud_storage.dart:143-168`


**Проблема:** Both methods contain the identical nested loop — for each message, for each attachment, check `a is FileAttachment && a.name != null`, then build a CloudFile with the same seven fields — differing only in whether they collect all matches or return the first (optionally id-matching) one.


**Решение:** Extract a shared helper (e.g. CloudFile _toCloudFile(Message msg, FileAttachment a, int chatId, int accountId), or an Iterable<CloudFile> generator over a message list) used by fetchFiles (collect all) and fetchLatestFile (early return), keeping the CloudFile construction in one place.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Duplicated pseudo-random filename and multipart-boundary generation</summary>


**Где:** `lib/backend/modules/file_uploader.dart:174-175`, `lib/backend/modules/file_uploader.dart:397-398`, `lib/backend/modules/file_uploader.dart:263`, `lib/backend/modules/file_uploader.dart:323`


**Проблема:** `(DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF).toString()` is repeated verbatim to synthesize an upload filename in uploadMediaFile and uploadVideoFile, and `'----KometBoundary${DateTime.now().microsecondsSinceEpoch}'` is repeated verbatim to build a multipart boundary in uploadImage and uploadPhoto.


**Решение:** Factor both into small private helpers String _syntheticFilename() and String _multipartBoundary(), used from all four call sites, so the generation scheme lives in one place.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Spoofed third-party User-Agent literal hardcoded and duplicated across header builders</summary>


**Где:** `lib/backend/modules/file_uploader.dart:252`, `lib/backend/modules/file_uploader.dart:516`


**Проблема:** The exact string 'OKMessages/26.14.1 (Android 11; TECNO MOBILE LIMITED TECNO LE7n; xxhdpi 480dpi 1080x2208)' is hardcoded twice, in _writeHeaders and _writeImageHeaders, and can silently drift out of sync when the spoofed version is bumped. The third header builder, _okCdnRequest (lines 477-489), sends no User-Agent at all — the same inconsistency in the other direction.


**Решение:** Hoist the User-Agent into a single shared constant referenced by all header builders (including _okCdnRequest, which currently omits it). If the app already maintains a device/spoofing fingerprint for the main transport connection, source it from there so the CDN UA and the protocol UA stay consistent — but verify that layer actually owns this string before wiring it, rather than assuming it does.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Enum <-> String parsing reimplemented ad hoc and inconsistently per settings class</summary>


**Где:** `lib/core/config/app_bubble_behavior.dart:24-27`, `lib/core/config/app_bubble_shape.dart:24-27`, `lib/core/config/app_message_actions_style.dart:23-26`, `lib/core/config/app_theme_mode.dart:23-34`, `lib/core/config/app_chat_chrome.dart:11-31`, `lib/core/config/app_visual_style.dart:11-25`


**Проблема:** Six settings classes each hand-write their own enum<->String round trip with no shared helper: three compare against `Enum.x.name` one member at a time (bubble behavior/shape, message actions), AppThemeMode switches on raw string literals `'light'/'dark'/'schedule'` instead of `.name` (23-34), AppChatChrome uses a manual switch on raw literals `'color'/'blur'/'none'` for both parse and encode (11-31) rather than `.name`, and AppVisualStyle compares/encodes the raw literal `'glossy'`/`'materialYou'` (11-25). Where raw literals are used they can silently drift from the enum's `.name`, and every added member requires updating separate hand-written mappings in lockstep.


**Решение:** Add one generic helper `T enumFromName<T extends Enum>(List<T> values, String? raw, T fallback) => values.firstWhere((v) => v.name == raw, orElse: () => fallback);`, paired with `.name` for encoding, across all enum-backed settings. This folds naturally into the `PersistedEnum<T>` abstraction from the load/save duplication finding.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — FormatRange flattening loop duplicated inside RichMessageController</summary>


**Где:** `lib/frontend/widgets/rich_message_controller.dart:57`, `lib/frontend/widgets/rich_message_controller.dart:208`


**Проблема:** `elementsForSend()` (57-69) and `buildTextSpan()` (208-219) contain the identical `_intervals.forEach((format, list) { for (final interval in list) ranges.add(FormatRange(format: format, start: interval.start, length: interval.end - interval.start)); })` loop to flatten the `_intervals` map into a `List<FormatRange>` — once to serialize for sending, once to feed the span builder.


**Решение:** Extract a private `List<FormatRange> _toFormatRanges()` and call it from both.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Photo-grid corner-radius logic duplicated verbatim between two-photo and grid layouts</summary>


**Где:** `lib/frontend/widgets/message_bubble.dart:1665`, `lib/frontend/widgets/message_bubble.dart:1698`


**Проблема:** `_buildTwoPhotos` (1665-1674) and `_buildPhotoGrid` (1698-1707) contain byte-identical matchTop/matchBottom + topR/bottomL/bottomR corner-radius derivation. A future bubble-shape tweak applied to one and missed on the other would silently diverge. (Note: the candidate also listed `_buildSinglePhoto` at 1553, but that method uses a genuinely different formula — `_smallRadius` fallbacks and an isMe-conditional bottomL — so it is not a true duplicate and a single 3-boolean helper cannot cover all three.)


**Решение:** Extract `BorderRadius _multiPhotoCornerRadius({required bool matchTop, required bool matchBottom, required bool isMe})` shared by `_buildTwoPhotos` and `_buildPhotoGrid`. Leave `_buildSinglePhoto` as-is (or give it its own clearly-named helper) since its corner formula differs.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — Country display-name selection logic duplicated instead of centralized on the model</summary>


**Где:** `lib/frontend/screens/auth/login_screen.dart:152-155`, `lib/frontend/screens/auth/select_country_screen.dart:56,130`


**Проблема:** The `lang == 'ru' ? country.ru : country.en` ternary for picking a localized country display name is written in `LoginScreen._countryDisplayName` and again inline in `SelectCountryScreen.build` (lang computed at 56, ternary at 130), rather than living once on `CountryName`. If a third locale or a fallback rule is added, the two sites can be updated inconsistently.


**Решение:** Add a `String displayName(String languageCode)` method to `CountryName` in core/config/countries.dart and call `country.displayName(lang)` from both screens.

</details>

<details>
<summary><b>🟡 LOW · ОПТ · [S]</b> — Poll.withStateMap re-derives state by serializing back to a Map and re-parsing instead of merging directly</summary>


**Где:** `lib/models/poll.dart:58-69`, `lib/models/poll.dart:71-114`


**Проблема:** withStateMap (called from polls.dart:81 after every vote) rebuilds a throwaway List<Map> from the already-typed `answers`, wraps it with the new stateMap, and calls Poll.fromServerMap again, repeating the entire resultsById construction and answer-merge loop. It works only because the merge logic is duplicated through a Map round trip rather than factored out. Minor (small data, infrequent), hence low.


**Решение:** Extract the resultsById build + answer->PollAnswer merge from fromServerMap into a private static helper taking the raw answer list (or typed answers) plus the state map, and have both fromServerMap and withStateMap call it directly, dropping the intermediate Map re-encoding.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [L]</b> — Attachment-kind classification re-derived independently in several places</summary>


**Где:** `lib/frontend/widgets/message_bubble.dart:173`, `lib/frontend/widgets/message_bubble.dart:178`, `lib/frontend/widgets/message_bubble.dart:185`, `lib/frontend/widgets/message_bubble.dart:217`, `lib/frontend/widgets/message_bubble.dart:772`, `lib/frontend/widgets/message_bubble.dart:1214`


**Проблема:** 'What kind of content is this message' is answered independently by `_hasShareAttachment` (173), `_isVideoNote` (178), `_isSticker` (185), `_computeContentType` (217, a first-item switch), `_reactionsUnderBubble` (772, its own first/whereType checks) and `_buildAttachmentContent` (1214, a third independent whereType dispatch chain in a different priority order than `_computeContentType`). All share the 'first non-keyboard attachment determines the kind' assumption but each encodes it slightly differently, so a new attachment type or priority rule must be updated in lock-step across all of them. (The candidate's claim that `_computeContentType` and `_buildAttachmentContent` could disagree is overstated — `_buildAttachmentContent` only runs when contentType is already `attachment` — so the risk is maintenance drift, not a live rendering mismatch, hence low severity.)


**Решение:** Introduce one `_MessageKind` computed once per message from a single attachment scan, exposing `.isShare`/`.isVideoNote`/`.isSticker`/`.contentType`/`.reactionsUnderBubble`, so exactly one place encodes the attachment priority order and every getter/builder reads from it.

</details>


### No-comments convention violations  (5 — 0 high)

_Explicit project rule forbids code comments, yet several files carry TODOs, banners, and explanatory comments._

<details>
<summary><b>🟡 LOW · КОСТЫЛЬ · [S]</b> — Comments left in code violate the project's explicit no-comments convention</summary>


**Где:** `lib/frontend/screens/calls/call_screen.dart:867`, `lib/frontend/screens/calls/calls_tab.dart:151`, `lib/frontend/screens/contacts/contacts_tab.dart:107`


**Проблема:** CLAUDE.md/AGENTS.md mandate 'No comments in code,' but a garbled inline TODO ('Бля иконку кометы в код дайтtе' мориарти 00. ал.о', line 867) sits above the Komet call-info icon button, and two other files carry throwaway comments ('// Open call details or initiate call' at calls_tab.dart:151, '// Sort contacts by first name' at contacts_tab.dart:107). All three confirmed.


**Решение:** Remove the comments; track the unfinished-work TODO in an issue tracker instead of an inline note, and rely on self-documenting names for the rest.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [S]</b> — Leftover TODOs and explanatory comments violate the no-comments convention</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:4350`, `lib/frontend/screens/chats/chat_screen.dart:1332`


**Проблема:** CLAUDE.md/AGENTS.md state 'No comments in code — write self-documenting code instead,' yet the render path carries unresolved `// TODO: Локализация` / `// TODO: Cклонения` markers (4350-4351), and other spots carry explanatory comments (e.g. 1332-1335). The TODOs also flag known-incomplete localization work sitting directly in build().


**Решение:** Remove the comments per the project convention, expressing intent through naming/structure, and track the localization gap as an issue rather than an in-code TODO.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [S]</b> — Existing code comments violate the project's no-comments convention</summary>


**Где:** `lib/frontend/screens/chats/chat_list_screen.dart:207-209`, `lib/frontend/screens/chats/chat_list_screen.dart:1182`, `lib/frontend/screens/chats/chat_list_screen.dart:1555-1556`


**Проблема:** Confirmed against CLAUDE.md's 'No comments in code' rule. A doc comment above `_getChatsBody` explains the memoization hack (207-209), an inline comment annotates the nav-tab haptic (1182), and a two-line comment explains the `ContactCache.isOfficial` vs `chat.isOfficial` distinction (1555-1556).


**Решение:** Remove the comments and express intent through structure/naming: a named getter such as `bool _isVerifiedContact(int secondId, CachedChat chat)` around the verified-badge check makes the two-source distinction self-documenting; the `_getChatsBody` comment is subsumed by the memoization rewrite.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [S]</b> — chat_info_screen.dart uses banner/inline comments, violating the project's 'no comments in code' convention</summary>


**Где:** `lib/frontend/screens/chats/chat_info_screen.dart:67`, `lib/frontend/screens/chats/chat_info_screen.dart:75`, `lib/frontend/screens/chats/chat_info_screen.dart:222`, `lib/frontend/screens/chats/chat_info_screen.dart:298`, `lib/frontend/screens/chats/chat_info_screen.dart:323`, `lib/frontend/screens/chats/chat_info_screen.dart:1155`


**Проблема:** CLAUDE.md/AGENTS.md mandate 'No comments in code. Write self-documenting code instead.' This file carries roughly a dozen '// ─── SECTION ───' banner comments plus inline '// DIALOG' / '// CHAT' field-group comments; it is the only file in this audit set that does so (search_screen, create_group_flow, poll_create_screen, scheduled_messages_screen contain none).


**Решение:** Remove the banner and inline comments. The section methods (_subtitle, _buildActions, _memberTile, _formatLastSeen, etc.) are already self-naming, so no widget-splitting is required to preserve readability.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [S]</b> — Custom painter contains explanatory comments, violating the project's no-comments convention</summary>


**Где:** `lib/frontend/screens/profile/settings_tab.dart:868`, `lib/frontend/screens/profile/settings_tab.dart:877`, `lib/frontend/screens/profile/settings_tab.dart:880`


**Проблема:** `_SpoilerPainter.paint()` has three inline comments ('// Draw the background', '// Draw "noisy" particles', '// Simple noise effect with dots using animation value for movement'). The project convention (AGENTS.md via CLAUDE.md) is 'No comments in code — write self-documenting code instead'. Trivial, but it is an explicit documented rule and this is the sole violation in the audited unit.


**Решение:** Remove the comments and split paint() into small named private methods (e.g. `_paintBackground(canvas, size, paint)`, `_paintNoise(canvas, size)`) so naming documents the intent.

</details>


### Прочее / Uncategorized  (7 — 0 high)

<details>
<summary><b>🟠 MED · КОСТЫЛЬ · [L]</b> — Fragile hand-rolled widget-tree memoization keyed on identityHashCode</summary>


**Где:** `lib/frontend/screens/chats/chat_list_screen.dart:207-231`, `lib/frontend/screens/chats/chat_list_screen.dart:810-841`


**Проблема:** Confirmed. `_getChatsBody()` (210-231) and `_chatsForPageIndex()` (810-841) build manual cache keys via `Object.hashAll`/`Object.hash` over `identityHashCode(_chats)`/`identityHashCode(_folders)` plus hand-picked fields, then reuse a cached `Widget`/`List`. This only stays correct because `_chats`/`_folders` are always replaced wholesale and because every field the cached subtree reads must be manually added to the key. `_enteringChatIds` is read inside the cached subtree (line 2260, `isNew: _enteringChatIds.contains(id)`) but is NOT part of the `_getChatsBody` key (211-225); it only works because it is coincidentally mutated in the same `setState` as `_chats` (696). Any future change that updates a read field without updating the key list silently serves a stale subtree. (Downgraded from high: currently correct, so this is a maintainability hazard, not a live bug.)


**Решение:** Extract the folder header/list into real `StatelessWidget`/`StatefulWidget` classes with typed constructor params (`chats`, `folders`, `selectedFolderId`, `enteringChatIds`, ...) and rely on Flutter's own element diffing plus `const`/`RepaintBoundary` instead of a custom identity-hash cache that must be kept in sync by hand.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — DIALOG peer-id derivation (chatId XOR myId) duplicated instead of using the existing _resolveOtherId helper</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:2158`, `lib/frontend/screens/chats/chat_screen.dart:2170`, `lib/frontend/screens/chats/chat_screen.dart:2180`, `lib/frontend/screens/chats/chat_screen.dart:3065`, `lib/frontend/screens/chats/chat_screen.dart:3119`


**Проблема:** `widget.chatId ^ _myId` — the undocumented assumption that a DIALOG chat id encodes both participant ids via XOR — is re-derived inline in _loadOtherPresence, _onPresenceChanged, _withOnlineDot, _startCall and _seedPresenceFromChat, each with slightly different `<= 0` / `> 0` guards. The screen already has _resolveOtherId() (line 3440) which encapsulates the DIALOG check, the XOR and the positivity guard, but these sites bypass it.


**Решение:** Route all sites through _resolveOtherId(); better, move the encoding into the model/module layer (e.g. CachedChat.otherParticipantId(myId)) so the assumption is documented and owned by one layer instead of copy-pasted through the UI.

</details>

<details>
<summary><b>🟠 MED · ДУБЛЬ · [S]</b> — Folder-page-index resolution from PageController re-implemented three times</summary>


**Где:** `lib/frontend/screens/chats/chat_list_screen.dart:864-873`, `lib/frontend/screens/chats/chat_list_screen.dart:925-936`, `lib/frontend/screens/chats/chat_list_screen.dart:1480-1493`


**Проблема:** Confirmed. `_isChatScrollControllerActive` (864-873), `_activeChatScrollController` (925-936), and the `NotificationListener.onNotification` closure (1480-1493) each independently reimplement 'if `_folderPageController` has no clients fall back to `_selectedFolderIndex`, else read `.page`, round, and clamp'. The three copies already differ slightly in clamp bounds (`_folderPageCount - 1` vs `_folderChatScrollControllers.length - 1`), which is exactly the drift this invites.


**Решение:** Extract one `int _currentFolderPageIndex()` returning the resolved, clamped page index and have all three sites call it instead of re-deriving `p.round().clamp(...)` inline.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [S]</b> — DIALOG 'other participant' lookup duplicated in two places</summary>


**Где:** `lib/frontend/screens/chats/chat_list_screen.dart:774-780`, `lib/frontend/screens/chats/chat_list_screen.dart:1545-1551`


**Проблема:** Confirmed. Both `_prefetchContactsForChats` (774-780) and the item builder (1545-1551) hand-roll the same 'find the participant id that isn't me, break on first match' loop over `chat.participants.entries`. Not verbatim (one accumulates into a set, one picks a single id) but the core participant-resolution logic is duplicated, so any change to participant semantics must be edited in two unrelated sites.


**Решение:** Add a helper on `CachedChat`, e.g. `int otherParticipantId(int myId) => participants.keys.firstWhere((k) => k != myId, orElse: () => myId);`, and use it from both sites.

</details>

<details>
<summary><b>🟡 LOW · ДУБЛЬ · [M]</b> — MessageAttachment.toMap() is unused dead code that has already drifted out of sync with fromMap</summary>


**Где:** `lib/models/attachment.dart:74`, `lib/models/attachment.dart:109-119`, `lib/models/attachment.dart:751-761`, `lib/models/attachment.dart:769-770`


**Проблема:** Verified via grep that `toMap()` has zero call sites outside attachment.dart; the only invocations are three internal nested calls (preview.toMap at 281, image.toMap at 586, button.toMap at 671), whose enclosing toMap() methods are themselves never called externally. So the abstract requirement (74) and all twelve implementations are effectively dead. It also already drifted: ForwardedMessageAttachment.toMap() (751-761) omits originalAttachments and originalContact, so if this were ever wired up for caching/outbox a forwarded message would lose its nested data on the round trip.


**Решение:** If nothing serializes attachments back to a Map (current state), delete the abstract `toMap()` and the twelve implementations to remove the unused, unverified surface. If offline outbox/cache persistence is planned, first fix ForwardedMessageAttachment.toMap() to include originalAttachments/originalContact and add a fromMap(toMap(x)) round-trip test.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [S]</b> — Send/record button uses four-deep nested ValueListenableBuilders</summary>


**Где:** `lib/frontend/screens/chats/chat_screen.dart:5851-5938`


**Проблема:** The send/mic/video button nests four `ValueListenableBuilder`s (`_hasText` -> `_voiceLocked` -> `_isRecordingVoice` -> `_videoNoteMode`) whose final visual/behavior depends on reading all four together. This is primarily a readability/nesting smell rather than a real perf win (a merged listener does not reduce rebuild count meaningfully), but the four-level indentation obscures the button logic.


**Решение:** Collapse into a single `ListenableBuilder(listenable: Listenable.merge([_hasText, _voiceLocked, _isRecordingVoice, _videoNoteMode]))` reading `.value` from each once — matching the merge pattern already used at line 4581.

</details>

<details>
<summary><b>🟡 LOW · СОМНИТ · [L]</b> — KometAppState mixes theming/locale, network-notification listening, and call routing in one root State</summary>


**Где:** `lib/main.dart:285-396`, `lib/main.dart:361-395`


**Проблема:** KometAppState owns theme/locale/font handling plus VPN-bypass and server-error stream subscriptions with their debounce/display logic (361-395) plus incoming-call listening/routing (324-326). Per the project's documented layered architecture (state/ holds ChangeNotifier state consumed by UI; business logic shouldn't live in widgets), the stream-subscription/notification/call-gating logic is UI-layer code doing service work. Factually accurate, but this is a large refactor of a currently-working root widget, so low priority.


**Решение:** Optionally split the unrelated concerns into focused units under state/ or core/: a NotificationRouter service owning the VPN-bypass and server-error subscriptions plus debounce, and an IncomingCallPresenter owning the incoming-call subscription/routing, consumed by KometAppState as listenables so it stays focused on theming/locale/MaterialApp wiring. Weigh against the effort since the current code works.

</details>
