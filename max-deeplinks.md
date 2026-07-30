# Диплинки MAX

Разобрано из `ru.oneme.app.apk` — MAX 26.24.0 (versionCode 6784, minSdk 26).
Точки входа: `AndroidManifest.xml` → `one.me.android.deeplink.LinkInterceptorActivity`,
парсер `one.me.link.interceptor.b0.a()`, хелпер `ru.ok.messages.utils.a`,
реестр внутренних маршрутов `iz4` / `nz4` (`DeepLinkRoute`), навигатор `pz4`.

## Что вообще перехватывается

Один активити (`LinkInterceptorActivity`) с двумя intent-filter, `android:autoVerify="true"`:

| Схема | Хост | Путь |
|---|---|---|
| `https` | `max.ru` | `/..*` (минимум один символ после `/`) |
| `http` | `max.ru` | `/..*` |
| `max` | `max.ru` | любой |

`max://…` внутри сразу переписывается в `https://…` (`b0.k()`), так что дальше всё едино.
Важная деталь: `/..*` требует непустой путь, поэтому ссылки вида `https://max.ru/?uid=123`
из браузера в приложение не попадают — только через схему `max://`, где путь не ограничен.

Нормализация ссылки перед разбором (`ru.ok.messages.utils.a.e()`):

- завершающий `/` отбрасывается;
- строка без схемы → дописывается `https://` (**то есть `max.ru/xxx` — валидный диплинк**);
- начинается с `:` или `max://:` → внутренний маршрут (см. ниже);
- начинается с `@` → ник, ссылка не переписывается.

Общий порядок разбора в `b0.a()`: `:auth` → (не готов к работе → `OpenApp` с отложенной ссылкой)
→ `:current` → внутренний маршрут → корневая ссылка → `:share-self-out` → чужой хост → контентные ссылки.

## Контентные ссылки max.ru

| Ссылка | Что открывает | Результат в коде |
|---|---|---|
| `max.ru` (и `http://max.ru`, `https://max.ru`, `max://max.ru`, `max://max.ru/`) | просто открывает приложение | `DeepLinkData$OpenApp` → `OpenApp` |
| `max.ru/<username>` | чат/канал/бота по публичной ссылке; если такой чат уже локально есть — открывает его напрямую, иначе резолвит на сервере | `JoinLink` → `ShowChat` / `ShowContact` / `ConfirmJoin` |
| `max.ru/@<nickname>` | то же, ник ищется среди ссылок известных чатов | → чат либо `UnknownContact` |
| `max.ru/<username>?start=<payload>` | диалог с ботом + автозапуск: отправляется `botStarted` со `startPayload` | `ShowContactDialog(chatId, startPayload, externalCallback)` |
| `max.ru/<username>?startapp=<payload>` | мини-приложение бота (payload обрезается по первому `&`, query из ссылки вычищается) | `StartWebAppLink` → `OpenWebApp(botId, startParam)` / `ErrorWebAppNotExist` |
| `max.ru/join/<code>` | вступление по приватной инвайт-ссылке | `JoinLink` → `ConfirmJoin` / `ShowChat` |
| `max.ru/joincall/<code>` | экран входа в звонок по ссылке | `CallJoinLink` → `ShowJoinCall` |
| `max.ru/stickerset/<id>` | стикерпак; `id` берётся до первого `-` | `StickerSet` → `ShowStickerSet` |
| `max.ru/<username>/<messageId>` | чат на конкретном сообщении (второй сегмент должен быть числом) | `MessagestLink` → `ShowChat(chatId, messageId)` |
| `max.ru/c/<chatId>/<messageId>` | сообщение/пост в чате по числовым id | `MessagestLink` → `ShowChat` |
| `max.ru/:folder?id=<folderId>` | список чатов в папке | `FolderChatList` → `OpenChatListInFolder`, иначе `UnknownFolderError` |
| `max.ru/?uid=<userId>` | контакт/диалог по id пользователя (ищется локально) | `DeepLinkData(contactId)` |
| `max.ru/?cid=<chatId>` | чат по серверному id (ищется локально) | `DeepLinkData(chatId)` |
| `max.ru/:auth/<...>` | подтверждение веб-логина по QR; путь принудительно урезается до `https://max.ru/:auth` | маршрут `:auth` |
| `max.ru/:current` | остаётся на текущем экране (для внешних колбэков) | `OpenCurrent` |
| `https://max.ru/:share-self-out` | системный шэринг своей инвайт-ссылки | `OpenExternalSharingToInvite` |
| `max.ru/:share?text=<text>` | шэринг текста внутрь приложения (выбор чата) | маршрут `:share` |
| любой другой хост | открывается во внешнем браузере | `OpenBrowser` |

