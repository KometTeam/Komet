import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/logger.dart';
import '../../models/informer_banner.dart';

// #***! баннеры над списком чатов
class BannersModule {
  static const _snapshotKey = 'informer_banners';
  static const _stateKey = 'informer_state';
  static const _enabledKey = 'informer_enabled';
  static const _serverFlag = 'informer-enabled';
  static const int _resyncMask = 1;
  // #***! по дефолту баннер живёт сутки
  static const int _defaultShowTime = 86400000;

  final Api _api;

  // #***! сервер пушит изменения набора
  BannersModule(this._api) {
    _api.pushStream
        .where((p) => p.opcode == Opcode.notifBanners)
        .listen(_handlePush);
  }

  // #***! наружу один активный, на него подписан список чатов
  final ValueNotifier<InformerBanner?> activeBanner = ValueNotifier(null);

  int? _accountId;
  bool _enabled = true;
  int _updateTime = 0;
  int _showTime = _defaultShowTime;
  List<InformerBanner> _banners = const [];
  // #***! память показов, сколько видели и когда закрыли
  final Map<String, BannerShowState> _showState = {};
  String? _lastShownId;
  // #***! _pinnedId держит баннер на экране чтоб не менялся под пальцем
  String? _pinnedId;
  Future<void>? _syncing;

  bool get isEnabled => _enabled;
  int get showTime => _showTime;
  List<InformerBanner> get banners => List.unmodifiable(_banners);

  BannerShowState stateOf(String bannerId) =>
      _showState[bannerId] ?? const BannerShowState();

  // #***! при логине снимок, потом баннеры из ответа, потом сервер
  Future<void> initFromLogin(
    int accountId,
    Map<dynamic, dynamic> loginData,
  ) async {
    await load(accountId);

    final config = loginData['config'];
    final serverConfig = config is Map ? config['server'] : null;
    if (serverConfig is Map && serverConfig.containsKey(_serverFlag)) {
      await _setEnabled(accountId, _parseFlag(serverConfig[_serverFlag]));
    }
    if (!_enabled) return;

    var applied = false;
    final inline = loginData['banners'];
    if (inline is Map) {
      applied = await applyPayload(accountId, inline.cast<dynamic, dynamic>());
    }

    if (applied && !_needsResync(loginData['updates'])) return;
    await syncFromServer();
  }

  // #***! поднимаем из базы чтоб было видно до ответа сервера
  Future<void> load(int accountId) async {
    _accountId = accountId;
    _pinnedId = null;
    await _restoreSnapshot(accountId);
    await _restoreShowState(accountId);
    final enabled = await AppDatabase.getSyncValue(accountId, _enabledKey);
    _enabled = enabled != '0';
    _recompute();
  }

  // #***! _syncing схлопывает параллельные синхры
  Future<void> syncFromServer() {
    return _syncing ??= _sync().whenComplete(() => _syncing = null);
  }

  // #***! updateTime старее нашего, данные протухли
  Future<bool> applyPayload(
    int accountId,
    Map<dynamic, dynamic> payload,
  ) async {
    final raw = payload['banners'];
    if (raw is! List) return false;

    final updateTime = _int(payload['updateTime']);
    if (_updateTime != 0 && updateTime != null && updateTime <= _updateTime) {
      return true;
    }

    final parsed = <InformerBanner>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final banner = InformerBanner.fromMap(entry);
      if (banner != null) parsed.add(banner);
    }

    _banners = parsed;
    if (updateTime != null) _updateTime = updateTime;
    final showTime = _int(payload['showTime']);
    if (showTime != null && showTime > 0) _showTime = showTime;

    // #***! показы исчезнувших баннеров чистим чтоб не копились
    final known = parsed.map((b) => b.id).toSet();
    _showState.removeWhere((id, _) => !known.contains(id));
    if (_pinnedId != null && !known.contains(_pinnedId)) _pinnedId = null;
    if (_lastShownId != null && !known.contains(_lastShownId)) {
      _lastShownId = null;
    }

