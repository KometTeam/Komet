import '../../backend/modules/messages.dart';

const String kAntiFloodNotification =
    'Упс! МАХ сбросил соединение, кажется, тебе стоит немного помедлить с командами.';
const Duration _antiFloodNotificationDuration = Duration(seconds: 3);

class CommandContext {
  final int accountId;
  final int chatId;
  final int? otherUserId;
  final String args;
  final MessagesModule messages;
  final bool Function() isOnline;
  final bool Function() isActive;
  final void Function(String message, {Duration? duration}) notify;
  final Future<String> Function(String text) postMessage;
  final Future<void> Function(String id, String text) updateMessage;

  const CommandContext({
    required this.accountId,
    required this.chatId,
    required this.otherUserId,
    required this.args,
    required this.messages,
    required this.isOnline,
    required this.isActive,
    required this.notify,
    required this.postMessage,
    required this.updateMessage,
  });

  void notifyAntiFlood() =>
      notify(kAntiFloodNotification, duration: _antiFloodNotificationDuration);
}

Future<bool> playFrames(
  CommandContext ctx,
  String id,
  List<String> frames,
  Duration delay, {
  int from = 1,
}) async {
  for (var i = from; i < frames.length; i++) {
    await Future.delayed(delay);
    if (!ctx.isActive()) return false;
    if (!ctx.isOnline()) {
      ctx.notifyAntiFlood();
      return false;
    }
    try {
      await ctx.updateMessage(id, frames[i]);
    } catch (_) {
      if (ctx.isActive() && !ctx.isOnline()) ctx.notifyAntiFlood();
      return false;
    }
  }
  return true;
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