Ошибочные ветки: `ErrorBrokenLink`, `ErrorPrivateChat`, `ErrorPrivateChannel`,
`ErrorMessageNotFounded`, `ErrorPostNotFounded`, `ErrorWebAppNotExist`,
`ContentLevelError`, `ItsYou` (ссылка на себя), `ShowContactRemoved`.

Отдельный флаг: `?externalCallback=1` в любой ссылке — результат прокидывается обратно
как внешний колбэк (`b0.d()`), плюс есть маршрут `:external_callback`.
Параметры `mt_*` (myTracker) вычищаются из ссылки до разбора.

## Внутренние маршруты (`:route`)

Полноценная часть диплинк-системы: 137 маршрутов, объявленных как
`DeepLinkRoute(uri, constraints, requiredParams, supportRoot)`. Матчинг — по пути без
ведущего `/`, регистронезависимо. Обязательные параметры передаются как query:
`max.ru/:profile?id=123&type=CHAT`. Если хотя бы одного обязательного параметра нет —
`Error`, экран не откроется.

Помимо http(s)/`max://` эти же маршруты дергаются изнутри приложения (`pz4.b/d`) и из пушей.

Пометки в таблице:
- **только внутри приложения** — маршрут исключён из обработки внешних ссылок (`constraints` содержит `k2b.g`);
- **без авторизации** — доступен без активной сессии, иначе редирект на `:login`;
- **не может быть корневым экраном** — `supportRoot = false`.