    await _persistSnapshot(accountId);
    await _persistShowState(accountId);
    _recompute();
    return true;
  }

  // #***! первый показ фиксит время, от него срок жизни
  Future<void> markShown(InformerBanner banner) async {
    if (_pinnedId == banner.id) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = stateOf(banner.id);
    _showState[banner.id] = current.copyWith(
      showCounter: current.showCounter + 1,
      showAt: current.showAt ?? now,
    );
    _lastShownId = banner.id;
    _pinnedId = banner.id;
    await _persistShowState(_accountId);
  }

  // #***! закрыли крестиком, помним до истечения rerun
  Future<void> close(InformerBanner banner) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _showState[banner.id] = stateOf(banner.id).copyWith(closedAt: now);
    if (_pinnedId == banner.id) _pinnedId = null;
    await _persistShowState(_accountId);
    _recompute();
  }

  Future<void> markClicked(InformerBanner banner) async {
    if (!banner.closesOnClick) return;
    await close(banner);
  }

  void refresh() {
    _pinnedId = null;
    _recompute();
  }

  void clear() {
    _accountId = null;
    _enabled = true;
    _updateTime = 0;
    _showTime = _defaultShowTime;
    _banners = const [];
    _showState.clear();
    _lastShownId = null;
    _pinnedId = null;
    activeBanner.value = null;
  }

  // #***! полная синхра, ошибку глотаем баннер того не стоит
  Future<void> _sync() async {
    final accountId = _accountId;
    if (accountId == null || !_enabled) return;
    try {
      final packet = await _api.sendRequest(Opcode.bannersSync, {
        'bannersSync': 0,
      });
      throwIfPacketError(packet);
      final payload = packet.payload;
      if (payload is Map) {
        await applyPayload(accountId, payload.cast<dynamic, dynamic>());
      }
    } catch (e) {
      logger.w('Баннеры: синхронизация не удалась: $e');
    }
  }

  // #***! пуш или с набором или просто просит перечитать
  void _handlePush(Packet packet) {
    final accountId = _accountId;
    if (accountId == null || !_enabled) return;
    final payload = packet.payload;
    if (payload is Map && payload['banners'] is List) {
      unawaited(applyPayload(accountId, payload.cast<dynamic, dynamic>()));
      return;
    }
    unawaited(syncFromServer());
  }

  // #***! выбираем активный, закреплённый или самый приоритетный
  void _recompute() {
    if (!_enabled) {
      activeBanner.value = null;
      return;
    }

    final pinned = _pinnedId;
    if (pinned != null) {
      for (final banner in _banners) {
        if (banner.id == pinned) {
          activeBanner.value = banner;
          return;
        }
      }
      _pinnedId = null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    var candidates = _banners.where((b) => _canShow(b, now)).toList();
    // #***! не повторяем тот что показывали в прошлый раз
    if (candidates.length > 1 && _lastShownId != null) {
      final others = candidates.where((b) => b.id != _lastShownId).toList();
      if (others.isNotEmpty) candidates = others;
    }
    if (candidates.isEmpty) {
      activeBanner.value = null;
      return;
    }
    activeBanner.value = candidates.reduce(
      (a, b) => b.priority > a.priority ? b : a,
    );
  }

  // #***! фильтр, лимит показов срок жизни и пауза
  bool _canShow(InformerBanner banner, int now) {
    final state = stateOf(banner.id);
    if (state.showCounter > 0 && state.showCounter >= banner.repeat) {
      return false;
    }
    final showAt = state.showAt;
    if (showAt != null && now - showAt > _showTime) return false;
    final closedAt = state.closedAt;
    if (closedAt != null) {
      if (banner.rerun <= 0) return false;
      if (now - closedAt <= banner.rerun) return false;
    }
    return true;
  }

  // #***! бит в updates значит баннеры изменились
  bool _needsResync(dynamic updates) {
    final mask = _int(updates);
    return mask != null && mask & _resyncMask != 0;
  }

  Future<void> _setEnabled(int accountId, bool value) async {
    _enabled = value;
    await AppDatabase.setSyncValue(accountId, _enabledKey, value ? '1' : '0');
    if (!value) activeBanner.value = null;
  }

  // #***! снимок и показы в sync_state отдельными джейсонами
  Future<void> _restoreSnapshot(int accountId) async {
    _banners = const [];
    _updateTime = 0;
    _showTime = _defaultShowTime;
    final raw = await AppDatabase.getSyncValue(accountId, _snapshotKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['banners'];
      final parsed = <InformerBanner>[];
      if (list is List) {
        for (final entry in list) {
          if (entry is! Map) continue;
          final banner = InformerBanner.fromMap(entry);
          if (banner != null) parsed.add(banner);
        }
      }
      _banners = parsed;
      _updateTime = _int(map['updateTime']) ?? 0;
      final showTime = _int(map['showTime']);
      if (showTime != null && showTime > 0) _showTime = showTime;
    } catch (_) {}
  }

  Future<void> _restoreShowState(int accountId) async {
    _showState.clear();
    _lastShownId = null;
    final raw = await AppDatabase.getSyncValue(accountId, _stateKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _lastShownId = map['lastShowedBannerId']?.toString();
      final entries = map['banners'];
      if (entries is Map) {
        entries.forEach((key, value) {
          if (value is Map) {
            _showState[key.toString()] = BannerShowState.fromJson(value);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _persistSnapshot(int accountId) async {
    await AppDatabase.setSyncValue(
      accountId,
      _snapshotKey,
      jsonEncode({
        'updateTime': _updateTime,
        'showTime': _showTime,
        'banners': _banners.map((b) => b.toJson()).toList(),
      }),
    );
  }

  Future<void> _persistShowState(int? accountId) async {
    if (accountId == null) return;
    await AppDatabase.setSyncValue(
      accountId,
      _stateKey,
      jsonEncode({
        'lastShowedBannerId': _lastShownId,
        'banners': {
          for (final entry in _showState.entries)
            entry.key: entry.value.toJson(),
        },
      }),
    );
  }

  // #***! флаг то булевый то строка то число
  static bool _parseFlag(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'yes' || v == 'on';
    }
    return true;
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
