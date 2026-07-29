# Протокол звонков (ru.oneme.app 26.24.0, versionCode 6784)

Источник: реверс APK `ru.oneme.app.apk` (jadx). SDK звонков — `ru.ok.android.externcalls.sdk`
(`calls-sdk`, sdkVersion `0.2.3`), медиаядро — `libjingle_peerconnection_so.so` (WebRTC).

## 0. Два независимых слоя

Звонок живёт в **двух** протоколах, и это ключ ко всему:

| Слой | Транспорт | Формат | За что отвечает |
|------|-----------|--------|-----------------|
| **MAX** | основной сокет приложения | MessagePack + Zstd, опкоды | создать/присоединиться к звонку, ссылки, история, пуш о входящем |
| **Signaling** | отдельный WebSocket на `endpoint` из ответа MAX | **JSON текстом** | всё внутри звонка: медиа, SDP/ICE, админка, участники |

MAX-слой выдаёт `endpoint` + `token`, дальше клиент открывает второй сокет и всё
управление звонком идёт уже там. Админка групповых звонков — целиком второй слой.

---

## 1. MAX-слой: опкоды звонков

Таблица опкодов вытащена из enum `p000/kzb.java` (`new kzb("ИМЯ", ordinal, (short) opcode, parser)`).

| Опкод | Имя | Назначение |
|-------|-----|-----------|
| 76 | `VIDEO_CHAT_START` | старт видеочата (в этой сборке ссылок на отправку нет — легаси) |
| 78 | `VIDEO_CHAT_START_ACTIVE` | **создать / войти в звонок** |
| 79 | `VIDEO_CHAT_HISTORY` | история видеочатов |
| 84 | `VIDEO_CHAT_CREATE_JOIN_LINK` | **создать ссылку-приглашение** |
| 89 | `LINK_INFO` | превью по ссылке (в т.ч. звонковой) |
| 137 | `NOTIF_CALL_START` | пуш «входящий звонок» |
| 163 | `CALL_HISTORY` | история звонков |
| 164 | `CALL_HISTORY_CLEAR` | очистка истории |
| 165 | `NOTIF_CALL_HISTORY` | пуш обновления истории |
| 166 | `VIDEO_CHAT_JOIN` | **вход по ссылке** |
| 195 | `VIDEO_CHAT_MEMBERS` | участники видеочата |

Полный дамп всех 175 опкодов — `calls-opcodes.txt` рядом с этим файлом.

### 1.0 Сверка с нашим `opcode_map.dart`

По звонкам расхождений в номерах нет, только в названиях (`164` мы зовём
`videoChatDeleteHistory`, в APK это `CALL_HISTORY_CLEAR`; `166` — `videoChatJoinByLink`
против `VIDEO_CHAT_JOIN`). Не хватает трёх звонковых опкодов:
`163 CALL_HISTORY`, `165 NOTIF_CALL_HISTORY` (и `103 GET_INBOUND_CALLS` у нас есть).

Вне звонков сверка дала одно расхождение, которое стоит проверить отдельно:
у нас `contactsGet = 8`, в APK опкод `8` — это `LOGIN2`. Остальные отличия — только имена
(`91` GET_COMMENTS_UPDATES / commentsInfo, `202`, `209`, `210`, `293`, `302`).

### 1.1 Создание / вход в звонок — opcode 78 `VIDEO_CHAT_START_ACTIVE`

`p000/vjb.java` → `m30941c()`:

```jsonc
// request payload
{
  "conversationId": "<string>",      // ApiProtocol.PARAM_CONVERSATION_ID
  "calleeIds":      [<long>, ...],   // только если массив непустой (p2p-звонок контактам)
  "chatId":         <long>,          // только если != null (звонок в чате/группе)
  "isVideo":        <bool>,
  "internalParams": "<json-string>"  // см. 1.4
}
```

`conversationId` генерируется клиентом (`one.me.calls.api.conversationid.ConversationIdGenerator`),
а не сервером — это идемпотентный ключ звонка.

### 1.2 Ссылка на групповой звонок — opcode 84 `VIDEO_CHAT_CREATE_JOIN_LINK`

`p000/rg4.java:1664`:

```jsonc
// request
{ "conversationId": "<string>" }
```

