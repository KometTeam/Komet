import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/build_profile.dart';
import 'package:komet/core/config/update_config.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('${platform.name} keeps the update check outside store builds', () {
      debugDefaultTargetPlatformOverride = platform;
      expect(BuildProfile.selfUpdate, !BuildProfile.isStore);
      expect(UpdateConfig.isConfigured, UpdateConfig.baseUrl.trim().isNotEmpty);
    });
  }
}
