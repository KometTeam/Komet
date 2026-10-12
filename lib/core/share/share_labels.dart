import '../../l10n/app_localizations.dart';

// #***! заголовок экрана поделиться
String shareTitleFor(
  AppLocalizations l10n, {
  required int photos,
  required int videos,
  required int documents,
  bool textOnly = false,
}) {
  if (textOnly) return l10n.shareTitleMessage;
  final total = photos + videos + documents;
  if (total == 0) return l10n.shareTitleMessage;

  if (photos == total) {
    return photos == 1 ? l10n.shareTitlePhoto : l10n.shareTitlePhotos(photos);
  }
  if (videos == total) {
    return videos == 1
        ? l10n.pasteAttachTitleVideo
        : l10n.shareTitleVideos(videos);
  }
  if (documents == total) {
    return documents == 1
        ? l10n.pasteAttachTitleFile
        : l10n.shareTitleFiles(documents);
  }
  return l10n.shareTitleFiles(total);
}

// #***! подпись с получателями, больше двух счётчиком
String shareSubtitleFor(AppLocalizations l10n, List<String> recipientNames) {
  if (recipientNames.isEmpty) return l10n.adaptiveShellSelectChat;
  if (recipientNames.length <= 2) {
    return l10n.shareSubtitleToChats(recipientNames.join(', '));
  }
  return l10n.shareSubtitleChatCount(recipientNames.length);
}
