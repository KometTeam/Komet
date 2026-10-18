import '../../../core/calls/call_info.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/app_localizations.dart';

typedef CallInfoRow = ({String label, String value});

List<CallInfoRow> callParticipantInfo(
  AppLocalizations l10n,
  CallSession session,
  CallParticipant p,
) {
  String clock(int millis) => formatClock(
    DateTime.fromMillisecondsSinceEpoch(millis),
    withSeconds: true,
  );
  String yesNo(bool value) => value ? l10n.callInfoYes : l10n.callInfoNo;

  final audio = p.isSelf ? !session.isMuted : p.audioEnabled;
  final video = p.isSelf ? session.localVideo : p.videoEnabled;
  final screen = p.isSelf ? session.localScreen : p.screenSharing;
  final media = [
    if (audio) l10n.callInfoMediaMic,
    if (video) l10n.callInfoMediaCamera,
    if (screen) l10n.callInfoMediaScreen,
  ];
  final client = p.isSelf ? session.selfClient : null;

  return [
    (
      label: l10n.callInfoAccount,
      value: '${p.externalId ?? l10n.callInfoUnknown}',
    ),
    (label: l10n.callInfoCallId, value: '${p.id}'),
    if (p.deviceIdx > 0)
      (label: l10n.callInfoDeviceIndex, value: '${p.deviceIdx}'),
    (
      label: l10n.callInfoPlatform,
      value: client?.platform ?? p.platform ?? l10n.callInfoUnknown,
    ),
    if ((client?.clientType ?? p.clientType ?? p.externalType) case final type?)
      (label: l10n.callInfoClient, value: type),
    if (p.transport case final transport?)
      (label: l10n.callInfoTransport, value: transport),
    if (!p.isSelf)
      if (_clientGuess(l10n, p) case final guess?)
        (label: l10n.callInfoGuess, value: guess),
    if (client?.device case final device?)
      (label: l10n.callInfoModel, value: device),
    if (client?.os case final os?) (label: l10n.callInfoOs, value: os),
    if (client?.sdk case final sdk?) (label: l10n.callInfoSdk, value: sdk),
    (
      label: l10n.callInfoRole,
      value: p.isCreator
          ? l10n.callInfoRoleCreator
          : p.isAdmin
          ? l10n.callInfoRoleAdmin
          : l10n.callInfoRoleMember,
    ),
    if (p.state.isNotEmpty) (label: l10n.callInfoStatus, value: p.state),
    if (p.joinedAt case final joined?)
      (label: l10n.callInfoJoined, value: clock(joined)),
    (
      label: l10n.callInfoMedia,
      value: media.isEmpty ? l10n.callInfoMediaNone : media.join(', '),
    ),
    if (p.mediaConnected case final connected?)
      (label: l10n.callInfoMediaConnected, value: yesNo(connected)),
    (
      label: l10n.callInfoNetwork,
      value: switch (p.networkRating) {
        final rating? => l10n.callInfoNetworkValue(
          (rating * 100).round(),
          switch (CallParticipant.networkBand(rating)) {
            0 => l10n.callInfoNetworkBad,
            1 => l10n.callInfoNetworkMedium,
            _ => l10n.callInfoNetworkGood,
          },
        ),
        null when session.topology == 'SERVER' => l10n.callInfoNetworkNoIssues,
        null => l10n.callInfoUnknown,
      },
    ),
    if (p.videoStalled)
      (label: l10n.callInfoVideo, value: l10n.callInfoVideoStalled),
    if (p.handRaised && p.handRaisedAt > 0)
      (
        label: l10n.callInfoHand,
        value: l10n.callInfoHandRaisedAt(clock(p.handRaisedAt)),
      ),
  ];
}

String? _clientGuess(AppLocalizations l10n, CallParticipant p) {
  final web = p.platform == 'WEB' || p.transport == 'WEB_TRANSPORT';
  final app = switch (p.platform) {
    'ANDROID' => l10n.callGuessAndroidApp,
    'IOS' => l10n.callGuessIosApp,
    _ => null,
  };
  return switch (p.engine) {
    CallEngine.firefox => 'Firefox',
    CallEngine.gstreamer => 'GStreamer',
    CallEngine.libwebrtc when web => l10n.callGuessChromium,
    CallEngine.libwebrtc => app ?? l10n.callGuessNativeWebrtc,
    null when web => l10n.callGuessBrowser,
    null => app,
  };
}
