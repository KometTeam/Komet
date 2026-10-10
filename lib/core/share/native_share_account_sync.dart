import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../backend/api.dart';
import '../../backend/modules/account.dart';
import '../../backend/modules/chats.dart';
import '../../backend/modules/contacts.dart';
import '../../backend/modules/messages.dart';
import '../config/komet_settings.dart';
import '../crypto/e2ee_service.dart';
import '../storage/app_database.dart';
import '../storage/chat_encryption_store.dart';
import '../storage/token_storage.dart';
import '../utils/logger.dart';
import 'native_share_account_channel.dart';
import 'share_account_snapshot.dart';
import 'share_recipient_eligibility.dart';

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

  void _refreshPrivacy() => unawaited(refresh());

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
    final recipients = <ShareRecipientSnapshot>[];
    for (final chat in cachedChats) {
      var title = chat.title?.trim() ?? '';
      if (chat.id == 0) {
        title = 'Избранное';
      } else if (chat.type == 'DIALOG') {
        for (final participant in chat.participants.keys) {
          if (participant != accountId) {
            title = ContactCache.get(participant) ?? title;
            break;
          }
        }
      }
      final disabledReason = shareRecipientDisabledReason(
        legacyEncryptionEnabled: ChatEncryptionStore.instance.isEnabled(
          accountId,
          chat.id,
        ),
        e2eePhase: E2eeService.instance.phaseOf(accountId, chat.id),
        isChannel: chat.type == 'CHANNEL',
        canPostToChannel: chat.iAmAdmin(accountId),
      );
      recipients.add(
        ShareRecipientSnapshot(
          id: chat.id,
          title: title.isEmpty ? 'Чат' : title,
          type: chat.type,
          disabledReason: disabledReason,
        ),
      );
    }
    final name = '${profile.firstName} ${profile.lastName ?? ''}'.trim();
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
        chats: recipients,
      ),
      generation,
    );
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    unawaited(_loginSubscription?.cancel());
    _loginSubscription = null;
    _chats?.chatsChanged.removeListener(_schedule);
    ContactsModule.revision.removeListener(_schedule);
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
