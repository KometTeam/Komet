import 'package:gwid/models/chat.dart';
import 'package:gwid/models/contact.dart';

class SearchResult {
  final Chat chat;
  final Contact? contact;
  final String matchedText;
  final String matchType;
  final int? messageIndex;

  SearchResult({
    required this.chat,
    this.contact,
    required this.matchedText,
    required this.matchType,
    this.messageIndex,
  });
}
