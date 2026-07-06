class DebugTest {
  static bool enabled = false;
  static int contactCount = 0;

  static const int debugAccountId = -424242;

  static const bool _envEnabled = bool.fromEnvironment('DEBUG_TEST');
  static const int _envContacts = int.fromEnvironment(
    'DEBUG_CONTACTS',
    defaultValue: -1,
  );

  static const String _flag = '--debug-test';
  static const String _contactsFlag = '--contacts';

  static void parse(List<String> args) {
    if (_envEnabled) enabled = true;
    if (_envContacts >= 0) {
      enabled = true;
      contactCount = _envContacts;
    }

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == _flag) {
        enabled = true;
      } else if (arg.startsWith('$_contactsFlag=')) {
        enabled = true;
        contactCount =
            int.tryParse(arg.substring(_contactsFlag.length + 1)) ??
            contactCount;
      } else if (arg == _contactsFlag && i + 1 < args.length) {
        enabled = true;
        contactCount = int.tryParse(args[i + 1]) ?? contactCount;
        i++;
      }
    }
  }
}
