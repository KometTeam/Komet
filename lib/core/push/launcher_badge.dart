import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../backend/modules/chats.dart';
import '../../backend/modules/cloud_storage.dart';
import '../config/app_badge.dart';
import '../config/komet_settings.dart';
import '../storage/archived_chats_store.dart';
import '../utils/logger.dart';

@immutable
class BadgeCount {
  const BadgeCount({
    required this.enabled,
    required this.byChats,
    required this.count,
    required this.chatIds,
  });

  factory BadgeCount.of(
    Iterable<CachedChat> chats, {
    required bool enabled,
    required bool includeMuted,
    required bool countMessages,
    required bool Function(CachedChat chat) isArchived,
  }) {
    final counted = <int>{};
    var messages = 0;
    if (enabled) {
      for (final chat in chats) {
        if (chat.unreadCount <= 0) continue;
        if (!includeMuted && chat.isMuted) continue;
        if (isArchived(chat)) continue;
        if (CloudStorageModule.isCloudStorageGroup(chat)) continue;
        counted.add(chat.id);
        messages += chat.unreadCount;
      }
    }
    return BadgeCount(
      enabled: enabled,
      byChats: !countMessages,
      count: countMessages ? messages : counted.length,
      chatIds: counted,
    );
  }

  final bool enabled;
  final bool byChats;
  final int count;
  final Set<int> chatIds;

  Map<String, Object> toArgs() => {
    'enabled': enabled,
    'byChats': byChats,
    'count': count,
    'chats': chatIds.toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is BadgeCount &&
      other.enabled == enabled &&
      other.byChats == byChats &&
      other.count == count &&
      setEquals(other.chatIds, chatIds);

  @override
  int get hashCode =>
      Object.hash(enabled, byChats, count, Object.hashAllUnordered(chatIds));
}

class LauncherBadge {
  LauncherBadge._();
  static final LauncherBadge instance = LauncherBadge._();

  static const _method = MethodChannel('ru.komet.app/launcher_badge');
  static const _throttle = Duration(milliseconds: 300);

  final ValueNotifier<bool> supported = ValueNotifier(false);

  Timer? _timer;
  BadgeCount? _sent;
  bool _sawChats = false;

  List<Listenable> get _sources => [
    chats.chatsChanged,
    ArchivedChatsStore.instance.revision,
    KometSettings.showHiddenChats,
    AppBadge.enabled.current,
    AppBadge.includeMuted.current,
    AppBadge.countMessages.current,
  ];

  Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid || supported.value) return;
    try {
      supported.value =
          await _method.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException catch (e) {
      logger.w('LauncherBadge: isSupported failed: ${e.message}');
    } on MissingPluginException {
      return;
    }
    if (!supported.value) return;
    for (final source in _sources) {
      source.addListener(_schedule);
    }
    _schedule();
  }

  void _schedule() {
    if (_timer != null) return;
    _timer = Timer(_throttle, _sync);
  }

  void _sync() {
    _timer = null;
    final next = _current();
    if (next == null || next == _sent) return;
    _sent = next;
    unawaited(_push(next));
  }

  BadgeCount? _current() {
    final enabled = AppBadge.enabled.current.value;
    final loaded = chats.chatsLoaded;
    if (enabled && !loaded && !_sawChats) return null;
    if (loaded) _sawChats = true;
    return BadgeCount.of(
      loaded
          ? chats.chatsSnapshot(
              includeHidden: KometSettings.showHiddenChats.value,
            )
          : const <CachedChat>[],
      enabled: enabled,
      includeMuted: AppBadge.includeMuted.current.value,
      countMessages: AppBadge.countMessages.current.value,
      isArchived: (chat) =>
          ArchivedChatsStore.instance.isArchived(chat.accountId, chat.id),
    );
  }

  Future<void> _push(BadgeCount badge) async {
    try {
      await _method.invokeMethod<void>('sync', badge.toArgs());
    } on PlatformException catch (e) {
      _sent = null;
      logger.w('LauncherBadge: sync failed: ${e.message}');
    }
  }
}
