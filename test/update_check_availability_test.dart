import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/build_profile.dart';
import 'package:komet/core/config/update_config.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('android keeps the update check outside store builds', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(BuildProfile.selfUpdate, !BuildProfile.isStore);
    expect(UpdateConfig.isConfigured, UpdateConfig.baseUrl.trim().isNotEmpty);
  });

  test('ios leaves out the update check without the store flavor', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(BuildProfile.selfUpdate, isFalse);
    expect(BuildProfile.isStore, isFalse);
    expect(BuildProfile.isAppStoreBuild, isFalse);
    expect(UpdateConfig.isConfigured, UpdateConfig.baseUrl.trim().isNotEmpty);
  });
}