Вызывается уже **после** того, как звонок создан (лог `"start creating p2p join link"`,
ошибки `"create p2p join link failed due to conversationId in null or empty"`,
`"join link already exist"`, метрика провала `CREATE_LINK_FAILED`).
То есть ссылка не создаёт звонок — она выдаётся к существующему `conversationId`.

Ответ — объект `VideoConference` (`p000/r6i.java`, msgpack-ключи):

```jsonc
{
  "conferenceId":          "<string>",
  "conversationId":        "<string>",
  "joinLink":              "<string>",
  "chatId":                <long>,
  "callName":              "<string>",
  "participantsCount":     <int>,
  "previewParticipantIds": [<long>, ...],
  "startAt":               <long>,
  "type":                  <int>,
  "owner":                 <...>
}
```

Этот же объект приходит в превью ссылки (`LINK_INFO`, 89).

### 1.3 Вход по ссылке — opcode 166 `VIDEO_CHAT_JOIN`

`p000/vjb.java` → `m30940b()`:

```jsonc
// request
{
  "joinLink":       "<string>",   // ApiProtocol.PARAM_JOIN_LINK
  "isVideo":        <bool>,
  "internalParams": "<json-string>"
}
```

Deep-link/роут разбирается в `p000/wg1.java` по ключам
`call_link`, `is_link_call`, `call_chat_id`, `call_title`, `chat_id`.

### 1.4 `internalParams`

JSON-строка, сериализуется из `InternalParamsDto`
(`ru/ok/android/externcalls/sdk/api/delegate/InternalParamsDto`), собирается в `p000/f98.java`:

```jsonc
{
  "platform":              "ANDROID",   // UploadHelper.SDK_TYPE_STRING
  "sdkVersion":            "0.2.3",
  "clientAppKey":          "<string>",
  "deviceId":              "<string>",
  "protocolVersion":       6,           // 6 если multiple-devices включён, иначе 5
  "domainId":              "<string|null>",
  "onlyAdminCanRecord":    false,
  "isWaitForAdminEnabled": <bool>,
  "hexCapability":         "1877f"      // см. раздел 6
}
```

### 1.5 Ответ: параметры конференции

Разбирается `CallInfoParser` / `ConversationParams` / `CallInfo`, ключи из `ApiProtocol`:

```jsonc
{
  "endpoint":       "<wss url>",   // сюда открываем signaling-сокет
  "wt_endpoint":    "<wss url>",   // watch-together
  "id":             "<string>",
  "token":          "<string>",
  "join_link":      "<string>",
  "client_type":    "<string>",
  "device_idx":     <int>,
  "is_concurrent":  <bool>,
  "p2p_forbidden":  <bool>,
  "upload_url":     "<string>",
  "stun_server":    { "urls": [ ... ] },
  "turn_server":    { "urls": [ ... ], "username": "...", "credential": "..." }
}
```

Плюс `wsIps` / `wtIps` — списки IP для обхода DNS.

---

## 2. Signaling: конверт сообщений

WebSocket на `endpoint`, полезная нагрузка — **JSON строкой** (не msgpack).

**Клиент → сервер** (`p000/r7l.java:m26483a`, `p000/tkf.java:117`):

```jsonc
{ "command": "<имя>", ...поля..., "sequence": <long> }
```

**Сервер → клиент**, три вида (`p000/tkf.java:m29114f`, `p000/r51.java:100`):

```jsonc
{ "type": "response", "sequence": <long>, "response": "<имя команды>", ... }
{ "type": "error",    "sequence": <long>, "error": "<код>", "errorCode": <int>, "recoverable": <bool> }
{ "notification": "<имя>", ... }            // + "stamp": <long> для порядка
```

Коды ошибок, которые встречаются: `service-unavailable`, `participants-limit-reached` (+`limit`),
`conversation-ended`, `conversation-not-found`, `conversation-recording`, `closed-conversation`,
`illegal-conversation-state`, `illegal-participant-state`, `invalid-request`, `invalid-token`,
`no-call`, `call-unfeasible`, `command-not-delivered`, `command-discarded`,
`command-can-not-be-postponed`, `movie-not-found`, `movie-limit-exceeded`.

### 2.1 Идентификатор участника

`participantId` в разных местах в двух формах:

