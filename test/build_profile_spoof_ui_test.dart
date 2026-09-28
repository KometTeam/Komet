import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/build_profile.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS hides the device spoofing settings', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(BuildProfile.spoofUi, isFalse);
  });

  test('Android keeps the device spoofing settings outside store builds', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(BuildProfile.spoofUi, !BuildProfile.isStore);
  });
}