| Маршрут | Обязательные параметры | Примечания |
|---|---|---|
| `:app-update/force` | — | без авторизации |
| `:attach/viewer` | `chat_id`, `attach_id`, `msg_id` |  |
| `:auth` | — |  |
| `:call-active` | — |  |
| `:call-admin-settings` | — |  |
| `:call-admin-waiting-room` | — |  |
| `:call-chat` | `chat_id` | только внутри приложения |
| `:call-contact` | — |  |
| `:call-debug-menu` | — |  |
| `:call-history-info` | — |  |
| `:call-incoming` | `chat_id`, `call_name` |  |
| `:call-join-link` | `link` | только внутри приложения |
| `:call-join-preview` | `link` |  |
| `:call-list` | — |  |
| `:call-opponents-list` | — |  |
| `:call-pip` | — |  |
| `:call-presettings` | `chat_id` |  |
| `:call-rate` | `call_id`, `is_group`, `is_video` |  |
| `:call-user` | `opponent_id` | только внутри приложения |
| `:calls-history` | — |  |
| `:chat-list` | — |  |
| `:chat/add-icon` | — |  |
| `:chats` | `id`, `type` |  |
| `:chats-search` | — |  |
| `:chats/callshare` | — |  |
| `:chats/forward` | `messages_ids` |  |
| `:chats/share` | — |  |
| `:comments` | `parent_chat_server_id`, `parent_message_server_id` |  |
| `:complaint` | — |  |
| `:contact-list` | — |  |
| `:contact-list/create-contact` | — |  |
| `:contact-list/share-invite` | — |  |
| `:contact/add/dialog` | `contact_id` |  |
| `:contacts-picker` | `request_code` |  |
| `:dialogs/file-download-warning` | `chat_id`, `message_id`, `file_id`, `file_name`, `file_size` |  |
| `:dialogs/share-media` | `msg_id`, `attach_id`, `local_attach_id`, `cause_ordinal` |  |
| `:external_callback` | — |  |
| `:inAppReview/fake` | — |  |
| `:invite/friends_to_max_bottom_sheet` | — |  |
| `:invite/phone` | — |  |
| `:invite/qr` | — |  |
| `:join` | `id`, `link` |  |
| `:link-intercept` | — |  |
| `:location/pick` | `chat_id`, `request_code` |  |
| `:location/show` | `chat_id`, `lat`, `lon`, `z` |  |
| `:login` | — | без авторизации |
| `:logout` | — | без авторизации |
| `:media-editor` | — |  |
| `:media-editor/crop` | `image_uri`, `file_path`, `mode` |  |
| `:media-picker/select/photo` | — | без авторизации, не корневой экран |
| `:neuro-avatars` | `id` |  |
| `:photo-editor` | — |  |
| `:polls/create` | `chat_id`, `request_code` |  |
| `:polls/result` | `chat_id`, `message_id`, `poll_id` |  |
| `:polls/result/voters` | `chat_id`, `message_id`, `poll_id`, `answer_id` |  |
| `:profile` | `id`, `type` |  |
| `:profile/add-admins` | `chat_id` |  |
| `:profile/add-members` | `chat_id`, `is_chat` |  |
| `:profile/attaches` | `id` |  |
| `:profile/avatars` | `id`, `type` |  |
| `:profile/change-owner` | `chat_id` |  |
| `:profile/comments-black-list` | `id` |  |
| `:profile/edit` | `id`, `type` |  |
| `:profile/edit/admin_permission` | `chat_id`, `contact_id`, `permissions_type` |  |
| `:profile/edit/link` | `id`, `type`, `flow` |  |
| `:profile/edit/reactions` | `id` |  |
| `:profile/invite` | `id` |  |
| `:profile/join-requests` | `id` |  |
| `:profile/member_permissions` | `id` |  |
| `:profile/members` | `id`, `type` |  |
| `:qr-scanner` | — |  |
| `:saved-messages` | — |  |
| `:scheduled-messages` | `id` |  |
| `:settings` | — |  |
| `:settings/aboutapp` | — |  |
| `:settings/appearance` | — |  |
| `:settings/battery` | — |  |
| `:settings/blacklist` | — |  |
| `:settings/caching` | — |  |
| `:settings/dev` | — | без авторизации, не корневой экран |
| `:settings/dev/integritylogsviewer` | — | без авторизации, не корневой экран |
| `:settings/dev/logsviewer` | — | без авторизации, не корневой экран |
| `:settings/dev/memorydebugger` | — | без авторизации |
| `:settings/dev/showroom` | — | без авторизации |
| `:settings/dev/threadsviewer` | — | без авторизации |
| `:settings/devices` | — |  |
| `:settings/folder` | `id` |  |
| `:settings/folder-list` | — |  |
| `:settings/folder/by-chat` | `ids` |  |
| `:settings/folder/create` | — |  |
| `:settings/folder/edit` | — |  |
| `:settings/folder/members-picker` | — |  |
| `:settings/folder/settings` | — |  |
| `:settings/locale` | — |  |
| `:settings/magic-room` | — | без авторизации |
| `:settings/media` | — |  |
| `:settings/media/autoload/video` | — |  |
| `:settings/media/autosave` | `type` |  |
| `:settings/messages` | — |  |
| `:settings/notifications` | — |  |
| `:settings/notifications/chat` | — |  |
| `:settings/notifications/dialog` | — |  |
| `:settings/notifications/other` | — |  |
| `:settings/privacy` | — |  |
| `:settings/privacy/creation-twofa` | `track_id`, `src` |  |
| `:settings/privacy/onboarding` | — |  |
| `:settings/privacy/onboarding-twofa` | `state` |  |
| `:settings/privacy/pincode` | `mode` |  |
| `:settings/privacy/profile-deletion` | — |  |
| `:settings/ringtone` | — |  |
| `:settings/server-host` | — | без авторизации |
| `:settings/server-port` | — | без авторизации |
| `:settings/webapp` | `bot_id` |  |
| `:settings/webapps` | — |  |
| `:share` | `text` |  |
| `:start-conversation` | — |  |
| `:start-conversation/add-subscribers` | `id` |  |
| `:start-conversation/channel` | — |  |
| `:start-conversation/chat` | — |  |
| `:stickers/favorite` | — |  |
| `:stickers/preview` | `sticker_id` |  |
| `:stickers/recent` | — |  |
| `:stickers/search` | — |  |
| `:stickers/set` | `set_id` |  |
| `:stickers/settings` | — |  |
| `:stickers/showcase` | — |  |
| `:stories/edit-privacy` | `story_id`, `settings` |  |
| `:stories/publish` | `path` |  |
| `:stories/publish/picker` | `title` |  |
| `:stories/viewer` | `owner_id`, `owner_type`, `type` |  |
| `:story/editor` | — |  |
| `:twofa/auth/password/check` | `track_id`, `phone` | без авторизации, не корневой экран |
| `:twofa/password/check` | — |  |
| `:unknown-call` | `call_id`, `caller_id` |  |
| `:videoweb/full` | `chat_id`, `msg_id` |  |
| `:webapp:root` | `bot_id`, `entry_point` |  |
| `:webview/faq` | — | без авторизации, не корневой экран |

