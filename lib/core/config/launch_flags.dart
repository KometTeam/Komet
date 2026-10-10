import 'package:flutter/foundation.dart';

abstract final class LaunchFlags {
  static const String debugFlag = '--debug';
  static const String loginPayloadFlag = '--dw19p-im-crazy';
  static const String debugTestFlag = '--debug-test';
  static const String contactsFlag = '--contacts';
  static const String berserkFlag = '--berserk';
  static const String noMuteFlag = '--no-mute';

  static const bool _envDebug = bool.fromEnvironment('KOMET_DEBUG');
  static const bool _envLoginPayload = bool.fromEnvironment(
    'KOMET_DW19P_IM_CRAZY',
  );
  static const bool _envDebugTest = bool.fromEnvironment('DEBUG_TEST');
  static const int _envContacts = int.fromEnvironment(
    'DEBUG_CONTACTS',
    defaultValue: -1,
  );
  static const bool _envBerserk = bool.fromEnvironment('BERSERK');
  static const bool _envNoMute = bool.fromEnvironment('NO_MUTE');

  static const String logLevel = String.fromEnvironment('KOMET_LOG_LEVEL');
  static const String instance = String.fromEnvironment('KOMET_INSTANCE');
  static const String updateBaseUrl = String.fromEnvironment(
    'KOMET_UPDATE_BASE_URL',
    defaultValue: 'https://cdn.komet.pw',
  );
  static const String reviewPhone = String.fromEnvironment(
    'KOMET_REVIEW_PHONE',
  );
  static const String reviewPayload = String.fromEnvironment(
    'KOMET_REVIEW_PAYLOAD',
  );
  static const bool appStoreBuild = bool.fromEnvironment('is_appstore_build');

  static const int debugTestAccountId = -424242;

  static bool debug = _envDebug || _envLoginPayload;
  static bool revealLoginPayload = _envLoginPayload;
  static bool debugTest = _envDebugTest || _envContacts >= 0;
  static int contactCount = _envContacts >= 0 ? _envContacts : 0;
  static bool berserk = _envBerserk;
  static bool noMute = _envNoMute;
  static List<String> unknown = const [];

  static void parse(List<String> args) {
    final unknownArgs = <String>[];
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
        case debugFlag:
          debug = true;
        case loginPayloadFlag:
          debug = true;
          revealLoginPayload = true;
        case debugTestFlag:
          debugTest = true;
        case berserkFlag:
          berserk = true;
        case noMuteFlag:
          noMute = true;
        case contactsFlag when i + 1 < args.length:
          _setContacts(args[++i]);
        case _ when arg.startsWith('$contactsFlag='):
          _setContacts(arg.substring(contactsFlag.length + 1));
        default:
          unknownArgs.add(arg);
      }
    }
    unknown = List.unmodifiable(unknownArgs);
  }

  static void _setContacts(String raw) {
    debugTest = true;
    contactCount = int.tryParse(raw) ?? contactCount;
  }

  static String get activeDebugFlag =>
      revealLoginPayload ? loginPayloadFlag : debugFlag;

  static List<String> get summary => [
    if (debug) activeDebugFlag,
    if (debugTest) debugTestFlag,
    if (debugTest && contactCount > 0) '$contactsFlag=$contactCount',
    if (berserk) berserkFlag,
    if (noMute) noMuteFlag,
    if (logLevel.isNotEmpty) 'KOMET_LOG_LEVEL=$logLevel',
    if (instance.isNotEmpty) 'KOMET_INSTANCE=$instance',
    if (reviewPhone.isNotEmpty || reviewPayload.isNotEmpty) 'KOMET_REVIEW_*',
    if (appStoreBuild) 'is_appstore_build',
  ];

  @visibleForTesting
  static void reset() {
    debug = _envDebug || _envLoginPayload;
    revealLoginPayload = _envLoginPayload;
    debugTest = _envDebugTest || _envContacts >= 0;
    contactCount = _envContacts >= 0 ? _envContacts : 0;
    berserk = _envBerserk;
    noMute = _envNoMute;
    unknown = const [];
  }
}
