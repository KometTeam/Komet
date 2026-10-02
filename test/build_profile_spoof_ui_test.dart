import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/build_profile.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('${platform.name} keeps the device spoofing settings outside store '
        'builds', () {
      debugDefaultTargetPlatformOverride = platform;
      expect(BuildProfile.spoofUi, !BuildProfile.isStore);
    });
  }
}
