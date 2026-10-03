import 'chat_info.dart';

enum ChatRestriction {
  forwardDisabled('DISABLE_FORWARD'),
  copyDisabled('MESSAGE_COPY_NOT_ALLOWED'),
  confirmBeforeSend('CONFIRM_BEFORE_SEND');

  const ChatRestriction(this.option);

  final String option;

  bool enabledIn(ChatInfo info) => info.option(option);

  Map<String, bool> optionFor(bool enabled) => {option: enabled};
}
