# Исправления по 16 пунктам аудита Komet dev.22

Подготовленная ветка: [fix/dev22-audit-2026-10-11](https://github.com/alcovaibe/Komet/tree/fix/dev22-audit-2026-10-11). PR не создан и без отдельного разрешения не отправляется.

База: `feature/FullStack`, `0.5.22+22`, commit `41def0a3e7ee987c58ad665bb115c22297e60ff0`. Сопоставлена с `dev/0.5.0`, `0.5.22+22`, commit `1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e`; актуальные SHA перепроверены 10.10.2026 UTC. Подготовлены изменения по 15 пунктам; пункт 11 уже исправлен в выбранной базе. Это 16 пунктов отчёта, не классификация «16 критических уязвимостей».

## 1. Отправка открытого содержимого в зашифрованный чат

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [ShareSender.send/_sendText](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/backend/modules/share_sender.dart#L160-L275); [sendVoice/sendVideoNote](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/frontend/screens/chats/chat/chat_media_send_controller.dart#L301-L351); [sendScheduledPhotos](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/frontend/screens/chats/chat/chat_media_send_controller.dart#L579-L638); [WebAppBridge._maxShare](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/frontend/screens/webapp/web_app_bridge.dart#L460-L490).

**Проблема:** Внешнее «Поделиться», отдельные вложения, голосовые сообщения, кружки и текст из мини-приложения проходят через обычную отправку без обязательной проверки шифрования чата. Отложенное видео может уйти до отказа в отправке зашифрованного фото. Пользователь ожидает шифрование, но сервер получает открытое содержимое.

**Подготовленное решение:** Введена OutgoingMessagePolicy и общая проверка в MessagesModule непосредственно перед отправкой и каждым retry. Учитываются парольное шифрование и все ненулевые фазы E2EE. Отправка шифртекста явно отмечается encryptedPayload; управляющие пакеты E2EE отделены от пользовательского содержимого. Share проверяет всех адресатов заранее, UI и WebApp дублируют ограничение. Редактирование отложенных сообщений в шифрованном чате безопасно отклоняется.

**Изменённые или проверенные файлы:** [lib/core/crypto/outgoing_message_policy.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/crypto/outgoing_message_policy.dart), [lib/backend/modules/messages.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/backend/modules/messages.dart), [lib/backend/modules/share_sender.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/backend/modules/share_sender.dart), [lib/frontend/screens/chats/scheduled_messages_screen.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/frontend/screens/chats/scheduled_messages_screen.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** Неподдерживаемые способы отправки и внешний share в шифрованные чаты заблокированы; полноценное шифрование всех типов вложений этим патчем не добавлено.

## 2. WebApp bridge доверяет посторонней странице и поддельному жесту

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [attach/registerGesture](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/frontend/screens/webapp/web_app_bridge.dart#L184-L215); [навигация](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/frontend/screens/webapp/web_app_screen.dart#L176-L210); [вариант FullStack](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/lib/frontend/screens/webapp/web_app_bridge.dart#L191-L222).

**Проблема:** Мост не проверяет origin и главный фрейм вызывающего документа. После перехода WebView на другой сайт сохраняется прежний bot ID и доступ к его хранилищу. Отдельный JS-обработчик webAppGesture позволяет скрипту самому отметить «касание пользователя». Для использования ошибки нужен чужой документ/фрейм или компрометация страницы.

**Подготовленное решение:** Мост проверяет точный origin и основной фрейм по нативным данным. На Android используется origin-bound WebMessageListener; JS больше не может сам подтвердить жест. Контекст привязан к аккаунту и поколению документа, в том числе после повторной загрузки того же origin. После await заново проверяется авторизация, старые ответы отбрасываются. Посторонние переходы открываются вне WebView.

**Изменённые или проверенные файлы:** [lib/frontend/screens/webapp/web_app_bridge.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/frontend/screens/webapp/web_app_bridge.dart), [lib/frontend/screens/webapp/web_app_screen.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/frontend/screens/webapp/web_app_screen.dart), [lib/frontend/screens/webapp/web_app_origin_policy.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/frontend/screens/webapp/web_app_origin_policy.dart), [pubspec.yaml](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/pubspec.yaml).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** Для метаданных origin/frame требуется flutter_inappwebview 6.2.0-beta.3. На платформах без надёжного подтверждения мост закрыт. Совместимость мини-приложений, Android WebView и iOS нужно проверить на устройствах.

## 3. PNG допускает огромную распаковку

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [unwrapNoisePng/_inflateBounded](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/crypto/noise_png.dart#L88-L183); [decryptImageBytes/looksEncryptedImage](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/crypto/chat_crypto_service.dart#L147-L175); [повторная обработка](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/crypto/encrypted_photo_cache.dart#L280-L292).

**Проблема:** Отдельные лимиты ширины и высоты по 16384 разрешают примерно 768 MiB распакованных строк и ещё 768 MiB результата. Малый сжатый файл способен потребовать более 1,5 GiB буферов до проверки криптоблока. Сетевой лимит 32 MiB этого не предотвращает. Распаковка синхронна; предварительная проверка и расшифровка повторяют её дважды.

**Подготовленное решение:** До выделения буферов проверяется decoded budget 32 MiB; ограничен также размер входного PNG. Inflate ограничен и подаётся небольшими порциями. Повторный предварительный разбор удалён. Разбор PNG и native decrypt выполняются одной задачей в isolate; одновременно выполняется одна такая задача. Копии ключа очищаются, CRC не создаёт большую промежуточную копию.

**Изменённые или проверенные файлы:** [lib/core/crypto/noise_png.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/crypto/noise_png.dart), [lib/core/crypto/chat_crypto_service.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/crypto/chat_crypto_service.dart), [lib/core/crypto/encrypted_photo_cache.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/crypto/encrypted_photo_cache.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** Большие старые изображения, превышающие бюджет, отклоняются. Время и память не измерялись на устройствах; ускорение в процентах не заявляется.

## 4. Расшифрованные фотографии остаются после смены ключа и удаления аккаунта

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [имена кэша](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/crypto/encrypted_photo.dart#L20-L26); [openEncryptedPhoto](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/crypto/encrypted_photo.dart#L86-L105); [готовый файл до проверки ключа](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/crypto/encrypted_photo_cache.dart#L233-L261); [removeAccount](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/backend/modules/account.dart#L683-L690).

**Проблема:** Открытые фото сохраняются в постоянном MediaCache. Парольное имя кэша не учитывает поколение ключа; готовая расшифровка возвращается до проверки текущего пароля. Удаление аккаунта не очищает согласованно парольные ключи, открытые фото и secure-хранилище ботов. E2EE проверяет билет раньше disk hit, но его фото также остаются открытыми на диске.

**Подготовленное решение:** Добавлен отдельный DecryptedPhotoStore во временной папке экземпляра приложения: очистка на старте, удаление старых decrypted_* из постоянного кэша, поколения и запрет публикации устаревших задач. Ключ проверяется до disk hit. Смена ключа/E2EE инвалидирует значения живых виджетов. Удаление аккаунта очищает связанные ключи, настройки и bot secure storage. Лимиты: 64 MiB на файл, 128 MiB суммарно.

**Изменённые или проверенные файлы:** [lib/core/crypto/decrypted_photo_store.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/crypto/decrypted_photo_store.dart), [lib/core/crypto/encrypted_photo.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/crypto/encrypted_photo.dart), [lib/core/crypto/encrypted_photo_cache.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/crypto/encrypted_photo_cache.dart), [lib/backend/modules/account.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/backend/modules/account.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** Это временный plaintext-кэш, а не шифрование локальных данных. Открытые данные доступны во время просмотра; crash и уже созданные копии требуют отдельных мер.

## 5. Кэш текста возвращает устаревшие расшифровки

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [идентичность и _begin](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/crypto/message_decryption_cache.dart#L47-L136); [асинхронные результаты и clear](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/crypto/message_decryption_cache.dart#L139-L219).

**Проблема:** Ключом служит только message ID. Изменённый шифртекст не инвалидирует уже полученный текст; одинаковые ID разных контекстов используют одну запись. После clear старый Future может вернуть расшифровку в новый кэш. Очистка карты не обнуляет значения у уже подписанных виджетов.

**Подготовленное решение:** Ключ кэша включает accountId/chatId/messageId; сравниваются шифртекст, версия операции, поколение и экземпляр notifier. Очистка обнуляет значения у подписанных виджетов. Редактирование, включая пустой текст, инвалидирует старую расшифровку; живые записи и активные задания защищены от вытеснения.

**Изменённые или проверенные файлы:** [lib/core/crypto/message_decryption_cache.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/crypto/message_decryption_cache.dart), [lib/frontend/widgets/decrypted_text.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/frontend/widgets/decrypted_text.dart), [lib/frontend/screens/chats/chat_screen.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/frontend/screens/chats/chat_screen.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

## 6. Недописанный E2EE-файл может считаться готовым

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [openE2eePhoto](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/crypto/encrypted_photo.dart#L157-L205).

**Проблема:** Расшифровка пишет сразу по окончательному имени. При аварийном завершении остаётся непустой обрезанный файл, который следующее открытие принимает за готовую расшифровку. Размер из билета не проверяется на точное совпадение с результатом.

**Подготовленное решение:** E2EE-файл пишется в уникальный staging. Билет ограничивается до записи, все блоки аутентифицируются, итоговый размер должен точно совпадать. Только после успеха выполняется атомарный rename. Ошибка и смена поколения удаляют staging; handles, sink, opener и ключи освобождаются в finally.

**Изменённые или проверенные файлы:** [lib/core/crypto/encrypted_photo.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/crypto/encrypted_photo.dart), [lib/core/crypto/decrypted_photo_store.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/crypto/decrypted_photo_store.dart), [test/decrypted_photo_store_test.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/test/decrypted_photo_store_test.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

## 7. MediaCache возвращает удалённый файл и неполно ограничивает загрузки

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [_download](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/utils/media_cache.dart#L160-L217); [_enforceLimit](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/utils/media_cache.dart#L275-L306).

**Проблема:** LRU может удалить только что скачанный файл, после чего _download возвращает его путь. Не все загрузки имеют maxBytes; нет обязательных таймаутов. При ошибке потока sink может остаться открытым. Прямые записи расшифровок обходят инкрементальный учёт, поэтому размер кэша становится неточным.

**Подготовленное решение:** Загрузки ограничены Content-Length и фактическим потоком; есть таймауты соединения, ответа и простоя. Публикация, учёт, clear и discard сериализованы. Новый результат защищён от LRU, имя нормализуется до in-flight lookup. Clear увеличивает поколение и не допускает поздней публикации. Pinned-файлы ограничены суммарно, plaintext вынесен в отдельное хранилище.

**Изменённые или проверенные файлы:** [lib/core/utils/media_cache.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/utils/media_cache.dart), [test/media_cache_security_test.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/test/media_cache_security_test.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** Сетевой файл ограничен 128 MiB, pinned-кэш — 128 MiB. Это меняет поведение больших видео и файлов; лимиты требуют продуктового согласования. При полной квоте новая запись отклоняется.

## 8. Сетевой запрет плагинов обходится через DNS

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [plugin fetch](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/plugins/plugin_runtime.dart#L226-L280); [_httpsUri/фильтр IP](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/plugins/plugin_runtime.dart#L313-L349); [media URL policy](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/plugins/plugin_media_downloader.dart#L106-L137).

**Проблема:** Проверяется частный IP, указанный буквально в URL, но не адреса DNS-имени. Разрешённый hostname может вести в локальную сеть. Отдельная предварительная DNS-проверка без фиксации адреса соединения также оставляет возможность смены ответа. Использование требует network-разрешения и приемлемого HTTPS-сертификата.

**Подготовленное решение:** Общая PluginNetworkPolicy проверяет HTTPS URL и весь набор DNS-ответов, включая смешанные адреса, IPv4-mapped IPv6 и специальные диапазоны. Сокет соединяется с уже проверенным InternetAddress; TLS сохраняет исходный hostname. Прокси отключён, redirect проверяется заново, fetch и media имеют ограничения времени и объёма.

**Изменённые или проверенные файлы:** [lib/core/plugins/plugin_network_policy.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/plugins/plugin_network_policy.dart), [lib/core/plugins/plugin_runtime.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/plugins/plugin_runtime.dart), [lib/core/plugins/plugin_media_downloader.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/plugins/plugin_media_downloader.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** Проверка IP не контролирует прозрачные прокси и маршрутизацию ОС. Это защита на уровне клиента, а не полная сетевая песочница.

## 9. PluginStorage теряет конкурентные изменения

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [get/set/remove/clear](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/plugins/plugin_storage.dart#L6-L48).

**Проблема:** Два set читают один старый JSON и перезаписывают изменения друг друга. Remove не сохраняет удаление ключа со значением null. Лимит encoded.length считает символы вместо UTF-8 байт. Namespace содержит только plugin ID, поэтому аккаунтные данные плагина не изолированы автоматически.

**Подготовленное решение:** Модификации PluginStorage сериализованы по namespace, ошибки не ломают очередь. Удаляется и null-значение; квота считается по UTF-8. Runtime использует namespace аккаунта и plugin ID. Удаление аккаунта/плагина инвалидирует старые операции и очищает все известные области. Host привязан к аккаунту и sessionEpoch, после загрузки медиа контекст проверяется повторно.

**Изменённые или проверенные файлы:** [lib/core/plugins/plugin_storage.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/plugins/plugin_storage.dart), [lib/core/plugins/plugin_runtime.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/plugins/plugin_runtime.dart), [lib/core/plugins/plugin_host.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/plugins/plugin_host.dart), [lib/core/plugins/plugin_store.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/plugins/plugin_store.dart), [lib/frontend/screens/chats/chat_screen.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/frontend/screens/chats/chat_screen.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** Старое глобальное v1-хранилище не копируется автоматически во все аккаунты: такая миграция нарушила бы изоляцию. Совместимость плагинов нужно проверить на устройствах.

## 10. Загрузка продолжает работать после смены аккаунта

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [UploadService](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/backend/modules/upload_service.dart#L265-L304); [повторные попытки](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/backend/modules/upload_service.dart#L681-L713); [switchAccount](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/backend/modules/account.dart#L635-L672); [sendRequest/beforeSend](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/backend/api.dart#L341-L370).

**Проблема:** UploadJob сохраняет account ID, но отправляет через общий messagesModule. После переключения аккаунта задача может продолжиться на новой сессии. Финальный beforeSend не передан из обычной загрузки. Принятие такого запроса сервером не подтверждено; отсутствующая привязка видна в коде.

**Подготовленное решение:** UploadJob и внешняя отправка фиксируют аккаунт, экземпляр сессии, sessionEpoch и accountEpoch. Смена активного аккаунта увеличивает epoch синхронно до await. Проверки выполняются перед URL, загрузкой, финальной отправкой и retry; MessagesModule проверяет контекст после login gate.

**Изменённые или проверенные файлы:** [lib/backend/modules/upload_service.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/backend/modules/upload_service.dart), [lib/backend/modules/file_uploader.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/backend/modules/file_uploader.dart), [lib/backend/modules/messages.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/backend/modules/messages.dart), [lib/core/storage/token_storage.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/storage/token_storage.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** Запросы, уже переданные сети до смены аккаунта, отозвать невозможно. Проверки предотвращают последующие шаги и новые отправки в изменившемся контексте.

## 11. Настройки чатов объявляются загруженными раньше чтения

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [load/write](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/storage/per_chat_json_store.dart#L34-L77); [готовое исправление FullStack](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/lib/core/storage/per_chat_json_store.dart#L36-L80).

**Проблема:** Load устанавливает _loaded до await чтения prefs. Второй вызов завершается с ещё пустыми настройками; потребитель может принять шифрование за выключенное. Ранняя запись также не ждёт чтения.

**Подготовленное решение:** В текущей feature/FullStack уже используется общий Future загрузки и повтор после ошибки. per_chat_json_store.dart оставлен без изменений. Регрессионный тест проверяет, что конкурентные потребители ждут один load и видят загруженные настройки.

**Изменённые или проверенные файлы:** [lib/core/storage/per_chat_json_store.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/storage/per_chat_json_store.dart), [test/security_audit_regressions_test.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/test/security_audit_regressions_test.dart).

**Статус:** Уже исправлено в базе FullStack; добавлена проверка.

**Ограничения:** Это исправление унаследовано от FullStack, а не внесено заново. В dev/0.5.0 исходная проблема сохраняется; для этой ветки потребуется отдельный backport.

## 12. Обычный --debug раскрывает OTP, токены и содержимое сообщений

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [WireDebugLog](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/lib/core/transport/wire_debug_log.dart#L10-L44); [_onWireLog](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/lib/backend/api.dart#L794-L810); [сохранение строк](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/lib/core/utils/debug_session_log.dart#L267-L300); [тест, закрепляющий открытый token](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/test/launch_flags_test.dart#L97-L110).

**Проблема:** В debug скрывается только payload LOGIN(19). Остальные пакеты проходят regex по password, но token, verifyCode, text и телефон сохраняются. RecordLogLine удаляет ANSI, не выполняя redactForLog. Секреты попадают в console и экспортируемый session log. По умолчанию debug выключен; риск возникает при диагностическом запуске и передаче журнала.

**Подготовленное решение:** Все wire payload проходят рекурсивную редактировку JSON вне зависимости от opcode. Удаляются токены, OTP/коды, пароли, QR-данные, текст сообщений и идентификаторы устройств; телефон маскируется. Некорректный JSON скрывается полностью. Экспорт DebugSessionLog повторяет редактирование. --dw19p-im-crazy показывает структуру LOGIN, но больше не выдаёт секреты.

**Изменённые или проверенные файлы:** [lib/core/transport/wire_debug_log.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/transport/wire_debug_log.dart), [lib/core/utils/log_redact.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/utils/log_redact.dart), [lib/core/utils/debug_session_log.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/utils/debug_session_log.dart), [CLAUDE.md](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/CLAUDE.md).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** Редактирование журналов не гарантирует отсутствие чувствительных данных в произвольных полях сторонних payload. Новые протокольные поля нужно добавлять в policy; ранее созданные журналы не переписываются.

## 13. Действующий временный пароль записывается в error log

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [rollback dev](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/backend/modules/account.dart#L542-L560); [rollback FullStack](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/lib/backend/modules/account.dart#L623-L645); [вывод в console/session log](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/utils/logger.dart#L44-L59).

**Проблема:** Если временный пароль web-SMS входа не удалось снять, logger.e печатает его целиком. Error-уровень доступен и в обычном release. Пароль остаётся действующим и может попасть в экспорт журнала.

**Подготовленное решение:** Временный 2FA-пароль больше не пишется в logger.e. До установки пароля серверу сохраняется защищённая запись с accountId и случайным operationId. После подтверждённого rollback удаляется только совпадающая запись. Незавершённую запись нельзя перезаписать. Показ возможен после явного подтверждения владельца в настройках безопасности либо после проверенного OTP для того же accountId.

**Изменённые или проверенные файлы:** [lib/backend/modules/account.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/backend/modules/account.dart), [lib/core/storage/temporary_password_recovery.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/storage/temporary_password_recovery.dart), [lib/frontend/widgets/temporary_password_recovery_dialog.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/frontend/widgets/temporary_password_recovery_dialog.dart), [lib/frontend/screens/auth/code_confirmation_screen.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/frontend/screens/auth/code_confirmation_screen.dart), [lib/frontend/screens/profile/security_screen.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/frontend/screens/profile/security_screen.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** Запись остаётся, пока откат не подтверждён, чтобы не лишить владельца восстановления. Сценарий повторного входа зависит от получения accountId после OTP; реальный SMS/2FA-flow и поведение Keychain требуют проверки на устройствах.

## 14. iOS Share Extension не перепроверяет шифрование во время отправки

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [публикация политики](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/lib/core/share/native_share_account_sync.dart#L86-L170); [authorizedCredentials](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/ios/Shared/KometShareAccounts.swift#L134-L143); [начальная проверка](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/ios/ShareExtension/ShareViewController.swift#L600-L616); [upload и конечный send](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/native/komet_share/src/engine.rs#L340-L431).

**Проблема:** Зашифрованные чаты запрещены в начальном snapshot, но разрешение проверяется один раз. Затем Rust долго загружает файлы и отправляет обычный payload. Включение шифрования или удаление аккаунта после проверки не отменяет уже работающий transport. Проверка разрыва подтверждена кодом; сценарий на iOS требует воспроизведения.

**Подготовленное решение:** Swift публикует epoch политики и время снимка аккаунта; изменения ключей/E2EE и удаление аккаунта инвалидируют разрешение. Rust читает снимок под общей файловой блокировкой и проверяет аккаунт, чат, epoch и свежесть перед соединением, загрузкой, каждым запросом и retry. Во время upload policy проверяется каждые 100 ms, изменение прекращает следующий шаг. Без authorization отправка запрещена.

**Изменённые или проверенные файлы:** [ios/Shared/KometShareAccounts.swift](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/ios/Shared/KometShareAccounts.swift), [ios/Runner/KometShareBridge.swift](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/ios/Runner/KometShareBridge.swift), [lib/core/share/native_share_account_channel.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/share/native_share_account_channel.dart), [lib/core/share/native_share_account_sync.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/share/native_share_account_sync.dart), [native/komet_share/src/authorization.rs](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/native/komet_share/src/authorization.rs), [native/komet_share/src/engine.rs](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/native/komet_share/src/engine.rs), [native/komet_share/src/transport.rs](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/native/komet_share/src/transport.rs).

**Статус:** Подготовлено; проверка Swift/iOS остаётся обязательной.

**Ограничения:** Rust проверен локально; Swift и обмен данными между приложением и Share Extension на iOS ещё не проверены. Снимок старше 5 минут отклоняется и требует открыть Komet. Уже отправленные байты отозвать нельзя. Старые версии extension должны обновляться вместе с приложением.

## 15. Выбор аватара вызывает ошибку разметки и падение CI

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [avatar picker test](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/test/avatar_picker_test.dart#L98-L136); [нижняя панель](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/lib/frontend/widgets/attachment/attachment_sheet.dart#L1240-L1320); [геометрия](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/lib/frontend/widgets/sliding_pill_nav.dart#L28-L44); [Row](https://github.com/KometTeam/Komet/blob/41def0a3e7ee987c58ad665bb115c22297e60ff0/lib/frontend/widgets/sliding_pill_nav.dart#L216-L243).

**Проблема:** В [сегодняшнем Tests CI](https://github.com/KometTeam/Komet/actions/runs/38072057463) тест выбора аватара фиксирует промах tap по «Файл» и RenderFlex overflow на 0,600 px справа. Следом inspector получает ошибку доступа к деактивированному ancestor. Точный первичный widget нужно установить воспроизведением; сегодняшний commit нельзя считать причиной только по времени падения.

**Подготовленное решение:** SlidingPillNav рассчитывает геометрию по реальной ширине внутри рамки через LayoutBuilder. Размеры и промежутки уменьшаются согласованно, пустой список безопасен. Тест аватара нажимает на доступную ячейку, а не скрытую подпись; добавлены проверки узких экранов с масштабом текста 2.

**Изменённые или проверенные файлы:** [lib/frontend/widgets/sliding_pill_nav.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/frontend/widgets/sliding_pill_nav.dart), [test/avatar_picker_test.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/test/avatar_picker_test.dart), [test/dev22_followup_regressions_test.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/test/dev22_followup_regressions_test.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** Проверены widget-тесты, а не визуальные снимки на всех платформах, DPR и стилях оформления.

## 16. Desktop-галерея блокирует интерфейс сканированием папок

**Ветки исходного отчёта:** `dev/0.5.0`, `feature/FullStack` — только `0.5.22+22`.

**Место исходной проблемы:** [GallerySource.load/_scan](https://github.com/KometTeam/Komet/blob/1b83a3fbdba5c67c3ed4fa8a0f977adcc9e1031e/lib/core/media/gallery_source.dart#L236-L272).

**Проблема:** Первая страница запускает existsSync/listSync/statSync и сортирует весь каталог на UI isolate. В папках с тысячами изображений пользователь ждёт полного обхода до появления первых элементов.

**Подготовленное решение:** Обход каталогов, stat и сортировка перенесены в compute worker. Параллельные запросы используют одну задачу и общий индекс; следующие страницы не запускают новый полный scan. Первая страница обновляет индекс после интервала 30 секунд. Регрессионный тест проверяет сортировку, стабильность пагинации и обновление.

**Изменённые или проверенные файлы:** [lib/core/media/gallery_source.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/lib/core/media/gallery_source.dart), [test/dev22_followup_regressions_test.dart](https://github.com/alcovaibe/Komet/blob/fix/dev22-audit-2026-10-11/test/dev22_followup_regressions_test.dart).

**Статус:** Исправление подготовлено; границы проверки приведены ниже.

**Ограничения:** FileSystemWatcher и живое обновление во время просмотра не добавлены. Это перенос тяжёлой работы с UI и устранение повторных scan, без измеренного процента ускорения.

## Проверки и готовность

Проверки выполнялись на синтетических данных, без APK/AAB.

- Flutter 3.47.0: точный framework commit и Dart 3.13.0 из соответствующего engine. Выполнен `dart analyze lib test tool`, замечаний нет.
- 105 целевых тестов Dart/Flutter в 10 файлах: security audit (14), decrypted photo store (8), media cache (3), launch flags (10), avatar picker (6), WebApp bridge (24), forwarding (15), outbox account (5), text send controller (13), follow-up regressions (7). Использован прямой frontend compiler + Flutter test engine и test_api runner; штатный `flutter test` целиком локально не запускался. Настоящие widget-тесты выполнялись в Flutter engine.
- Rust: `RUSTFLAGS=-Dwarnings cargo test --locked --manifest-path native/komet_share/Cargo.toml` — 22 теста прошли, включая отсутствие authorization, устаревший epoch, отзыв между upload/send и отмену активной загрузки.
- C crypto-core: штатные тесты и AddressSanitizer прошли. Для ASan использован `ASAN_OPTIONS=detect_leaks=0`: LeakSanitizer в этой среде не проверен.
- Python native build/signing: 15 проверок прошли. Полный набор native Python требует macOS `plutil` и локально не подтверждён.
- В workflow подготовлены штатные `flutter analyze`, полный `flutter test`, Rust-тесты и macOS Swift/Python. Их наличие не означает успешный CI run.

Перед признанием всей ветки готовой к merge остаются полный штатный Flutter CI, Swift/macOS проверки и ручная проверка WebView, SMS/2FA и iOS Share Extension. Обновление WebView до beta и ограничения размеров/свежести требуют внимания при review. Пользователь разрешил подготовку исправлений и issue; создание PR запрещено до отдельного разрешения.
