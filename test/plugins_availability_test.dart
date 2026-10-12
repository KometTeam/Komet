import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/build_profile.dart';
import 'package:komet/frontend/commands/commands.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('plugins are available on Android and sideloaded iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(BuildProfile.plugins, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(BuildProfile.plugins, isTrue);
  });

  test('iOS registry starts with built-in commands', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    CommandRegistry.instance.initialize();
    final names = CommandRegistry.instance.commands.value
        .map((c) => c.name)
        .toList();
    expect(names.first, '/shrug');
  });
}
