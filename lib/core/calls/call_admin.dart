import 'ws2_signaling.dart';

enum CallMedia {
  audio('AUDIO'),
  video('VIDEO'),
  screenShare('SCREEN_SHARING'),
  movieShare('MOVIE_SHARING');

  const CallMedia(this.wire);
  final String wire;
}

enum CallMuteState {
  unmute('UNMUTE'),
  mute('MUTE'),
  mutePermanent('MUTE_PERMANENT');

  const CallMuteState(this.wire);
  final String wire;
}

enum CallRoleName {
  creator('CREATOR'),
  admin('ADMIN'),
  speaker('SPEAKER');

  const CallRoleName(this.wire);
  final String wire;
}

enum CallOption {
  requireAuthToJoin('REQUIRE_AUTH_TO_JOIN'),
  waitingHall('WAITING_HALL'),
  recurring('RECURRING'),
  feedback('FEEDBACK'),
  audienceMode('AUDIENCE_MODE'),
  asr('ASR'),
  waitForAdmin('WAIT_FOR_ADMIN'),
  adminIsHere('ADMIN_IS_HERE');

  const CallOption(this.wire);
  final String wire;
}

enum CallFeature {
  addParticipant('ADD_PARTICIPANT'),
  admin('ADMIN'),
  asr('ASR'),
  movieShare('MOVIE_SHARE'),
  record('RECORD'),
  speaker('SPEAKER');

  const CallFeature(this.wire);
  final String wire;
}

enum CallListType {
  grid('GRID'),
  side('SIDE');

  const CallListType(this.wire);
  final String wire;
}

class CallParticipantRef {
  final int id;
  final int deviceIdx;
  final bool isGroup;

  const CallParticipantRef(this.id, {this.deviceIdx = 0, this.isGroup = false});

  String get wire => '${isGroup ? 'g' : 'u'}$id:d$deviceIdx';
}

class CallAdmin {
  final Ws2Signaling _signaling;

  const CallAdmin(this._signaling);

  Future<void> requestMedia(
    Set<CallMedia> media, {
    CallParticipantRef? participant,
    String? roomId,
  }) {
    return _signaling.sendCommand(
      'mute-participant',
      extra: {
        'participantId': ?participant?.wire,
        'requestedMedia': media.map((m) => m.wire).toList(),
        'roomId': ?roomId,
      },
    );
  }

  Future<void> setMuteStates(
    Map<CallMedia, CallMuteState?> states, {
    CallParticipantRef? participant,
    String? roomId,
  }) {
    return _signaling.sendCommand(
      'mute-participant',
      extra: {
        'participantId': ?participant?.wire,
        'muteStates': {
          for (final media in CallMedia.values) media.wire: states[media]?.wire,
        },
        'roomId': ?roomId,
      },
    );
  }

  Future<void> muteMicrophone(
    CallParticipantRef participant, {
    bool muted = true,
  }) {
    return _signaling.sendCommand(
      'switch-micro',
      extra: {'eId': participant.wire, 'muteTarget': muted},
    );
  }

  Future<void> muteEveryone() {
    return _signaling.sendCommand(
      'switch-micro',
      extra: const {'all': true, 'muteTarget': true},
    );
  }

  Future<void> setPromoted(CallParticipantRef participant, bool promoted) {
    return _signaling.sendCommand(
      'promote-participant',
      extra: {'participantId': participant.wire, 'demote': !promoted},
    );
  }

  Future<void> setRoles(
    CallParticipantRef participant,
    List<CallRoleName> roles, {
    bool revoke = false,
  }) {
    return _signaling.sendCommand(
      'grant-roles',
      extra: {
        'participantId': participant.wire,
        'roles': roles.map((r) => r.wire).toList(),
        'revoke': revoke,
      },
    );
  }

  Future<void> removeParticipant(CallParticipantRef participant) {
    return _signaling.sendCommand(
      'remove-participant',
      extra: {'participantId': participant.wire},
    );
  }

  Future<void> setPinned(
    CallParticipantRef participant,
    bool pinned, {
    String? roomId,
  }) {
    return _signaling.sendCommand(
      'pin-participant',
      extra: {
        'participantId': participant.wire,
        'unpin': !pinned,
        'roomId': ?roomId,
      },
    );
  }

  Future<void> setOptions(Map<CallOption, bool> options) {
    return _signaling.sendCommand(
      'change-options',
      extra: {
        'options': {
          for (final entry in options.entries) entry.key.wire: entry.value,
        },
      },
    );
  }

  Future<void> enableFeatureForRoles(
    CallFeature feature,
    List<CallRoleName> roles,
  ) {
    return _signaling.sendCommand(
      'enable-feature-for-roles',
      extra: {
        'feature': feature.wire,
        'roles': roles.map((r) => r.wire).toList(),
      },
    );
  }

  Future<void> lowerAllHands() => _signaling.sendCommand('put-hands-down');

  Future<void> setHandRaised(bool raised, {CallParticipantRef? participant}) {
    return _setState({'hand': raised ? '1' : '0'}, participant: participant);
  }

  Future<void> setAssistanceRequested(
    bool requested, {
    CallParticipantRef? participant,
  }) {
    return _setState({'drat': requested ? '1' : '0'}, participant: participant);
  }

  Future<void> _setState(
    Map<String, String> state, {
    CallParticipantRef? participant,
  }) {
    return _signaling.sendCommand(
      'change-participant-state',
      extra: {
        'participantState': {'state': state},
        'participantId': ?participant?.wire,
      },
    );
  }

  Future<void> addParticipants(
    List<String> externalIds, {
    bool? unban,
    bool showChatHistory = false,
  }) {
    return _signaling.sendCommand(
      'add-participant',
      extra: {
        'externalIds': externalIds,
        if (unban == true) 'unban': true,
        if (showChatHistory) 'payload': '{"show_chat_history":true}',
      },
    );
  }

  Future<void> addParticipantByLink(String link) {
    return _signaling.sendCommand(
      'add-participant',
      extra: {'participantIdAsQRCodeLink': link},
    );
  }

  Future<Map<String, dynamic>> startRecord({
    int? movieId,
    String? name,
    String? description,
    String? privacy,
    int? groupId,
    String? albumId,
    bool streamMovie = false,
    String? roomId,
  }) {
    return _signaling.sendCommand(
      'record-start',
      extra: {
        'movieId': movieId,
        'name': name,
        'description': description,
        'privacy': privacy,
        'groupId': groupId,
        'albumId': albumId,
        'streamMovie': streamMovie,
        'roomId': ?roomId,
      },
    );
  }

  Future<void> stopRecord({bool remove = false, String? roomId}) {
    return _signaling.sendCommand(
      'record-stop',
      extra: {if (remove) 'remove': true, 'roomId': ?roomId},
    );
  }

  Future<Map<String, dynamic>> participantChunk({
    int count = 50,
    CallListType listType = CallListType.grid,
    String? roomId,
  }) {
    return _signaling.sendCommand(
      'get-participant-list-chunk',
      extra: {'count': count, 'listType': listType.wire, 'roomId': ?roomId},
    );
  }

  Future<Map<String, dynamic>> waitingHall({
    int count = 50,
    String? fromId,
    bool backward = false,
  }) {
    return _signaling.sendCommand(
      'get-waiting-hall',
      extra: {'count': count, 'fromId': ?fromId, 'backward': backward},
    );
  }
}
