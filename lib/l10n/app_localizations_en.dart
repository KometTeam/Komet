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
  String get serverTrustMincifryTitle => 'Trust the Минцифры CA';

  @override
  String get serverTrustMincifrySubtitle =>
      'Required for api2.oneme.ru: its certificate chains to the Russian Trusted Root CA, which is absent from the standard trust store. The root is bundled with the app; other hosts keep using the usual roots.';

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
  String get codeErrorInvalid => 'Invalid code';

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
  String get infoPacketSection => 'Login packet';

  @override
  String get infoChatsSection => 'Chats in login packet';

  @override
  String get infoChatSettingsSection => 'Per-chat settings';

  @override
  String get infoServerSection => 'Server';

  @override
  String get infoUserSection => 'User';

  @override
  String get infoExperimentsSection => 'Experiments';

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
  String get infoPhone => 'phone';

  @override
  String get infoPhotoId => 'photoId';

  @override
  String get infoAccountStatus => 'accountStatus';

  @override
  String get infoContactOptions => 'contact options';

  @override
  String get infoProfileOptions => 'profile options';

  @override
  String get infoNames => 'names';

  @override
  String get infoBaseUrl => 'baseUrl';

  @override
  String get infoBaseRawUrl => 'baseRawUrl';

  @override
  String get infoChatMarker => 'chatMarker';

  @override
  String get infoServerTime => 'server time';

  @override
  String get infoUpdates => 'updates';

  @override
  String get infoMessagesCount => 'messages in packet';

  @override
  String get infoContactsCount => 'contacts in packet';

  @override
  String get infoPresenceCount => 'presence records';

  @override
  String get infoConfigHash => 'config hash';

  @override
  String get infoChatsCount => 'chats loaded';

  @override
  String get infoChatsActive => 'active';

  @override
  String get infoChatsHidden => 'hidden';

  @override
  String get infoChatsDialogs => 'dialogs';

  @override
  String get infoChatsGroups => 'groups';

  @override
  String get infoChatsChannels => 'channels';

  @override
  String get infoChatsUnread => 'unread chats';

  @override
  String get infoChatsNewMessages => 'new messages';

  @override
  String get infoChatsMessages => 'messages in loaded chats';

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
  String get commentsWrite => 'Comment';

  @override
  String get commentsTitle => 'Comments';

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
    );
    return '$_temp0';
  }

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
  String get editProfileBio => 'About me';

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
  String get msgActionsCopyLink => 'Copy link';

  @override
  String get msgActionsSelectAll => 'Select all';

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
  String get msgActionsInfo => 'Info';

  @override
  String get msgActionsReadBy => 'Read by';

  @override
  String get msgActionsReadByEmpty => 'Nobody has read it yet';

  @override
  String get msgActionsReadByUnknownUser => 'User';

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
  String get notificationsFkmIosUnsupported =>
      'Push notifications are not available on iOS yet.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsFkmSectionTitle =>
      'Notifications without Google (FKM)';

  @override
  String get notificationsFkmEnableLabel => 'Enable notifications';

  @override
  String get notificationsFkmEnableSubtitle =>
      'Komet keeps its own connection to the server and shows notifications itself. A service notification will stay in the shade while this is on.';

  @override
  String get notificationsFkmUnsupported => 'FKM is Android-only';

  @override
  String get notificationsFkmBatteryAction => 'Open settings';

  @override
  String get notificationsFkmBatteryMessage =>
      'Otherwise the system will put the background connection to sleep and notifications will be late or lost.';

  @override
  String get notificationsFkmBatteryTitle => 'Turn off battery saving?';

  @override
  String get notificationsFkmPermissionDenied =>
      'FKM cannot work without the notification permission';

  @override
  String get notificationsFkmConfirmAction => 'Enable FKM';

  @override
  String get notificationsFkmConfirmMessage =>
      'Notifications will arrive over the app’s own background connection, and a permanent service notification will stay in the shade. You can turn FKM off right from it.';

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
  String get themeSettingsCustomTitle => 'Custom';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceVisualStyleTitle => 'Visual style';

  @override
  String get appearanceVisualStyleSubtitle =>
      'Material You or dimensional Glossy capsules';

  @override
  String get appearanceStyleAuto => 'Match theme';

  @override
  String get appearanceVisualStyleMaterialYou => 'Material You';

  @override
  String get appearanceVisualStyleGlossy => 'Glossy';

  @override
  String get appearanceVisualStyleLiquidGlass => 'Liquid Glass';

  @override
  String get appearanceGlassMaterial => 'Glass';

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
  String get appearanceChatChromeTransparent => 'Frost blur';

  @override
  String get appearanceComposerTitle => 'Input bar';

  @override
  String get appearanceComposerSubtitle =>
      'Style and background of the message input bar';

  @override
  String get appearanceComposerBackgroundStandard => 'Default';

  @override
  String get appearanceComposerBackgroundFrost => 'Frost blur';

  @override
  String get appearanceNavPillTitle => 'Switcher style';

  @override
  String get appearanceNavPillSubtitle =>
      'Section switcher on the chats screen';

  @override
  String get appearanceNavPillGlossy => 'Glossy';

  @override
  String get appearanceNavPillFrost => 'G-FrostBlur';

  @override
  String get playbackPillAt => 'at';

  @override
  String get playbackPillYou => 'You';

  @override
  String get appearanceGradientTitle => 'Gradient';

  @override
  String get appearanceGradientSubtitle =>
      'Depth and highlights in Glossy capsules';

  @override
  String get appearanceSpectrumTitle => 'Spectrum background';

  @override
  String get appearanceSpectrumSubtitle =>
      'Experimental — living bars beneath the interface';

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
  String get callLinkGroupCall => 'Group call';

  @override
  String get callLinkSendInMax => 'Send in MAX';

  @override
  String get callLinkStart => 'Start call';

  @override
  String get callLinkSent => 'Link sent';

  @override
  String get callLinkSendFailed => 'Couldn\'t send the link';

  @override
  String get callLinkCreateFailed => 'Couldn\'t create the call';

  @override
  String get callParticipantYou => 'You';

  @override
  String get callParticipantFallback => 'Participant';

  @override
  String get callTooltipMinimize => 'Minimize';

  @override
  String get callTooltipExpand => 'Expand';

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
  String callCameraUnavailable(Object error) {
    return 'Camera unavailable: $error';
  }

  @override
  String get callTooltipMicrophone => 'Microphone';

  @override
  String get callMicrophoneTitle => 'Microphone';

  @override
  String get callMicrophoneSystem => 'System default';

  @override
  String get callMicrophoneEmpty => 'No microphones found';

  @override
  String get callMicrophoneRefresh => 'Refresh list';

  @override
  String get callMicrophoneMonitors => 'Monitors — system audio';

  @override
  String callMicrophoneFallback(Object index) {
    return 'Microphone $index';
  }

  @override
  String callMicrophoneFailed(Object error) {
    return 'Could not switch microphone: $error';
  }

  @override
  String get callMicStillLive => 'Still live';

  @override
  String get callNoMuteHint =>
      '--no-mute: audio keeps going out even while the mic is off';

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
  String get contactProfileActionAddContact => 'Add to contacts';

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
  String contactIdFallback(String id) {
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
  String photoViewerCounter(int index, int total) {
    return 'Photo $index of $total';
  }

  @override
  String photoViewerCounterFile(int total) {
    return 'FILE of $total';
  }

  @override
  String photoViewerSentToday(String sender, String time) {
    return '$sender • today at $time';
  }

  @override
  String photoViewerSentOn(String sender, String date, String time) {
    return '$sender • $date at $time';
  }

  @override
  String get photoViewerSaveAs => 'Save as…';

  @override
  String get photoViewerSaveToGallery => 'Save to gallery';

  @override
  String get photoViewerViewAll => 'View all photos';

  @override
  String get photoViewerRotate => 'Rotate';

  @override
  String mediaViewerCounter(int index, int total) {
    return '$index of $total';
  }

  @override
  String get mediaViewerViewAll => 'View all media';

  @override
  String get videoViewerSettings => 'Settings';

  @override
  String get videoViewerSpeed => 'Speed';

  @override
  String get videoViewerQuality => 'Quality';

  @override
  String get videoViewerFailed => 'Could not play the video';

  @override
  String get videoViewerRetry => 'Retry';

  @override
  String get videoViewerClose => 'Close';

  @override
  String get sharedCopyLink => 'Copy link';

  @override
  String get sharedLinkCopied => 'Link copied';

  @override
  String get chatInfoActionLeave => 'Leave';

  @override
  String get chatInfoActionSubscribe => 'Subscribe';

  @override
  String get chatInfoSubscribed => 'You subscribed to the channel';

  @override
  String get chatInfoSubscribeFailed => 'Could not subscribe to the channel';

  @override
  String get chatInfoActionJoin => 'Join';

  @override
  String get chatInfoJoinedGroup => 'You joined the group';

  @override
  String get chatInfoJoinGroupFailed => 'Could not join the group';

  @override
  String get chatInfoActionMuted => 'Muted';

  @override
  String get chatInfoNotificationsOn => 'Notifications on';

  @override
  String get chatInfoNotificationsOff => 'Notifications off';

  @override
  String get chatInfoMenuBlock => 'Block';

  @override
  String get chatInfoMenuUnblock => 'Unblock';

  @override
  String get chatInfoMenuDeleteChat => 'Delete chat';

  @override
  String get chatInfoMenuClearHistory => 'Clear history';

  @override
  String get chatInfoClearHistoryTitle => 'Clear history';

  @override
  String get chatInfoClearHistoryMessage =>
      'All messages in this chat will be deleted permanently.';

  @override
  String get chatInfoClearHistoryForAll => 'For everyone';

  @override
  String get chatInfoClearHistoryConfirm => 'Clear';

  @override
  String get chatInfoClearHistoryDone => 'History cleared';

  @override
  String get chatInfoDeleteChatTitle => 'Delete chat';

  @override
  String get chatInfoDeleteChatMessage =>
      'The chat will be deleted together with the whole conversation.';

  @override
  String get chatInfoDeleteChatConfirm => 'Delete';

  @override
  String get chatInfoLeaveGroupTitle => 'Leave group';

  @override
  String get chatInfoLeaveGroupMessage =>
      'You will no longer receive messages from this group.';

  @override
  String get chatInfoLeaveChannelTitle => 'Leave channel';

  @override
  String get chatInfoLeaveChannelMessage =>
      'You will no longer receive posts from this channel.';

  @override
  String get chatInfoLeaveConfirm => 'Leave';

  @override
  String get chatInfoLeaveFailed => 'Could not leave the chat';

  @override
  String get chatInfoCallConfirmTitle => 'Start a call';

  @override
  String chatInfoCallConfirmMessage(String name) {
    return 'Call $name?';
  }

  @override
  String get chatInfoConfirmYes => 'Yes';

  @override
  String get chatInfoConfirmNo => 'No';

  @override
  String get chatInfoCallFailed => 'Could not start the call';

  @override
  String get chatInfoBlockConfirmTitle => 'Block';

  @override
  String chatInfoBlockConfirmMessage(String name) {
    return 'Are you sure you want to block $name?';
  }

  @override
  String get chatInfoBlockDone => 'User blocked';

  @override
  String get chatInfoUnblockDone => 'User unblocked';

  @override
  String get chatInfoBlockFailed => 'Could not change the block state';

  @override
  String get chatInfoComplaintTitle => 'Report';

  @override
  String get chatInfoComplaintSubtitle => 'Choose a reason for the report';

  @override
  String get chatInfoComplaintSend => 'Report';

  @override
  String get chatInfoComplaintClose => 'Close';

  @override
  String get chatInfoComplaintEmpty => 'Could not load the report reasons';

  @override
  String get chatInfoComplaintSent => 'Report sent';

  @override
  String get chatInfoComplaintFailed => 'Could not send the report';

  @override
  String get chatInfoActionCancel => 'Cancel';

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
  String get chatInfoMemberDeleted => 'Account deleted';

  @override
  String get chatInfoInviteByLink => 'Invite via link';

  @override
  String get chatInfoInviteLinkHint => 'You can invite anyone with this link';

  @override
  String get chatInfoAddMembersAction => 'Add';

  @override
  String get chatInfoMembersSearchHint => 'Search';

  @override
  String get chatInfoAddMembersEmpty => 'No one to add';

  @override
  String get chatInfoMembersAdded => 'Members added';

  @override
  String get chatInfoAddMembersError => 'Couldn\'t add members';

  @override
  String get chatInfoNoData => 'No data';

  @override
  String get chatInfoHideExtra => 'Hide';

  @override
  String get chatInfoShowMoreExtra => 'Details';

  @override
  String get chatSendConfirmMessage => 'Send this message to the chat?';

  @override
  String get chatSendConfirmAction => 'Send';

  @override
  String get chatInfoRowDisableForward => 'Forwarding disabled';

  @override
  String get chatInfoRowCopyDisabled => 'Copying disabled';

  @override
  String get chatInfoRowOnlyAdminCall => 'Admins can call';

  @override
  String get chatInfoRowAllCanPin => 'Anyone can pin';

  @override
  String get chatInfoRowMembersSeeLink => 'Members see the link';

  @override
  String get chatInfoRowConfirmBeforeSend => 'Confirm before sending';

  @override
  String get chatInfoRowOnlyOwnerIconTitle => 'Owner edits title and icon';

  @override
  String get chatInfoRowPromotedDisabled => 'Promoted content off';

  @override
  String get chatInfoRowUserId => 'User ID';

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
  String get securityModeLocked => 'Turn off safe mode to change this setting';

  @override
  String get securityModeSheetSubtitle => 'No unwanted contact or content';

  @override
  String get securityModeSheetSearch =>
      'People won\'t be able to find you by phone number';

  @override
  String get securityModeSheetCalls =>
      'Only people from your contacts can call you';

  @override
  String get securityModeSheetInvites =>
      'Only people you\'ve already talked to can add you to groups';

  @override
  String get securityModeSheetContent =>
      'You\'ll only see safe posts and channels';

  @override
  String get securityModeSheetEnable => 'Turn on';

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
  String get securityConfidentialityWarning =>
      'These toggles do not exist in the original app, and they may be unavailable to you.\n\nIf the server refuses, it will drop the connection. (conection closed)';

  @override
  String get securityConfidentialityDecline => 'No';

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
  String get attachSheetCameraError => 'Couldn\'t open the camera';

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
  String get attachSheetMoreActions => 'More';

  @override
  String get attachSheetSendSeparately => 'Send separately';

  @override
  String get attachSheetLimitedAccessInfo => 'Not all photos are accessible';

  @override
  String get attachSheetSectionInProgress => 'Section under development';

  @override
  String get attachSheetContact => 'Contact';

  @override
  String get attachSheetContactSearchHint => 'Search contacts';

  @override
  String get attachSheetNoContacts => 'You have no contacts yet';

  @override
  String get attachSheetNoContactsFound => 'No contacts found';

  @override
  String get attachSheetNoGalleryAccessTitle => 'No access to the gallery';

  @override
  String get attachSheetNoGalleryAccessSubtitle =>
      'Allow access to photos to pick them from here';

  @override
  String get attachSheetAllow => 'Allow';

  @override
  String get attachSheetGalleryFailedTitle => 'Could not load the gallery';

  @override
  String get attachSheetRetry => 'Retry';

  @override
  String get attachSheetSettings => 'Settings';

  @override
  String get attachSheetAddCaptionHint => 'Add a caption...';

  @override
  String get attachSheetCamera => 'Camera';

  @override
  String get attachSheetCameraAllow => 'Allow camera';

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
  String get fontSettingsPickFile => 'Choose file';

  @override
  String get fontSettingsPickFileHint => 'A .ttf, .otf or .ttc font';

  @override
  String get fontSettingsNotAFont => 'This is not a font file';

  @override
  String get fontSettingsCancel => 'Cancel';

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

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateUpToDate => 'You have the latest version';

  @override
  String get updateCheckFailed =>
      'Couldn\'t check for updates. Try again later';

  @override
  String get profileResurrecting =>
      'Oops! The server didn\'t send your profile. Trying to regenerate…';

  @override
  String get profilePhoneRegenFailed =>
      'Couldn\'t regenerate your phone number. Please sign in again and report the issue to the developers';

  @override
  String get addContactTitle => 'Add contact';

  @override
  String get addContactFirstName => 'First name';

  @override
  String get addContactLastName => 'Last name (optional)';

  @override
  String get addContactSave => 'Save contact';

  @override
  String addContactNotFound(String phone) {
    return '$phone not found';
  }

  @override
  String get addContactNotFoundSubtitle => 'This number isn\'t on the app yet';

  @override
  String get addContactSearchOther => 'Search for other number';

  @override
  String get addContactError => 'Couldn\'t add contact';

  @override
  String get contactBubbleNew => 'New contact';

  @override
  String get contactBubbleAlreadyAdded => 'Already in your contacts';

  @override
  String get contactBubbleOpenProfile => 'Open profile';

  @override
  String get miniAppOpen => 'Open';

  @override
  String get miniAppFailed => 'Couldn\'t open the app';

  @override
  String get editContactMenu => 'Edit contact';

  @override
  String get editContactTitle => 'Edit contact';

  @override
  String get editContactFirstName => 'First name';

  @override
  String get editContactLastName => 'Last name';

  @override
  String get editContactSave => 'Save';

  @override
  String get editContactDelete => 'Delete contact';

  @override
  String get editContactDeleteConfirmTitle => 'Delete contact?';

  @override
  String get editContactDeleteConfirmBody =>
      'This contact will be removed from your list.';

  @override
  String get editContactDeleteCancel => 'Cancel';

  @override
  String get editContactError => 'Couldn\'t save changes';

  @override
  String get downloadsTitle => 'Recent downloads';

  @override
  String get downloadsTooltip => 'Downloads';

  @override
  String get downloadsSettings => 'Settings';

  @override
  String get downloadsEmpty => 'Downloaded files will appear here';

  @override
  String get downloadsUnknownSource => 'Unknown source';

  @override
  String get downloadsPhoto => 'Photo';

  @override
  String get downloadsVideo => 'Video';

  @override
  String get downloadsGif => 'GIF';

  @override
  String get downloadsAudio => 'Audio';

  @override
  String get downloadsFile => 'File';

  @override
  String get downloadsOpenFailed => 'Couldn\'t open the file';

  @override
  String get audioPlaybackChannel => 'Audio playback';

  @override
  String get audioPlaybackFailed => 'Couldn\'t play the file';

  @override
  String get downloadsClearHistory => 'Clear download history';

  @override
  String get downloadsClearTitle => 'Clear download history?';

  @override
  String get downloadsClearBody =>
      'The files will stay on the device, but this list will be cleared.';

  @override
  String get downloadsClearConfirm => 'Clear';

  @override
  String get downloadsHistoryCleared => 'Download history cleared';

  @override
  String uploadNotificationPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: 'Photo',
    );
    return '$_temp0';
  }

  @override
  String get uploadNotificationVideo => 'Video';

  @override
  String get uploadNotificationVideoNote => 'Video message';

  @override
  String get uploadNotificationVoice => 'Voice message';

  @override
  String get uploadNotificationFile => 'File';

  @override
  String uploadNotificationMultiple(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sending $count files',
    );
    return '$_temp0';
  }

  @override
  String get uploadNotificationPreparing => 'Preparing…';

  @override
  String uploadSpeedBytes(String value) {
    return '$value B/s';
  }

  @override
  String uploadSpeedKb(String value) {
    return '$value KB/s';
  }

  @override
  String uploadSpeedMb(String value) {
    return '$value MB/s';
  }

  @override
  String get savedMessagesEmptyPreview => 'Save something here';

  @override
  String proxyCurrentState(String value) {
    return 'Currently: $value';
  }

  @override
  String get blacklistEmpty => 'Nobody is blocked';

  @override
  String get joinRequestsTitle => 'Join requests';

  @override
  String get joinRequestsEmpty => 'No pending requests';

  @override
  String get joinRequestsApprove => 'Approve';

  @override
  String get joinRequestsDecline => 'Decline';

  @override
  String get joinRequestsApproved => 'Request approved';

  @override
  String get joinRequestsDeclined => 'Request declined';

  @override
  String get joinRequestsActionFailed => 'Failed, try again';

  @override
  String get joinRequestsLoadError => 'Failed to load requests';

  @override
  String get blacklistLoadError => 'Failed to load the blacklist';

  @override
  String get videoEditorQualityLow => 'Small size';

  @override
  String get videoEditorQualityHigh => 'High quality';

  @override
  String get videoEditorCaptionHint => 'Add a caption...';

  @override
  String get videoEditorMuteTooltip => 'Send without sound';

  @override
  String get videoEditorProcessing => 'Processing video…';

  @override
  String get videoEditorExportFailed => 'Failed to process the video';

  @override
  String get videoEditorFrameFailed => 'Failed to grab a frame';

  @override
  String get videoEditorQualityTooltip => 'Quality';

  @override
  String get webPushTitle => 'Notifications on iOS';

  @override
  String get webPushIntro =>
      'Komet has no ordinary push on iOS: Apple issues a notification token only to apps signed with a developer certificate, and a sideloaded build never gets one.\n\nThe way around it is a web app on the Home Screen. MAX\'s own server sends the notifications through Apple, and a separate icon displays them.\n\nThat needs a web session. Komet creates one and approves it itself, from this very device — no phone number or code required.';

  @override
  String get webPushConfirm => 'Continue';

  @override
  String get webPushPasswordExplainer =>
      'Two-factor protection is enabled on this account.';

  @override
  String webPushPasswordHintLabel(String hint) {
    return 'Hint: $hint';
  }

  @override
  String get webPushPasswordHint => 'Password';

  @override
  String get webPushInstallTitle => 'Install the web app';

  @override
  String get webPushInstallBody =>
      'Open push.komet.pw in Safari, add it to the Home Screen and launch the icon that appears. Notifications do not work from a browser tab — that is how iOS works.\n\nIn the app, allow notifications, create a subscription and tap \"Open Komet\". The subscription registers itself from there.';

  @override
  String get webPushLinkedTitle => 'Notifications connected';

  @override
  String get webPushLinkedBody =>
      'The subscription is registered on the server. Do not delete the Home Screen icon — the notifications go with it.\n\nIf push stops arriving, open the web app and link again: Apple sometimes rotates the subscription address.';

  @override
  String get webPushOpenSite => 'Open push.komet.pw';

  @override
  String get webPushSignOut => 'Disconnect notifications';

  @override
  String get webPushLinked => 'Notifications connected';

  @override
  String webPushLinkFailed(String error) {
    return 'Could not connect notifications: $error';
  }

  @override
  String get webPushNotAuthorized =>
      'Sign in under \"Notifications via PWA\" first';

  @override
  String get webPushConnect => 'Connect notifications';

  @override
  String get webPushWaitingBody =>
      'Komet is approving the web session from this device. This usually takes a few seconds.';

  @override
  String get webPushNeedsOnline =>
      'No connection to the server. Wait for it and try again.';

  @override
  String get webPushSignOutConfirm =>
      'The web session will be terminated and disappear from your device list. To get notifications back you will have to connect again.';

  @override
  String get webPushSignOutAction => 'Disconnect';

  @override
  String get webPushStatusService => 'Service';

  @override
  String get webPushStatusToken => 'Token';

  @override
  String get webPushStatusLinkedAt => 'Linked';

  @override
  String get webPushStatusDevice => 'Device';

  @override
  String get securityDeleteProfileTitle => 'Delete profile';

  @override
  String get securityDeleteProfileSubtitle =>
      'The profile and all its data are removed after 30 days';

  @override
  String get securityDeleteProfileConfirmTitle => 'Delete profile?';

  @override
  String get securityDeleteProfileConfirmMessage =>
      'Your MAX profile will be deleted in 30 days. You can cancel the request at any time before that.';

  @override
  String get securityDeleteProfileConfirmAction => 'Delete';

  @override
  String securityDeleteProfileScheduled(String date) {
    return 'Profile will be deleted on $date';
  }

  @override
  String get securityDeleteProfileKeep => 'Don\'t delete profile';

  @override
  String get securityDeleteProfileRequested => 'Deletion request accepted';

  @override
  String get securityDeleteProfileCanceled => 'Profile deletion canceled';

  @override
  String securityDeleteProfileError(String error) {
    return 'Failed to send the request: $error';
  }

  @override
  String get composerPasteAttachment => 'Paste file';

  @override
  String get pasteAttachTitleImage => 'Send image';

  @override
  String get pasteAttachTitleVideo => 'Send video';

  @override
  String get pasteAttachTitleFile => 'Send file';

  @override
  String pasteAttachTitleMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count files',
      one: 'Send 1 file',
    );
    return '$_temp0';
  }

  @override
  String get pasteAttachCaptionHint => 'Caption';

  @override
  String get pasteAttachSend => 'Send';

  @override
  String get pasteAttachCancel => 'Cancel';

  @override
  String get pasteAttachFailed => 'Nothing to paste from the clipboard';

  @override
  String get profileQrTitle => 'My QR code';

  @override
  String get profileQrHint => 'Scan the code to open the profile';

  @override
  String get profileQrUnavailable => 'Could not get the profile link';

  @override
  String get authLimitsLoginTitle => 'Account temporarily limited';

  @override
  String authLimitsLoginSubtitle(DateTime until) {
    final intl.DateFormat untilDateFormat = intl.DateFormat(
      'MMMM d, HH:mm',
      localeName,
    );
    final String untilString = untilDateFormat.format(until);

    return 'The limits should lift around $untilString';
  }

  @override
  String get authLimitsLogin2faTitle => 'Two-factor authentication';

  @override
  String get authLimitsLogin2faBody =>
      'You can\'t set or remove the login password.';

  @override
  String get authLimitsLoginSessionsTitle => 'Ending sessions';

  @override
  String get authLimitsLoginSessionsBody =>
      'You can\'t end all sessions at once.';

  @override
  String get authLimitsSignupTitle => 'Account may be limited';

  @override
  String get authLimitsSignupSubtitle =>
      'New accounts aren\'t all limited, and the server lifts the limits itself';

  @override
  String get authLimitsSignupMessagesTitle => 'Messages';

  @override
  String get authLimitsSignupMessagesBody =>
      'You may only be able to write to people who already have you in their contacts.';

  @override
  String get authLimitsSignupGroupsTitle => 'Groups';

  @override
  String get authLimitsSignupGroupsBody => 'Joining groups may be unavailable.';

  @override
  String get authLimitsSignupMoreTitle => 'Other limits are possible';

  @override
  String get authLimitsSignupMoreBody =>
      'The server doesn\'t announce the full list — if something doesn\'t work, try again later.';

  @override
  String get authLimitsConfirm => 'Got it';

  @override
  String get e2eeTitle => 'End-to-end encryption';

  @override
  String get e2eeStatusNone => 'Off';

  @override
  String e2eeStatusOffered(String name) {
    return 'Waiting for $name to accept';
  }

  @override
  String e2eeStatusPending(String name) {
    return '$name wants to turn on encryption';
  }

  @override
  String get e2eeStatusEstablished => 'On';

  @override
  String e2eeStatusKeyChanged(String name) {
    return '$name\'s encryption key has changed';
  }

  @override
  String get e2eeEnable => 'Turn on';

  @override
  String get e2eeAccept => 'Accept';

  @override
  String get e2eeDecline => 'Decline';

  @override
  String get e2eeCancelOffer => 'Cancel request';

  @override
  String get e2eeReset => 'Reset session';

  @override
  String get e2eeResetConfirm =>
      'Reset the encrypted session? Both sides will need to set it up again.';

  @override
  String get e2eeFingerprint => 'Safety number';

  @override
  String e2eeFingerprintHint(String name) {
    return 'Compare these 60 digits with $name outside MAX — in person or over another channel. If they match, the server did not substitute the keys.';
  }

  @override
  String get e2eeVerified => 'Verified in person';

  @override
  String get e2eeCeiling =>
      'Only message text and photos are encrypted. The server still sees who talks to whom and when, sees that the chat is encrypted, and can withhold messages. Nothing here hides that.';

  @override
  String e2eeNeedsKomet(String name) {
    return '$name needs Komet for this to work.';
  }

  @override
  String get e2eeOfferSent => 'Request sent';

  @override
  String get e2eeOfferFailed => 'Could not send the request';

  @override
  String get e2eeAcceptFailed => 'Could not accept the request';

  @override
  String e2eeBannerPending(String name) {
    return '$name wants to turn on end-to-end encryption';
  }

  @override
  String e2eeBannerKeyChanged(String name) {
    return '$name\'s encryption key has changed. Check the safety number before accepting.';
  }

  @override
  String get e2eeTransferTitle => 'Move to another device';

  @override
  String get e2eeTransferHint =>
      'The transfer file holds your key and sessions. After importing it on the new device, stop using this one for encrypted chats.';

  @override
  String get e2eeExport => 'Export';

  @override
  String get e2eeImport => 'Import';

  @override
  String get e2eeTransferPassword => 'Transfer password';

  @override
  String get e2eeExportFailed => 'Could not export';

  @override
  String e2eeImported(int count) {
    return 'Sessions moved: $count';
  }

  @override
  String get e2eeImportFailed =>
      'Could not import — wrong password or damaged file';

  @override
  String get e2eeLegacyNote =>
      'Passphrase mode for groups: no forward secrecy, anyone who knows the passphrase can read the whole history.';

  @override
  String get e2eeTooLong =>
      'The message is too long for an encrypted chat. Split it up.';

  @override
  String get e2eeEncryptFailed => 'Could not encrypt the message';

  @override
  String get e2eeRotateIdentity => 'Replace my key';

  @override
  String get e2eeRotateConfirm =>
      'Create a new identity key? Every encrypted session will be reset, your contacts will see a key-change warning, and the safety numbers will change.';

  @override
  String get e2eeRotated => 'Key replaced';

  @override
  String get e2eeRotateFailed => 'Could not replace the key';

  @override
  String get e2eeForwardBlocked =>
      'Forwarding is off in an encrypted chat: the server, not your device, would supply the message text.';

  @override
  String get e2eeEditUnavailable =>
      'This message can\'t be decrypted on this device, so it can\'t be edited.';

  @override
  String get e2eeScheduledMediaBlocked =>
      'Scheduled photos are not supported in an encrypted chat yet. Send them now, or turn encryption off.';

  @override
  String get e2eeSearchBlocked =>
      'Search is off in an encrypted chat: the query would go to the server, and the server only sees ciphertext.';

  @override
  String get e2eeAwaitingPeer =>
      'This session was moved from another device. Wait for one message from your contact before sending — otherwise both devices would use the same key.';

  @override
  String e2eeBannerRehandshake(String name) {
    return '$name is turning encryption on again. Accept only if you expected this — otherwise the server is replaying an old request to reset your session.';
  }

  @override
  String get e2eeExportedAndDisabled =>
      'Transfer created. Encryption is now off on this device: import the file on the new one and turn it on there.';

  @override
  String get chatNoAccessMessage => 'You don\'t have access to this chat';

  @override
  String get chatNoAccessOk => 'OK';

  @override
  String get chatEmptyTitle => 'No messages yet';

  @override
  String get chatGreetingHint => 'Write a message or send this sticker';

  @override
  String get chatCallBannerTitle => 'Call in chat';

  @override
  String get chatVideoCallBannerTitle => 'Video call in chat';

  @override
  String chatCallParticipants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
  }

  @override
  String get chatCallJoin => 'Join';

  @override
  String get composerHintMessage => 'Message';

  @override
  String get composerHintComment => 'Comment';

  @override
  String get composerHintCommandArgs => 'Fill in the command arguments';

  @override
  String get emojiPanelRecent => 'Recent';

  @override
  String get emojiPanelAnimated => 'Animated';

  @override
  String get attachmentFileFallback => 'File';

  @override
  String get attachmentContactFallback => 'Contact';

  @override
  String userFallbackName(Object id) {
    return 'User #$id';
  }

  @override
  String get devicesUnknownValue => 'Unknown';

  @override
  String infoLoadError(Object error) {
    return 'Error: $error';
  }

  @override
  String get chatInfoTabInfo => 'Info';

  @override
  String get callInfoConversationId => 'Conversation ID';

  @override
  String get chatQrTitle => 'QR code';

  @override
  String get chatQrHint => 'Scan the code to open this chat';

  @override
  String get linkQrUnavailable => 'Couldn\'t get the link';

  @override
  String get notificationsDesktopNote =>
      'Notifications aren\'t shown on the computer yet. The settings below are your account\'s push settings for phones.';

  @override
  String get fileNoAppToOpen =>
      'No app on this device can open this file. Choose where to send it.';

  @override
  String get lockTitle => 'Enter your passcode';

  @override
  String get lockBiometricReason => 'Unlock Komet';

  @override
  String lockBlocked(String time) {
    return 'Too many attempts. Try again in $time';
  }

  @override
  String lockAttemptsLeft(int count) {
    return 'Wrong passcode. Attempts left: $count';
  }

  @override
  String get lockNow => 'Lock Komet';

  @override
  String get passcodeTitle => 'Passcode';

  @override
  String get passcodeCreate => 'Create a passcode';

  @override
  String get passcodeRepeat => 'Repeat the passcode';

  @override
  String get passcodeMismatch => 'The passcodes didn\'t match, try again';

  @override
  String get passcodeDigitsHint => 'Four digits';

  @override
  String get passcodeEnable => 'Turn passcode on';

  @override
  String get passcodeEnabled => 'Passcode is on';

  @override
  String get passcodeChanged => 'Passcode changed';

  @override
  String get passcodeChange => 'Change passcode';

  @override
  String get passcodeBiometric => 'Unlock with biometrics';

  @override
  String get passcodeBiometricHint =>
      'Fingerprint or face instead of the passcode';

  @override
  String get passcodeAutoLock => 'Auto-lock';

  @override
  String get passcodeAutoLockHint =>
      'Lock Komet when you don\'t touch it for a while';

  @override
  String get passcodeAutoLockOff => 'Off';

  @override
  String passcodeAutoLockAfter(int minutes) {
    return 'After $minutes min';
  }

  @override
  String get passcodeDisable => 'Turn passcode off';

  @override
  String get passcodeDisableTitle => 'Turn passcode off?';

  @override
  String get passcodeDisableMessage =>
      'Komet will open without asking for the passcode.';

  @override
  String get passcodeDisableAction => 'Turn off';

  @override
  String get passcodeCancel => 'Cancel';

  @override
  String get passcodeDisabled => 'Passcode is off';

  @override
  String get passcodeOnDescription =>
      'Komet asks for the passcode every time you open it. The lock in the chat list header locks it right away.';

  @override
  String get passcodeOffDescription =>
      'Protect your chats: Komet will ask for a passcode every time you open it.';

  @override
  String get passcodeForgotHint =>
      'If you forget the passcode, you\'ll have to clear Komet\'s data or reinstall it and sign in again. After five wrong attempts input is blocked for five minutes.';

  @override
  String get mediaDevicesTitle => 'Camera and microphone';

  @override
  String get mediaDevicesMicrophone => 'Microphone';

  @override
  String get mediaDevicesMicrophoneHint => 'Used for calls and voice messages';

  @override
  String get mediaDevicesCamera => 'Camera';

  @override
  String get mediaDevicesCameraHint =>
      'Used for calls and, if you like, for video messages';

  @override
  String get mediaDevicesSystemMicrophone => 'System microphone';

  @override
  String get mediaDevicesSystemCamera => 'System camera';

  @override
  String mediaDevicesCameraFallback(int number) {
    return 'Camera $number';
  }

  @override
  String get mediaDevicesFront => 'Front';

  @override
  String get mediaDevicesBack => 'Rear';

  @override
  String get mediaDevicesVideoNotes => 'Video messages';

  @override
  String get mediaDevicesVideoNoteCustom => 'My camera';

  @override
  String get mediaDevicesVideoNoteCustomHint =>
      'Record video messages with the camera chosen above';

  @override
  String get mediaDevicesVideoNoteCustomMissing =>
      'Choose a camera above, until then the system one is used';

  @override
  String get mediaDevicesVideoNoteRear => 'Start with the rear camera';

  @override
  String get mediaDevicesVideoNoteRearHint =>
      'Otherwise a video message starts with the front camera';

  @override
  String get chatPreviewMarkRead => 'Mark as read';

  @override
  String get chatPreviewOpen => 'Open';

  @override
  String get attachSheetSendAsVideoNote => 'Send as video message';

  @override
  String attachSheetVideoNoteTooLong(int seconds) {
    return 'A video message can\'t be longer than $seconds s';
  }

  @override
  String get undoAction => 'Undo';

  @override
  String get undoContinue => 'Continue';

  @override
  String get undoMessageUnpinned => 'You unpinned the message';

  @override
  String undoMessagesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages deleted',
      one: 'Message deleted',
    );
    return '$_temp0';
  }

  @override
  String undoChatsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats deleted',
      one: 'Chat deleted',
    );
    return '$_temp0';
  }

  @override
  String undoChatsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats archived',
      one: 'Chat archived',
    );
    return '$_temp0';
  }

  @override
  String undoChatsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats unarchived',
      one: 'Chat unarchived',
    );
    return '$_temp0';
  }

  @override
  String get undoLeftGroup => 'You left the group';

  @override
  String get undoLeftChannel => 'You left the channel';

  @override
  String get forwardHideSender => 'Hide sender\'s name';

  @override
  String get forwardShowSender => 'Show sender\'s name';

  @override
  String get forwardHideSenderUnavailable =>
      'Polls, calls and service messages can only be forwarded with the sender\'s name';

  @override
  String get forwardWithoutSender => 'Forward without sender';

  @override
  String forwardWithoutSenderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Forward without sender: $count messages',
      one: 'Forward without sender: 1 message',
    );
    return '$_temp0';
  }

  @override
  String get adminsTitle => 'Admins';

  @override
  String get channelFollowersTitle => 'Followers';

  @override
  String get channelStatsTitle => 'Channel statistics';

  @override
  String get channelStatsUnavailable =>
      'Channel statistics aren\'t available yet';

  @override
  String get adminsAdd => 'Add admin';

  @override
  String get channelPickAdminTitle => 'Choose a follower';

  @override
  String get adminsPickEmpty => 'No followers to appoint';

  @override
  String get membersSearchHint => 'Search by name';

  @override
  String adminRoleYou(String role) {
    return '$role (you)';
  }

  @override
  String get channelAddFollowers => 'Add followers';

  @override
  String get channelFollowersEmpty => 'No followers yet';

  @override
  String get membersLoadFailed => 'Couldn\'t load the list';

  @override
  String get adminAppointTitle => 'Appoint admin';

  @override
  String get adminEditTitle => 'Admin rights';

  @override
  String get channelRightEditChannel => 'Edit channel';

  @override
  String get adminRightEditInfoHint => 'Photo, name, description';

  @override
  String get channelRightCreatePosts => 'Create posts';

  @override
  String get channelRightEditPosts => 'Edit other people\'s posts';

  @override
  String get channelRightDeletePosts => 'Delete other people\'s posts';

  @override
  String get channelRightPinPosts => 'Pin posts';

  @override
  String get channelRightManageFollowers => 'Add and remove followers';

  @override
  String get channelRightViewStats => 'View channel stats';

  @override
  String get adminRightManageAdmins => 'Appoint and remove admins';

  @override
  String get adminRightManageAdminsHint =>
      'Will only be able to remove admins they appointed themselves';

  @override
  String get adminAppointAction => 'Appoint as admin';

  @override
  String get adminSave => 'Save';

  @override
  String get adminAppointed => 'Admin appointed';

  @override
  String get adminSaved => 'Rights saved';

  @override
  String get ownershipTransfer => 'Transfer ownership';

  @override
  String ownershipTransferConfirm(String name) {
    return '$name will become the new owner.';
  }

  @override
  String get ownershipTransferAction => 'Transfer';

  @override
  String get ownershipTransferred => 'Ownership transferred';

  @override
  String get adminRemove => 'Remove from admins';

  @override
  String adminRemoveConfirm(String name) {
    return '$name will no longer be an admin.';
  }

  @override
  String get adminRemoveAction => 'Remove';

  @override
  String get adminRemoved => 'Removed from admins';

  @override
  String get adminActionFailed => 'Couldn\'t apply the change';

  @override
  String get channelInviteSendInMax => 'Send in MAX';

  @override
  String get channelInviteShowQr => 'Show QR code';

  @override
  String get channelInviteRevoke => 'Revoke link';

  @override
  String get channelInviteRevokeConfirm =>
      'The current link will stop working. People will be able to join only with the new one.';

  @override
  String get channelInviteRevokeAction => 'Revoke';

  @override
  String get channelInviteRevoked => 'New link created';

  @override
  String get channelJoinRequests => 'Join requests';

  @override
  String get channelJoinRequestsHint =>
      'The channel can only be joined after an admin approves the request';

  @override
  String get groupPickAdminTitle => 'Choose a member';

  @override
  String get groupRightEditInfo => 'Edit chat';

  @override
  String get groupRightDeleteMessages => 'Delete messages';

  @override
  String get groupRightPinMessages => 'Pin messages';

  @override
  String get groupRightManageMembers => 'Add and remove members';

  @override
  String get groupRightEditLink => 'Update chat link';

  @override
  String get groupSettingsTitle => 'Group settings';

  @override
  String get groupSettingsName => 'Chat name';

  @override
  String get groupSettingsDescription => 'Chat description';

  @override
  String get groupSettingsSaved => 'Changes saved';

  @override
  String get groupSettingsPhotoUpdated => 'Photo updated';

  @override
  String get groupSettingsPhotoTooLarge => 'The image is too large (8 MB max)';

  @override
  String get groupSettingsLeave => 'Leave chat';

  @override
  String get reactionsTitle => 'Reactions';

  @override
  String get reactionsSummaryAll => 'All';

  @override
  String get reactionsSummaryOff => 'Off';

  @override
  String reactionsSummaryCount(int allowed, int total) {
    return '$allowed of $total';
  }

  @override
  String get reactionsEnable => 'Enable reactions';

  @override
  String get reactionsCountHeader => 'Reactions per message';

  @override
  String reactionsCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reactions',
      one: '1 reaction',
    );
    return '$_temp0';
  }

  @override
  String get reactionsAllowedHeader => 'Allowed reactions';

  @override
  String get reactionsEdit => 'Edit';

  @override
  String get reactionsDone => 'Done';

  @override
  String get reactionsReset => 'Reset reaction settings';

  @override
  String get reactionsLoadFailed => 'Couldn\'t load reaction settings';

  @override
  String get reactionsNoneAllowed => 'Keep at least one reaction';

  @override
  String get memberPermissionsTitle => 'Member permissions';

  @override
  String get memberPermissionEditInfo =>
      'Change the chat name, photo and description';

  @override
  String get memberPermissionAddMembers => 'Add members';

  @override
  String get memberPermissionPin => 'Pin messages';

  @override
  String get memberPermissionInvite => 'Invite via link';

  @override
  String get memberPermissionCall => 'Call in the chat';

  @override
  String get ownerLeaveTitle => 'You\'re the owner';

  @override
  String get ownerLeaveChannelMessage =>
      'To leave the channel, first transfer ownership to another follower.';

  @override
  String get ownerLeaveGroupMessage =>
      'To leave the group, first transfer ownership to another member.';

  @override
  String get ownershipPickTitle => 'New owner';

  @override
  String get ownershipPickEmpty => 'No one to transfer ownership to';

  @override
  String get forwardOneTitle => 'Forward message';

  @override
  String forwardBatchTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Forward $count messages',
      one: 'Forward 1 message',
    );
    return '$_temp0';
  }

  @override
  String get forwardCommentHint => 'Add a comment...';

  @override
  String get forwardOffline => 'No connection';

  @override
  String get forwardFailed => 'Couldn\'t forward';

  @override
  String forwardDelivered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Forwarded to $count chats',
      one: 'Forwarded to 1 chat',
    );
    return '$_temp0';
  }

  @override
  String forwardDeliveredPartly(int delivered, int failed) {
    return 'Forwarded to $delivered, failed for $failed';
  }

  @override
  String get reactionUnavailable => 'This reaction isn\'t allowed in this chat';

  @override
  String get membersSearchMore => 'Search the rest';

  @override
  String get groupRestrictionsTitle => 'Restrictions';

  @override
  String get groupRestrictionForward => 'Disable forwarding';

  @override
  String get groupRestrictionForwardHint =>
      'Messages from this chat can\'t be forwarded';

  @override
  String get groupRestrictionCopy => 'Disable copying';

  @override
  String get groupRestrictionCopyHint => 'Message text can\'t be copied';

  @override
  String get groupRestrictionConfirmSend => 'Confirm before sending';

  @override
  String get groupRestrictionConfirmSendHint =>
      'Every message asks for confirmation before it is sent';

  @override
  String get notificationsBadgeSectionTitle => 'App icon badge';

  @override
  String get notificationsBadgeLabel => 'Show unread count';

  @override
  String get notificationsBadgeMutedLabel => 'Include muted chats';

  @override
  String get notificationsBadgeMessagesLabel => 'Count messages';

  @override
  String get notificationsBadgeMessagesSubtitle =>
      'Off — count unread chats instead';

  @override
  String get accountSwitchFailed => 'Couldn\'t switch account';

  @override
  String get accountSessionLostTitle => 'Sign in again';

  @override
  String accountSessionLostBody(String name) {
    return 'The session of “$name” is no longer valid on this device.';
  }

  @override
  String get accountSessionLostSignIn => 'Sign in';

  @override
  String get accountSessionLostRemove => 'Remove from device';

  @override
  String get accountSessionLostRemoved => 'Account removed from this device';

  @override
  String get contactsSearchHint => 'Search contacts';

  @override
  String get contactsSearchEmpty => 'Nothing found';

  @override
  String get contactsNfcExchange => 'NFC exchange';

  @override
  String get contactsFindUser => 'Add contact';

  @override
  String get contactDeleted => 'Contact deleted';

  @override
  String get contactDeleteFailed => 'Couldn\'t delete the contact';

  @override
  String get contactLocalPhotoChoose => 'Choose photo';

  @override
  String get contactLocalPhotoReset => 'Restore profile photo';

  @override
  String get contactLocalPhotoSaved => 'Photo is visible only to you';

  @override
  String get contactLocalPhotoFailed => 'Couldn\'t process the image';

  @override
  String get contactLocalPhotoTooLarge => 'Image is too large (max 8 MB)';

  @override
  String get channelTypeTitle => 'Channel type and link';

  @override
  String get channelCreatedTitle => 'Private channel created';

  @override
  String get channelCreatedSubtitle => 'It is ready to be set up';

  @override
  String get channelTypePrivate => 'Private';

  @override
  String get channelTypePrivateHint => 'The channel is available by link only';

  @override
  String get channelTypePublic => 'Public';

  @override
  String get channelTypePublicHint => 'The channel can be found in search';

  @override
  String get channelTypePublicUnavailable =>
      'Public channels are not available yet';

  @override
  String get channelInviteLinkCaption => 'Invite link to your channel';

  @override
  String get channelBusinessTitle => 'Public for business';

  @override
  String get channelBusinessHint =>
      'For legal entities, individual entrepreneurs, self-employed workers and government organizations';

  @override
  String get channelSettingsTitle => 'Channel settings';

  @override
  String get channelSettingsName => 'Channel name';

  @override
  String get channelSettingsDescription => 'Channel description';

  @override
  String get channelConfirmPosting => 'Confirm before posting';

  @override
  String get channelConfirmPostingHint =>
      'To double-check the post and avoid mistakes';

  @override
  String get channelComments => 'Comments';

  @override
  String get channelCommentsEnableTitle =>
      'Comments are a part of your channel';

  @override
  String get channelCommentsEnableMessage =>
      'Make sure to monitor discussions and keep them civil: you can remove comments and restrict users';

  @override
  String get channelCommentsEnable => 'Enable';

  @override
  String get channelCommentsKeepOff => 'Don\'t enable';

  @override
  String get channelDelete => 'Delete channel';

  @override
  String get channelDeleteTitle => 'Delete the channel?';

  @override
  String get channelDeleteMessage =>
      'To prevent the channel from being deleted for all followers, you can transfer the rights to another owner';

  @override
  String get channelDeleteTransfer => 'Transfer ownership and leave';

  @override
  String get followerRemove => 'Remove';

  @override
  String get followerRemoveTitle => 'Remove follower';

  @override
  String followerRemoveConfirm(String name) {
    return '$name will no longer follow the channel.';
  }

  @override
  String get followerRemoved => 'Follower removed';

  @override
  String get channelReadyTitle => 'Channel is ready';

  @override
  String get channelReadyHint => 'Add posts and invite followers';

  @override
  String get groupReadyTitle => 'Group is ready';

  @override
  String get groupReadyHint => 'Send the first message and invite members';

  @override
  String get botStart => 'Start';

  @override
  String get memberRemoveTitle => 'Remove member';

  @override
  String memberRemoveConfirm(String name) {
    return '$name will be removed from the group.';
  }

  @override
  String get memberRemoved => 'Member removed';

  @override
  String get chatScreenReactionUpdateFailed => 'Couldn\'t update the reaction';

  @override
  String get chatScreenBotStartFailed => 'Couldn\'t start the bot';

  @override
  String get chatScreenMessageNotLoaded => 'The message isn\'t loaded';

  @override
  String get chatScreenMarkUnreadFailed => 'Couldn\'t mark as unread';

  @override
  String get chatScreenMessagePinned => 'Message pinned';

  @override
  String get chatScreenNothingToForward => 'Nothing to forward';

  @override
  String get chatScreenDeleteMessagesFailed => 'Couldn\'t delete the messages';

  @override
  String get chatScreenDeleteMessageTitle => 'Delete message';

  @override
  String get chatScreenDeleteMessageConfirm =>
      'Are you sure you want to delete this message?';

  @override
  String chatScreenDeleteAlsoFor(String name) {
    return 'Also delete for $name';
  }

  @override
  String get chatScreenMenuMute => 'Disable notifications';

  @override
  String get chatScreenMenuChangeWallpaper => 'Change wallpaper';

  @override
  String get chatScreenMenuEncryption => 'Message encryption';

  @override
  String get chatScreenChatLinkUnavailable => 'Couldn\'t get the chat link';

  @override
  String get chatScreenSubscribeFailed => 'Couldn\'t subscribe';

  @override
  String get chatScreenJoinFailed => 'Couldn\'t join';

  @override
  String get chatScreenWallpaperSaveFailed => 'Couldn\'t save the wallpaper';

  @override
  String get chatScreenCallsDialogsOnly =>
      'Calls are only available in private chats';

  @override
  String chatScreenMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String chatScreenSubscribersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscribers',
      one: '1 subscriber',
    );
    return '$_temp0';
  }

  @override
  String get chatScreenFormatHeading => 'Heading';

  @override
  String get chatScreenFormatBold => 'Bold';

  @override
  String get chatScreenFormatItalic => 'Italic';

  @override
  String get chatScreenFormatUnderline => 'Underline';

  @override
  String get chatScreenFormatStrikethrough => 'Strikethrough';

  @override
  String get chatScreenFormatMonospace => 'Monospace';

  @override
  String get chatScreenFormatQuote => 'Quote';

  @override
  String get chatScreenFormatMention => 'Mention';

  @override
  String get chatScreenMessageTooLong =>
      'The message is too long. Split it into several';

  @override
  String get chatScreenEncryptionKeyMissing => 'No encryption key is set';

  @override
  String get chatScreenPluginFilesEncryptUnsupported =>
      'Plugin files can\'t be encrypted yet';

  @override
  String chatScreenCommandMissingArgument(String name, String usage) {
    return 'Missing argument $name. Format: $usage';
  }

  @override
  String chatScreenPluginError(String error) {
    return 'Plugin error: $error';
  }

  @override
  String chatScreenCommandFillField(String name) {
    return 'Fill in the $name field';
  }

  @override
  String chatScreenScheduledFor(String when) {
    return 'Scheduled for $when';
  }

  @override
  String get chatScreenScheduleFailed => 'Couldn\'t schedule the message';

  @override
  String get chatScreenMessageNotSentYet => 'The message hasn\'t been sent yet';

  @override
  String get chatScreenChannelUnavailable => 'Channel unavailable';

  @override
  String get chatScreenChannelFallback => 'Channel';

  @override
  String get chatScreenNoEncryptFiles => 'Files can\'t be encrypted yet';

  @override
  String get chatScreenNoEncryptLocation => 'Location can\'t be encrypted yet';

  @override
  String get chatScreenNoEncryptPolls => 'Polls can\'t be encrypted yet';

  @override
  String get chatScreenNoEncryptContacts => 'Contacts can\'t be encrypted yet';

  @override
  String get stickerPackSheetRemoved => 'Sticker pack removed';

  @override
  String get stickerPackSheetAdded => 'Sticker pack added';

  @override
  String get stickerPackSheetActionFailed => 'Couldn\'t complete the action';

  @override
  String get stickerPackSheetLinkUnavailable => 'Link unavailable';

  @override
  String stickerPackSheetForwardedTo(String chat) {
    return 'Forwarded to “$chat”';
  }

  @override
  String get stickerPackSheetUnavailable => 'Sticker pack unavailable';

  @override
  String stickerPackSheetStickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stickers',
      one: '1 sticker',
    );
    return '$_temp0';
  }

  @override
  String get stickerPackSheetRemove => 'Remove';

  @override
  String get performanceScreenTitle => 'Performance';

  @override
  String get performanceScreenLowWarning =>
      'App performance may drop. Are you sure?';

  @override
  String get performanceScreenHighWarning =>
      'This is unlikely to give any noticeable FPS boost, but it may use more memory. Are you sure?';

  @override
  String get performanceScreenCacheTitle => 'Message cache';

  @override
  String get performanceScreenCacheSubtitle =>
      'How many pixels of messages to keep built outside the visible area.';

  @override
  String performanceScreenCurrentExtent(int value) {
    return 'Current cacheExtent: $value';
  }

  @override
  String get performanceScreenLessUsage => 'Lower usage';

  @override
  String get performanceScreenMoreFps => 'Higher FPS';

  @override
  String get chatWallpaperSheetImageTooLarge =>
      'The image is too large (max 16 MB)';

  @override
  String get chatWallpaperSheetTitle => 'Wallpaper';

  @override
  String get chatWallpaperSheetSampleIncoming =>
      'How about a new wallpaper for this chat?';

  @override
  String get chatWallpaperSheetSampleOutgoing => 'Looks great 🔥';

  @override
  String get chatWallpaperSheetNone => 'No wallpaper';

  @override
  String get chatWallpaperSheetYourPhoto => 'Your photo';

  @override
  String get chatWallpaperSheetFromGallery => 'From gallery';

  @override
  String get maxLinkNavChatNotFound => 'Chat not found';

  @override
  String get maxLinkNavProfileFallback => 'Profile';

  @override
  String get maxLinkNavPlatformUnsupported =>
      'This isn\'t available on your platform';

  @override
  String get maxLinkNavAppFallback => 'App';

  @override
  String get maxLinkNavNothingToSend => 'Nothing to send';

  @override
  String get maxLinkNavFolderNotFound => 'Folder not found';

  @override
  String get maxLinkNavSignInFirst => 'Sign in to an account first';

  @override
  String get pollCreateValidationHint =>
      'Enter a question and at least 2 options';

  @override
  String get pollCreateAnswersTitle => 'Answer options';

  @override
  String get pollCreateMultipleAnswers => 'Multiple answers';

  @override
  String get pollCreateAnonymous => 'Anonymous voting';

  @override
  String get pollCreateTitle => 'New poll';

  @override
  String get pollCreateSubmit => 'Create';

  @override
  String get pollCreateQuestionHint => 'Ask a question';

  @override
  String pollCreateOptionHint(int number) {
    return 'Option $number';
  }

  @override
  String get pollCreateAddOption => 'Add option';

  @override
  String get webQrLoginTitle => 'QR sign-in';

  @override
  String get webQrLoginMessage =>
      'Are you sure you want to sign in to your account on the web or in the MAX desktop app?';

  @override
  String get webQrLoginConfirmed => 'Sign-in confirmed';

  @override
  String webQrLoginFailed(String error) {
    return 'Couldn\'t confirm sign-in: $error';
  }

  @override
  String get messageActionsScreenTitle => 'Action menu';

  @override
  String get messageActionsScreenRadialDescription =>
      'An arc of buttons around the tap point';

  @override
  String get messageActionsScreenList => 'List';

  @override
  String get messageActionsScreenListDescription =>
      'A vertical menu next to the message';

  @override
  String get messageActionsScreenStyle => 'Style';

  @override
  String get messageActionsScreenStyleSubtitle =>
      'How the menu appears when you long-press a message';

  @override
  String get videoNoteBubbleTranscriptionFailed => 'Couldn\'t transcribe';

  @override
  String get webAppScreenCloseConfirm => 'Close the mini app?';

  @override
  String get voiceRecordUnsupported =>
      'Voice messages aren\'t available on this platform';

  @override
  String get voiceRecordNoMicAccess => 'No access to the microphone';

  @override
  String get voiceRecordStartFailed => 'Couldn\'t start recording';

  @override
  String get voiceRecordEncodeFailed => 'Couldn\'t encode the recording';

  @override
  String get spoofScreenFullWarningTitle => 'There may be consequences.';

  @override
  String get spoofScreenFullWarningSubtitle =>
      'Only change this if you know what you\'re doing.';

  @override
  String callScreenShareFailed(String error) {
    return 'Screen sharing didn\'t start: $error';
  }

  @override
  String get themeSettingsCustomizeAction => 'Customize';

  @override
  String get chatListNavChats => 'Chats';

  @override
  String get chatListNavCalls => 'Calls';

  @override
  String get chatListNavContacts => 'Contacts';

  @override
  String get chatListShareSendFailed => 'Couldn\'t send';

  @override
  String chatListMuteFailedCount(int count, String error) {
    return 'Couldn\'t change $count chats: $error';
  }

  @override
  String get chatListDeleteStatusChanged =>
      'The chats\' status has changed, please try again';

  @override
  String chatListDeleteChatWith(String name) {
    return 'Delete chat with $name?';
  }

  @override
  String chatListDeleteChatsCount(int count) {
    return 'Delete $count chats?';
  }

  @override
  String get chatListDeleteIrreversible =>
      'The conversation can\'t be restored';

  @override
  String chatListDeleteOwnedChat(String name) {
    return 'Do you want to delete the chat “$name”?';
  }

  @override
  String chatListDeleteGroupsForAll(int count) {
    return 'Delete $count groups for everyone?';
  }

  @override
  String get chatListDeleteOwnedChatBody =>
      'Transfer ownership so the other members can keep talking';

  @override
  String get chatListDeleteCannotUndo => 'This action can\'t be undone';

  @override
  String get chatListDeleteChatForAll => 'Delete chat for everyone';

  @override
  String get chatListDeleteForAll => 'Delete for everyone';

  @override
  String get chatListYourStory => 'Your story';

  @override
  String get chatListAllChatsFolder => 'All chats';

  @override
  String chatListRecipientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients',
      one: '$count recipient',
    );
    return '$_temp0';
  }

  @override
  String get chatListSavedMessages => 'Saved Messages';

  @override
  String get chatListReadAll => 'Mark all as read';

  @override
  String get chatListForwardingHint => 'Forwarding...';

  @override
  String get chatListEmpty => 'Looks like it\'s empty here...';

  @override
  String get chatListOpenToLoad => 'open the chat to load it';

  @override
  String get chatListArchive => 'Archive';

  @override
  String get chatListNewStory => 'New story';

  @override
  String get chatListOpenVideoFailed => 'Couldn\'t open the video';

  @override
  String get chatListOpenPhotoFailed => 'Couldn\'t open the photo';

  @override
  String get chatListDraftPrefix => 'Draft: ';

  @override
  String get chatListPreviewWrongKey => 'wrong key';

  @override
  String get chatListPreviewUnavailable => 'unavailable on this device';

  @override
  String get chatListMessagePerson => 'Message someone';

  @override
  String get chatListCreateGroup => 'New group';

  @override
  String get chatListCreateChannel => 'New channel';

  @override
  String get chatListCreateContact => 'New contact';

  @override
  String get chatListCreateFolder => 'New folder';

  @override
  String get chatListMessageAction => 'Message';

  @override
  String get chatListNoUnreadChats => 'No unread chats';

  @override
  String get chatListAllMarkedRead => 'All chats marked as read';

  @override
  String get callsTabStatusMissed => 'Missed';

  @override
  String get callsTabStatusCanceled => 'Canceled';

  @override
  String get callsTabStatusOutgoing => 'Outgoing';

  @override
  String get callsTabStatusIncoming => 'Incoming';

  @override
  String get callsTabCallBack => 'Call back';

  @override
  String get callsTabPeerUnknown => 'Couldn\'t identify the other person';

  @override
  String get callsTabAlreadyInCall => 'A call is already in progress';

  @override
  String callsTabStartFailed(String error) {
    return 'Couldn\'t start the call: $error';
  }

  @override
  String get callsTabJoinTitle => 'Join a call';

  @override
  String get callsTabJoinDescription => 'Paste an invite link';

  @override
  String get callsTabNotACallLink => 'This isn\'t a call link';

  @override
  String get callsTabCreateCall => 'Create call';

  @override
  String get callsTabMissed => 'Missed';

  @override
  String get callsTabEmpty => 'No calls';

  @override
  String get chatEncryptionProfileNotLoaded => 'Profile hasn\'t loaded yet';

  @override
  String get chatEncryptionEnterKeyHint => 'Enter an encryption key';

  @override
  String get chatEncryptionEnabled => 'Encryption enabled';

  @override
  String get chatEncryptionDisabled => 'Encryption disabled';

  @override
  String get chatEncryptionTitle => 'Message encryption';

  @override
  String get chatEncryptionToggle => 'Encrypt messages';

  @override
  String get chatEncryptionToggleSubtitle =>
      'Message text in this chat will be encrypted with the key below';

  @override
  String get chatEncryptionKeyLabel => 'Key';

  @override
  String get chatEncryptionKeyHint => 'Enter key';

  @override
  String get chatEncryptionKeyNote =>
      'The key is stored only on this device. The other person must enter the same key, otherwise they won\'t be able to read the messages. This is the password mode for groups: no forward secrecy, anyone who knows the password can read the whole history.';

  @override
  String get storyViewerDeleteTitle => 'Delete story?';

  @override
  String get storyViewerDeleteMessage =>
      'The story will disappear for everyone who can view it.';

  @override
  String get storyViewerDeleteFailed => 'Couldn\'t delete the story';

  @override
  String storyViewerDeleteFailedWithReason(String reason) {
    return 'Couldn\'t delete the story: $reason';
  }

  @override
  String get storyViewerEmpty => 'No stories';

  @override
  String get storyViewerJustNow => 'just now';

  @override
  String storyViewerMinutesAgo(int count) {
    return '$count min';
  }

  @override
  String storyViewerHoursAgo(int count) {
    return '$count h';
  }

  @override
  String storyViewerDaysAgo(int count) {
    return '$count d';
  }

  @override
  String get webviewPermissionCamera => 'camera';

  @override
  String get webviewPermissionMicrophone => 'microphone';

  @override
  String get webviewPermissionCameraAndMicrophone => 'camera and microphone';

  @override
  String get webviewPermissionGeolocation => 'location';

  @override
  String get webviewPermissionOther => 'additional access';

  @override
  String get webviewPermissionWebPage => 'Web page';

  @override
  String get webviewPermissionTitle => 'Access request';

  @override
  String webviewPermissionMessage(String host, String resources) {
    return '$host is requesting access to: $resources.';
  }

  @override
  String get webviewPermissionDeny => 'Deny';

  @override
  String get createChannelFailed => 'Couldn\'t create the channel';

  @override
  String get createChannelAvatarProcessFailed => 'Couldn\'t process the avatar';

  @override
  String get createChannelAvatarUploadFailed => 'Couldn\'t upload the avatar';

  @override
  String get createChannelDescription =>
      'Only you post in a channel, members read. You can invite them after it\'s created.';

  @override
  String get createChannelCancel => 'Cancel';

  @override
  String get createChannelCreating => 'Creating...';

  @override
  String get createChannelCreate => 'Create';

  @override
  String get codeConfirmationConnectionDropped =>
      'Connection lost, reconnecting…';

  @override
  String get codeConfirmationNoConnection => 'No connection to the server';

  @override
  String get codeConfirmationConnectionRestored => 'Connection restored';

  @override
  String codeConfirmationReconnectFailed(String error) {
    return 'Couldn\'t restore the connection: $error';
  }

  @override
  String codeConfirmationRefreshFailed(String error) {
    return 'Couldn\'t refresh the code: $error';
  }

  @override
  String get codeConfirmationNewCodeSent => 'We sent a new code';

  @override
  String get codeConfirmationSmsNoToken =>
      'SMS sign-in: the server didn\'t return a token';

  @override
  String get codeConfirmationCodeExpired =>
      'The code expired — we sent a new one';

  @override
  String get pollViewVoteFailed => 'Couldn\'t vote';

  @override
  String get pollViewLoading => 'Loading poll…';

  @override
  String get pollViewMultipleAnswers => 'Multiple answers';

  @override
  String get pollViewSingleAnswer => 'Single answer';

  @override
  String pollViewVotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '$count vote',
    );
    return '$_temp0';
  }

  @override
  String get pollViewVote => 'Vote';

  @override
  String get customizationChatBackground => 'Chat background';

  @override
  String get customizationMessageActions => 'Actions menu';

  @override
  String get customizationAppIcon => 'App icon';

  @override
  String get customizationTitle => 'Customization';

  @override
  String get folderActionNewFolder => 'New folder';

  @override
  String folderActionDeleteConfirm(String title) {
    return 'Delete the folder “$title”? The chats will stay where they are.';
  }

  @override
  String get folderActionDeleteFailed => 'Couldn\'t delete the folder';

  @override
  String get webAppBiometryAccessNotice =>
      'The mini app will be able to ask for fingerprint or face confirmation.';

  @override
  String get webAppBiometryAuthReason => 'Confirm the action in the mini app';

  @override
  String get webAppBiometryAccessTitle => 'Allow biometrics?';

  @override
  String get webAppPhoneRequestTitle => 'Share your phone number?';

  @override
  String get webAppPhoneRequestMessage =>
      'The mini app will receive your phone number.';

  @override
  String get webAppPhoneRequestShare => 'Share';

  @override
  String get promptDialogConfirm => 'Confirm';

  @override
  String get emojiPanelLoadFailed => 'Couldn\'t load emoji';

  @override
  String get emojiPanelEmpty => 'No emoji';

  @override
  String get mediaPreviewEditorOpenFailed => 'Couldn\'t open the editor';

  @override
  String get fontSettingsSampleText =>
      'The quick brown fox jumps over the lazy dog';

  @override
  String get callParticipantsNoServer => 'No connection to the call server';

  @override
  String callParticipantsActionFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get callParticipantsMuteMic => 'Mute microphone';

  @override
  String get callParticipantsRequestCamera => 'Request camera';

  @override
  String get callParticipantsRevokeAdmin => 'Remove admin';

  @override
  String get callParticipantsRevokeSpeaker => 'Remove from speakers';

  @override
  String get callParticipantsMakeSpeaker => 'Make speaker';

  @override
  String get callParticipantsPromote => 'Promote';

  @override
  String get callParticipantsDemote => 'Demote';

  @override
  String get callParticipantsRemoveFromCall => 'Remove from call';

  @override
  String get callParticipantsCallSettings => 'Call settings';

  @override
  String get callParticipantsFeatureAccess => 'Who can use features';

  @override
  String get callParticipantsInviteLink => 'Participant invite link';

  @override
  String get callParticipantsOptionAuthOnly => 'Signed-in users only';

  @override
  String get callParticipantsOptionWaitingHall => 'Waiting room';

  @override
  String get callParticipantsOptionRecurring => 'Recurring call';

  @override
  String get callParticipantsOptionFeedback => 'Feedback collection';

  @override
  String get callParticipantsOptionAudienceMode => 'Audience mode';

  @override
  String get callParticipantsSpeechTranscription => 'Speech transcription';

  @override
  String get callParticipantsOptionWaitForAdmin => 'Wait for an admin';

  @override
  String get callParticipantsOptionAdminIsHere => 'Admin is present';

  @override
  String get callParticipantsFeatureMovieShare => 'Watch together';

  @override
  String get callParticipantsCallRecording => 'Call recording';

  @override
  String get callParticipantsFeatureSpeaker => 'Be a speaker';

  @override
  String callParticipantsTitle(int count) {
    return 'Participants · $count';
  }

  @override
  String get callParticipantsMuteAll => 'Mute everyone';

  @override
  String get callParticipantsLowerAllHands => 'Lower all hands';

  @override
  String get callParticipantsLowerHand => 'Lower hand';

  @override
  String get callParticipantsRaiseHand => 'Raise hand';

  @override
  String get callParticipantsStopRecording => 'Stop recording';

  @override
  String get callParticipantsStartRecording => 'Start recording';

  @override
  String get callParticipantsRolePermissions => 'Role permissions';

  @override
  String get callParticipantsAddByLink => 'Add by link';

  @override
  String get callParticipantsCreator => 'Creator';

  @override
  String get callParticipantsAdmin => 'Admin';

  @override
  String get callParticipantsSpeaker => 'Speaker';

  @override
  String get callParticipantsHandRaised => 'Hand raised';

  @override
  String get chatMediaSendEnableLocation => 'Turn on location services';

  @override
  String get chatMediaSendNoLocationAccess => 'No access to location';

  @override
  String get chatMediaSendLocationFailed => 'Couldn\'t get your location';

  @override
  String get chatMediaSendScheduledEncryptedPhotos =>
      'Scheduled photos aren\'t supported in encrypted chats yet';

  @override
  String get chatMediaSendVideoNotEncryptable =>
      'Videos can\'t be encrypted yet';

  @override
  String get chatMediaSendPhotoEncryptFailed => 'Couldn\'t encrypt the photo';

  @override
  String get chatMediaSendNoEncryptionKey => 'Encryption key isn\'t set';

  @override
  String get chatMediaSendNoUploadUrl =>
      'the server didn\'t provide an upload link';

  @override
  String get chatMediaSendUploadRejected => 'upload rejected';

  @override
  String get chatMediaSendServerRejected =>
      'the server didn\'t accept the message';

  @override
  String chatMediaSendFileFailed(String detail) {
    return 'File not sent: $detail';
  }

  @override
  String chatMediaSendVideoNoteFailed(String detail) {
    return 'Video message not sent: $detail';
  }

  @override
  String chatMediaSendVoiceFailed(String detail) {
    return 'Voice message not sent: $detail';
  }

  @override
  String chatMediaSendPhotoFailed(String detail) {
    return 'Photo not sent: $detail';
  }

  @override
  String chatMediaSendVideoFailed(String detail) {
    return 'Video not sent: $detail';
  }

  @override
  String get chatMediaSendScheduled => 'Scheduled';

  @override
  String chatMediaSendScheduledAt(String date) {
    return 'Scheduled for $date';
  }

  @override
  String get chatMediaSendScheduleFailed => 'Couldn\'t schedule';

  @override
  String get messageListToday => 'Today';

  @override
  String get messageListYesterday => 'Yesterday';

  @override
  String messageListDateThisYear(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String messageListDateOtherYear(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'd MMMM y',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get messageListUnreadMessages => 'Unread messages';

  @override
  String get photoViewerSavedToGallery => 'Saved to gallery';

  @override
  String photoViewerSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get photoViewerSaveFileFailed => 'Couldn\'t save the file';

  @override
  String get photoViewerFileSaved => 'File saved';

  @override
  String get photoViewerErrorNoLink => 'no link';

  @override
  String get photoViewerErrorNoMedia => 'no media';

  @override
  String get photoViewerMediaLoadFailed => 'Couldn\'t load the media';

  @override
  String get avatarPhotoLoadFailed => 'Couldn\'t load the photo';

  @override
  String get avatarPhotoDeleteTitle => 'Delete photo?';

  @override
  String get avatarPhotoDeleteBody =>
      'The photo will be removed from your profile and avatar history.';

  @override
  String loginScreenReconnectFailed(String error) {
    return 'Couldn\'t reconnect: $error';
  }

  @override
  String get loginScreenSmsWarningTitle =>
      'IF YOUR ACCOUNT HAS NO 2FA, ALL SESSIONS WILL BE RESET';

  @override
  String get loginScreenSmsWarningBody =>
      'This method is experimental, use it at your own risk.';

  @override
  String get loginScreenOfflineWait =>
      'No connection to the server. Please wait until it connects.';

  @override
  String get loginScreenOfflineRetry =>
      'No connection to the server. Please try again.';

  @override
  String get loginScreenConnecting =>
      'Connecting to the server, just a moment…';

  @override
  String get loginScreenAlwaysSendSms => 'Always send SMS (EXPERIMENTAL)';

  @override
  String get editProfileNameEmpty => 'Name can\'t be empty';

  @override
  String get editProfileSaved => 'Profile saved';

  @override
  String get editProfileAvatarUploadFailed => 'Couldn\'t upload the avatar';

  @override
  String get editProfileAvatarUpdated => 'Avatar updated';

  @override
  String get editProfilePhotoDeleted => 'Photo deleted';

  @override
  String get findUserInvalidPhone => 'Enter a valid phone number';

  @override
  String get findUserPhoneNotFound => 'No contact with this number was found';

  @override
  String get findUserInvalidId => 'Enter a numeric ID';

  @override
  String get findUserIdNotFound => 'No contact with this ID was found';

  @override
  String get findUserPhoneTab => 'Phone';

  @override
  String get findUserPhoneHint => 'Enter a phone number';

  @override
  String get findUserIdHint => 'Enter a contact ID';

  @override
  String get loginSuccessGreetingWelcome => 'Welcome to Komet!';

  @override
  String get loginSuccessGreetingEmergencyExit =>
      'An emergency exit at 30,000 feet. The illusion of safety.';

  @override
  String get loginSuccessGreetingFunnyThings =>
      'Sometimes funny things can be a criminal offense';

  @override
  String get loginSuccessGreetingFarewell =>
      'If you\'re reading this message, I\'m no longer alive.';

  @override
  String get loginSuccessGreetingGondor => 'Where was Gondor when...';

  @override
  String get loginSuccessGreetingEasterEgg => 'You found an Easter egg!';

  @override
  String get chatTextSendUnknownCommand => 'NO SUCH COMMAND🚨🚨🚨';

  @override
  String get chatTextSendSaveFailed => 'Couldn\'t save the message';

  @override
  String get voiceBubbleLoadFailed => 'Couldn\'t load the audio';

  @override
  String get voiceBubblePlaybackError => 'Playback error';

  @override
  String get voiceBubbleTranscribe => 'T';

  @override
  String get voiceBubbleTranscribing => 'transcribing...';

  @override
  String get voiceBubbleTranscriptionFailed => 'transcription failed';

  @override
  String chatInfoStoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stories',
      one: '$count story',
    );
    return '$_temp0';
  }

  @override
  String chatInfoMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String chatInfoSubscriberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscribers',
      one: '$count subscriber',
    );
    return '$_temp0';
  }

  @override
  String get customGradientTitle => 'Custom theme';

  @override
  String get customGradientAnimation => 'Animation';

  @override
  String get customGradientAnimationSubtitle => 'Smoothly shifting colors';

  @override
  String avatarHistoryDeleteFailed(String error) {
    return 'Couldn\'t delete the photo: $error';
  }

  @override
  String get avatarHistoryEmpty => 'No photos';

  @override
  String get videoBubbleOpenFailed => 'Couldn\'t open the video';

  @override
  String get videoBubbleLoadFailed => 'Couldn\'t get the video';

  @override
  String get accountSwitcherNoName => 'No name';

  @override
  String get accountSwitcherAddAccount => 'Add account';

  @override
  String infoScreenWeeksShort(int weeks) {
    return '$weeks wk';
  }

  @override
  String infoScreenDaysShort(int days) {
    return '$days d';
  }

  @override
  String get pluginsScreenPickKinetFile =>
      'Choose a file with the .kinet extension';

  @override
  String get pluginsScreenReadFileFailed => 'Couldn\'t read the selected file';

  @override
  String pluginsScreenOpenFailed(String error) {
    return 'Couldn\'t open .kinet: $error';
  }

  @override
  String get pluginsScreenHttpsRequired => 'A valid HTTPS link is required';

  @override
  String pluginsScreenDownloadFailed(String error) {
    return 'Couldn\'t download .kinet: $error';
  }

  @override
  String pluginsScreenVersionAuthor(String version, String author) {
    return 'Version $version · $author';
  }

  @override
  String pluginsScreenSignatureVerified(String fingerprint) {
    return 'Ed25519 signature verified\n$fingerprint';
  }

  @override
  String get pluginsScreenNotSigned => 'The plugin isn\'t signed';

  @override
  String get pluginsScreenPermissionsTitle =>
      'The plugin will be granted these permissions:';

  @override
  String get pluginsScreenAllowAndInstall => 'Allow and install';

  @override
  String pluginsScreenInstalled(String name) {
    return '$name installed';
  }

  @override
  String pluginsScreenInstallFailed(String error) {
    return 'Couldn\'t install the plugin: $error';
  }

  @override
  String get pluginsScreenNoUpdates => 'No updates available';

  @override
  String get pluginsScreenUpdateTitle => 'Update plugin?';

  @override
  String get pluginsScreenUpdated => 'Plugin updated';

  @override
  String pluginsScreenUpdateFailed(String error) {
    return 'Couldn\'t update: $error';
  }

  @override
  String get pluginsScreenUninstallTitle => 'Delete plugin?';

  @override
  String get pluginsScreenUninstalled => 'Plugin and its data deleted';

  @override
  String pluginsScreenUninstallFailed(String error) {
    return 'Couldn\'t delete: $error';
  }

  @override
  String get pluginsScreenTitle => 'Plugins';

  @override
  String get pluginsScreenInstallFile => 'Install .kinet';

  @override
  String get pluginsScreenInstallUrl => 'Install from URL';

  @override
  String get pluginsScreenBundled => 'Built-in Komet plugin';

  @override
  String pluginsScreenSigned(String fingerprint) {
    return 'Signed · $fingerprint';
  }

  @override
  String get pluginsScreenUnsigned => 'Not signed';

  @override
  String get pluginsScreenCheckUpdates => 'Check for updates';

  @override
  String get pluginsScreenDownload => 'Download';

  @override
  String get kometSettingsViewDeletedSubtitle => 'Show deleted messages';

  @override
  String get kometSettingsViewRedactedSubtitle =>
      'Show the edit history of messages';

  @override
  String get kometSettingsFullTimestampSubtitle =>
      'Show message times with seconds';

  @override
  String get kometSettingsShowForwardSubtitle =>
      'Mark forwarded messages even when no author is shown on them';

  @override
  String get kometSettingsTypingTimeSubtitle =>
      'Tries to estimate how long a message took to type';

  @override
  String get kometSettingsFoldersHeader => 'Folders';

  @override
  String get kometSettingsHideAllFolderSubtitle =>
      'Hide the \"All\" folder when you have other folders. Chats are sorted only by your folders';

  @override
  String get kometSettingsShowHiddenChatsSubtitle =>
      'Show hidden chats that usually don\'t appear in the list: from group calls, private channels and chats you\'ve left';

  @override
  String get kometSettingsArchiveOnPullSubtitle =>
      'Hide the archive and show it when you pull the chat list down, after stories';

  @override
  String get kometSettingsGhostModeSubtitle => 'You don\'t appear online';

  @override
  String get kometSettingsAntiReadSubtitle =>
      'Read messages without marking them as read';

  @override
  String get kometSettingsSelfOnlineCheckSubtitle =>
      'Checks every ~10 seconds when you were last online. Useful for testing ghost mode';

  @override
  String get kometSettingsDebugHeader => 'Debugging';

  @override
  String get kometSettingsDebugLogsLabel => 'Record debug logs';

  @override
  String get kometSettingsDebugLogsSubtitle =>
      'Writes protocol traffic to a file on the device — helps diagnose bugs in reports';

  @override
  String get sharedContentSavedToGallery => 'Saved to gallery';

  @override
  String get sharedContentFileSaved => 'File saved';

  @override
  String get sharedContentVideoLoadFailed => 'Couldn\'t load the video';

  @override
  String get sharedContentAudioLoadFailed => 'Couldn\'t load the audio';

  @override
  String get sharedContentPlaybackError => 'Playback error';

  @override
  String get messageBubbleButtonUnsupported => 'This button isn\'t supported';

  @override
  String get messageBubblePlatformUnavailable =>
      'This isn\'t available on your platform';

  @override
  String messageBubbleEditedTime(String time) {
    return 'edited $time';
  }

  @override
  String get messageBubbleWrongKey => 'wrong key';

  @override
  String get messageBubbleUnavailableOnDevice => 'unavailable on this device';

  @override
  String get messageBubbleReplyDeleted => 'message deleted';

  @override
  String get searchScreenSavedMessages => 'Saved Messages';

  @override
  String get searchScreenStartTyping => 'Start typing to search';

  @override
  String get searchScreenByPhone => 'By phone number';

  @override
  String get searchScreenContacts => 'Contacts';

  @override
  String get searchScreenChats => 'Chats';

  @override
  String get searchScreenGlobalSearch => 'Global search';

  @override
  String get searchScreenUntitled => 'Untitled';

  @override
  String get fileBubbleCorrupted => 'File is corrupted';

  @override
  String get fileBubbleWrongKey => 'Wrong key';

  @override
  String get fileBubbleTapToOpen => 'Tap to open';

  @override
  String get fileBubbleDownloadFailed => 'Couldn\'t download the file';

  @override
  String get fileBubbleDecryptPhotoFailed => 'Couldn\'t decrypt the photo';

  @override
  String get fileBubbleUnknownFile => 'Couldn\'t identify the file';

  @override
  String get fileBubbleOpenFailedReason => 'couldn\'t open';

  @override
  String get fileBubbleDownloadFailedReason => 'couldn\'t download';

  @override
  String get storyComposerUploadUrlFailed => 'Couldn\'t get the upload address';

  @override
  String get storyComposerPhotoUploadFailed => 'Couldn\'t upload the photo';

  @override
  String get storyComposerVideoUploadFailed => 'Couldn\'t upload the video';

  @override
  String get storyComposerPublished => 'Story published';

  @override
  String get storyComposerPublish => 'Publish';

  @override
  String get storyComposerContacts => 'Contacts';

  @override
  String textEntityProfileNotFound(String nickname) {
    return 'Profile @$nickname not found';
  }

  @override
  String get textEntityCopyPhone => 'Copy phone number';

  @override
  String get textEntityPhoneCopied => 'Number copied';

  @override
  String get textEntityCall => 'Call';

  @override
  String get textEntityCopyCard => 'Copy card number';

  @override
  String get textEntityCardCopied => 'Card number copied';

  @override
  String get textEntityDialFailed => 'Couldn\'t open the phone app';

  @override
  String get textEntityNotOnMax => 'This person isn\'t on MAX yet';

  @override
  String get callLinkHandlerAlreadyInCall => 'A call is already in progress';

  @override
  String callLinkHandlerJoinPromptWithCount(String name, int count) {
    return 'Join the call “$name”? In the call now: $count.';
  }

  @override
  String callLinkHandlerJoinPrompt(String name) {
    return 'Join the call “$name”?';
  }

  @override
  String get callLinkHandlerJoinFailed => 'Couldn\'t join the call';

  @override
  String get appIconScreenUnsupported =>
      'Changing the icon is only available on Android and iOS';

  @override
  String appIconScreenChanged(String name) {
    return 'Icon changed to “$name”';
  }

  @override
  String appIconScreenChangeFailed(String error) {
    return 'Couldn\'t change the icon: $error';
  }

  @override
  String get appIconScreenTitle => 'App icon';

  @override
  String get appIconScreenAppearance => 'Icon style';

  @override
  String get appIconScreenHint =>
      'On Android the app will close so the launcher picks up the new icon. On iOS it changes instantly with a system dialog.';

  @override
  String get appIconScreenOnlyMobile => 'Only available on Android and iOS';

  @override
  String get password2faConnectionDropped => 'Connection lost…';

  @override
  String get password2faConnectionDroppedRelogin =>
      'Connection lost — sign in again';

  @override
  String get password2faEnterPassword =>
      'Enter your password to finish signing in';

  @override
  String get contactsTabFindContact => 'Find contact';

  @override
  String get contactsTabFind => 'Find';

  @override
  String get contactsTabLastSeenRecently => 'Last seen recently';

  @override
  String get contactsTabTitle => 'Contacts';

  @override
  String get contactsTabEmpty => 'No contacts';

  @override
  String securityScreenBlockedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts',
      one: '1 contact',
    );
    return '$_temp0';
  }

  @override
  String get attachmentPanelInvalidFileId => 'Invalid fileId';

  @override
  String get attachmentPanelPickFile => 'Choose from files';

  @override
  String get attachmentPanelSendById => 'Send by id';

  @override
  String selectionBarSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get metaMarksLikelyForwarded =>
      'This message was most likely forwarded';

  @override
  String metaMarksTypingTime(String duration) {
    return 'This message took about ~$duration to type';
  }

  @override
  String get searchViewHint => 'Search...';

  @override
  String get searchViewNoResults => 'Search returned nothing...';

  @override
  String get adaptiveShellSelectChat => 'Select a chat';

  @override
  String get settingsTabPhotoDeleted => 'Photo deleted';

  @override
  String settingsTabPhotoDeleteFailed(String error) {
    return 'Couldn\'t delete the photo: $error';
  }

  @override
  String settingsTabAppVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get settingsTabCloudStorageSubtitle => 'Via MAX';

  @override
  String get settingsTabCloudStorageWhitelistTitle => 'Works under whitelists';

  @override
  String get settingsTabCloudStorageWhitelistBody =>
      'You can send files even when your internet access is restricted.';

  @override
  String get settingsTabCloudStorageLimitsTitle =>
      'Files up to 4 GB, no limit on count.';

  @override
  String get settingsTabCloudStorageLimitsBody =>
      'You can store a massive amount of data.';

  @override
  String get settingsTabCloudStoragePrivacyTitle =>
      'File privacy is not guaranteed';

  @override
  String get settingsTabCloudStoragePrivacyBody =>
      'Cloud storage works through your account on the MAX server, so the right people can still look at it.';

  @override
  String get settingsTabLogoutConfirmTitle => 'Log out of your account?';

  @override
  String get settingsTabLogoutConfirmBody =>
      'Account data will be removed from this device.';

  @override
  String get settingsTabLogoutConfirm => 'Log out';

  @override
  String settingsTabLogoutFailed(String error) {
    return 'Couldn\'t log out: $error';
  }

  @override
  String get settingsTabSferumSignIn => 'Sign in to Sferum';

  @override
  String get settingsTabSferumTitle => 'Sferum';

  @override
  String get settingsTabCloudStorageBeta => 'Cloud storage [BETA]';

  @override
  String get settingsTabDevelopers => 'For developers';

  @override
  String get settingsTabLogout => 'Log out';

  @override
  String get settingsTabOnline => 'online';

  @override
  String settingsTabLastSeen(String time) {
    return 'Last seen $time';
  }

  @override
  String get settingsTabOffline => 'offline';

  @override
  String get folderEditTypeContacts => 'Contacts';

  @override
  String get folderEditTypeNonContacts => 'Non-contacts';

  @override
  String get folderEditTypeChannels => 'Channels';

  @override
  String get folderEditTypeBots => 'Bots';

  @override
  String get folderEditSavedMessages => 'Saved Messages';

  @override
  String get folderEditNoActiveAccount => 'No active account';

  @override
  String get folderEditSaveFailed => 'Couldn\'t save the folder';

  @override
  String folderEditDeleteConfirm(String title) {
    return 'Delete the folder “$title”? The chats will stay where they are.';
  }

  @override
  String get folderEditDeleteFailed => 'Couldn\'t delete the folder';

  @override
  String get folderEditNewTitle => 'New folder';

  @override
  String get folderEditEditTitle => 'Edit folder';

  @override
  String get folderEditNameHint => 'Folder name';

  @override
  String get folderEditChatTypesSection => 'CHAT TYPES';

  @override
  String get folderEditChatsSection => 'CHATS AND CHANNELS';

  @override
  String get folderEditSavedMessagesSubtitle => 'Messages to yourself';

  @override
  String get folderEditShowOnlySection => 'SHOW ONLY';

  @override
  String get folderEditNotMutedChats => 'Chats with notifications on';

  @override
  String get folderEditUnreadChats => 'Unread chats';

  @override
  String get folderEditClearSelection => 'Clear selection';

  @override
  String get folderEditDeleteFolder => 'Delete folder';

  @override
  String get folderEditCreate => 'Create folder';

  @override
  String get composerInputMuteNotifications => 'Mute notifications';

  @override
  String get composerInputForwardFromYou => 'Forwarding your message';

  @override
  String get composerInputForwardMessage => 'Forwarding a message';

  @override
  String composerInputForwardFrom(String name) {
    return 'Forwarding from $name';
  }

  @override
  String composerInputForwardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Forwarding: $count messages',
      one: 'Forwarding: 1 message',
    );
    return '$_temp0';
  }

  @override
  String composerInputReplyTo(String name) {
    return 'Reply to $name';
  }

  @override
  String get composerInputSwipeToCancel => '‹ Swipe left to cancel';

  @override
  String get composerInputSwipeToCancelHint => '‹ swipe left to cancel';

  @override
  String get composerInputHistoryEmpty => 'history is empty...';

  @override
  String get createGroupFailed => 'Couldn\'t create the group';

  @override
  String get createGroupAvatarProcessFailed => 'Couldn\'t process the avatar';

  @override
  String get createGroupAvatarUploadFailed => 'Couldn\'t upload the avatar';

  @override
  String get createGroupSelectParticipants => 'Select participants';

  @override
  String get createGroupCancel => 'Cancel';

  @override
  String get createGroupNext => 'Next';

  @override
  String get createGroupTitle => 'Create group';

  @override
  String get createGroupNameHint => 'Group name';

  @override
  String get createGroupCreating => 'Creating...';

  @override
  String get createGroupCreate => 'Create';

  @override
  String controlBubbleQuotedTitle(String title) {
    return '“$title”';
  }

  @override
  String get controlBubbleCreatedByMe => ' created the chat';

  @override
  String get controlBubbleCreatedByOther => ' created the chat';

  @override
  String get controlBubbleAddedByMe => ' added ';

  @override
  String get controlBubbleAddedByOther => ' added ';

  @override
  String get controlBubbleLeftByMe => ' left the chat';

  @override
  String get controlBubbleLeftByOther => ' left the chat';

  @override
  String get controlBubbleJoinedByMe => ' joined the chat';

  @override
  String get controlBubbleJoinedByOther => ' joined the chat';

  @override
  String get controlBubblePinnedByMe => ' pinned a message';

  @override
  String get controlBubblePinnedByOther => ' pinned a message';

  @override
  String get controlBubbleRenamedByMe => ' changed the chat name';

  @override
  String get controlBubbleRenamedByOther => ' changed the chat name';

  @override
  String controlBubbleRenamedTo(String title) {
    return ' to $title';
  }

  @override
  String get controlBubblePhotoChangedByMe => ' changed the chat photo';

  @override
  String get controlBubblePhotoChangedByOther => ' changed the chat photo';

  @override
  String get controlBubbleBotStarted => 'Bot started';

  @override
  String get maxLinkNoPublicLink => 'This profile has no public link';

  @override
  String get maxLinkShareFailed => 'Couldn\'t share the link';

  @override
  String get maxLinkOpenProfileFailed => 'Couldn\'t open the profile';

  @override
  String get maxLinkOpenChatFailed => 'Couldn\'t open the chat';

  @override
  String get maxLinkJoinThisChatConfirm => 'Join this chat?';

  @override
  String maxLinkJoinChatConfirm(String title) {
    return 'Join “$title”?';
  }

  @override
  String get maxLinkProfileFallback => 'Profile';

  @override
  String get videoNoteCameraUnavailable => 'Camera unavailable';

  @override
  String get videoNoteNeedCameraAndMic =>
      'Video messages need access to the camera and microphone';

  @override
  String get videoNoteNoMicAccess => 'No access to the microphone';

  @override
  String get videoNoteNoCameraAccess => 'No access to the camera';

  @override
  String get videoNoteCameraNotReady => 'The camera isn\'t ready yet';

  @override
  String get videoNoteStartFailed =>
      'Couldn\'t start recording the video message';

  @override
  String get videoNoteSaveFailed => 'Couldn\'t save the video message';

  @override
  String get scheduleTimePickerTitle => 'Send later';

  @override
  String get scheduleTimePickerToday => 'Today';

  @override
  String get scheduleTimePickerTomorrow => 'Tomorrow';

  @override
  String get scheduleTimePickerTodayLower => 'today';

  @override
  String get scheduleTimePickerTomorrowLower => 'tomorrow';

  @override
  String scheduleTimePickerSendAt(String day, String time) {
    return 'Send $day at $time';
  }

  @override
  String get scheduleTimePickerPastTime => 'The time must be in the future';

  @override
  String get chatBackgroundSaveFailed => 'Couldn\'t save the wallpaper';

  @override
  String get chatBackgroundTitle => 'Chat background';

  @override
  String get chatBackgroundDescription =>
      'This wallpaper applies to every chat that doesn\'t have its own background.';

  @override
  String get chatBackgroundTintTitle => 'Match the interface to the wallpaper';

  @override
  String get chatBackgroundTintSubtitle =>
      'The app\'s accent color will be taken from the background';

  @override
  String get chatBackgroundPick => 'Choose wallpaper';

  @override
  String get chatBackgroundSampleIncoming => 'One background for all chats';

  @override
  String get chatBackgroundSampleOutgoing => 'Beautiful ✨';

  @override
  String get chatWallpaperPreviewTitle => 'Wallpaper';

  @override
  String get chatWallpaperPreviewBlur => 'Blur';

  @override
  String get chatWallpaperPreviewMotion => 'Motion';

  @override
  String get chatWallpaperPreviewDimming => 'Dimming';

  @override
  String get chatWallpaperPreviewSampleIncoming =>
      'How about new wallpaper for this chat?';

  @override
  String get chatWallpaperPreviewSampleOutgoing => 'Great idea.';

  @override
  String get stickerPanelLoadFailed => 'Couldn\'t load stickers';

  @override
  String get stickerPanelEmpty => 'No stickers';

  @override
  String get stickerPanelEmojiTab => 'Emoji';

  @override
  String get stickerPanelStickersTab => 'Stickers';

  @override
  String get callBubbleGroupVideo => 'Group video call';

  @override
  String get callBubbleCanceledVideo => 'Canceled video call';

  @override
  String get callBubbleMissedVideo => 'Missed video call';

  @override
  String get callBubbleOutgoingVideo => 'Outgoing video call';

  @override
  String get callBubbleIncomingVideo => 'Incoming video call';

  @override
  String get callBubbleCanceled => 'Canceled call';

  @override
  String get callBubbleMissed => 'Missed call';

  @override
  String get callBubbleOutgoing => 'Outgoing call';

  @override
  String maxRouteUnsupported(String route) {
    return 'Link not supported: $route';
  }

  @override
  String maxRouteIncomplete(String route) {
    return 'Incomplete link: $route';
  }

  @override
  String get cloudStorageScreenExpired => 'expired';

  @override
  String cloudStorageScreenExpiresInDays(int days) {
    return '$days d';
  }

  @override
  String cloudStorageScreenExpiresInHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String cloudStorageScreenExpiresInMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get webQrScanTitle => 'QR for web and desktop';

  @override
  String get webQrScanCameraUnavailable => 'Camera unavailable';

  @override
  String get webQrScanHint =>
      'Point the camera at the QR code on your computer screen';

  @override
  String get messageRowEditTitle => 'Edit message';

  @override
  String get locationBubbleOpenInMaps => 'Open in maps';

  @override
  String get commandArgumentsCancel => 'Cancel command';

  @override
  String commandArgumentsOptional(String name) {
    return '$name · optional';
  }

  @override
  String get storyRingYourStory => 'Your story';

  @override
  String formatBytesB(String value) {
    return '$value B';
  }

  @override
  String formatBytesKb(String value) {
    return '$value KB';
  }

  @override
  String formatBytesMb(String value) {
    return '$value MB';
  }

  @override
  String formatBytesGb(String value) {
    return '$value GB';
  }

  @override
  String formatApproxSeconds(String whole, String fraction) {
    return '$whole.$fraction s';
  }

  @override
  String formatApproxMinutes(String whole, String fraction) {
    return '$whole.$fraction min';
  }

  @override
  String get lastSeenJustNow => 'Last seen just now';

  @override
  String lastSeenMinutesAgo(int minutes) {
    return 'Last seen $minutes min ago';
  }

  @override
  String lastSeenHoursAgo(int hours) {
    return 'Last seen $hours h ago';
  }

  @override
  String lastSeenDaysAgo(int days) {
    return 'Last seen $days d ago';
  }

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get connectionStatusConnecting => 'Connecting...';

  @override
  String get connectionStatusWaitingForNetwork => 'Waiting for network...';

  @override
  String get chatActivityTyping => 'Typing...';

  @override
  String get chatActivityChoosingSticker => 'Choosing a sticker...';

  @override
  String chatActivityTypingOne(String name) {
    return '$name is typing...';
  }

  @override
  String chatActivityTypingTwo(String first, String second) {
    return '$first and $second are typing...';
  }

  @override
  String chatActivityTypingMany(String name, int count) {
    return '$name and $count more are typing...';
  }

  @override
  String chatActivityStickerOne(String name) {
    return '$name is choosing a sticker...';
  }

  @override
  String chatActivityStickerTwo(String first, String second) {
    return '$first and $second are choosing stickers...';
  }

  @override
  String chatActivityStickerMany(String name, int count) {
    return '$name and $count more are choosing stickers...';
  }

  @override
  String get shareTitleMessage => 'Send message';

  @override
  String get shareTitlePhoto => 'Send photo';

  @override
  String shareTitlePhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count photos',
      one: 'Send $count photo',
    );
    return '$_temp0';
  }

  @override
  String shareTitleVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count videos',
      one: 'Send $count video',
    );
    return '$_temp0';
  }

  @override
  String shareTitleFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count files',
      one: 'Send $count file',
    );
    return '$_temp0';
  }

  @override
  String shareSubtitleToChats(String names) {
    return 'To $names';
  }

  @override
  String shareSubtitleChatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'To $count chats',
      one: 'To $count chat',
    );
    return '$_temp0';
  }

  @override
  String get pluginPermissionChatWrite => 'Send messages';

  @override
  String get pluginPermissionChatEdit => 'Edit sent messages';

  @override
  String get pluginPermissionUiNotify => 'Show notifications';

  @override
  String get pluginPermissionContactRead => 'Read the chat partner\'s data';

  @override
  String get pluginPermissionReplyRead =>
      'Read the message the command replies to';

  @override
  String get pluginPermissionNetwork => 'Internet access';

  @override
  String get pluginPermissionPhotoWrite => 'Send photos';

  @override
  String get pluginPermissionFileWrite => 'Send files';

  @override
  String get pluginPermissionStorage => 'Plugin local storage';

  @override
  String pluginUpdateNewPermissions(String permissions) {
    return 'The update requests new permissions: $permissions';
  }

  @override
  String get transcriptionNotRecognized => 'Couldn\'t recognize the voice';

  @override
  String get chatWallpaperThemeOcean => 'Ocean';

  @override
  String get chatWallpaperThemeSunset => 'Sunset';

  @override
  String get chatWallpaperThemeLavender => 'Lavender';

  @override
  String get chatWallpaperThemeMint => 'Mint';

  @override
  String get chatWallpaperThemeGraphite => 'Graphite';

  @override
  String get chatWallpaperThemeSky => 'Sky';

  @override
  String get chatWallpaperThemePeach => 'Peach';

  @override
  String get chatWallpaperThemeForest => 'Forest';

  @override
  String get chatWallpaperThemeGrape => 'Grape';

  @override
  String get chatWallpaperThemeNight => 'Night';

  @override
  String get chatWallpaperThemeRose => 'Rose';

  @override
  String get chatWallpaperThemeAmber => 'Amber';

  @override
  String get mediaSaveFileNotFound => 'file not found';

  @override
  String get mediaSaveNoGalleryAccess => 'no access to the gallery';

  @override
  String get commandShrugDescription => 'send a kaomoji';

  @override
  String scheduleTimePickerDayLabel(String weekday, String date) {
    return '$weekday, $date';
  }
}
