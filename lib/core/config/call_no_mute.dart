class CallNoMute {
  CallNoMute._();

  static const String flag = '--no-mute';

  static bool enabled = const bool.fromEnvironment('NO_MUTE');

  static void parse(List<String> args) {
    if (args.contains(flag)) enabled = true;
  }
}
