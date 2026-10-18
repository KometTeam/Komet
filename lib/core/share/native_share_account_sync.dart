import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    show DefaultCacheManager;
import 'package:flutter/widgets.dart';

import '../../backend/api.dart';
import '../../backend/modules/account.dart';
import '../../backend/modules/chats.dart';
import '../../backend/modules/contacts.dart';
import '../../backend/modules/messages.dart';
import '../config/app_stories.dart';
import '../config/komet_settings.dart';
import '../crypto/e2ee_service.dart';
import '../crypto/outgoing_message_policy.dart';
import '../storage/app_database.dart';
import '../storage/chat_encryption_store.dart';
import '../storage/local_contact_avatars.dart';
import '../storage/token_storage.dart';
import '../utils/logger.dart';
import '../utils/media_cache.dart';
import 'native_share_account_channel.dart';
import 'share_account_snapshot.dart';
import 'share_avatar_export.dart';
import 'share_recipient_eligibility.dart';
import 'share_theme_export.dart';

class NativeShareAccountSync with WidgetsBindingObserver {
  NativeShareAccountSync._();

  static final instance = NativeShareAccountSync._();
  Api? _api;
  AccountModule? _account;
  ChatsModule? _chats;
  Timer? _timer;
  StreamSubscription<LoginStatus>? _loginSubscription;
  Future<void>? _operation;
  bool _refreshRequested = false;

  void init(Api api, AccountModule account, ChatsModule chats) {
    if (!Platform.isIOS || _api != null) return;
    _api = api;
    _account = account;
    _chats = chats;
    _loginSubscription = account.loginStatusStream.listen((status) {
      if (status == LoginStatus.success) unawaited(refresh());
    });
    chats.chatsChanged.addListener(_schedule);
    ContactsModule.revision.addListener(_schedule);
    AppStories.current.addListener(_schedule);
    ChatEncryptionStore.instance.revision.addListener(_refreshPrivacy);
    E2eeService.instance.revision.addListener(_refreshPrivacy);
    KometSettings.ghostMode.addListener(_schedule);
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
  }

  void _schedule() {
    _timer ??= Timer(const Duration(milliseconds: 400), () {
      _timer = null;
      unawaited(refresh());
    });
  }

