Не оставляй комментарии в код
Старайся писать чистый код
Лучше качество чем количество
Когда при исправления какой то ошибки/добавление новой возникает ситуация 50/50 где можно выбрать починить сейчас но костылём, или чинить долго, упорно, может даже вообще не починить и переписать пол приложения - выбирай долго и упорно. 
ВМЕСТО СНЕКБАРОВ ИСПОЛЬЗУЙ НАШИ КАСТОМНЫЕ УВЕДОМЛЕНИЕ showCustomNotification(context, 'текст')
Never leave real data in test files, including existing message contents or real IDs captured from requests. Use synthetic fixtures instead.
Не пытайся собирать APK/AAB (flutter build apk, flutter build appbundle, gradle assemble) — сборку запускает пользователь, тебе достаточно flutter analyze
Если делаешь кнопку, где иконка переключается перечёркнутая/неперечёркнутая (вспышка, микрофон, звук, уведомления) — она должна анимироваться lottie-иконкой, а не подменяться мгновенно: добавь спеку в SLASH_SPECS в tool/make_morph_icons.py (fill=1.0, если кнопка рисует Icon(..., fill: 1)), прогони python3 tool/make_morph_icons.py и выводи через LottieSlashIcon. Ассеты в assets/lottie/ руками не правь — только через генератор.