## Как это работает в Komet

Точка входа одна для всех случаев: `MaxLink.parse()` в `lib/core/links/max_link.dart`
разбирает ссылку в sealed-тип, `tryHandleMaxLink()` в
`lib/frontend/widgets/max_link_handler.dart` его исполняет. Через неё идут и внешние
диплинки (`DeepLinkService` → `app_links`), и тапы внутри приложения
(`openExternalUrl` → текст сообщений, био, описания каналов, inline-кнопки, упоминания).
Ссылки без схемы (`max.ru/…`) распознаются и парсером, и автолинковкой в тексте.
Ссылки, которым не нужен сервер (маршруты, `:share`, папки, вкладки), больше не ждут
подключения — `DeepLinkService` проверяет `MaxLink.needsConnection`.

Манифест Komet уже ловит `https/http max.ru` (+ `www.`) и схемы `komet://`, `max://`.

### Контентные ссылки

| Ссылка | Поведение в Komet |
|---|---|
| `max.ru` | возврат на корневой экран |
| `max.ru/<username>`, `@<nickname>`, `u/<id>` | резолв через `LINK_INFO` → чат, канал или профиль |
| `?start=<payload>` | диалог с ботом + автоотправка `botStarted` |
| `?startapp=<payload>` | мини-приложение бота (`WebAppScreen`), botId берётся из резолва ссылки |
| `join/<code>` | подтверждение вступления и переход в чат |
| `joincall/<code>` | экран входа в звонок |
| `stickerset/<id>` | шит стикерпака |
| `<username>/<messageId>`, `c/<chatId>/<messageId>` | чат с переходом к сообщению (время берётся из `LINK_INFO`, иначе догружаем историю назад) |
| `?uid=<userId>` | профиль контакта |
| `?cid=<chatId>` | чат по серверному id |
| `:folder?id=` | корневой список с выбранной папкой |
| `:auth/<token>` | подтверждение веб-логина (в отличие от MAX токен не отбрасывается — он нужен нашему флоу) |
| `:current` | ничего не делает, как в MAX |
| `:share?text=` | панель пересылки → выбранный чат с текстом в поле ввода |
| `:share-self-out` | системный шэринг своей публичной ссылки |
| чужой хост | внешний браузер |

### Внутренние маршруты

Реализованы в `lib/frontend/widgets/max_route_handler.dart`:

| Маршрут | Экран Komet |
|---|---|
| `:chat-list`, `:settings/folder-list` | список чатов |
| `:calls-history`, `:call-list` | вкладка звонков |
| `:contact-list` | вкладка контактов |
| `:settings` | вкладка настроек |
| `:chats-search` | поиск |
| `:saved-messages` | Избранное |
| `:chats?id=` | чат |
| `:profile?id=&type=` | профиль контакта или чата (по `type`) |
| `:profile/members`, `:profile/avatars` | тот же профиль |
| `:profile/attaches?id=` | профиль на вкладке медиа |
| `:profile/edit` | редактирование своего профиля |
| `:scheduled-messages?id=` | отложенные сообщения чата |
| `:stickers/set?set_id=` | шит стикерпака |
| `:webapp:root?bot_id=&entry_point=`, `:settings/webapp?bot_id=` | мини-приложение |
| `:location/show?lat=&lon=&z=` | карта |
| `:qr-scanner` | сканер QR |
| `:settings/appearance` | внешний вид |
| `:settings/notifications` (+ `/chat`, `/dialog`, `/other`) | уведомления |
| `:settings/devices` | устройства |
| `:settings/aboutapp` | о приложении |
| `:settings/privacy`, `:settings/privacy/pincode`, `:settings/blacklist` | безопасность |
| `:settings/messages` | действия с сообщениями |
| `:settings/dev` (+ подэкраны) | отладочное меню |
| `:link-intercept`, `:external_callback` | no-op |

Остальные маршруты из таблицы выше показывают уведомление
«Ссылка не поддерживается: `<маршрут>`» — в Komet для них нет экрана. Сознательно не
подключены: `:login`/`:logout` (деструктивно), `:polls/*`, `:comments`, `:chats/forward`,
`:stories/*`, `:call-*` (кроме списка), `:twofa/*`, `:complaint`, `:media-*`,
`:attach/viewer`, `:videoweb/full`, `:invite/*` — им нужны либо чужие экраны, либо
контекст, которого в ссылке нет. Флаг `?externalCallback=1` не обрабатывается.
