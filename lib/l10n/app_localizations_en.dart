// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginTitle => 'Sign in to Komet';

  @override
  String get loginSubtitle =>
      'Check your country code and enter your\nphone number.';

  @override
  String get loginCountry => 'Country';

  @override
  String get loginPhoneNumber => 'Phone number';

  @override
  String get loginOtherSignInMethods => 'Other sign-in methods';

  @override
  String get loginTermsIntro => 'By continuing, you agree to \n';

  @override
  String get loginTermsLink => 'the terms of use';

  @override
  String get loginTermsOfUse => 'Terms of use';

  @override
  String get loginConfirmPhoneTitle => 'Is this the correct number?';

  @override
  String get loginEdit => 'Change';

  @override
  String get loginDone => 'Done';

  @override
  String get loginReadTermsNotification => 'Please read the terms of use first';

  @override
  String get loginSpoofRedacted => 'Spoofing';

  @override
  String get loginProxy => 'Proxy';

  @override
  String get loginChangeServer => 'Change server';

  @override
  String get serverSettingsTitle => 'Server';

  @override
  String get serverHostLabel => 'Host';

  @override
  String get serverPortLabel => 'Port';

  @override
  String get serverApply => 'Apply and reconnect';

  @override
  String get serverUseDefault => 'Reset to default';

  @override
  String get serverInvalidHostOrPort => 'Enter a valid host and port (1–65535)';

  @override
  String get serverSettingsSaved => 'Server settings applied';

  @override
  String get serverReconnectFailed => 'Could not connect to the server';

  @override
  String get loginSignInWithQr => 'Sign in with QR code';

  @override
  String get loginSignInWithToken => 'Sign in with token';

  @override
  String get tokenLoginTitle => 'Token login';

  @override
  String get tokenLoginTokenLabel => 'Token';

  @override
  String get tokenLoginNote =>
      'Token login only works with spoofing. Enter the data of the device the token belongs to, otherwise the account may be banned.';

  @override
  String get tokenLoginButton => 'Sign in';

  @override
  String get tokenLoginError =>
      'Fill in the token, device name, OS version and Device ID';

  @override
  String get tokenLoginFailed => 'Sign in failed';

  @override
  String get loginSignInWithSessionFile => 'Sign in with session file';

  @override
  String get loginLanguage => 'Language';

  @override
  String get languageNameRu => 'Русский';

  @override
  String get languageNameEn => 'English';

  @override
  String get selectCountryTitle => 'Select country';

  @override
  String get selectCountrySearchHint => 'Search countries…';

  @override
  String get codeConfirmationSmsSent =>
      'We sent an SMS with a verification code to your phone number.';

  @override
  String codeResendInSeconds(int seconds) {
    return 'Resend in $seconds s.';
  }

  @override
  String get codeResendSms => 'Resend code via SMS';

  @override
  String get codeError2faMissing => 'Error: missing data for 2FA';

  @override
  String get codeConfirmation2faWarning =>
      'MAX may require 2FA on your account to sign in. If you didn\'t receive the code, set up 2FA from a client where you\'re already signed in.';

  @override
  String get proxySettingsTitle => 'Proxy';

  @override
  String get proxyTypeNone => 'Disabled';

  @override
  String get proxyTypeSocks5 => 'SOCKS5';

  @override
  String get proxyTypeHttp => 'HTTP(S)';

  @override
  String get proxyHostLabel => 'Proxy host';

  @override
  String get proxyPortLabel => 'Proxy port';

  @override
  String get proxyUsernameLabel => 'Username (optional)';

  @override
  String get proxyPasswordLabel => 'Password (optional)';

  @override
  String get proxyApply => 'Apply and reconnect';

  @override
  String get proxyDisable => 'Disable proxy';

  @override
  String get proxySettingsSaved => 'Proxy settings applied';

  @override
  String get proxyInvalidHostOrPort =>
      'Enter a valid proxy host and port (1–65535)';

  @override
  String get spoofScreenTitle => 'Session spoofing';

  @override
  String get spoofEnableTitle => 'Device spoofing';

  @override
  String get spoofEnableSubtitleOn => 'Enabled for this account';

  @override
  String get spoofEnableSubtitleOff => 'Disabled — using the real device';

  @override
  String get spoofInfoHint =>
      'Tap \"Generate\":\n• Short tap: random preset.\n• Long press: real device data.';

  @override
  String get spoofMethodTitle => 'Spoofing method';

  @override
  String get spoofMethodPartial => 'Partial';

  @override
  String get spoofMethodFull => 'Full';

  @override
  String get spoofMethodPartialDescription =>
      'Recommended method. Random data is used, but your real timezone and locale are kept for plausibility.';

  @override
  String get spoofMethodFullDescription =>
      'All data including timezone and locale is generated randomly. Use this method at your own risk!';

  @override
  String get spoofDeviceTypeTitle => 'Device type';

  @override
  String get spoofDeviceTypeDescription =>
      'Controls which devices are generated: Android or iOS';

  @override
  String get spoofDeviceTypeLabel => 'Device type';

  @override
  String get spoofMainSectionTitle => 'Main data';

  @override
  String get spoofFieldDeviceName => 'Device name';

  @override
  String get spoofFieldOsVersion => 'OS version';

  @override
  String get spoofRegionalSectionTitle => 'Regional data';

  @override
  String get spoofFieldScreen => 'Screen resolution';

  @override
  String get spoofFieldTimezone => 'Timezone';

  @override
  String get spoofFieldLocale => 'Locale';

  @override
  String get spoofFieldDeviceLocale => 'Device locale (derived)';

  @override
  String get spoofIdentifiersSectionTitle => 'Identifiers';

  @override
  String get spoofIdentifiersDescription =>
      'mt_instanceid and clientSessionId are generated automatically on every app launch. Only the Device ID can be changed.';

  @override
  String get spoofFieldInstanceId => 'mt_instanceid';

  @override
  String get spoofFieldClientSessionId => 'clientSessionId';

  @override
  String get spoofFieldPushDeviceType => 'Push device type';

  @override
  String get spoofFieldDeviceId => 'Device ID';

  @override
  String get spoofRegenerateIdTooltip => 'Generate a new ID';

  @override
  String get spoofFieldAppVersion => 'App version';

  @override
  String get spoofFieldBuildNumber => 'Build number';

  @override
  String get spoofFieldArchitecture => 'Architecture';

  @override
  String get spoofButtonGenerate => 'Generate';

  @override
  String get spoofButtonApply => 'Apply';

  @override
  String get spoofDialogUnsureTitle => 'Are you sure?';

  @override
  String get spoofDialogUnsureContent =>
      'The app may become unstable due to API incompatibility';

  @override
  String get spoofDialogCancel => 'Cancel';

  @override
  String get spoofDialogYes => 'Yes';

  @override
  String get spoofDialogApplyTitle => 'Apply settings?';

  @override
  String get spoofDialogApplyContent => 'Need to reconnect the app, ok?';

  @override
  String get spoofDialogApplyWarning =>
      'Your spoof will change immediately. But due to MAX specifics, you must re-login to the account for it to become visible';

  @override
  String get spoofDialogReloginTitle => 'Done!';

  @override
  String get spoofDialogReloginContent =>
      'Due to MAX specifics, your spoof is changed, but changes will be visible only after re-login.';

  @override
  String get spoofDialogReloginWarning => 'Re-login now?';

  @override
  String get spoofDialogReloginDeny => 'Later';

  @override
  String get spoofDialogReloginConfirm => 'Re-login now';

  @override
  String get spoofDialogApplyDeny => 'No';

  @override
  String get spoofDialogApplyConfirm => 'Ok!';

  @override
  String spoofErrorApplyFailed(String error) {
    return 'Failed to apply settings: $error';
  }

  @override
  String get profileMenuSpoof => 'Spoofing';

  @override
  String get infoTitle => 'Info';

  @override
  String get infoAccountSection => 'Account';

  @override
  String get infoServerSection => 'Server';

  @override
  String get infoUserSection => 'User';

  @override
  String get infoYMapSection => 'Y-Map';

  @override
  String get infoFileUploadTypes => 'file-upload-unsupported-types';

  @override
  String get infoWhiteListLinks => 'white-list-links';

  @override
  String get infoRegistrationTime => 'registrationTime';

  @override
  String get infoCountry => 'country';

  @override
  String get infoVideoChatHistory => 'videoChatHistory';

  @override
  String get infoUpdateTime => 'updateTime';

  @override
  String get infoId => 'id';

  @override
  String get infoChatMarker => 'chatMarker';

  @override
  String get infoAccountRemovalEnabled => 'account-removal-enabled';

  @override
  String get infoImageSize => 'image-size';

  @override
  String get infoGce => 'gce';

  @override
  String get infoGcce => 'gcce';

  @override
  String get infoMaxMsgLength => 'max-msg-length';

  @override
  String get infoQuotesEnabled => 'quotes-enabled';

  @override
  String get infoCallsEndpoint => 'calls-endpoint';

  @override
  String get infoSendLocationEnabled => 'send-location-enabled';

  @override
  String get infoLgce => 'lgce';

  @override
  String get infoWud => 'wud';

  @override
  String get infoVideoMsgEnabled => 'video-msg-enabled';

  @override
  String get infoGrse => 'grse';

  @override
  String get infoEditTimeout => 'edit-timeout';

  @override
  String get infoImageQuality => 'image-quality';

  @override
  String get infoUnsafeFilesAlert => 'unsafe-files-alert';

  @override
  String get infoAccountNicknameEnabled => 'account-nickname-enabled';

  @override
  String get infoMentionsEntityNamesLimit => 'mentions_entity_names_limit';

  @override
  String get infoReactionsEnabled => 'reactions-enabled';

  @override
  String get infoTile => 'tile';

  @override
  String get infoGeocoder => 'geocoder';

  @override
  String get infoStatic => 'static';

  @override
  String get chatInfoSubscribers => 'subscribers:';

  @override
  String get chatInfoInvitedBy => 'invited by:';

  @override
  String get chatInfoLink => 'link:';

  @override
  String get chatInfoOfficial => 'official:';

  @override
  String get chatInfoComments => 'comments:';

  @override
  String get chatInfoAplus => 'approved by Roskomnadzor:';

  @override
  String get chatInfoSignAdmin => 'admin signature:';

  @override
  String get chatInfoLastChanged => 'last changed:';

  @override
  String get chatInfoJoinTime => 'joined:';

  @override
  String get chatInfoCreated => 'created:';

  @override
  String get chatInfoTitle => 'Info';

  @override
  String get chatInfoMembers => 'members:';

  @override
  String get chatInfoLastSeen => 'last seen recently';

  @override
  String get chatInfoHasBots => 'has bots:';

  @override
  String get chatInfoBlockedCount => 'blocked in group:';

  @override
  String get chatInfoOfficialStatus => 'official status:';

  @override
  String get chatInfoJoined => 'joined:';

  @override
  String get chatInfoGroupCreated => 'group created:';

  @override
  String get chatInfoGroupOwner => 'group owner:';

  @override
  String get chatInfoDialogStarted => 'dialog started:';

  @override
  String get editProfileTitle => 'Edit Profile';

  @override
  String get editProfileSave => 'Save';

  @override
  String get editProfileFirstName => 'First name';

  @override
  String get editProfileLastName => 'Last name';

  @override
  String get editProfileRemovePhoto => 'Remove photo';

  @override
  String get registrationTitle => 'Create your profile';

  @override
  String get registrationSubtitle => 'Add your name and pick an avatar';

  @override
  String get registrationChooseAvatar => 'Choose an avatar';

  @override
  String get msgActionsCopy => 'Copy';

  @override
  String get emojiSearchHint => 'Search emoji';

  @override
  String get msgActionsEdit => 'Edit';

  @override
  String get msgActionsReply => 'Reply';

  @override
  String get msgActionsForward => 'Forward';

  @override
  String get msgActionsMarkUnread => 'Mark as unread';

  @override
  String get msgActionsPin => 'Pin';

  @override
  String get msgActionsUnpin => 'Unpin';

  @override
  String get pinnedMessageTitle => 'Pinned message';

  @override
  String get msgActionsEditHistory => 'Edit history';

  @override
  String get msgActionsReport => 'Report';

  @override
  String get msgActionsDelete => 'Delete';

  @override
  String get msgActionsCopied => 'Copied';

  @override
  String get msgActionsLoadReasonsFailed => 'Failed to load reasons';

  @override
  String get msgActionsCurrentVersion => 'current version';

  @override
  String msgActionsCurrentVersionWithDate(String date) {
    return 'current version · $date';
  }

  @override
  String get msgActionsNoText => '(no text)';

  @override
  String notificationsSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get notificationsFkmAlreadyHasFcm => 'Why? You already have FCM.';

  @override
  String get notificationsFkmDownloadFcm => 'Better download the FCM version.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsFkmSectionTitle => 'FKM';

  @override
  String get notificationsFkmEnableLabel => 'Enable notifications';

  @override
  String get notificationsFkmEnableSubtitle =>
      'For FKM notifications to work, the app will need to keep a notification in the shade.';

  @override
  String get notificationsMainSectionTitle => 'Notifications';

  @override
  String get notificationsAllLabel => 'All notifications';

  @override
  String get notificationsNewSectionTitle => 'New notifications';

  @override
  String get notificationsPreviewLabel => 'Message preview';

  @override
  String get notificationsSoundLabel => 'Sound';

  @override
  String get notificationsAdditionalSectionTitle => 'Additional';

  @override
  String get notificationsCallsLabel => 'Call notifications';

  @override
  String get notificationsNewContactsLabel => 'Notifications from new contacts';

  @override
  String get notificationsHapticsSectionTitle => 'Haptic feedback';

  @override
  String get notificationsHapticsLabel => 'Haptic feedback';

  @override
  String get notificationsHapticsSubtitle =>
      'Vibration feedback for actions in the app';

  @override
  String devicesLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get devicesQrLinkDialogTitle => 'Link from QR';

  @override
  String get devicesQrLinkDialogHint => 'Paste the QR code content';

  @override
  String get devicesAllTerminated => 'All sessions terminated';

  @override
  String devicesGenericError(String error) {
    return 'Error: $error';
  }

  @override
  String devicesIpLookupError(String error) {
    return 'IP error: $error';
  }

  @override
  String get devicesTitle => 'Devices';

  @override
  String get devicesPromoTitle => 'Devices in KOMET';

  @override
  String get devicesPromoSubtitle => 'Who has access to your account?';

  @override
  String get devicesScanQrButton => 'Scan QR';

  @override
  String get devicesCurrentSuffix => ' (current)';

  @override
  String get devicesOnlineStatus => 'Online';

  @override
  String get devicesTerminateOthersButton =>
      'Terminate all sessions except the current one';

  @override
  String get devicesMobileNetworkLabel => 'Mobile network';

  @override
  String get devicesProxyDetectedLabel => 'Proxy/VPN detected';

  @override
  String get themeSettingsTitle => 'Theme';

  @override
  String get themeSettingsModeCardTitle => 'Theme mode';

  @override
  String get themeSettingsModeCardSubtitle =>
      'Light, dark, or automatic switching';

  @override
  String get themeSettingsModeSystem => 'System';

  @override
  String get themeSettingsModeLight => 'Light';

  @override
  String get themeSettingsModeDark => 'Dark';

  @override
  String get themeSettingsModeSchedule => 'Scheduled';

  @override
  String get themeSettingsAmoledTitle => 'AMOLED black';

  @override
  String get themeSettingsAmoledSubtitle =>
      'Pure black background for OLED screens';

  @override
  String get themeSettingsScheduleTitle => 'Schedule';

  @override
  String get themeSettingsScheduleSubtitleEnabled =>
      'When dark theme turns on automatically';

  @override
  String get themeSettingsScheduleSubtitleDisabled =>
      'Available in \"Scheduled\" mode';

  @override
  String get themeSettingsScheduleDarkFrom => 'Dark from';

  @override
  String get themeSettingsScheduleLightFrom => 'Light from';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceVisualStyleTitle => 'Visual style';

  @override
  String get appearanceVisualStyleSubtitle =>
      'Material You or dimensional Glossy capsules';

  @override
  String get appearanceVisualStyleMaterialYou => 'Material You';

  @override
  String get appearanceVisualStyleGlossy => 'Glossy';

  @override
  String get appearanceChatChromeTitle => 'Chat screen elements';

  @override
  String get appearanceChatChromeSubtitle =>
      'Background of the top and bottom panels: color, blur, or transparent. With blur or transparency, messages scroll under the panels';

  @override
  String get appearanceChatChromeColor => 'Color';

  @override
  String get appearanceChatChromeBlur => 'Blur';

  @override
  String get appearanceChatChromeNone => 'None';

  @override
  String get appearanceChatChromeTransparent => 'Clear';

  @override
  String get appearanceGradientTitle => 'Gradient';

  @override
  String get appearanceGradientSubtitle =>
      'Depth and highlights in Glossy capsules';

  @override
  String get appearanceAccentColorTitle => 'Accent color';

  @override
  String get appearanceAccentColorSystem => 'System';

  @override
  String get appearanceAccentColorSubtitle =>
      'Main color of the interface and bubbles';

  @override
  String get appearanceAccentColorSystemActive => 'System color is active';

  @override
  String get appearanceAccentColorReset => 'Reset to system';

  @override
  String get appearanceBubbleShapeTitle => 'Message shape';

  @override
  String get appearanceBubbleShapeSubtitle => 'Bubble corner rounding';

  @override
  String get appearanceBubbleShapeMobile => 'TG Mobile';

  @override
  String get appearanceBubbleShapeDesktop => 'TG Desktop';

  @override
  String get appearanceBubbleBehaviorTitle => 'Message behavior';

  @override
  String get appearanceBubbleBehaviorSubtitle =>
      'Whether bubble shape changes based on neighbors in a group';

  @override
  String get appearanceBubbleBehaviorMutable => 'Mutable';

  @override
  String get appearanceBubbleBehaviorImmutable => 'Immutable';

  @override
  String get appearancePreviewHello => 'Hi!';

  @override
  String get appearancePreviewHowIsIt => 'How do you like it?';

  @override
  String get appearancePreviewHmm => 'hmm...';

  @override
  String get appearancePreviewNotBad => 'Not bad at all!';

  @override
  String get callKometDetectedNotification => 'This person uses Komet! :3';

  @override
  String get callStatusConnecting => 'Connecting';

  @override
  String get callGroupConnecting => 'Connecting…';

  @override
  String get callGroupWaitingParticipants => 'Waiting for participants…';

  @override
  String get callParticipantYou => 'You';

  @override
  String get callParticipantFallback => 'Participant';

  @override
  String get callTooltipMinimize => 'Minimize';

  @override
  String get callTooltipKometHub => 'Komet';

  @override
  String get callInfoTitle => 'About call';

  @override
  String get callPeerMicOff => 'Microphone off';

  @override
  String get callPeerCameraOn => 'Camera on';

  @override
  String get callUnknownName => 'Unknown';

  @override
  String get callIncoming => 'Incoming call';

  @override
  String get callStatusRinging => 'Calling';

  @override
  String get callStatusEnded => 'Call ended';

  @override
  String get callDecline => 'Decline';

  @override
  String get callAccept => 'Accept';

  @override
  String get callSpeaker => 'Speaker';

  @override
  String get callVideoLabel => 'Video';

  @override
  String get callScreenLabel => 'Screen';

  @override
  String get callUnmute => 'Unmute';

  @override
  String get callMute => 'Mute';

  @override
  String get callEndButton => 'End';

  @override
  String get callInfoClient => 'Client';

  @override
  String get callInfoPlatform => 'Platform';

  @override
  String get callInfoCountry => 'Country';

  @override
  String get callInfoInContacts => 'In contacts';

  @override
  String get callValueYes => 'yes';

  @override
  String get callValueNo => 'no';

  @override
  String get callInfoPeerIp => 'Peer IP';

  @override
  String get callInfoPeerNetwork => 'Peer network';

  @override
  String get callInfoPath => 'Connection path';

  @override
  String get callInfoCodec => 'Codec';

  @override
  String get callInfoServer => 'Server';

  @override
  String get callInfoTopology => 'Topology';

  @override
  String get callInfoStatus => 'Status';

  @override
  String get callStatusValueConnected => 'connected';

  @override
  String get callStatusValueConnecting => 'connecting…';

  @override
  String get callInfoPeerMic => 'Peer microphone';

  @override
  String get callMicValueOn => 'on';

  @override
  String get callMicValueOff => 'off';

  @override
  String get callInfoPeerCamera => 'Peer camera';

  @override
  String get callCameraValueOn => 'on';

  @override
  String get callCameraValueOff => 'off';

  @override
  String get callInfoVideoTrack => 'Video track';

  @override
  String callInfoVideoTrackPresent(int count) {
    return 'yes ($count)';
  }

  @override
  String get callInfoVideoSize => 'Video size';

  @override
  String get callInfoFrameRendering => 'Frame rendering';

  @override
  String get callBadgeEncrypted => 'Encrypted';

  @override
  String get callBadgeAudio => 'Audio';

  @override
  String get callBadgeRecording => 'Recording';

  @override
  String get callBadgeNoiseSuppression => 'Noise suppression';

  @override
  String get callBadgeAnimoji => 'Animoji';

  @override
  String get callInfoNoDataYet => 'Data will appear after connecting…';

  @override
  String get hubTitleMenu => 'Komet';

  @override
  String get hubChatPageTitle => 'Anonymous chat';

  @override
  String get hubGamesTitle => 'Games';

  @override
  String get hubCheckersTitle => 'Checkers';

  @override
  String get hubChatTileTitle => 'Chat';

  @override
  String get hubChatTileSubtitle => 'Anonymous messages';

  @override
  String get hubGamesTileSubtitle => 'Play with your partner';

  @override
  String get hubCheckersTileSubtitle => 'Russian checkers';

  @override
  String get hubMoreSoonTitle => 'More coming soon…';

  @override
  String get hubMoreSoonSubtitle => 'In development';

  @override
  String get hubChatPrivacyNote =>
      'Sent directly through the call, stored nowhere';

  @override
  String get hubChatEmpty => 'No messages yet';

  @override
  String get hubChatInputHint => 'Message…';

  @override
  String get hubCheckersRestart => 'Restart';

  @override
  String get hubCheckersYouWhite => 'You\'re playing white';

  @override
  String get hubCheckersYouBlack => 'You\'re playing black';

  @override
  String get hubCheckersWon => 'You won 🎉';

  @override
  String get hubCheckersLost => 'You lost';

  @override
  String get hubCheckersYourMove => 'Your move';

  @override
  String get hubCheckersOpponentMove => 'Opponent\'s move…';

  @override
  String get scheduledPickTimeTitle => 'When to send';

  @override
  String get scheduledEditTitle => 'Edit';

  @override
  String get scheduledMessageTextHint => 'Message text';

  @override
  String get scheduledSave => 'Save';

  @override
  String get scheduledEditFailed => 'Failed to edit message';

  @override
  String get scheduledDeleteConfirmTitle => 'Delete scheduled message?';

  @override
  String get scheduledDeleteConfirmMessage => 'The message won\'t be sent.';

  @override
  String get scheduledDeleteConfirmLabel => 'Delete';

  @override
  String get scheduledDeleteFailed => 'Failed to delete message';

  @override
  String get scheduledAppBarTitle => 'Scheduled';

  @override
  String get scheduledEmpty => 'No scheduled messages';

  @override
  String get scheduledAttachPhoto => 'Photo';

  @override
  String get scheduledAttachVideo => 'Video';

  @override
  String get scheduledAttachVoice => 'Voice message';

  @override
  String get scheduledAttachFile => 'File';

  @override
  String get scheduledAttachLocation => 'Location';

  @override
  String get scheduledAttachForwarded => 'Forwarded';

  @override
  String get scheduledAttachGeneric => 'Attachment';

  @override
  String contactProfileLoadError(String error) {
    return 'Error: $error';
  }

  @override
  String get contactProfileBot => 'Bot';

  @override
  String get contactProfileOnline => 'Online';

  @override
  String get contactProfileRecentlyActive => 'Recently active';

  @override
  String get contactProfileActionChat => 'Chat';

  @override
  String get contactProfileActionSound => 'Sound';

  @override
  String get contactProfileActionCall => 'Call';

  @override
  String get contactProfileInfoPhone => 'Phone';

  @override
  String get contactProfileInfoCountry => 'Country';

  @override
  String get contactProfileInfoGender => 'Gender';

  @override
  String get contactProfileInfoRegistration => 'Registration';

  @override
  String get contactProfileInfoUpdated => 'Updated';

  @override
  String get contactProfileInfoAccountStatus => 'Account status';

  @override
  String get contactProfileInfoDescription => 'Description';

  @override
  String get contactProfileInfoLink => 'Link';

  @override
  String get contactProfileInfoFlags => 'Flags';

  @override
  String nfcPeerNameFallback(String id) {
    return 'Contact #$id';
  }

  @override
  String get nfcPeerFirstNameFallback => 'Contact';

  @override
  String get nfcContactAdded => 'Contact added';

  @override
  String nfcAddFailed(String error) {
    return 'Failed to add: $error';
  }

  @override
  String get nfcReasonBluetoothOff => 'Turn on Bluetooth and try again';

  @override
  String get nfcReasonPermission =>
      'Bluetooth permissions are needed for exchange';

  @override
  String get nfcReasonDefault => 'Failed to establish connection';

  @override
  String get nfcSheetTitle => 'Contact exchange';

  @override
  String get nfcUnsupported => 'NFC is not available on this device';

  @override
  String get nfcDisabled => 'Turn on NFC in phone settings and try again';

  @override
  String get nfcScanningTitle => 'Hold the phones close together';

  @override
  String get nfcScanningSubtitle => 'Both devices must keep this screen open';

  @override
  String get nfcExchangingTitle => 'Exchanging contacts…';

  @override
  String get nfcExchangingSubtitle => 'Almost done';

  @override
  String nfcPeerIdFallback(String id) {
    return 'ID $id';
  }

  @override
  String get nfcAdded => 'Added';

  @override
  String get nfcAddContact => 'Add contact';

  @override
  String get chatInfoTabGeneralChats => 'Common chats';

  @override
  String get chatInfoTabMedia => 'Media';

  @override
  String get chatInfoTabFiles => 'Files';

  @override
  String get chatInfoTabVoice => 'Voice messages';

  @override
  String get chatInfoTabLinks => 'Links';

  @override
  String get chatInfoTabMembers => 'Members';

  @override
  String get chatInfoEmptyGeneralChats => 'No common chats';

  @override
  String get chatInfoEmptyMedia => 'No media';

  @override
  String get chatInfoEmptyFiles => 'No files';

  @override
  String get chatInfoEmptyVoice => 'No voice messages';

  @override
  String get chatInfoEmptyLinks => 'No links';

  @override
  String chatInfoOnlineOfTotal(String online, String total) {
    return '$online of $total online';
  }

  @override
  String sharedMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get sharedLoadMore => 'Show more';

  @override
  String get sharedGoToMessage => 'Go to message';

  @override
  String get sharedDownload => 'Download';

  @override
  String get sharedCopyLink => 'Copy link';

  @override
  String get sharedLinkCopied => 'Link copied';

  @override
  String get chatInfoActionLeave => 'Leave';

  @override
  String get chatInfoBio => 'About';

  @override
  String get chatInfoInviteLink => 'Invite link';

  @override
  String get chatInfoCollapse => 'Collapse';

  @override
  String get chatInfoShowMore => 'More';

  @override
  String get chatInfoAddMember => 'Add member';

  @override
  String get chatInfoRoleOwner => 'owner';

  @override
  String get chatInfoRoleAdmin => 'Admin';

  @override
  String get chatInfoNoData => 'No data';

  @override
  String get chatInfoHideExtra => 'Hide';

  @override
  String get chatInfoShowMoreExtra => 'Details';

  @override
  String get chatInfoRowId => 'Chat ID';

  @override
  String get chatInfoRowCreated => 'Created';

  @override
  String get chatInfoRowModified => 'Modified';

  @override
  String get chatInfoRowMembersCount => 'Members';

  @override
  String get chatInfoRowOwner => 'Owner';

  @override
  String get chatInfoRowCreatedGroup => 'Created';

  @override
  String get chatInfoRowJoined => 'Joined';

  @override
  String get chatInfoRowModifiedGroup => 'Modified';

  @override
  String get chatInfoRowHasBots => 'Has bots';

  @override
  String get chatInfoRowBlockedCount => 'Blocked';

  @override
  String get chatInfoRowOfficialGroup => 'Official';

  @override
  String get chatInfoRowSignAdmin => 'Admin signature';

  @override
  String get chatInfoRowSubscribersCount => 'Subscribers';

  @override
  String get chatInfoRowOfficialChannel => 'Official';

  @override
  String get chatInfoRowComments => 'Comments';

  @override
  String get chatInfoRowRkn => 'Roskomnadzor approved';

  @override
  String get chatInfoRowOnlyAdmin => 'Admins only';

  @override
  String get securityTitle => 'Security';

  @override
  String securityLoadError(String error) {
    return 'Loading error: $error';
  }

  @override
  String securitySaveError(String error) {
    return 'Save error: $error';
  }

  @override
  String get securityPrivacyAll => 'Everyone';

  @override
  String get securityPrivacyContacts => 'My contacts';

  @override
  String get securityPrivacyNobody => 'Nobody';

  @override
  String get securityFamilyProtection => 'Family protection';

  @override
  String get securityEnabledFem => 'Enabled';

  @override
  String get securityDisabledFem => 'Disabled';

  @override
  String get securityPasswordTitle => 'Login password';

  @override
  String get securityEnabledMasc => 'Enabled';

  @override
  String get securityDisabledMasc => 'Disabled';

  @override
  String get securityModeTitle => 'Safe mode';

  @override
  String get securityModeSubtitle => 'Hides personal information';

  @override
  String get securitySettingsUnavailable =>
      'Changing this setting is not available yet';

  @override
  String get securityFindByPhone => 'Find me by phone number';

  @override
  String get securityWhoCanCall => 'Who can call me';

  @override
  String get securityWhoCanInvite => 'Who can invite me to chats';

  @override
  String get securityShowContact => 'Show contact';

  @override
  String get securityContentSafe => 'Safe';

  @override
  String get securityContentAll => 'All';

  @override
  String get securityShowOnlineStatus => 'See online status';

  @override
  String get securityShowMyNumber => 'See my number';

  @override
  String get securityConfirmTitle => 'Are you sure?';

  @override
  String get securityHiddenStatusWarning =>
      'You won\'t be able to see the online status of other users.';

  @override
  String get securityConfidentialityHeader => 'PRIVACY';

  @override
  String get securityReadReceipts => 'Read receipts';

  @override
  String get securityAltKeyboard => 'Alternative keyboard';

  @override
  String get securityUnsafeFiles => 'Accept unsafe files';

  @override
  String get securityAudioTranscription => 'Audio transcription';

  @override
  String get securityBlacklistTitle => 'Blacklist';

  @override
  String securityBlacklistNotification(String count) {
    return 'Blacklist: $count contacts';
  }

  @override
  String get passwordEntryWrongPassword => 'Wrong password';

  @override
  String get passwordEntryConfirmTitle => 'Confirm password';

  @override
  String get passwordEntryCurrentPasswordHint => 'Current password';

  @override
  String get passwordEntryContinue => 'Continue';

  @override
  String get passwordEntryNotSetTitle => 'Password is not set';

  @override
  String get passwordEntry2faSubtitle => 'Two-factor authentication';

  @override
  String get passwordEntrySetupAction => 'Set password';

  @override
  String get passwordEntryGateMessage =>
      'Enter your login password to manage protection';

  @override
  String get passwordEntryGenericPasswordHint => 'Password';

  @override
  String get passwordEntrySetTitle => 'Password is set';

  @override
  String passwordEntryHintPrefix(String hint) {
    return 'Hint: $hint';
  }

  @override
  String get passwordEntryChangePasswordAction => 'Change password';

  @override
  String get passwordEntryChangeEmailAction => 'Change email';

  @override
  String get passwordEntryDeleteAction => 'Delete password';

  @override
  String get passwordEntryMinPasswordError =>
      'Password must be at least 6 characters';

  @override
  String get passwordEntryMismatchError => 'Passwords do not match';

  @override
  String get passwordEntryInvalidEmailError => 'Enter a valid email';

  @override
  String get passwordEntryInvalidCodeError => 'Enter the 6-digit code';

  @override
  String get passwordEntrySetupTitle => 'Password setup';

  @override
  String get passwordEntryStepPassword => 'Password';

  @override
  String get passwordEntryStepHint => 'Hint';

  @override
  String get passwordEntryStepEmail => 'Email';

  @override
  String get passwordEntryStepCode => 'Code';

  @override
  String get passwordEntryChoosePassword => 'Choose a password';

  @override
  String get passwordEntryMinCharsHint => 'At least 6 characters';

  @override
  String get passwordEntryEnterPasswordHint => 'Enter password';

  @override
  String get passwordEntryEnterAgain => 'Enter the password again';

  @override
  String get passwordEntryRepeatHint => 'Repeat password';

  @override
  String get passwordEntryHintForPassword => 'Password hint';

  @override
  String get passwordEntryOptional => 'Optional';

  @override
  String get passwordEntryHintFieldHint => 'Enter a hint (optional)';

  @override
  String get passwordEntryLinkEmail => 'Link an email';

  @override
  String get passwordEntryEmailPurpose => 'For password recovery. Optional';

  @override
  String get passwordEntryEmailHintOptional => 'example@mail.com (optional)';

  @override
  String get passwordEntryEnterCode => 'Enter the code';

  @override
  String passwordEntryCodeSentTo(String email) {
    return 'Code sent to $email';
  }

  @override
  String get passwordEntryChangedNotif => 'Password changed';

  @override
  String get passwordEntryNewPassword => 'New password';

  @override
  String get passwordEntryNewPasswordHint => 'Enter new password';

  @override
  String get passwordEntryRepeatNewPasswordHint => 'Repeat new password';

  @override
  String get passwordEntryEmailChangedNotif => 'Email changed';

  @override
  String get passwordEntryNewEmail => 'New email';

  @override
  String get passwordEntryEmailHint => 'example@mail.com';

  @override
  String get passwordEntryRemovedNotif => 'Password removed';

  @override
  String get passwordEntryRemoveTitle => 'Remove password';

  @override
  String get passwordEntryRemoveWarning =>
      'Warning! Removing the password will weaken your account\'s protection.';

  @override
  String get cloudStorageNoActiveProfile => 'No active profile';

  @override
  String get cloudStorageSetupFailed => 'Could not create environment';

  @override
  String get cloudStorageTitle => 'Cloud storage';

  @override
  String get cloudStorageNotConfiguredTitle =>
      'Cloud storage environment isn\'t set up';

  @override
  String get cloudStorageNotConfiguredSubtitle => 'Let\'s start? It\'s quick.';

  @override
  String get cloudStorageStart => 'Start';

  @override
  String cloudStorageUploadingPercent(String percent) {
    return 'Uploading $percent%';
  }

  @override
  String get cloudStorageStartUploadHint =>
      'Start an upload to see the progress bar';

  @override
  String get cloudStorageEmptyTitle => 'No cloud files yet...';

  @override
  String get cloudStorageEmptySubtitle => 'Add one?';

  @override
  String get cloudStorageUpload => 'Upload';

  @override
  String get cloudStorageFromFile => 'From file';

  @override
  String get cloudStorageById => 'By ID';

  @override
  String get cloudStorageFileIdLabel => 'File ID';

  @override
  String get cloudStorageSizeLabel => 'Size';

  @override
  String get cloudStorageNoLinkYet => 'No link yet. Create one.';

  @override
  String cloudStorageLinkExpiresIn(String time) {
    return 'Link expires in $time';
  }

  @override
  String get cloudStorageLinkCopied => 'Link copied';

  @override
  String get cloudStorageInvalidId => 'Invalid ID';

  @override
  String get cloudStorageSendError => 'Send error';

  @override
  String get cloudStorageSendByIdTitle => 'Send by ID';

  @override
  String get cloudStorageSend => 'Send';

  @override
  String get digitalIdGosuslugiLinkUnavailable =>
      'Linking Gosuslugi isn\'t available on this platform. Do this in the mobile app.';

  @override
  String get digitalIdGosuslugiLinkFailed => 'Could not get the Gosuslugi link';

  @override
  String get digitalIdGosuslugiTitle => 'Gosuslugi';

  @override
  String get digitalIdDocsUnavailable =>
      'Documents aren\'t available yet. Try again later.';

  @override
  String get digitalIdTitle => 'Digital ID';

  @override
  String get digitalIdNotConfiguredTitle => 'Digital ID isn\'t set up';

  @override
  String get digitalIdLinkGosuslugiHint =>
      'Link your Gosuslugi account so your documents appear in Digital ID. The phone number in MAX must match the one in your Gosuslugi profile.';

  @override
  String get digitalIdLinkOrRefreshHint =>
      'Link Gosuslugi to get access to your documents, or refresh the page if you\'ve already set up Digital ID.';

  @override
  String get digitalIdLoadDocuments => 'Load documents';

  @override
  String get digitalIdLinkGosuslugiButton => 'Link Gosuslugi';

  @override
  String get digitalIdGosuslugiProfileFallback => 'Gosuslugi profile';

  @override
  String digitalIdBirthDate(String date) {
    return 'Date of birth: $date';
  }

  @override
  String get digitalIdPersonalDataTitle => 'Personal data';

  @override
  String get digitalIdSnilsLabel => 'SNILS';

  @override
  String get digitalIdInnLabel => 'INN';

  @override
  String get digitalIdBirthPlaceLabel => 'Place of birth';

  @override
  String get digitalIdRegistrationAddressLabel => 'Registration address';

  @override
  String get digitalIdDocumentsTitle => 'Documents';

  @override
  String digitalIdDocSeries(String series) {
    return 'series $series';
  }

  @override
  String digitalIdDocNumber(String number) {
    return 'No. $number';
  }

  @override
  String get digitalIdPassesTitle => 'Passes';

  @override
  String digitalIdCardInn(String inn) {
    return 'INN $inn';
  }

  @override
  String get digitalIdBiometryConfigured => 'Biometrics set up on this device';

  @override
  String get digitalIdBiometryNotConfigured =>
      'Biometrics not set up on this device';

  @override
  String get digitalIdDocPassport => 'Russian passport';

  @override
  String get digitalIdDocOms => 'Health insurance policy (OMS)';

  @override
  String get digitalIdDocDriverLicense => 'Driver\'s license';

  @override
  String get digitalIdDocVehicleSts => 'Vehicle registration certificate (STS)';

  @override
  String get digitalIdDocChildBirthCert => 'Birth certificate';

  @override
  String get digitalIdDocPensionCert => 'Pension certificate';

  @override
  String get digitalIdDocDisabledCert => 'Disability certificate';

  @override
  String get digitalIdDocLargeFamilyCert => 'Large family certificate';

  @override
  String get digitalIdDocStudentTicket => 'Student ID';

  @override
  String get digitalIdDocChildInn => 'Child\'s INN';

  @override
  String get digitalIdDocChildOms => 'Child\'s health insurance policy (OMS)';

  @override
  String get attachSheetGallery => 'Gallery';

  @override
  String get attachSheetPoll => 'Poll';

  @override
  String get attachSheetCameraComingSoon => 'Camera is coming soon';

  @override
  String get attachSheetSendFileTitle => 'Send a file';

  @override
  String get attachSheetSendFileSubtitle =>
      'A document, archive, or any other file';

  @override
  String get attachSheetChooseFileButton => 'Choose file';

  @override
  String get attachSheetShareLocationTitle => 'Share location';

  @override
  String get attachSheetShareLocationSubtitle => 'Send your current location';

  @override
  String get attachSheetSendLocationButton => 'Send location';

  @override
  String get attachSheetCreatePoll => 'Create poll';

  @override
  String get attachSheetCreatePollSubtitle => 'A question with answer options';

  @override
  String get attachSheetNoImagesFound => 'No images found';

  @override
  String get attachSheetLimitedAccessInfo => 'Not all photos are accessible';

  @override
  String get attachSheetSectionInProgress => 'Section under development';

  @override
  String get attachSheetNoGalleryAccessTitle => 'No access to the gallery';

  @override
  String get attachSheetNoGalleryAccessSubtitle =>
      'Allow access to photos to pick them from here';

  @override
  String get attachSheetAllow => 'Allow';

  @override
  String get attachSheetSettings => 'Settings';

  @override
  String get attachSheetAddCaptionHint => 'Add a caption...';

  @override
  String get attachSheetCamera => 'Camera';

  @override
  String get photoEditorApplyFailed => 'Couldn\'t apply';

  @override
  String get photoEditorFlipTooltip => 'Flip';

  @override
  String get photoEditorRotateTooltip => 'Rotate';

  @override
  String get photoEditorCancel => 'CANCEL';

  @override
  String get photoEditorReset => 'RESET';

  @override
  String get photoEditorDone => 'DONE';

  @override
  String get photoEditorTextDialogTitle => 'Text';

  @override
  String get photoEditorTextDialogHint => 'Enter text';

  @override
  String get photoEditorOk => 'OK';

  @override
  String get photoEditorApplyChangesFailed => 'Couldn\'t apply changes';

  @override
  String get photoEditorClearAll => 'Clear all';

  @override
  String get photoEditorAddText => 'Add text';

  @override
  String get photoEditorTabDraw => 'DRAW';

  @override
  String get photoEditorTabStickers => 'STICKERS';

  @override
  String get photoEditorTabText => 'TEXT';

  @override
  String get photoEditorChannelAll => 'All';

  @override
  String get photoEditorChannelRed => 'Red';

  @override
  String get photoEditorChannelGreen => 'Green';

  @override
  String get photoEditorChannelBlue => 'Blue';

  @override
  String get photoEditorEnhance => 'Enhance';

  @override
  String get photoEditorExposure => 'Exposure';

  @override
  String get photoEditorContrast => 'Contrast';

  @override
  String get photoEditorSaturation => 'Saturation';

  @override
  String get photoEditorWarmth => 'Warmth';

  @override
  String get photoEditorVignette => 'Vignette';

  @override
  String get photoEditorBlurOff => 'Off';

  @override
  String get photoEditorBlurRadial => 'Radial';

  @override
  String get photoEditorBlurLinear => 'Linear';

  @override
  String get fontSettingsInvalidInput => 'Enter a font link or name';

  @override
  String fontSettingsFontNotFound(String name) {
    return 'Font \"$name\" not found or no network';
  }

  @override
  String fontSettingsFontAdded(String name) {
    return 'Font \"$name\" added';
  }

  @override
  String fontSettingsFontRemoved(String name) {
    return 'Font \"$name\" removed';
  }

  @override
  String get fontSettingsAddFontTitle => 'Add font';

  @override
  String get fontSettingsAddFontDescription =>
      'Paste a Google Fonts link or font name';

  @override
  String get fontSettingsAddFontConfirm => 'Add';

  @override
  String get fontSettingsTitle => 'Fonts';

  @override
  String get fontSettingsSectionFont => 'Font';

  @override
  String get fontSettingsLoading => 'Loading…';

  @override
  String get fontSettingsSectionFontSize => 'Font size';

  @override
  String get fontSettingsPreviewLabel => 'PREVIEW';

  @override
  String get fontSettingsReset => 'Reset';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateAvailableBody(String version) {
    return 'Version $version is out. Update the app?';
  }

  @override
  String get updateWhatsNew => 'WHAT\'S NEW';

  @override
  String get updateAction => 'Update';

  @override
  String get updateLater => 'Later';

  @override
  String get updateSkip => 'Skip';

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String get updateDownloadFailed => 'Failed to download the update';
}
