import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/calls/call_permissions.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test('an already granted microphone is not requested again', () async {
    var requests = 0;
    final access = await CallPermissions.ensureMicrophone(
      needsRuntimePermission: true,
      readStatus: () async => PermissionStatus.granted,
      request: () async {
        requests++;
        return PermissionStatus.granted;
      },
    );

    expect(access, CallMicrophoneAccess.granted);
    expect(requests, 0);
  });

  test('a denied microphone is requested before the call starts', () async {
    var requests = 0;
    final access = await CallPermissions.ensureMicrophone(
      needsRuntimePermission: true,
      readStatus: () async => PermissionStatus.denied,
      request: () async {
        requests++;
        return PermissionStatus.granted;
      },
    );

    expect(access, CallMicrophoneAccess.granted);
    expect(requests, 1);
  });

  test('a permanently denied microphone produces a specific failure', () async {
    await expectLater(
      CallPermissions.requireMicrophone(
        needsRuntimePermission: true,
        readStatus: () async => PermissionStatus.permanentlyDenied,
        request: () async => PermissionStatus.permanentlyDenied,
      ),
      throwsA(
        isA<CallMicrophonePermissionException>().having(
          (error) => error.access,
          'access',
          CallMicrophoneAccess.permanentlyDenied,
        ),
      ),
    );
  });

  test(
    'platforms without runtime microphone permissions skip the prompt',
    () async {
      var reads = 0;
      var requests = 0;
      final access = await CallPermissions.ensureMicrophone(
        needsRuntimePermission: false,
        readStatus: () async {
          reads++;
          return PermissionStatus.denied;
        },
        request: () async {
          requests++;
          return PermissionStatus.denied;
        },
      );

      expect(access, CallMicrophoneAccess.granted);
      expect(reads, 0);
      expect(requests, 0);
    },
  );
}