- разложенный: `{"participantId": <long>, "participantType": "GROUP"|"USER", "deviceIdx": <int>}`
- строкой (`mq1.m20652b()`): `u<id>` для юзера, `g<id>` для группы, с суффиксом устройства

Идентификаторы медиа-треков (`p000/r7l.java:m26478K`):

```
<participantId>:sCAMERA        // камера
<participantId>:sSCREEN        // ДЕМОНСТРАЦИЯ ЭКРАНА
<participantId>:sMOVIE:m<id>   // расшаренное видео
<participantId>:sSTREAM
<participantId>:sANIMOJI
audio-<participantId>          // аудио-трек
video-<participantId>          // видео-трек
```

---

## 3. Медиа: камера / микрофон / экран

### 3.1 Своё состояние — `change-media-settings`

`p000/zkf.java` + `p000/r7l.java:m26497o`. Шлётся **целиком, не дельтой**, при любом переключении:

```jsonc
{
  "command": "change-media-settings",
  "mediaSettings": {
    "isVideoEnabled":            <bool>,   // камера
    "isAudioEnabled":            <bool>,   // микрофон
    "isScreenSharingEnabled":    <bool>,   // ДЕМОНСТРАЦИЯ ЭКРАНА
    "isAnimojiEnabled":          <bool>,
    "isFastScreenSharingEnabled": <bool>,  // только если включён fastScreenShare
    "isAudioSharingEnabled":     <bool>    // только если включён audioShare
  },
  "sequence": <long>
}
```

Последние два поля **условные** — добавляются только когда соответствующая фича согласована
при подключении. Если слать их всегда — есть риск, что старый сервер отвергнет команду.

### 3.2 Чужое состояние — нотификации

```jsonc
{ "notification": "media-settings-changed",
  "participantId": <long>, "participantType": "...", "deviceIdx": <int>,
  "mediaSettings": { "isAudioEnabled": ..., "isVideoEnabled": ...,
                     "isScreenSharingEnabled": ..., "isAnimojiEnabled": ... } }
```

```jsonc
// админ принудительно выключил медиа — клиент ОБЯЗАН применить и погасить у себя
{ "notification": "force-media-settings-change", "mediaSettings": { ... } }
```

```jsonc
{ "notification": "audio-activity", "activeParticipants": ["u123", ...] }
{ "notification": "speaker-changed", "speaker": "u123" }
```

### 3.3 Демонстрация экрана — детали

Что нужно, чтобы экран реально поехал (`ScreenCaptureManagerImpl.setScreenCaptureEnabled`):

1. **Capability `SCREEN_TRACK_PRODUCER` (бит 0)** должен быть в маске (см. 6).
   Без него сервер не примет screen-трек. `SCREEN_TRACK_CONSUMER` (бит 4) — чтобы видеть чужой.
2. Проверяется медиа-опция `screenshareState`: если админ поставил `MUTE_PERMANENT`
   на `SCREEN_SHARING` — включение молча игнорируется.
3. `change-media-settings` с `isScreenSharingEnabled: true`.
4. В PeerConnection добавляется **отдельный видео-трек** с id `<pid>:sSCREEN`
   (unified plan, вторая m-line) — камера при этом остаётся своим треком `<pid>:sCAMERA`.
   Это самое частое место поломки: если слать экран в тот же трек, что и камеру,
   удалённая сторона увидит либо камеру, либо ничего.
5. Foreground-сервис `CallScreenShareService` с типом `mediaProjection` — андроид-специфика,
   но без него система убивает захват.

**Про 1:1 (topology `DIRECT`).** Топология бывает `DIRECT` (p2p) и `SERVER` (`p000/f9h.java`).
Само видео экрана в `DIRECT` работает, а вот **звук демонстрации** (`setAudioCaptureEnabled`,
`n61.m21001I`) жёстко требует `SERVER`:

```java
if (m21020p() && this.f46846n0.m24163I(f9h.f22608c)) { // f22608c == SERVER
```

Апгрейд топологии клиент запрашивает сам:

```jsonc
{ "command": "switch-topology", "topology": "SERVER", "force": false }
```

В стоковом клиенте это шлётся при развале p2p ICE (`onTopologyUpgradeProposed`), но команда
доступна в любой момент. Сервер отвечает нотификацией:

