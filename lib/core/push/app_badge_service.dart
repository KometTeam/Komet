import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../backend/modules/chats.dart';
import '../storage/token_storage.dart';
import '../utils/logger.dart';
import 'push_proxy_client.dart';

class AppBadgeService {
  AppBadgeService._();
  static final AppBadgeService instance = AppBadgeService._();

  static const _channel = MethodChannel('ru.komet.app/notifications');

  bool _started = false;
  Timer? _timer;
  int _lastSent = -1;

  void start() {
    if (_started || !Platform.isIOS) return;
    _started = true;
    chats.chatsChanged.addListener(_schedule);
    _schedule();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_started) {
      chats.chatsChanged.removeListener(_schedule);
    }
    _started = false;
    _setBadge(0);
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), _refresh);
  }

  Future<void> _refresh() async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _setBadge(0);
      return;
    }
    final list = await chats.getChats(accountId);
    var total = 0;
    for (final c in list) {
      total += c.unreadCount;
    }
    _setBadge(total);
  }

  Future<void> syncToServer() async {
    if (!Platform.isIOS) return;
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;
    final list = await chats.getChats(accountId);
    final map = <String, int>{};
    for (final c in list) {
      if (c.unreadCount > 0) {
        map[c.id.toString()] = c.unreadCount;
      }
    }
    unawaited(PushProxyClient.instance.syncUnread(map));
  }

  void _setBadge(int n) {
    if (n == _lastSent) return;
    _lastSent = n;
    try {
      _channel.invokeMethod<void>('setBadge', n);
    } catch (e) {
      logger.w('AppBadge: setBadge: $e');
    }
  }
}
