import '../../models/shared_payload.dart';

class ShareInbox {
  ShareInbox({
    required this.consume,
    required this.acknowledge,
    required this.onShare,
    this.release,
  });

  final Future<Object?> Function() consume;
  final Future<void> Function(String id) acknowledge;
  final void Function(SharedPayload payload) onShare;
  final Future<void> Function(String id)? release;

  String? _activeId;
  bool _completed = false;
  bool _acknowledged = false;
  Future<void> Function()? _waitForRelease;
  bool _checkRequested = false;
  Future<void>? _operation;

  Future<void> check() {
    _checkRequested = true;
    return _operation ??= _drain().whenComplete(() => _operation = null);
  }

  Future<void> complete({Future<void> Function()? waitForRelease}) {
    if (_activeId == null) return Future.value();
    _completed = true;
    _waitForRelease ??= waitForRelease;
    return check();
  }

  Future<void> _drain() async {
    while (_checkRequested) {
      _checkRequested = false;
      final activeId = _activeId;
      if (activeId != null) {
        if (!_completed) return;
        if (!_acknowledged) {
          await acknowledge(activeId);
          _acknowledged = true;
        }
        await _waitForRelease?.call();
        await release?.call(activeId);
        _activeId = null;
        _completed = false;
        _acknowledged = false;
        _waitForRelease = null;
      }

      _checkRequested = false;
      final raw = await consume();
      if (raw is! Map) continue;
      final id = raw['id'];
      if (id is! String || id.isEmpty) continue;
      final payload = SharedPayload.fromMap(raw);
      if (payload == null) {
        await acknowledge(id);
        await release?.call(id);
        _checkRequested = true;
        continue;
      }
      _activeId = id;
      onShare(payload);
    }
  }
}
