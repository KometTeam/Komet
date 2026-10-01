import '../core/utils/emoji_keyword_index.dart';

class ChatReactionSettings {
  static const int maxCount = 8;

  final bool isActive;
  final int count;
  final bool included;
  final List<String> reactionIds;

  const ChatReactionSettings({
    required this.isActive,
    required this.count,
    required this.included,
    required this.reactionIds,
  });

  static ChatReactionSettings? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final count = raw['count'];
    final ids = raw['reactionIds'];
    return ChatReactionSettings(
      isActive: raw['isActive'] != false,
      count: count is int ? count.clamp(1, maxCount) : maxCount,
      included: raw['included'] == true,
      reactionIds: ids is List
          ? ids.map((id) => id.toString()).toList(growable: false)
          : const [],
    );
  }

  bool get restricted => included || reactionIds.isNotEmpty;

  bool Function(String emoji) filterFor(Iterable<String> present) {
    if (!isActive) return (_) => false;
    final listed = reactionIds.map(EmojiKeywordIndex.normalize).toSet();
    final onMessage = present.map(EmojiKeywordIndex.normalize).toSet();
    final full = onMessage.length >= count;
    return (emoji) {
      final key = EmojiKeywordIndex.normalize(emoji);
      if (listed.contains(key) != included) return false;
      return !full || onMessage.contains(key);
    };
  }

  static List<String> presentWithoutMine(Object? reactionInfo) {
    if (reactionInfo is! Map) return const [];
    final counters = reactionInfo['counters'];
    if (counters is! List) return const [];
    final mine = reactionInfo['yourReaction']?.toString();
    final mineKey = mine == null ? null : EmojiKeywordIndex.normalize(mine);
    return [
      for (final counter in counters)
        if (counter is Map && counter['reaction'] != null)
          if (EmojiKeywordIndex.normalize(counter['reaction'].toString()) !=
                  mineKey ||
              (counter['count'] is int && (counter['count'] as int) > 1))
            counter['reaction'].toString(),
    ];
  }

  bool allows(String emoji) => filterFor(const [])(emoji);

  bool allowsOn(String emoji, Iterable<String> present) =>
      filterFor(present)(emoji);

  Set<String> allowedOf(Iterable<String> catalog) {
    final listed = reactionIds.map(EmojiKeywordIndex.normalize).toSet();
    return {
      for (final emoji in catalog)
        if (listed.contains(EmojiKeywordIndex.normalize(emoji)) == included)
          emoji,
    };
  }

  static List<String> forbiddenOf(
    Iterable<String> catalog,
    Set<String> allowed,
  ) => [
    for (final emoji in catalog)
      if (!allowed.contains(emoji)) emoji,
  ];
}
