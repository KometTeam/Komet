import 'package:gwid/models/message.dart';

abstract class ChatItem {}

class MessageItem extends ChatItem {
  final Message message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isGrouped;

  MessageItem(
    this.message, {
    this.isFirstInGroup = false,
    this.isLastInGroup = false,
    this.isGrouped = false,
  });
}

class DateSeparatorItem extends ChatItem {
  final DateTime date;
  DateSeparatorItem(this.date);
}
