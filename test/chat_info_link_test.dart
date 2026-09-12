import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chat_parsing.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/models/chat_info.dart';

void main() {
  const myId = 7;

  ChatInfo channel({
    required String access,
    Map<String, dynamic> admins = const {},
    Map<String, dynamic> options = const {},
  }) {
    return ChatInfo.fromMap({
      'id': -100,
      'type': 'CHANNEL',
      'owner': 0,
      'participants': {'$myId': 1},
      'adminParticipants': admins,
      'link': 'https://example.test/synthetic_channel',
      'access': access,
      'options': options,
    });
  }

  group('ChatInfo.canSeeLink', () {
    test('shows the public link to a plain subscriber', () {
      final info = channel(access: 'PUBLIC');

      expect(info.isPublic, isTrue);
      expect(info.canSeeInviteLink(myId), isFalse);
      expect(info.canSeeLink(myId), isTrue);
    });

    test('hides the private invite link from a plain subscriber', () {
      final info = channel(access: 'PRIVATE');

      expect(info.isPublic, isFalse);
      expect(info.canSeeLink(myId), isFalse);
    });

    test('shows the private invite link to an admin', () {
      final info = channel(
        access: 'PRIVATE',
        admins: {
          '$myId': {'permissions': 0},
        },
      );

      expect(info.canSeeLink(myId), isTrue);
    });

    test('shows the private invite link when members may see it', () {
      final info = channel(
        access: 'PRIVATE',
        options: {'MEMBERS_CAN_SEE_PRIVATE_LINK': true},
      );

      expect(info.canSeeLink(myId), isTrue);
    });
  });

  group('CachedChat.publicLink', () {
    CachedChat parse(Map<String, dynamic> chat, {CachedChat? previous}) =>
        parseChatRow(
          chat,
          myId,
          myId,
          const {},
          const {},
          const {},
          previous == null ? const {} : {previous.id: previous},
          0,
        )!;

    Map<String, dynamic> channelPayload({String? access}) => {
      'id': -100,
      'type': 'CHANNEL',
      'title': 'Synthetic channel',
      'participants': {'$myId': 1},
      'link': 'https://example.test/synthetic_channel',
      'access': ?access,
    };

    test('keeps the link of a public chat', () {
      expect(
        parse(channelPayload(access: 'PUBLIC')).publicLink,
        'https://example.test/synthetic_channel',
      );
    });

    test('never treats a private invite link as public', () {
      expect(parse(channelPayload(access: 'PRIVATE')).publicLink, isNull);
    });

    test('keeps the known link when the payload says nothing', () {
      final previous = parse(channelPayload(access: 'PUBLIC'));

      expect(
        parse(channelPayload(), previous: previous).publicLink,
        'https://example.test/synthetic_channel',
      );
    });
  });
}
