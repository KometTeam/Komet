import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/build_profile.dart';
import 'package:komet/core/config/ios_release.dart';

void main() {
  test('tests run without the App Store build flag', () {
    expect(BuildProfile.isAppStoreBuild, isFalse);
  });

  test('gates match the pure helpers for this build', () {
    const store = BuildProfile.isStore;
    const appStore = BuildProfile.isAppStoreBuild;
    final ios = IosRelease.isIOS;
    final macos = IosRelease.isMacOS;
    expect(
      BuildProfile.plugins,
      BuildProfile.pluginsFor(appStoreBuild: appStore),
    );
    expect(
      BuildProfile.selfUpdate,
      BuildProfile.selfUpdateFor(
        store: store,
        appStoreBuild: appStore,
        ios: ios,
        macos: macos,
      ),
    );
    expect(
      BuildProfile.spoofUi,
      BuildProfile.spoofUiFor(store: store, appStoreBuild: appStore),
    );
  });

  group('plugins', () {
    test('stay without the flag', () {
      expect(BuildProfile.pluginsFor(appStoreBuild: false), isTrue);
    });

    test('are left out of App Store builds', () {
      expect(BuildProfile.pluginsFor(appStoreBuild: true), isFalse);
    });
  });

  group('update check', () {
    final gate = BuildProfile.selfUpdateFor;

    test('stays in regular Android builds without the flag', () {
      expect(
        gate(store: false, appStoreBuild: false, ios: false, macos: false),
        isTrue,
      );
    });

    test('is off in App Store builds', () {
      expect(
        gate(store: false, appStoreBuild: true, ios: false, macos: false),
        isFalse,
      );
    });

    test('is off in the store flavor', () {
      expect(
        gate(store: true, appStoreBuild: false, ios: false, macos: false),
        isFalse,
      );
      expect(
        gate(store: true, appStoreBuild: true, ios: false, macos: false),
        isFalse,
      );
    });

    test('is off on iOS in both build types', () {
      expect(
        gate(store: false, appStoreBuild: false, ios: true, macos: false),
        isFalse,
      );
      expect(
        gate(store: false, appStoreBuild: true, ios: true, macos: false),
        isFalse,
      );
    });

    test('is off on macOS in both build types', () {
      expect(
        gate(store: false, appStoreBuild: false, ios: false, macos: true),
        isFalse,
      );
      expect(
        gate(store: false, appStoreBuild: true, ios: false, macos: true),
        isFalse,
      );
    });
  });

  group('spoofing screen', () {
    final gate = BuildProfile.spoofUiFor;

    test('stays in regular builds without the flag', () {
      expect(gate(store: false, appStoreBuild: false), isTrue);
    });

    test('is off in App Store builds', () {
      expect(gate(store: false, appStoreBuild: true), isFalse);
    });

    test('is off in the store flavor', () {
      expect(gate(store: true, appStoreBuild: false), isFalse);
      expect(gate(store: true, appStoreBuild: true), isFalse);
    });
  });
}
