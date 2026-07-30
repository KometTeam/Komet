import 'dart:async';

import 'package:flutter/material.dart';

import '../../backend/modules/chats.dart';
import '../../backend/modules/links.dart';
import '../../core/links/max_link.dart';
import '../../core/storage/app_database.dart';
import '../../main.dart';
import '../screens/chats/chat_screen.dart';
import '../screens/contacts/open_contact_profile.dart';
import 'call_link_handler.dart';
import 'confirm_dialog.dart';
import 'custom_notification.dart';
import 'sticker_pack_sheet.dart';
import 'swipe_route.dart';
import 'web_qr_login.dart';

Future<bool> tryHandleMaxLink(BuildContext context, String url) async {
  final link = MaxLink.parse(url);
  if (link == null) return false;

  if (link.kind == MaxLinkKind.call) {
    return tryHandleCallLink(context, url);
  }

  if (link.kind == MaxLinkKind.auth) {
    await confirmAndAuthorizeWebQrLogin(context, link.url);
    return true;
  }

  if (link.kind == MaxLinkKind.stickerSet) {
    return _openStickerSet(context, link.url);
  }

  final resolved = await _resolve(link);
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

Future<ResolvedLink?> _resolve(MaxLink link) async {
  final resolved = await LinkModule.resolve(api, link.url);
  if (link.startPayload == null || link.baseUrl == link.url) return resolved;
  if (resolved is ResolvedChat || resolved is ResolvedUser) return resolved;
  return LinkModule.resolve(api, link.baseUrl);
}

Future<bool> _openStickerSet(BuildContext context, String url) async {
  final path = url
      .replaceFirst(
        RegExp(r'^https?://(?:www\.)?max\.ru/', caseSensitive: false),
        '',
      )
      .split('?')
      .first
      .split('#')
      .first;
  final set = await stickersModule.resolveSetByLink(path);
  if (!context.mounted) return true;
  if (set == null) {
    showCustomNotification(context, 'Стикерпак недоступен');
    return true;
  }
  await showStickerPackSheet(context, knownSetId: set.id);
  return true;
}

Future<void> _openContact(
  BuildContext context,
  MaxLink link,
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
  final profile = await AppDatabase.loadActiveProfile();
  final myId = profile?.id ?? 0;
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
  MaxLink link,
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

  final profile = await AppDatabase.loadActiveProfile();
  final myId = profile?.id ?? 0;
  var isMember = myId != 0 && await AppDatabase.isChatInList(myId, id);

  await chats.cacheServerChat(chat, myId, inList: isMember);
  if (!context.mounted) return;

  if (link.kind == MaxLinkKind.invite && access == 'PRIVATE' && !isMember) {
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

  pushSwipeable(
    context,
    (_) => ChatScreen(
      chatId: id,
      name: title,
      imageUrl: icon,
      chatType: type,
      channelSubscribed: type == 'CHANNEL' ? isMember : null,
    ),
  );
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
