import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart' show KometApp;

enum UploadKind { photo, video, file }

class _NotificationJob {
  _NotificationJob({required this.kind, required this.count, this.filename});

  final UploadKind kind;
  final int count;
  final String? filename;

  int sent = 0;
  int total = 0;
  double fraction = 0;
  int speedBps = 0;

  int _windowSent = 0;
  int _windowAt = DateTime.now().millisecondsSinceEpoch;

  void report(int sentBytes, int totalBytes, double jobFraction) {
    sent = sentBytes;
    total = totalBytes;
    fraction = jobFraction.clamp(0.0, 1.0);

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _windowAt;
    if (elapsed < 500) return;
    final delta = sent - _windowSent;
    speedBps = delta <= 0 ? 0 : (delta * 1000 / elapsed).round();
    _windowSent = sent;
    _windowAt = now;
  }

  String label(AppLocalizations l10n) {
    final name = filename;
    return switch (kind) {
      UploadKind.photo => l10n.uploadNotificationPhotos(count),
      UploadKind.video => l10n.uploadNotificationVideo,
      UploadKind.file =>
        name == null || name.isEmpty ? l10n.uploadNotificationFile : name,
    };
  }
}

class UploadNotificationService {
  static const MethodChannel _channel = MethodChannel(
    'ru.komet.app/upload_service',
  );
  static const int _minIntervalMs = 350;

  static final Map<String, _NotificationJob> _jobs = {};
  static bool _running = false;
  static String? _lastTitle;
  static String? _lastBody;
  static int _lastPercent = -1;
  static int _lastPushAt = 0;

  static bool get _enabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void begin(
    String id, {
    required UploadKind kind,
    int count = 1,
    String? filename,
  }) {
    if (!_enabled) return;
    _jobs[id] = _NotificationJob(
      kind: kind,
      count: count < 1 ? 1 : count,
      filename: filename,
    );
    _push(force: true);
  }

  static void report(
    String id, {
    required int sent,
    required int total,
    required double fraction,
  }) {
    if (!_enabled) return;
    final job = _jobs[id];
    if (job == null) return;
    job.report(sent, total, fraction);
    _push();
  }

  static void end(String id) {
    if (!_enabled) return;
    if (_jobs.remove(id) == null) return;
    if (_jobs.isEmpty) {
      _stop();
      return;
    }
    _push(force: true);
  }

  static void _stop() {
    _running = false;
    _lastTitle = null;
    _lastBody = null;
    _lastPercent = -1;
    _lastPushAt = 0;
    _invoke('stop', const <String, dynamic>{});
  }

  static void _push({bool force = false}) {
    if (_jobs.isEmpty) return;

    var sumSent = 0;
    var sumTotal = 0;
    var sumSpeed = 0;
    var fractionSum = 0.0;
    var sizesKnown = true;
    for (final job in _jobs.values) {
      sumSent += job.sent;
      sumTotal += job.total;
      sumSpeed += job.speedBps;
      fractionSum += job.fraction;
      if (job.total <= 0) sizesKnown = false;
    }

    final fraction = sizesKnown && sumTotal > 0
        ? sumSent / sumTotal
        : fractionSum / _jobs.length;
    final percent = (fraction * 100).round().clamp(0, 100);

    final l10n = _localizations();
    final title = _jobs.length == 1
        ? _jobs.values.first.label(l10n)
        : l10n.uploadNotificationMultiple(_jobs.length);
    final body = percent <= 0 && sumSpeed <= 0
        ? l10n.uploadNotificationPreparing
        : sumSpeed > 0
        ? '$percent% · ${_formatSpeed(l10n, sumSpeed)}'
        : '$percent%';

    final now = DateTime.now().millisecondsSinceEpoch;
    final changed =
        title != _lastTitle || body != _lastBody || percent != _lastPercent;
    if (!force && (!changed || now - _lastPushAt < _minIntervalMs)) return;

    _lastTitle = title;
    _lastBody = body;
    _lastPercent = percent;
    _lastPushAt = now;

    final args = <String, dynamic>{
      'title': title,
      'body': body,
      'progress': percent,
      'indeterminate': percent <= 0 && sumSpeed <= 0,
    };
    if (_running) {
      _invoke('update', args);
      return;
    }
    _running = true;
    _invoke('start', args);
  }

  static String _formatSpeed(AppLocalizations l10n, int bps) {
    if (bps < 1024) return l10n.uploadSpeedBytes('$bps');
    if (bps < 1024 * 1024) return l10n.uploadSpeedKb('${(bps / 1024).round()}');
    return l10n.uploadSpeedMb((bps / (1024 * 1024)).toStringAsFixed(1));
  }

  static AppLocalizations _localizations() {
    final context = KometApp.navigatorKey.currentContext;
    if (context != null) {
      final scoped = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      if (scoped != null) return scoped;
    }
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return lookupAppLocalizations(Locale(code == 'ru' ? 'ru' : 'en'));
  }

  static Future<void> _invoke(String method, Map<String, dynamic> args) async {
    try {
      await _channel.invokeMethod(method, args);
    } catch (_) {}
  }
}
