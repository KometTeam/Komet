import 'dart:async';

import 'package:flutter/material.dart';

import '../../backend/modules/chats.dart';
import '../../backend/modules/messages.dart' show ContactCache;
import '../../core/cache/info_cache.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/webview_support.dart';
import '../../main.dart';
import '../screens/chats/chat_list_screen.dart';
import '../screens/chats/chat_screen.dart';
import '../screens/contacts/open_contact_profile.dart';
import '../screens/webapp/web_app_bridge.dart';
import '../screens/webapp/web_app_screen.dart';
import 'custom_notification.dart';
import 'sticker_pack_sheet.dart';
import 'swipe_route.dart';

void popToAppRoot(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
}

Future<BuildContext?> popToAppRootAndSettle(BuildContext context) async {
  popToAppRoot(context);
  await WidgetsBinding.instance.endOfFrame;
  return KometApp.navigatorKey.currentContext;
}

Future<int> currentAccountId() async {
  final profile = await AppDatabase.loadActiveProfile();
  return profile?.id ?? 0;
}

Future<CachedChat?> resolveChat(int myId, int chatId) async {
  var rows = await chats.getChat(myId, chatId);
  if (rows.isEmpty) {
    await chats.ensureChatCached(api, myId, chatId);
    rows = await chats.getChat(myId, chatId);
  }
  return rows.isEmpty ? null : rows.first;
}

Future<bool> openChatById(
  BuildContext context,
  int chatId, {
  int? messageId,
  int? messageTime,
  String? initialText,
}) => openChatAtMessage(
  context,
  chatId,
  messageId: messageId?.toString(),
  messageTime: messageTime,
  initialText: initialText,
);

Future<bool> openChatAtMessage(
  BuildContext context,
  int chatId, {
  String? messageId,
  int? messageTime,
  String? initialText,
}) async {
  final myId = await currentAccountId();
  if (myId == 0) return false;
  final chat = await resolveChat(myId, chatId);
  if (!context.mounted) return false;
  if (chat == null) {
    showCustomNotification(context, 'Чат не найден');
    return true;
  }

  final title = chat.title?.trim();
  final peerId = (chat.type == 'DIALOG' && chatId != 0) ? chatId ^ myId : 0;
  final name = (title != null && title.isNotEmpty)
      ? title
      : (ContactCache.get(chatId ^ myId) ?? 'Чат');
  final imageUrl =
      (peerId > 0 ? ContactCache.getAvatar(peerId) : null) ??
      chat.iconUrl ??
      '';

  await pushSwipeable(
    context,
    (_) => ChatScreen(
      chatId: chatId,
      name: name,
      imageUrl: imageUrl,
      chatType: chat.type,
      initialMessageId: messageId,
      initialMessageTime: messageTime,
      initialText: initialText,
    ),
  );
  return true;
}

Future<bool> openContactById(BuildContext context, int userId) async {
  final info = await ContactInfoFetch.get(userId);
  if (!context.mounted) return false;
  await openContactDialogProfile(
    context,
    contactId: userId,
    name: ContactCache.get(userId) ?? info?.displayName ?? 'Профиль',
    avatarUrl: info?.avatarUrl,
  );
  return true;
}

Future<bool> openStickerSetByPath(BuildContext context, String path) async {
  final set = await stickersModule.resolveSetByLink(path);
  if (!context.mounted) return true;
  if (set == null) {
    showCustomNotification(context, 'Стикерпак недоступен');
    return true;
  }
  await showStickerPackSheet(context, knownSetId: set.id);
  return true;
}

Future<bool> openStickerSetById(BuildContext context, int setId) async {
  await showStickerPackSheet(context, knownSetId: setId);
  return true;
}

Future<bool> openWebAppForBot(
  BuildContext context,
  int botId, {
  String? startParam,
  int? chatId,
}) async {
  if (!webViewSupported) {
    showCustomNotification(context, 'На вашей платформе это недоступно');
    return true;
  }
  final myId = await currentAccountId();
  if (!context.mounted) return false;
  final dialogId = chatId ?? (myId == 0 ? null : myId ^ botId);
  final title = ContactCache.get(botId) ?? 'Приложение';

  await pushSwipeable(
    context,
    (_) => WebAppScreen(
      title: title,
      entryPoint: WebAppEntryPoint.url,
      loader: () => webAppModule.fetchLaunch(
        botId,
        startParam: startParam,
        chatId: dialogId,
      ),
    ),
  );
  return true;
}

Future<bool> shareTextToChat(BuildContext context, String text) async {
  if (text.isEmpty) {
    showCustomNotification(context, 'Нечего отправлять');
    return true;
  }
  final target = await openForwardScreen(context: context);
  if (target == null || !context.mounted) return true;

  await pushSwipeable(
    context,
    (_) => ChatScreen(
      chatId: target.chatId,
      name: target.name,
      imageUrl: target.imageUrl,
      chatType: target.chatType,
      initialText: text,
    ),
  );
  return true;
}

Future<bool> openFolderChatList(BuildContext context, String folderId) async {
  final root = await popToAppRootAndSettle(context);
  if (ChatListScreen.selectFolder(folderId)) return true;
  if (root != null && root.mounted) {
    showCustomNotification(root, 'Папка не найдена');
  }
  return true;
}

Future<bool> openRootTab(BuildContext context, int index) async {
  final root = await popToAppRootAndSettle(context);
  if (ChatListScreen.selectTab(index)) return true;
  if (root != null && root.mounted) notifyNeedsAccount(root);
  return true;
}

void notifyNeedsAccount(BuildContext context) =>
    showCustomNotification(context, 'Сначала войдите в аккаунт');
