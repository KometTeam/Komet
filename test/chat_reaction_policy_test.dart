import 'package:flutter_test/flutter_test.dart';
import 'package:komet/models/chat_reaction_settings.dart';

ChatReactionSettings _settings({
  bool active = true,
  int count = 8,
  bool included = false,
  List<String> ids = const [],
}) => ChatReactionSettings(
  isActive: active,
  count: count,
  included: included,
  reactionIds: ids,
);

void main() {
  test('nothing is allowed while reactions are off', () {
    expect(_settings(active: false).allows('👍'), isFalse);
  });

  test('forbidden reactions are refused, others pass', () {
    final settings = _settings(ids: ['😴', '⚡']);

    expect(settings.allows('😴'), isFalse);
    expect(settings.allows('⚡️'), isFalse);
    expect(settings.allows('👍'), isTrue);
  });

  test('an allow list only lets its own reactions through', () {
    final settings = _settings(included: true, ids: ['👍']);

    expect(settings.allows('👍'), isTrue);
    expect(settings.allows('❤️'), isFalse);
  });

  test('a full message only takes reactions it already has', () {
    final settings = _settings(count: 2);

    expect(settings.allowsOn('🔥', ['👍', '❤️']), isFalse);
    expect(settings.allowsOn('❤', ['👍', '❤️']), isTrue);
    expect(settings.allowsOn('🔥', ['👍']), isTrue);
  });

  test('switching my own reaction does not count it as taken', () {
    final settings = _settings(count: 2);
    final info = {
      'yourReaction': '👍',
      'counters': [
        {'reaction': '👍', 'count': 1},
        {'reaction': '❤️', 'count': 3},
      ],
    };

    final present = ChatReactionSettings.presentWithoutMine(info);

    expect(present, ['❤️']);
    expect(settings.allowsOn('🔥', present), isTrue);
  });

  test('a reaction others also chose still counts', () {
    final present = ChatReactionSettings.presentWithoutMine({
      'yourReaction': '👍',
      'counters': [
        {'reaction': '👍', 'count': 2},
        {'reaction': '❤️', 'count': 1},
      ],
    });

    expect(present, ['👍', '❤️']);
    expect(_settings(count: 2).allowsOn('🔥', present), isFalse);
  });

  test('a disabled filter refuses everything', () {
    final allows = _settings(active: false).filterFor(const []);

    expect(allows('👍'), isFalse);
  });
}
