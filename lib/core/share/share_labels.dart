import '../utils/format.dart';

String shareTitleFor({
  required int photos,
  required int videos,
  required int documents,
  bool textOnly = false,
}) {
  if (textOnly) return 'Отправить сообщение';
  final total = photos + videos + documents;
  if (total == 0) return 'Отправить сообщение';

  if (photos == total) {
    return photos == 1
        ? 'Отправить фотографию'
        : 'Отправить $photos '
              '${pluralRu(photos, 'фотографию', 'фотографии', 'фотографий')}';
  }
  if (videos == total) {
    return videos == 1 ? 'Отправить видео' : 'Отправить $videos видео';
  }
  if (documents == total) {
    return documents == 1
        ? 'Отправить файл'
        : 'Отправить $documents '
              '${pluralRu(documents, 'файл', 'файла', 'файлов')}';
  }
  return 'Отправить $total ${pluralRu(total, 'файл', 'файла', 'файлов')}';
}

String shareSubtitleFor(List<String> recipientNames) {
  if (recipientNames.isEmpty) return 'Выберите чат';
  if (recipientNames.length <= 2) return 'В чат ${recipientNames.join(', ')}';
  final count = recipientNames.length;
  return 'В $count ${pluralRu(count, 'чат', 'чата', 'чатов')}';
}