```jsonc
{ "notification": "topology-changed", "topology": "SERVER" | "DIRECT" }
```

Практический вывод для нашего клиента: если экран в 1:1 не едет — проверять в порядке
(1) бит capability, (2) отдельный `sSCREEN`-трек, (3) при необходимости `switch-topology → SERVER`.

### 3.4 Согласование фич при подключении

`p000/r7l.java:m26485c` — объект, который клиент отдаёт при инициализации сессии.
Именно он включает `fastScreenShare` и остальное:

```jsonc
{
  "maxH264Decoders":                     <int>,
  "estimatedPerformanceIndex":           <int>,          // опционально
  "producerNotificationDataChannelVersion": 7,
  "producerCommandDataChannelVersion":   <int>,
  "audioMix":                            true,
  "consumerUpdate":                      <bool>,
  "onDemandTracks":                      <bool>,
  "singleSession":                       true,
  "unifiedPlan":                         true,
  "fastScreenShare":                     true,
  "producerScreenDataChannelVersion":    1,              // условно
  "consumerScreenDataChannelVersion":    1,              // условно
  "animojiDataChannelVersion":           2,              // условно
  "animojiBackendRender":                true,           // условно
  "asrDataChannelVersion":               1,              // условно
  "consumerFastScreenShare":             true,           // условно
  "consumerFastScreenShareQualityOnDemand": true,
  "audioShare":                          true,           // условно
  "simulcast":                           true,           // условно
  "simulcastNativeOrder":                true,           // условно
  "red":                                 true,
  "videoTracksCount":                    <int>,          // если > 0
  "csrcAccessible":                      true            // если videoTracksCount > 0
}
```

---

## 4. SDP / ICE

Всё заворачивается в `transmit-data` (`p000/r7l.java:m26493k`, `m26502t`, `m26503u`):

```jsonc
// offer / answer
{ "command": "transmit-data",
  "participantId": <long>, "participantType": "...", "deviceIdx": <int>,
  "data": {
    "sdp":          { "type": "offer"|"answer", "sdp": "<sdp>", "p2pRelay": "true" },
    "capabilities": "1877f",     // hex, если != 0
    "label":        "<string>"   // опционально
  },
  "sequence": <long> }

// одиночный кандидат
{ "command": "transmit-data", ..., "data": { "candidate": { "candidate": "...", "sdpMid": "...", "sdpMLineIndex": <int> } } }

// удалённые кандидаты
{ "command": "transmit-data", ..., "data": { "candidates-removed": [ {...}, ... ] } }
```

`p2pRelay: "true"` (строкой!) добавляется только в offer при включённом P2P-relay.

Топология SERVER добавляет отдельный набор команд (`p000/ooh.java`):
`allocate-consumer`, `accept-producer`, `request-realloc` — аллокация консьюмеров/продюсеров
на медиасервере. Плюс `change-simulcast`, `update-display-layout`, `report-network-stat`,
`report-perf-stat` (`p000/ug8.java`).

---

## 5. Групповые звонки: администрирование

Роли (`p000/pq1.java`): **`CREATOR`**, **`ADMIN`**, **`SPEAKER`**.

### 5.1 Мьют участников

```jsonc
// запросить включение медиа у участника (или у всех, если participantId=null)
{ "command": "mute-participant",
  "participantId": "u123" | null,
  "requestedMedia": ["AUDIO"|"VIDEO"|"SCREEN_SHARING"|"MOVIE_SHARING", ...],
  "roomId": "<id>"                     // опционально, для session room
}
```

```jsonc
// жёстко выставить состояния мьюта
{ "command": "mute-participant",
  "participantId": "u123" | null,
  "muteStates": {
    "AUDIO":          "UNMUTE"|"MUTE"|"MUTE_PERMANENT"|null,
    "VIDEO":          ...,
    "SCREEN_SHARING": ...,
    "MOVIE_SHARING":  ...
  },
  "roomId": "<id>"                     // опционально
}
```

`MUTE` — выключить сейчас (можно включить обратно), `MUTE_PERMANENT` — запретить.
Внутренние состояния клиента: `UNMUTED`, `UNMUTED_BUT_MUTED_ONCE`, `MUTED_PERMANENT`,
`MUTED_PERMANENT_BUT_UNMUTED_ONCE`.

