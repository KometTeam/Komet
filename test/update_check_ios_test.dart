import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/build_profile.dart';
import 'package:komet/core/config/update_config.dart';
import 'package:komet/core/utils/update_checker.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS has no update check', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(BuildProfile.selfUpdate, isFalse);
    expect(UpdateConfig.isConfigured, isFalse);
    expect(await UpdateChecker.fetchLatest(), isNull);
    final result = await UpdateChecker.checkNow();
    expect(result.status, UpdateCheckStatus.failed);
  });

  test('Android keeps the update check outside store builds', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(BuildProfile.selfUpdate, !BuildProfile.isStore);
    expect(UpdateConfig.isConfigured, UpdateConfig.baseUrl.trim().isNotEmpty);
  });
}
