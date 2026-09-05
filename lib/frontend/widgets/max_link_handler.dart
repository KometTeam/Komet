import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../backend/modules/chats.dart';
import '../../backend/modules/links.dart';
import '../../core/links/max_link.dart';
import '../../core/links/profile_link.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/share_origin.dart';
import '../../main.dart';
import '../screens/chats/chat_screen.dart';
import '../screens/contacts/open_contact_profile.dart';
import 'call_link_handler.dart';
import 'confirm_dialog.dart';
import 'custom_notification.dart';
import 'max_link_nav.dart';
import 'max_route_handler.dart';
import 'swipe_route.dart';
import 'web_qr_login.dart';

Future<bool> tryHandleMaxLink(BuildContext context, String url) async {
  final link = MaxLink.parse(url);
  if (link == null) return false;

  switch (link) {
    case MaxRootLink():
      popToAppRoot(context);
      return true;
    case MaxCurrentLink():
      return true;
    case MaxAuthLink(:final url):
      await confirmAndAuthorizeWebQrLogin(context, url);
      return true;
    case MaxCallLink(:final url):
      return tryHandleCallLink(context, url);
    case MaxStickerSetLink(:final path):
      return openStickerSetByPath(context, path);
    case MaxShareSelfLink():
      return _shareOwnLink(context);
    case MaxShareTextLink(:final text):
      return shareTextToChat(context, text);
    case MaxFolderLink(:final folderId):
      return openFolderChatList(context, folderId);
    case MaxRouteLink(:final route, :final params):
      return openMaxRoute(context, route, params);
    case MaxContactIdLink(:final userId):
      return openContactById(context, userId);
    case MaxChatIdLink(:final chatId, :final messageId):
      return openChatById(context, chatId, messageId: messageId);
    case MaxWebAppLink():
      return _openWebAppLink(context, link);
    case MaxContentLink():
      return _openContentLink(context, link);
  }
}

Future<ResolvedLink?> _resolve(String url, String baseUrl) async {
  final resolved = await LinkModule.resolve(api, url);
  if (baseUrl == url) return resolved;
  if (resolved is ResolvedChat || resolved is ResolvedUser) return resolved;
  return LinkModule.resolve(api, baseUrl);
}

Future<bool> _openContentLink(BuildContext context, MaxContentLink link) async {
  final resolved = await _resolve(link.url, link.baseUrl);
  if (!context.mounted) return true;

  switch (resolved) {
    case null:
      return false;
    case ResolvedLinkError(:final message):
      showCustomNotification(context, message);
      return true;
    case ResolvedUser(:final contact):
      await _openContact(context, link, contact);
      return true;
    case ResolvedChat():
      await _openResolvedChat(context, link, resolved);
      return true;
  }
}

Future<bool> _openWebAppLink(BuildContext context, MaxWebAppLink link) async {
  final resolved = await _resolve(link.url, link.url);
  if (!context.mounted) return true;

  final botId = await _botIdOf(resolved);
  if (!context.mounted) return true;
  if (botId == null) {
    final message = resolved is ResolvedLinkError
        ? resolved.message
        : 'Не удалось открыть приложение';
    showCustomNotification(context, message);
    return true;
  }
  return openWebAppForBot(context, botId, startParam: link.startApp);
}

Future<int?> _botIdOf(ResolvedLink? resolved) async {
  switch (resolved) {
    case ResolvedUser(:final contact):
      final id = contact['id'];
      return id is int ? id : null;
    case ResolvedChat(:final chat):
      final chatId = chat['id'];
      if (chatId is! int) return null;
      if ((chat['type'] as String?) != 'DIALOG') return null;
      final myId = await currentAccountId();
      return myId == 0 ? null : chatId ^ myId;
    default:
      return null;
  }
}

Future<bool> _shareOwnLink(BuildContext context) async {
  final link = await ownProfileLink();
  if (!context.mounted) return true;

  if (link == null) {
    showCustomNotification(context, 'У профиля нет публичной ссылки');
    return true;
  }
  try {
    await Share.share(link, sharePositionOrigin: shareOriginOf(context));
  } catch (_) {
    if (context.mounted) {
      showCustomNotification(context, 'Не удалось поделиться ссылкой');
    }
  }
  return true;
}

