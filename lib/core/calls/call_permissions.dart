import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum CallMicrophoneAccess { granted, denied, permanentlyDenied }

class CallMicrophonePermissionException implements Exception {
  const CallMicrophonePermissionException(this.access);

  final CallMicrophoneAccess access;

  bool get permanentlyDenied =>
      access == CallMicrophoneAccess.permanentlyDenied;

  @override
  String toString() => 'CallMicrophonePermissionException($access)';
}

typedef CallPermissionStatusReader = Future<PermissionStatus> Function();
typedef CallPermissionRequester = Future<PermissionStatus> Function();

abstract final class CallPermissions {
  static bool get _needsRuntimeMicrophonePermission =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<CallMicrophoneAccess> ensureMicrophone({
    bool? needsRuntimePermission,
    CallPermissionStatusReader? readStatus,
    CallPermissionRequester? request,
  }) async {
    if (!(needsRuntimePermission ?? _needsRuntimeMicrophonePermission)) {
      return CallMicrophoneAccess.granted;
    }

    final current =
        await (readStatus ?? (() => Permission.microphone.status))();
    if (current.isGranted) return CallMicrophoneAccess.granted;
    if (current.isPermanentlyDenied || current.isRestricted) {
      return CallMicrophoneAccess.permanentlyDenied;
    }

    final requested = await (request ?? Permission.microphone.request)();
    if (requested.isGranted) return CallMicrophoneAccess.granted;
    if (requested.isPermanentlyDenied || requested.isRestricted) {
      return CallMicrophoneAccess.permanentlyDenied;
    }
    return CallMicrophoneAccess.denied;
  }

  static Future<void> requireMicrophone({
    bool? needsRuntimePermission,
    CallPermissionStatusReader? readStatus,
    CallPermissionRequester? request,
  }) async {
    final access = await ensureMicrophone(
      needsRuntimePermission: needsRuntimePermission,
      readStatus: readStatus,
      request: request,
    );
    if (access != CallMicrophoneAccess.granted) {
      throw CallMicrophonePermissionException(access);
    }
  }
}