Быстрый мьют микрофона (`ConversationImpl:2331`, `:3446`):

```jsonc
{ "command": "switch-micro", "eId": "u123", "muteTarget": <bool> }
{ "command": "switch-micro", "all": true,   "muteTarget": true }
```

Обратная нотификация: `{ "notification": "switch-micro", "mute": <bool> }`
(если поля `mute` нет — клиент логирует `switch-micro without 'mute'` и игнорирует).

### 5.2 Роли и промоушен

```jsonc
{ "command": "promote-participant", "participantId": "u123", "demote": <bool> }

{ "command": "grant-roles", "participantId": "u123",
  "roles": ["ADMIN", "SPEAKER", ...], "revoke": <bool> }

// стерео-режим / запрос слова
{ "command": "request-promotion", ... }     // + reject / unrequest
{ "command": "accept-promotion", ... }
{ "command": "get-hand-queue" }
```

### 5.3 Участники

```jsonc
// по внешним id
{ "command": "add-participant",
  "externalIds": [ ... ],
  "unban": true,                              // опционально
  "payload": "{\"show_chat_history\":true}" } // опционально, СТРОКОЙ

// по ссылке/QR
{ "command": "add-participant", "participantIdAsQRCodeLink": "<link>" }

{ "command": "remove-participant", "participantId": "u123" }

{ "command": "pin-participant", "participantId": "u123",
  "unpin": <bool>, "roomId": "<id>" }

{ "command": "get-participant-list-chunk",
  "count": <int>, "listType": "GRID"|"SIDE", "roomId": "<id>" }

{ "command": "get-waiting-hall", "count": <int>, "fromId": "...", "backward": <bool> }
```

### 5.4 Состояния участника (рука, помощь)

```jsonc
{ "command": "change-participant-state",
  "participantId": "u123",           // отсутствует → своё состояние
  "participantState": { "state": { "hand": "1"|"0", "drat": "1"|"0" } } }

{ "command": "put-hands-down" }      // опустить руки всем
```

`hand` — поднятая рука, `drat` — запрошена помощь (`ASSISTANCE_REQUESTED`).
Значения строковые `"1"` / `"0"`.

### 5.5 Опции конференции

```jsonc
{ "command": "change-options",
  "options": { "WAITING_HALL": true, "AUDIENCE_MODE": false, ... } }
```

Доступные опции (`p000/l61.java`): `REQUIRE_AUTH_TO_JOIN`, `WAITING_HALL`, `RECURRING`,
`FEEDBACK`, `AUDIENCE_MODE`, `ASR`, `WAIT_FOR_ADMIN`, `ADMIN_IS_HERE`.

```jsonc
{ "command": "enable-feature-for-roles",
  "feature": "ADD_PARTICIPANT"|"ADMIN"|"ASR"|"MOVIE_SHARE"|"RECORD"|"SPEAKER",
  "roles": ["ADMIN", "SPEAKER", ...] }
```

### 5.6 Запись

```jsonc
{ "command": "record-start",
  "movieId": <long>, "name": "...", "description": "...",
  "privacy": "...", "groupId": <long>, "albumId": "...",
  "streamMovie": <bool>, "roomId": "<id>" }

{ "command": "record-stop", "roomId": "<id>", "remove": <bool> }
```

Ответ на `record-start`: `{"type":"response","sequence":N,"response":"record-start","recordMovieId":<id>}`.

### 5.7 Комнаты (session rooms)

```jsonc
{ "command": "switch-room", "participantId": "u123", "toRoomId": "<id>" }
{ "command": "update-rooms", "rooms": [ { "id": "...",
      "addParticipantIds": [...], "removeParticipantIds": [...] } ] }
{ "command": "get-rooms" }
{ "command": "room-query", ... }
{ "command": "room-tx", ... }
```

### 5.8 Совместный просмотр / шаринг ссылки

```jsonc
{ "command": "add-movie",    "movieId": <long>, ... }
{ "command": "update-movie", "movieId": <long>, "pause": <bool> }
{ "command": "remove-movie", "movieId": <long> }

{ "command": "start-url-sharing", "sharedUrl": "<url>" }
{ "command": "stop-url-sharing" }
```