Future<void> _openContact(
  BuildContext context,
  MaxContentLink link,
  Map<dynamic, dynamic> contact,
) async {
  final id = contact['id'];
  if (id is! int) {
    showCustomNotification(context, 'Не удалось открыть профиль');
    return;
  }

  final startPayload = link.startPayload;
  if (startPayload != null &&
      await _startBotDialog(context, id, contact, startPayload)) {
    return;
  }
  if (!context.mounted) return;

  unawaited(
    openContactDialogProfile(
      context,
      contactId: id,
      name: _contactName(contact),
      avatarUrl: contact['baseUrl'] as String?,
    ),
  );
}

Future<bool> _startBotDialog(
  BuildContext context,
  int botId,
  Map<dynamic, dynamic> contact,
  String startPayload,
) async {
  final myId = await currentAccountId();
  if (myId == 0) return false;

  final chatId =
      await AppDatabase.findDialogChatByParticipant(myId, botId) ??
      (myId ^ botId);
  if (chatId <= 0 || !context.mounted) return false;

  _openChatAndStartBot(
    context,
    chatId: chatId,
    name: _contactName(contact),
    imageUrl: (contact['baseUrl'] as String?) ?? '',
    chatType: 'DIALOG',
    startPayload: startPayload,
  );
  return true;
}

void _openChatAndStartBot(
  BuildContext context, {
  required int chatId,
  required String name,
  required String imageUrl,
  required String chatType,
  required String startPayload,
}) {
  if (ChatScreen.startBotInVisibleChat(chatId, startPayload)) return;
  pushSwipeable(
    context,
    (_) => ChatScreen(
      chatId: chatId,
      name: name,
      imageUrl: imageUrl,
      chatType: chatType,
      botStartPayload: startPayload,
    ),
  );
}

Future<void> _openResolvedChat(
  BuildContext context,
  MaxContentLink link,
  ResolvedChat resolved,
) async {
  final chat = resolved.chat;
  final id = chat['id'];
  if (id is! int) {
    showCustomNotification(context, 'Не удалось открыть чат');
    return;
  }

  final title = (chat['title'] as String?)?.trim() ?? '';
  final type = (chat['type'] as String?) ?? 'CHAT';
  final icon = (chat['baseIconUrl'] as String?) ?? '';
  final access = chat['access'];

  final myId = await currentAccountId();
  var isMember = myId != 0 && await AppDatabase.isChatInList(myId, id);

  await chats.cacheServerChat(chat, myId, inList: isMember);
  if (!context.mounted) return;

  if (link.kind == MaxContentKind.invite &&
      access == 'PRIVATE' &&
      !isMember) {
    final label = title.isEmpty ? 'этот чат' : '«$title»';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Вступить',
      message: 'Вступить в $label?',
      confirmLabel: 'Вступить',
    );
    if (!confirmed || !context.mounted) return;

    final error = await LinkModule.join(api, link.url);
    if (error != null) {
      if (context.mounted) showCustomNotification(context, error);
      return;
    }
    isMember = true;
    await chats.cacheServerChat(chat, myId, inList: true);
    if (!context.mounted) return;
  }

  final startPayload = link.startPayload;
  if (startPayload != null && type == 'DIALOG') {
    _openChatAndStartBot(
      context,
      chatId: id,
      name: title,
      imageUrl: icon,
      chatType: type,
      startPayload: startPayload,
    );
    return;
  }

  final target = _messageTarget(link, resolved.message);
  pushSwipeable(
    context,
    (_) => ChatScreen(
      chatId: id,
      name: title,
      imageUrl: icon,
      chatType: type,
      channelSubscribed:
          (type == 'CHANNEL' || type == 'CHAT' || type == 'GROUP')
          ? isMember
          : null,
      initialMessageId: target?.id,
      initialMessageTime: target?.time,
    ),
  );
}

({String id, int? time})? _messageTarget(
  MaxContentLink link,
  Map<dynamic, dynamic>? message,
) {
  final serverId = message?['id']?.toString();
  final time = message?['time'];
  if (serverId != null && serverId.isNotEmpty) {
    return (id: serverId, time: time is int ? time : null);
  }
  final messageId = link.messageId;
  if (messageId == null) return null;
  return (id: messageId.toString(), time: null);
}

String _contactName(Map<dynamic, dynamic> contact) {
  final names = contact['names'];
  if (names is List && names.isNotEmpty && names.first is Map) {
    final entry = names.first as Map;
    final full = (entry['name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final first = (entry['firstName'] as String?)?.trim() ?? '';
    final last = (entry['lastName'] as String?)?.trim() ?? '';
    final joined = '$first $last'.trim();
    if (joined.isNotEmpty) return joined;
  }
  return 'Профиль';
}
