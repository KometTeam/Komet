import 'package:flutter/foundation.dart';
import 'package:kolibri/kolibri.dart' show setDnsCachePath;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../storage/app_instance.dart';
import '../utils/logger.dart';
import 'tls_config.dart';

abstract final class NetworkCore {
  static Future<void> configure() async {
    await TlsConfig.applyMincifryTrust();
    await _keepWorkingAddresses();
  }

  static Future<void> _keepWorkingAddresses() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationSupportDirectory();
      setDnsCachePath(
        path: p.join(dir.path, 'kolibri_dns${AppInstance.suffix}.cache'),
      );
    } catch (e) {
      logger.w('[net] адреса серверов не переживут перезапуск: $e');
    }
  }
}
