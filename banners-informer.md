# Баннеры (informer) в web-версии MAX

Баннеры вроде «Публичные каналы — для всех» внутри кода называются **informer**.
Они **полностью приходят с сервера** по WebSocket запросом с опкодом `302`.
В JS-бандлах текста баннеров нет — локально хранятся только счётчики показов.

Исходники: `dump/web.max.ru/_app/immutable/chunks/BWjA24QQ.js` (логика),
`_app/immutable/nodes/9.Dqm5zlvE.js` (рендер тайла + аналитика).

---

## Как это работает

1. В общем sync-ответе сессии сервер выставляет бит `1` в bitmask-поле `updates`:
   ```js
   e.updates && new Pu(e.updates).get(1) && await J.banners.resync()
   ```
2. Клиент шлёт запрос с опкодом **302**:
   ```js
   Ah = Y(async ({bannersSync:e}, {send:t}) => await t(302, {bannersSync:e}))
   // resync(): let e = await Ah({bannersSync:0}); await this.upsert(e);
   ```
3. Сервер отвечает `{showTime, updateTime, banners:[…]}`.
4. Какой баннер показать — считается на клиенте (`activeBanner`): фильтр `canShow`,
   затем выбор с максимальным `priority`.
5. Весь механизм гейтится серверным конфигом `informer-enabled`.
6. Состояние показов хранится в `localStorage['__oneme_informer']`:
   ```js
   informerState = { lastShowedBannerId: null, banners: { /* id -> {showCounter, closedTime} */ } }
   ```

---

## Пример ответа сервера

```json
{
  "ver": 10,
  "cmd": 1,
  "seq": 14,
  "opcode": 302,
  "payload": {
    "showTime": 86400000,
    "updateTime": 1784123975588,
    "banners": [
      {
        "id": "public_channels_cid_test",
        "title": "Публичные каналы — для всех",
        "settings": 1,
        "description": "Привлекайте новую аудиторию",
        "priority": 16,
        "repeat": 1,
        "rerun": 5400000000000000,
        "animojiId": 1446,
        "url": "https://max.ru/max_news/AZ9kk1KhJAo",
        "type": 1
      }
    ]
  }
}
```

---

## Конверт (обёртка WS-сообщения)

| Поле | Значение | На что влияет |
|---|---|---|
| `ver` | 10 | Версия протокола WebSocket. |
| `cmd` | 1 | Тип пакета. `1` = ответ на запрос (response), не server-push. |
| `seq` | 14 | Номер запроса. Клиент послал `302 {bannersSync:0}` под этим seq — сервер отвечает тем же seq для матчинга. |
| `opcode` | 302 | Код операции = синхронизация баннеров/informer. |
| `payload` | {…} | Полезная нагрузка, попадает в `banners.upsert(e)`. |

## payload — верхний уровень

**`showTime`: 86400000** (24 ч в мс)
Сколько времени баннер считается «свежим» после первого показа.
```js
isShowTimeOver = ka.now - this.showAt > this.showTime
```
Прошло больше `showTime` с момента первого показа → `canShow` = false, баннер пропадает.

**`updateTime`: 1784123975588** (unix-мс)
Версия набора баннеров. Новые данные применяются только если пришло свежее:
```js
e.banners && e.updateTime > this.informer.updateTime && (…apply…)
```

## Объект баннера

**`id`: `"public_channels_cid_test"`**
Уникальный ключ. По нему хранятся `showCounter` и `closedTime` в `localStorage['__oneme_informer']`
и запоминается `lastShowedBannerId` (чтобы не показать один баннер подряд дважды).
Суффикс `_test` = тестовый баннер.

**`title`: «Публичные каналы — для всех»** — верхняя (цветная) строка тайла.

**`description`: «Привлекайте новую аудиторию»** — вторая строка. Оба текста только с сервера.

**`settings`: 1** — битовая маска флагов отображения (`new Pu(settings)`). Биты:
- `1` = TEXT_ANIMATION — анимация текста
- `2` = HIDE_CLOSE_BUTTON — скрыть крестик
- `4` = HIDE_ON_CLICK — закрывать по клику
- `8` = ICON_THEME_COLOR — красить иконку в цвет темы

Здесь `1` → только анимация текста; крестик «×» есть, клик ведёт по ссылке.

**`priority`: 16**
Приоритет при нескольких баннерах — показывается один с максимальным:
```js
e.reduce((a,b) => b.priority > a.priority ? b : a)
```
При одном баннере роли не играет.

**`repeat`: 1**
Максимум показов:
```js
hasRemainingShows = showCounter===0 ? true : showCounter < repeat
```
`1` → показать ровно один раз.

**`rerun`: 5400000000000000**
Кулдаун (мс) перед повторным показом после закрытия крестиком:
```js
isCloseCooldownOver = closedAt ? (rerun>0 ? Date.now()-closedAt > rerun : false) : true
```
Значение огромное (~171 000 лет) → «закрыл — больше не увидишь».

**`animojiId`: 1446**
ID аниможи-иконки слева в тайле:
```js
J.assets.animojisCache.getLazy(bu.resolveId(this.$.animojiId))
```

**`url`: `https://max.ru/max_news/AZ9kk1KhJAo`**
Куда ведёт клик (вместе с `type:1`).

**`type`: 1** — тип баннера:
- `0` TYPE_TEXT — просто текст
- `1` TYPE_LINK — кликабельный, открывает `url` ← этот случай
- `2` TYPE_UPDATE — баннер обновления приложения

---

## Итог по этому баннеру

Тестовый кликабельный баннер про публичные каналы: показывается один раз (`repeat:1`),
с анимацией текста (`settings:1`), «живёт» сутки после показа (`showTime`), по клику
открывает `max.ru/max_news/...`; если закрыть крестиком — не возвращается практически
никогда (`rerun`). Приоритет 16 нужен только при конкуренции нескольких баннеров.

Убрать/подменить баннер локально можно, перехватив ответ на опкод `302`
либо отключив серверный флаг `informer-enabled`.
