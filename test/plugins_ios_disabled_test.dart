import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/ios_release.dart';
import 'package:komet/frontend/commands/commands.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('plugins are available on Android but not on iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(IosRelease.plugins, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(IosRelease.plugins, isFalse);
  });

  test('iOS registry keeps only built-in commands', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    CommandRegistry.instance.initialize();
    final names = CommandRegistry.instance.commands.value
        .map((c) => c.name)
        .toList();
    expect(names, ['/shrug']);
    expect(
      CommandRegistry.instance.commands.value.any(
        (c) => c.pluginCommand != null,
      ),
      isFalse,
    );
  });
}
