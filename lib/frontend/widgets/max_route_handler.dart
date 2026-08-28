import 'package:flutter/material.dart';

import '../../core/config/build_profile.dart';
import '../../core/utils/link_opener.dart';
import '../screens/chats/chat_info_screen.dart';
import '../screens/chats/chat_list_screen.dart';
import '../screens/chats/scheduled_messages_screen.dart';
import '../screens/profile/appearance_screen.dart';
import '../screens/profile/debug_menu_screen.dart';
import '../screens/profile/devices_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/info_screen.dart';
import '../screens/profile/message_actions_screen.dart';
import '../screens/profile/notifications_screen.dart';
import '../screens/profile/security_screen.dart';
import '../screens/profile/web_qr_scan_screen.dart';
import 'custom_notification.dart';
import 'max_link_nav.dart';
import 'swipe_route.dart';

Future<bool> openMaxRoute(
  BuildContext context,
  String route,
  Map<String, String> params,
) async {
  switch (route) {
    case ':chat-list':
    case ':settings/folder-list':
      return openRootTab(context, 0);
    case ':calls-history':
    case ':call-list':
      return openRootTab(context, 1);
    case ':contact-list':
      return openRootTab(context, 2);
    case ':settings':
      return openRootTab(context, 3);

    case ':chats-search':
      final root = await popToAppRootAndSettle(context);
      if (ChatListScreen.openSearch()) return true;
      if (root != null && root.mounted) notifyNeedsAccount(root);
      return true;

    case ':saved-messages':
      final root = await popToAppRootAndSettle(context);
      if (ChatListScreen.openSavedMessages()) return true;
      if (root != null && root.mounted) notifyNeedsAccount(root);
      return true;

    case ':settings/folder':
      final id = params['id']?.trim();
      if (id == null || id.isEmpty) return _badLink(context, route);
      return openFolderChatList(context, id);

    case ':chats':
      final id = _intOf(params['id']);
      if (id == null) return _badLink(context, route);
      return openChatById(context, id);

    case ':profile':
    case ':profile/members':
    case ':profile/avatars':
      final id = _intOf(params['id']);
      if (id == null) return _badLink(context, route);
      final type = (params['type'] ?? '').toUpperCase();
      if (type == 'CHAT' || type == 'CHANNEL') {
        return openChatInfoById(context, id);
      }
      return openContactById(context, id);

    case ':profile/attaches':
      final id = _intOf(params['id']);
      if (id == null) return _badLink(context, route);
      return openChatInfoById(context, id, initialTab: ChatInfoTab.media);

    case ':profile/edit':
      return _push(context, const EditProfileScreen());

    case ':scheduled-messages':
      final id = _intOf(params['id']);
      if (id == null) return _badLink(context, route);
      return openScheduledMessages(context, id);

    case ':stickers/set':
      final setId = _intOf(params['set_id']);
      if (setId == null) return _badLink(context, route);
      return openStickerSetById(context, setId);

    case ':webapp:root':
      final botId = _intOf(params['bot_id']);
      if (botId == null) return _badLink(context, route);
      return openWebAppForBot(
        context,
        botId,
        startParam: params['entry_point'],
        chatId: _intOf(params['chat_id']),
      );

    case ':settings/webapp':
      final botId = _intOf(params['bot_id']);
      if (botId == null) return _badLink(context, route);
      return openWebAppForBot(context, botId);

    case ':location/show':
      final lat = double.tryParse(params['lat'] ?? '');
      final lon = double.tryParse(params['lon'] ?? '');
      if (lat == null || lon == null) return _badLink(context, route);
      await openLocationOnMap(
        context,
        lat,
        lon,
        zoom: double.tryParse(params['z'] ?? ''),
      );
      return true;

    case ':qr-scanner':
      return _push(context, const WebQrScanScreen());
    case ':settings/appearance':
      return _push(context, const AppearanceScreen());
    case ':settings/notifications':
    case ':settings/notifications/chat':
    case ':settings/notifications/dialog':
    case ':settings/notifications/other':
      return _push(context, const NotificationsScreen());
    case ':settings/devices':
      return _push(context, const DevicesScreen());
    case ':settings/aboutapp':
      return _push(context, const InfoScreen());
    case ':settings/privacy':
    case ':settings/privacy/pincode':
    case ':settings/blacklist':
      return _push(context, const SecurityScreen());
    case ':settings/messages':
      return _push(context, const MessageActionsScreen());
    case ':settings/dev':
    case ':settings/dev/logsviewer':
    case ':settings/dev/memorydebugger':
    case ':settings/dev/showroom':
    case ':settings/dev/threadsviewer':
    case ':settings/dev/integritylogsviewer':
      if (!BuildProfile.devTools) break;
      return _push(context, const DebugMenuScreen());

    case ':current':
    case ':link-intercept':
    case ':external_callback':
      return true;
  }

  if (context.mounted) {
    showCustomNotification(context, 'Ссылка не поддерживается: $route');
  }
  return true;
}

Future<bool> openChatInfoById(
  BuildContext context,
  int chatId, {
  ChatInfoTab? initialTab,
}) async {
  final myId = await currentAccountId();
  if (myId == 0) return false;
  final chat = await resolveChat(myId, chatId);
  if (!context.mounted) return false;

  final title = chat?.title?.trim();
  return _push(
    context,
    ChatInfoScreen(
      chatId: chatId,
      name: (title != null && title.isNotEmpty) ? title : 'Чат',
      imageUrl: chat?.iconUrl ?? '',
      chatType: chat?.type ?? 'CHAT',
      initialTab: initialTab,
    ),
  );
}

Future<bool> openScheduledMessages(BuildContext context, int chatId) async {
  final myId = await currentAccountId();
  if (myId == 0) return false;
  final chat = await resolveChat(myId, chatId);
  if (!context.mounted) return false;

  final title = chat?.title?.trim();
  return _push(
    context,
    ScheduledMessagesScreen(
      chatId: chatId,
      accountId: myId,
      chatName: (title != null && title.isNotEmpty) ? title : 'Чат',
    ),
  );
}

Future<bool> _push(BuildContext context, Widget screen) async {
  await pushSwipeable(context, (_) => screen);
  return true;
}

bool _badLink(BuildContext context, String route) {
  showCustomNotification(context, 'Неполная ссылка: $route');
  return true;
}

int? _intOf(String? raw) {
  final value = int.tryParse(raw?.trim() ?? '');
  return (value == null || value <= 0) ? null : value;
}
