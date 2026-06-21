import '../../backend/modules/messages.dart';

class CommandContext {
  final int accountId;
  final int chatId;
  final int? otherUserId;
  final MessagesModule messages;
  final bool Function() isOnline;
  final bool Function() isActive;
  final void Function(String message) notify;
  final Future<String> Function(String text) postMessage;
  final Future<void> Function(String id, String text) updateMessage;

  const CommandContext({
    required this.accountId,
    required this.chatId,
    required this.otherUserId,
    required this.messages,
    required this.isOnline,
    required this.isActive,
    required this.notify,
    required this.postMessage,
    required this.updateMessage,
  });
}

typedef CommandRunner = Future<void> Function(CommandContext ctx);

class SlashCommand {
  final String name;
  final String description;
  final CommandRunner? run;
  final bool hidden;

  const SlashCommand(
    this.name,
    this.description, {
    this.run,
    this.hidden = false,
  });
}
