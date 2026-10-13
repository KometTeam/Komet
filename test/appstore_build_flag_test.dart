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
    expect(
      BuildProfile.isStoreRelease,
      BuildProfile.storeReleaseFor(store: store, appStoreBuild: appStore),
    );
  });

  test('features store rules forbid follow the store release flag', () {
    const release = BuildProfile.isStoreRelease;
    expect(BuildProfile.devTools, !release);
    expect(BuildProfile.insecureTransport, !release);
    expect(BuildProfile.trafficCapture, !release);
    expect(BuildProfile.pranks, !release);
    expect(BuildProfile.hiddenContentViewers, !release);
    expect(BuildProfile.digitalId, !release);
    expect(BuildProfile.ipGeoLookup, !release);
    expect(BuildProfile.sessionCityLookup, !release);
  });

  test('presence tweaks and the log link follow the App Store flag', () {
    expect(BuildProfile.stealthPresence, !BuildProfile.isAppStoreBuild);
    expect(BuildProfile.logExportLink, !BuildProfile.isAppStoreBuild);
  });

  group('store release', () {
    test('is off only outside both stores', () {
      expect(
        BuildProfile.storeReleaseFor(store: false, appStoreBuild: false),
        isFalse,
      );
    });

    test('covers the Play flavor and the App Store build', () {
      expect(
        BuildProfile.storeReleaseFor(store: true, appStoreBuild: false),
        isTrue,
      );
      expect(
        BuildProfile.storeReleaseFor(store: false, appStoreBuild: true),
        isTrue,
      );
    });
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
