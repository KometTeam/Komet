import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/build_profile.dart';

void main() {
  test('tests run without the App Store build flag', () {
    expect(BuildProfile.isAppStoreBuild, isFalse);
  });

  test('const gates match the pure helpers for this build', () {
    const store = BuildProfile.isStore;
    const appStore = BuildProfile.isAppStoreBuild;
    expect(
      BuildProfile.plugins,
      BuildProfile.pluginsFor(appStoreBuild: appStore),
    );
    expect(
      BuildProfile.selfUpdate,
      BuildProfile.selfUpdateFor(store: store, appStoreBuild: appStore),
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

  group('update check and spoofing screen', () {
    final gates = {
      'selfUpdate': BuildProfile.selfUpdateFor,
      'spoofUi': BuildProfile.spoofUiFor,
    };
    for (final entry in gates.entries) {
      final gate = entry.value;
      test('${entry.key} stays in regular builds without the flag', () {
        expect(gate(store: false, appStoreBuild: false), isTrue);
      });

      test('${entry.key} is off in App Store builds', () {
        expect(gate(store: false, appStoreBuild: true), isFalse);
      });

      test('${entry.key} is off in the store flavor', () {
        expect(gate(store: true, appStoreBuild: false), isFalse);
        expect(gate(store: true, appStoreBuild: true), isFalse);
      });
    }
  });
}
