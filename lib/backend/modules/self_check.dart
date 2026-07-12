import 'dart:async';

import '../../core/cache/info_cache.dart';
import '../../core/cache/self_presence.dart';
import '../../core/config/komet_settings.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import '../api.dart';

class SelfCheckService {
  SelfCheckService._();

  static final SelfCheckService instance = SelfCheckService._();

  static const Duration interval = Duration(seconds: 10);

  Api? _api;
  Timer? _timer;

  void init(Api api) {
    if (_api != null) return;
    _api = api;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(_check()));
  }

  void checkNow() => unawaited(_check());

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_api == null || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_check()));
    checkNow();
  }

  Future<void> _check() async {
    final api = _api;
    if (api == null || api.state != SessionState.online) return;
    if (!KometSettings.selfOnlineCheck.value) return;
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;
    final presence = await PresenceFetch.get(accountId, forceRefresh: true);
    logger.i('[SELF CHECK] id=$accountId presence=$presence');
    if (presence == null) return;
    SelfPresence.applySelfCheck(
      online: presence['status'] == 1,
      seenSeconds: presence['seen'] is int ? presence['seen'] as int : null,
    );
  }
}