  void _refreshPrivacy() {
    unawaited(
      NativeShareAccountChannel.instance
          .invalidateAll()
          .then((_) => refresh())
          .catchError((Object error) {
            logger.w('Share privacy invalidation failed: ${error.runtimeType}');
          }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.resumed) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() {
    if (_api == null) return Future.value();
    _timer?.cancel();
    _timer = null;
    _refreshRequested = true;
    return _operation ??= _drain().whenComplete(() => _operation = null);
  }

  Future<void> _drain() async {
    while (_refreshRequested) {
      _refreshRequested = false;
      try {
        await _publishActiveAccount();
      } catch (error) {
        logger.w('Share account sync failed: ${error.runtimeType}');
      }
    }
  }

  Future<void> _publishActiveAccount() async {
    final api = _api;
    final account = _account;
    final chats = _chats;
    if (api == null ||
        account == null ||
        chats == null ||
        !account.isLoggedIn ||
        api.state != SessionState.online) {
      return;
    }
    final options = api.shareSessionOptions;
    if (options == null) return;
    final epoch = api.sessionEpoch;
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;
    final channel = NativeShareAccountChannel.instance;
    final generation = channel.generation(accountId);
    final token = await TokenStorage.readToken(accountId);
    final profile = await AppDatabase.loadProfile(accountId);
    if (token == null || profile == null) return;
    await ChatEncryptionStore.instance.load();
    await E2eeService.instance.ensureLoaded(accountId);
    final privacyRevision = ChatEncryptionStore.instance.revision.value;
    final e2eeRevision = E2eeService.instance.revision.value;
    final cachedChats = await chats.getChats(accountId);
    if (await TokenStorage.getActiveAccountId() != accountId ||
        api.sessionEpoch != epoch ||
        api.state != SessionState.online ||
        !account.isLoggedIn ||
        !identical(_api, api) ||
        !identical(_account, account)) {
      return;
    }
    if (privacyRevision != ChatEncryptionStore.instance.revision.value ||
        e2eeRevision != E2eeService.instance.revision.value ||
        !E2eeService.instance.isLoaded(accountId)) {
      _refreshRequested = true;
      return;
    }
    final avatarNames = <String>{};
    final recipients = <ShareRecipientSnapshot>[];
    for (final chat in cachedChats) {
      var title = chat.title?.trim() ?? '';
      var peerId = 0;
      if (chat.id == 0) {
        title = 'Избранное';
      } else if (chat.type == 'DIALOG') {
        for (final participant in chat.participants.keys) {
          if (participant != accountId) {
            peerId = participant;
            title = ContactCache.get(participant) ?? title;
            break;
          }
        }
      }
      final disabledReason = shareRecipientDisabledReason(
        requiresEncryption: OutgoingMessagePolicy.requiresEncryption(
          accountId,
          chat.id,
        ),
        isChannel: chat.type == 'CHANNEL',
        canPostToChannel: chat.iAmAdmin(accountId),
      );
      String? avatar;
      if (chat.id != 0) {
        avatar = await _exportCachedAvatar(
          accountId,
          chatId: chat.id,
          chat: chat,
          peerId: peerId,
        );
        if (avatar != null) avatarNames.add(avatar);
      }
      recipients.add(
        ShareRecipientSnapshot(
          id: chat.id,
          title: title.isEmpty ? 'Чат' : title,
          type: chat.type,
          disabledReason: disabledReason,
          avatar: avatar,
          avatarUrl: _avatarUrl(chat.type, peerId, chat.iconUrl),
        ),
      );
    }
    await ShareThemeExport.export();
    final name = '${profile.firstName} ${profile.lastName ?? ''}'.trim();
    // #***! своя аватарка для ячейки «В сторис» и шапки шаринга
    final ownBytes = await _cachedUrlAvatarBytes(profile.baseUrl);
    if (ownBytes != null && ownBytes.isNotEmpty) {
      await ShareAvatarExport.exportOwn(accountId: accountId, bytes: ownBytes);
    }
    await channel.publish(
      ShareAccountSnapshot(
        accountId: accountId,
        accountName: name.isEmpty ? 'Komet' : name,
        token: token,
        session: {
          ...options,
          'ping_interactive': !KometSettings.ghostMode.value,
        },
        login: account.buildLoginPayload(token),
        accountAvatarUrl: _httpUrl((profile.baseUrl ?? '').trim()),
        chats: withStoryRecipient(
          recipients: recipients,
          storiesEnabled: AppStories.current.value,
        ),
      ),
      generation,
    );
    await ShareAvatarExport.prune(accountId: accountId, keep: avatarNames);
  }

  // #***! в снапшот уходит только кеш: сетевую докачку аватарок делает расширение
  Future<String?> _exportCachedAvatar(
    int accountId, {
    required int chatId,
    required CachedChat chat,
    required int peerId,
  }) async {
    try {
      final bytes = await _cachedChatAvatarBytes(chat, peerId);
      if (bytes == null || bytes.isEmpty) return null;
      return await ShareAvatarExport.export(
        accountId: accountId,
        chatId: chatId,
        bytes: bytes,
        key: md5.convert(bytes).toString().substring(0, 16),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _cachedChatAvatarBytes(CachedChat chat, int peerId) async {
    if (chat.type == 'DIALOG' && peerId > 0) {
      final localPath = LocalContactAvatars.instance.pathFor(peerId);
      if (localPath != null) {
        try {
          final bytes = await File(localPath).readAsBytes();
          if (bytes.isNotEmpty) return bytes;
        } on FileSystemException catch (_) {
          return _cachedUrlAvatarBytes(ContactCache.getAvatar(peerId));
        }
      }
      return _cachedUrlAvatarBytes(ContactCache.getAvatar(peerId));
    }
    return _cachedUrlAvatarBytes(chat.iconUrl);
  }

  Future<Uint8List?> _cachedUrlAvatarBytes(String? url) async {
    final source = (url ?? '').trim();
    if (source.isEmpty) return null;
    try {
      // #***! первый источник — кэш аватарок приложения (cached_network_image):
      // они уже скачаны для чат-листа, из MediaCache их не достать
      final inAppCache = await DefaultCacheManager().getFileFromCache(source);
      if (inAppCache != null) {
        final bytes = await inAppCache.file.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (_) {}
    final name = 'avatar_${source.hashCode & 0x7fffffff}.jpg';
    try {
      final cached = await MediaCache.existing(name);
      return cached == null ? null : await cached.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static String? _avatarUrl(String type, int peerId, String? iconUrl) {
    if (type == 'DIALOG' && peerId > 0) {
      return _httpUrl(ContactCache.getAvatar(peerId));
    }
    return _httpUrl(iconUrl);
  }

  static String? _httpUrl(String? value) {
    final url = value?.trim() ?? '';
    if (url.isEmpty) return null;
    if (!url.startsWith('https://') && !url.startsWith('http://')) {
      return null;
    }
    return url;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    unawaited(_loginSubscription?.cancel());
    _loginSubscription = null;
    _chats?.chatsChanged.removeListener(_schedule);
    ContactsModule.revision.removeListener(_schedule);
    AppStories.current.removeListener(_schedule);
    ChatEncryptionStore.instance.revision.removeListener(_refreshPrivacy);
    E2eeService.instance.revision.removeListener(_refreshPrivacy);
    KometSettings.ghostMode.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    _api = null;
    _account = null;
    _chats = null;
    _refreshRequested = false;
  }
}