### 5.9 Прочее

```jsonc
{ "command": "hangup", "reason": "..." }
{ "command": "accept-call", ... }
{ "command": "custom-data", "participantId": <long>, "participantType": "...",
  "deviceIdx": <int>, "data": { ...произвольный JSON... } }
{ "command": "request-asr", ... }
```

---

## 6. Capabilities

`ClientCapabilities` — битовая маска, передаётся **hex-строкой** (в `capabilities` внутри
`transmit-data.data` и в `hexCapability` внутри `internalParams`).

| Бит | Имя | Что даёт |
|-----|-----|----------|
| 0 | `SCREEN_TRACK_PRODUCER` | **отдавать демонстрацию экрана** |
| 1 | `VIDEO_TRACKS` | видео-треки |
| 2 | `WAITING_HALL` | зал ожидания |
| 3 | `FILTER_DEFAULTS` | |
| 4 | `SCREEN_TRACK_CONSUMER` | **принимать чужую демонстрацию** |
| 5 | `ADMIN_MUTE_NOTIFY` | нотификации админского мьюта |
| 6 | `WATCH_MOVIE` | совместный просмотр |
| 8 | `SESSION_ROOMS` | комнаты |
| 9 | `VMOJI` | анимоджи |
| 10 | `CALL_TO_CONTACTS` | |
| 11 | `AUDIENCE_MODE` | режим зрителей |
| 14 | `SESSION_STATE_UPDATES` | |
| 15 | `ADD_PARTICIPANT` | добавление участников |
| 16 | `USE_P2P_RELAY` | p2p-relay |
| 17 | `WAIT_FOR_ADMIN` | ждать админа |
| 18 | `HOLD` | удержание |

Дефолт стокового клиента — биты `0,1,2,3,4,5,6,8,9,10,15,16` = **`0x1877f`**.
Обрати внимание: `AUDIENCE_MODE`(11), `SESSION_STATE_UPDATES`(14), `WAIT_FOR_ADMIN`(17),
`HOLD`(18) в дефолт **не входят** и включаются по конфигу.

---

## 7. Нотификации сервер → клиент (полный список)

Из switch в `p000/r51.java` (ключ `"notification"`):

**Сессия и участники**
`connection`, `registered-peer`, `participant-added`, `participant-joined`, `accepted-call`,
`participants-state-changed`, `participant-state-changed`, `participant-animoji-changed`,
`decorative-participant-id-changed`, `session-state`, `stalled-activity`, `hold`, `hungup`,
`closed-conversation`, `multiparty-chat-created`

**Медиа**
`media-settings-changed`, `force-media-settings-change`, `audio-activity`, `speaker-changed`,
`switch-micro`, `mute-participant`, `topology-changed`, `realloc-con`, `transmitted-data`

**Админка**
`roles-changed`, `promote-participant`, `promotion-approved`, `options-changed`,
`feature-set-changed`, `features-per-role-changed`, `pin-participant`, `settings-update`

**Комнаты**
`room-updated`, `rooms-updated`, `room-participants-updated`, `chat-room-updated`

**Контент**
`record-started`, `record-stopped`, `movie-share-started`, `movie-share-stopped`,
`url-sharing-info-updated`, `asr-started`, `asr-stopped`, `chat-message`, `custom-data`,
`join-link-changed`, `feedback`, `rate-call-data`

---

## 8. Что из этого чинит наши баги

**Демонстрация экрана в 1:1** — раздел 3.3. Порядок проверки: бит 0 в capabilities →
отдельный трек `<pid>:sSCREEN` → `change-media-settings` с полным объектом →
при необходимости `switch-topology → SERVER` (обязательно, если нужен звук демонстрации).

**Групповые звонки** — скорее всего не хватает серверной топологии целиком:
`allocate-consumer` / `accept-producer` / `request-realloc` (`p000/ooh.java`),
плюс `get-participant-list-chunk` для подгрузки участников пачками и
`update-display-layout` для раскладки. В `DIRECT` группа не работает by design.

**Условные поля.** `isFastScreenSharingEnabled` / `isAudioSharingEnabled` в `mediaSettings`
и половина полей в объекте согласования фич добавляются **только** при включённой фиче.
Слать их безусловно — рискованно.
