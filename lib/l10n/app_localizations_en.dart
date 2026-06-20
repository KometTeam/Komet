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
}
