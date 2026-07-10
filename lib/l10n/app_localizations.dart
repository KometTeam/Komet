import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Komet'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check your country code and enter your\nphone number.'**
  String get loginSubtitle;

  /// No description provided for @loginCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get loginCountry;

  /// No description provided for @loginPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get loginPhoneNumber;

  /// No description provided for @loginOtherSignInMethods.
  ///
  /// In en, this message translates to:
  /// **'Other sign-in methods'**
  String get loginOtherSignInMethods;

  /// No description provided for @loginTermsIntro.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to \n'**
  String get loginTermsIntro;

  /// No description provided for @loginTermsLink.
  ///
  /// In en, this message translates to:
  /// **'the terms of use'**
  String get loginTermsLink;

  /// No description provided for @loginTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get loginTermsOfUse;

  /// No description provided for @loginConfirmPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Is this the correct number?'**
  String get loginConfirmPhoneTitle;

  /// No description provided for @loginEdit.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get loginEdit;

  /// No description provided for @loginDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get loginDone;

  /// No description provided for @loginReadTermsNotification.
  ///
  /// In en, this message translates to:
  /// **'Please read the terms of use first'**
  String get loginReadTermsNotification;

  /// No description provided for @loginSpoofRedacted.
  ///
  /// In en, this message translates to:
  /// **'Spoofing'**
  String get loginSpoofRedacted;

  /// No description provided for @loginProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get loginProxy;

  /// No description provided for @loginChangeServer.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get loginChangeServer;

  /// No description provided for @serverSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverSettingsTitle;

  /// No description provided for @serverHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get serverHostLabel;

  /// No description provided for @serverPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get serverPortLabel;

  /// No description provided for @serverApply.
  ///
  /// In en, this message translates to:
  /// **'Apply and reconnect'**
  String get serverApply;

  /// No description provided for @serverUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get serverUseDefault;

  /// No description provided for @serverInvalidHostOrPort.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid host and port (1–65535)'**
  String get serverInvalidHostOrPort;

  /// No description provided for @serverSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Server settings applied'**
  String get serverSettingsSaved;

  /// No description provided for @serverReconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the server'**
  String get serverReconnectFailed;

  /// No description provided for @loginSignInWithQr.
  ///
  /// In en, this message translates to:
  /// **'Sign in with QR code'**
  String get loginSignInWithQr;

  /// No description provided for @loginSignInWithToken.
  ///
  /// In en, this message translates to:
  /// **'Sign in with token'**
  String get loginSignInWithToken;

  /// No description provided for @tokenLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Token login'**
  String get tokenLoginTitle;

  /// No description provided for @tokenLoginTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get tokenLoginTokenLabel;

  /// No description provided for @tokenLoginNote.
  ///
  /// In en, this message translates to:
  /// **'Token login only works with spoofing. Enter the data of the device the token belongs to, otherwise the account may be banned.'**
  String get tokenLoginNote;

  /// No description provided for @tokenLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get tokenLoginButton;

  /// No description provided for @tokenLoginError.
  ///
  /// In en, this message translates to:
  /// **'Fill in the token, device name, OS version and Device ID'**
  String get tokenLoginError;

  /// No description provided for @tokenLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed'**
  String get tokenLoginFailed;

  /// No description provided for @loginSignInWithSessionFile.
  ///
  /// In en, this message translates to:
  /// **'Sign in with session file'**
  String get loginSignInWithSessionFile;

  /// No description provided for @loginLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get loginLanguage;

  /// No description provided for @languageNameRu.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageNameRu;

  /// No description provided for @languageNameEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// No description provided for @selectCountryTitle.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get selectCountryTitle;

  /// No description provided for @selectCountrySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search countries…'**
  String get selectCountrySearchHint;

  /// No description provided for @codeConfirmationSmsSent.
  ///
  /// In en, this message translates to:
  /// **'We sent an SMS with a verification code to your phone number.'**
  String get codeConfirmationSmsSent;

  /// No description provided for @codeResendInSeconds.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds} s.'**
  String codeResendInSeconds(int seconds);

  /// No description provided for @codeResendSms.
  ///
  /// In en, this message translates to:
  /// **'Resend code via SMS'**
  String get codeResendSms;

  /// No description provided for @codeError2faMissing.
  ///
  /// In en, this message translates to:
  /// **'Error: missing data for 2FA'**
  String get codeError2faMissing;

  /// No description provided for @codeConfirmation2faWarning.
  ///
  /// In en, this message translates to:
  /// **'MAX may require 2FA on your account to sign in. If you didn\'t receive the code, set up 2FA from a client where you\'re already signed in.'**
  String get codeConfirmation2faWarning;

  /// No description provided for @proxySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get proxySettingsTitle;

  /// No description provided for @proxyTypeNone.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get proxyTypeNone;

  /// No description provided for @proxyTypeSocks5.
  ///
  /// In en, this message translates to:
  /// **'SOCKS5'**
  String get proxyTypeSocks5;

  /// No description provided for @proxyTypeHttp.
  ///
  /// In en, this message translates to:
  /// **'HTTP(S)'**
  String get proxyTypeHttp;

  /// No description provided for @proxyHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Proxy host'**
  String get proxyHostLabel;

  /// No description provided for @proxyPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Proxy port'**
  String get proxyPortLabel;

  /// No description provided for @proxyUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get proxyUsernameLabel;

  /// No description provided for @proxyPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get proxyPasswordLabel;

  /// No description provided for @proxyApply.
  ///
  /// In en, this message translates to:
  /// **'Apply and reconnect'**
  String get proxyApply;

  /// No description provided for @proxyDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable proxy'**
  String get proxyDisable;

  /// No description provided for @proxySettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Proxy settings applied'**
  String get proxySettingsSaved;

  /// No description provided for @proxyInvalidHostOrPort.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid proxy host and port (1–65535)'**
  String get proxyInvalidHostOrPort;

  /// No description provided for @spoofScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Session spoofing'**
  String get spoofScreenTitle;

  /// No description provided for @spoofEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Device spoofing'**
  String get spoofEnableTitle;

  /// No description provided for @spoofEnableSubtitleOn.
  ///
  /// In en, this message translates to:
  /// **'Enabled for this account'**
  String get spoofEnableSubtitleOn;

  /// No description provided for @spoofEnableSubtitleOff.
  ///
  /// In en, this message translates to:
  /// **'Disabled — using the real device'**
  String get spoofEnableSubtitleOff;

  /// No description provided for @spoofInfoHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Generate\":\n• Short tap: random preset.\n• Long press: real device data.'**
  String get spoofInfoHint;

  /// No description provided for @spoofMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Spoofing method'**
  String get spoofMethodTitle;

  /// No description provided for @spoofMethodPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get spoofMethodPartial;

  /// No description provided for @spoofMethodFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get spoofMethodFull;

  /// No description provided for @spoofMethodPartialDescription.
  ///
  /// In en, this message translates to:
  /// **'Recommended method. Random data is used, but your real timezone and locale are kept for plausibility.'**
  String get spoofMethodPartialDescription;

  /// No description provided for @spoofMethodFullDescription.
  ///
  /// In en, this message translates to:
  /// **'All data including timezone and locale is generated randomly. Use this method at your own risk!'**
  String get spoofMethodFullDescription;

  /// No description provided for @spoofDeviceTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Device type'**
  String get spoofDeviceTypeTitle;

  /// No description provided for @spoofDeviceTypeDescription.
  ///
  /// In en, this message translates to:
  /// **'Controls which devices are generated: Android or iOS'**
  String get spoofDeviceTypeDescription;

  /// No description provided for @spoofDeviceTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Device type'**
  String get spoofDeviceTypeLabel;

  /// No description provided for @spoofMainSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Main data'**
  String get spoofMainSectionTitle;

  /// No description provided for @spoofFieldDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get spoofFieldDeviceName;

  /// No description provided for @spoofFieldOsVersion.
  ///
  /// In en, this message translates to:
  /// **'OS version'**
  String get spoofFieldOsVersion;

  /// No description provided for @spoofRegionalSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Regional data'**
  String get spoofRegionalSectionTitle;

  /// No description provided for @spoofFieldScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen resolution'**
  String get spoofFieldScreen;

  /// No description provided for @spoofFieldTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get spoofFieldTimezone;

  /// No description provided for @spoofFieldLocale.
  ///
  /// In en, this message translates to:
  /// **'Locale'**
  String get spoofFieldLocale;

  /// No description provided for @spoofFieldDeviceLocale.
  ///
  /// In en, this message translates to:
  /// **'Device locale (derived)'**
  String get spoofFieldDeviceLocale;

  /// No description provided for @spoofIdentifiersSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Identifiers'**
  String get spoofIdentifiersSectionTitle;

  /// No description provided for @spoofIdentifiersDescription.
  ///
  /// In en, this message translates to:
  /// **'mt_instanceid and clientSessionId are generated automatically on every app launch. Only the Device ID can be changed.'**
  String get spoofIdentifiersDescription;

  /// No description provided for @spoofFieldInstanceId.
  ///
  /// In en, this message translates to:
  /// **'mt_instanceid'**
  String get spoofFieldInstanceId;

  /// No description provided for @spoofFieldClientSessionId.
  ///
  /// In en, this message translates to:
  /// **'clientSessionId'**
  String get spoofFieldClientSessionId;

  /// No description provided for @spoofFieldPushDeviceType.
  ///
  /// In en, this message translates to:
  /// **'Push device type'**
  String get spoofFieldPushDeviceType;

  /// No description provided for @spoofFieldDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get spoofFieldDeviceId;

  /// No description provided for @spoofRegenerateIdTooltip.
  ///
  /// In en, this message translates to:
  /// **'Generate a new ID'**
  String get spoofRegenerateIdTooltip;

  /// No description provided for @spoofFieldAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get spoofFieldAppVersion;

  /// No description provided for @spoofFieldBuildNumber.
  ///
  /// In en, this message translates to:
  /// **'Build number'**
  String get spoofFieldBuildNumber;

  /// No description provided for @spoofFieldArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get spoofFieldArchitecture;

  /// No description provided for @spoofButtonGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get spoofButtonGenerate;

  /// No description provided for @spoofButtonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get spoofButtonApply;

  /// No description provided for @spoofDialogUnsureTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get spoofDialogUnsureTitle;

  /// No description provided for @spoofDialogUnsureContent.
  ///
  /// In en, this message translates to:
  /// **'The app may become unstable due to API incompatibility'**
  String get spoofDialogUnsureContent;

  /// No description provided for @spoofDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get spoofDialogCancel;

  /// No description provided for @spoofDialogYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get spoofDialogYes;

  /// No description provided for @spoofDialogApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply settings?'**
  String get spoofDialogApplyTitle;

  /// No description provided for @spoofDialogApplyContent.
  ///
  /// In en, this message translates to:
  /// **'Need to reconnect the app, ok?'**
  String get spoofDialogApplyContent;

  /// No description provided for @spoofDialogApplyWarning.
  ///
  /// In en, this message translates to:
  /// **'Your spoof will change immediately. But due to MAX specifics, you must re-login to the account for it to become visible'**
  String get spoofDialogApplyWarning;

  /// No description provided for @spoofDialogReloginTitle.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get spoofDialogReloginTitle;

  /// No description provided for @spoofDialogReloginContent.
  ///
  /// In en, this message translates to:
  /// **'Due to MAX specifics, your spoof is changed, but changes will be visible only after re-login.'**
  String get spoofDialogReloginContent;

  /// No description provided for @spoofDialogReloginWarning.
  ///
  /// In en, this message translates to:
  /// **'Re-login now?'**
  String get spoofDialogReloginWarning;

  /// No description provided for @spoofDialogReloginDeny.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get spoofDialogReloginDeny;

  /// No description provided for @spoofDialogReloginConfirm.
  ///
  /// In en, this message translates to:
  /// **'Re-login now'**
  String get spoofDialogReloginConfirm;

  /// No description provided for @spoofDialogApplyDeny.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get spoofDialogApplyDeny;

  /// No description provided for @spoofDialogApplyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Ok!'**
  String get spoofDialogApplyConfirm;

  /// No description provided for @spoofErrorApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to apply settings: {error}'**
  String spoofErrorApplyFailed(String error);

  /// No description provided for @profileMenuSpoof.
  ///
  /// In en, this message translates to:
  /// **'Spoofing'**
  String get profileMenuSpoof;

  /// No description provided for @infoTitle.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get infoTitle;

  /// No description provided for @infoAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get infoAccountSection;

  /// No description provided for @infoServerSection.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get infoServerSection;

  /// No description provided for @infoUserSection.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get infoUserSection;

  /// No description provided for @infoYMapSection.
  ///
  /// In en, this message translates to:
  /// **'Y-Map'**
  String get infoYMapSection;

  /// No description provided for @infoFileUploadTypes.
  ///
  /// In en, this message translates to:
  /// **'file-upload-unsupported-types'**
  String get infoFileUploadTypes;

  /// No description provided for @infoWhiteListLinks.
  ///
  /// In en, this message translates to:
  /// **'white-list-links'**
  String get infoWhiteListLinks;

  /// No description provided for @infoRegistrationTime.
  ///
  /// In en, this message translates to:
  /// **'registrationTime'**
  String get infoRegistrationTime;

  /// No description provided for @infoCountry.
  ///
  /// In en, this message translates to:
  /// **'country'**
  String get infoCountry;

  /// No description provided for @infoVideoChatHistory.
  ///
  /// In en, this message translates to:
  /// **'videoChatHistory'**
  String get infoVideoChatHistory;

  /// No description provided for @infoUpdateTime.
  ///
  /// In en, this message translates to:
  /// **'updateTime'**
  String get infoUpdateTime;

  /// No description provided for @infoId.
  ///
  /// In en, this message translates to:
  /// **'id'**
  String get infoId;

  /// No description provided for @infoChatMarker.
  ///
  /// In en, this message translates to:
  /// **'chatMarker'**
  String get infoChatMarker;

  /// No description provided for @infoAccountRemovalEnabled.
  ///
  /// In en, this message translates to:
  /// **'account-removal-enabled'**
  String get infoAccountRemovalEnabled;

  /// No description provided for @infoImageSize.
  ///
  /// In en, this message translates to:
  /// **'image-size'**
  String get infoImageSize;

  /// No description provided for @infoGce.
  ///
  /// In en, this message translates to:
  /// **'gce'**
  String get infoGce;

  /// No description provided for @infoGcce.
  ///
  /// In en, this message translates to:
  /// **'gcce'**
  String get infoGcce;

  /// No description provided for @infoMaxMsgLength.
  ///
  /// In en, this message translates to:
  /// **'max-msg-length'**
  String get infoMaxMsgLength;

  /// No description provided for @infoQuotesEnabled.
  ///
  /// In en, this message translates to:
  /// **'quotes-enabled'**
  String get infoQuotesEnabled;

  /// No description provided for @infoCallsEndpoint.
  ///
  /// In en, this message translates to:
  /// **'calls-endpoint'**
  String get infoCallsEndpoint;

  /// No description provided for @infoSendLocationEnabled.
  ///
  /// In en, this message translates to:
  /// **'send-location-enabled'**
  String get infoSendLocationEnabled;

  /// No description provided for @infoLgce.
  ///
  /// In en, this message translates to:
  /// **'lgce'**
  String get infoLgce;

  /// No description provided for @infoWud.
  ///
  /// In en, this message translates to:
  /// **'wud'**
  String get infoWud;

  /// No description provided for @infoVideoMsgEnabled.
  ///
  /// In en, this message translates to:
  /// **'video-msg-enabled'**
  String get infoVideoMsgEnabled;

  /// No description provided for @infoGrse.
  ///
  /// In en, this message translates to:
  /// **'grse'**
  String get infoGrse;

  /// No description provided for @infoEditTimeout.
  ///
  /// In en, this message translates to:
  /// **'edit-timeout'**
  String get infoEditTimeout;

  /// No description provided for @infoImageQuality.
  ///
  /// In en, this message translates to:
  /// **'image-quality'**
  String get infoImageQuality;

  /// No description provided for @infoUnsafeFilesAlert.
  ///
  /// In en, this message translates to:
  /// **'unsafe-files-alert'**
  String get infoUnsafeFilesAlert;

  /// No description provided for @infoAccountNicknameEnabled.
  ///
  /// In en, this message translates to:
  /// **'account-nickname-enabled'**
  String get infoAccountNicknameEnabled;

  /// No description provided for @infoMentionsEntityNamesLimit.
  ///
  /// In en, this message translates to:
  /// **'mentions_entity_names_limit'**
  String get infoMentionsEntityNamesLimit;

  /// No description provided for @infoReactionsEnabled.
  ///
  /// In en, this message translates to:
  /// **'reactions-enabled'**
  String get infoReactionsEnabled;

  /// No description provided for @infoTile.
  ///
  /// In en, this message translates to:
  /// **'tile'**
  String get infoTile;

  /// No description provided for @infoGeocoder.
  ///
  /// In en, this message translates to:
  /// **'geocoder'**
  String get infoGeocoder;

  /// No description provided for @infoStatic.
  ///
  /// In en, this message translates to:
  /// **'static'**
  String get infoStatic;

  /// No description provided for @chatInfoSubscribers.
  ///
  /// In en, this message translates to:
  /// **'subscribers:'**
  String get chatInfoSubscribers;

  /// No description provided for @chatInfoInvitedBy.
  ///
  /// In en, this message translates to:
  /// **'invited by:'**
  String get chatInfoInvitedBy;

  /// No description provided for @chatInfoLink.
  ///
  /// In en, this message translates to:
  /// **'link:'**
  String get chatInfoLink;

  /// No description provided for @chatInfoOfficial.
  ///
  /// In en, this message translates to:
  /// **'official:'**
  String get chatInfoOfficial;

  /// No description provided for @chatInfoComments.
  ///
  /// In en, this message translates to:
  /// **'comments:'**
  String get chatInfoComments;

  /// No description provided for @chatInfoAplus.
  ///
  /// In en, this message translates to:
  /// **'approved by Roskomnadzor:'**
  String get chatInfoAplus;

  /// No description provided for @chatInfoSignAdmin.
  ///
  /// In en, this message translates to:
  /// **'admin signature:'**
  String get chatInfoSignAdmin;

  /// No description provided for @chatInfoLastChanged.
  ///
  /// In en, this message translates to:
  /// **'last changed:'**
  String get chatInfoLastChanged;

  /// No description provided for @chatInfoJoinTime.
  ///
  /// In en, this message translates to:
  /// **'joined:'**
  String get chatInfoJoinTime;

  /// No description provided for @chatInfoCreated.
  ///
  /// In en, this message translates to:
  /// **'created:'**
  String get chatInfoCreated;

  /// No description provided for @chatInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get chatInfoTitle;

  /// No description provided for @chatInfoMembers.
  ///
  /// In en, this message translates to:
  /// **'members:'**
  String get chatInfoMembers;

  /// No description provided for @chatInfoLastSeen.
  ///
  /// In en, this message translates to:
  /// **'last seen recently'**
  String get chatInfoLastSeen;

  /// No description provided for @chatInfoHasBots.
  ///
  /// In en, this message translates to:
  /// **'has bots:'**
  String get chatInfoHasBots;

  /// No description provided for @chatInfoBlockedCount.
  ///
  /// In en, this message translates to:
  /// **'blocked in group:'**
  String get chatInfoBlockedCount;

  /// No description provided for @chatInfoOfficialStatus.
  ///
  /// In en, this message translates to:
  /// **'official status:'**
  String get chatInfoOfficialStatus;

  /// No description provided for @chatInfoJoined.
  ///
  /// In en, this message translates to:
  /// **'joined:'**
  String get chatInfoJoined;

  /// No description provided for @chatInfoGroupCreated.
  ///
  /// In en, this message translates to:
  /// **'group created:'**
  String get chatInfoGroupCreated;

  /// No description provided for @chatInfoGroupOwner.
  ///
  /// In en, this message translates to:
  /// **'group owner:'**
  String get chatInfoGroupOwner;

  /// No description provided for @chatInfoDialogStarted.
  ///
  /// In en, this message translates to:
  /// **'dialog started:'**
  String get chatInfoDialogStarted;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTitle;

  /// No description provided for @editProfileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editProfileSave;

  /// No description provided for @editProfileFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get editProfileFirstName;

  /// No description provided for @editProfileLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get editProfileLastName;

  /// No description provided for @editProfileRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get editProfileRemovePhoto;

  /// No description provided for @registrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your profile'**
  String get registrationTitle;

  /// No description provided for @registrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your name and pick an avatar'**
  String get registrationSubtitle;

  /// No description provided for @registrationChooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose an avatar'**
  String get registrationChooseAvatar;

  /// No description provided for @msgActionsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get msgActionsCopy;

  /// No description provided for @emojiSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search emoji'**
  String get emojiSearchHint;

  /// No description provided for @msgActionsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get msgActionsEdit;

  /// No description provided for @msgActionsReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get msgActionsReply;

  /// No description provided for @msgActionsForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get msgActionsForward;

  /// No description provided for @msgActionsMarkUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark as unread'**
  String get msgActionsMarkUnread;

  /// No description provided for @msgActionsPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get msgActionsPin;

  /// No description provided for @msgActionsUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get msgActionsUnpin;

  /// No description provided for @pinnedMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned message'**
  String get pinnedMessageTitle;

  /// No description provided for @msgActionsEditHistory.
  ///
  /// In en, this message translates to:
  /// **'Edit history'**
  String get msgActionsEditHistory;

  /// No description provided for @msgActionsReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get msgActionsReport;

  /// No description provided for @msgActionsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get msgActionsDelete;

  /// No description provided for @msgActionsCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get msgActionsCopied;

  /// No description provided for @msgActionsLoadReasonsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load reasons'**
  String get msgActionsLoadReasonsFailed;

  /// No description provided for @msgActionsCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'current version'**
  String get msgActionsCurrentVersion;

  /// No description provided for @msgActionsCurrentVersionWithDate.
  ///
  /// In en, this message translates to:
  /// **'current version · {date}'**
  String msgActionsCurrentVersionWithDate(String date);

  /// No description provided for @msgActionsNoText.
  ///
  /// In en, this message translates to:
  /// **'(no text)'**
  String get msgActionsNoText;

  /// No description provided for @notificationsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String notificationsSaveFailed(String error);

  /// No description provided for @notificationsFkmAlreadyHasFcm.
  ///
  /// In en, this message translates to:
  /// **'Why? You already have FCM.'**
  String get notificationsFkmAlreadyHasFcm;

  /// No description provided for @notificationsFkmDownloadFcm.
  ///
  /// In en, this message translates to:
  /// **'Better download the FCM version.'**
  String get notificationsFkmDownloadFcm;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsFkmSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'FKM'**
  String get notificationsFkmSectionTitle;

  /// No description provided for @notificationsFkmEnableLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get notificationsFkmEnableLabel;

  /// No description provided for @notificationsFkmEnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For FKM notifications to work, the app will need to keep a notification in the shade.'**
  String get notificationsFkmEnableSubtitle;

  /// No description provided for @notificationsMainSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsMainSectionTitle;

  /// No description provided for @notificationsAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All notifications'**
  String get notificationsAllLabel;

  /// No description provided for @notificationsNewSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'New notifications'**
  String get notificationsNewSectionTitle;

  /// No description provided for @notificationsPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Message preview'**
  String get notificationsPreviewLabel;

  /// No description provided for @notificationsSoundLabel.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get notificationsSoundLabel;

  /// No description provided for @notificationsAdditionalSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Additional'**
  String get notificationsAdditionalSectionTitle;

  /// No description provided for @notificationsCallsLabel.
  ///
  /// In en, this message translates to:
  /// **'Call notifications'**
  String get notificationsCallsLabel;

  /// No description provided for @notificationsNewContactsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications from new contacts'**
  String get notificationsNewContactsLabel;

  /// No description provided for @notificationsHapticsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get notificationsHapticsSectionTitle;

  /// No description provided for @notificationsHapticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get notificationsHapticsLabel;

  /// No description provided for @notificationsHapticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Vibration feedback for actions in the app'**
  String get notificationsHapticsSubtitle;

  /// No description provided for @devicesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String devicesLoadFailed(String error);

  /// No description provided for @devicesQrLinkDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Link from QR'**
  String get devicesQrLinkDialogTitle;

  /// No description provided for @devicesQrLinkDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the QR code content'**
  String get devicesQrLinkDialogHint;

  /// No description provided for @devicesAllTerminated.
  ///
  /// In en, this message translates to:
  /// **'All sessions terminated'**
  String get devicesAllTerminated;

  /// No description provided for @devicesGenericError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String devicesGenericError(String error);

  /// No description provided for @devicesIpLookupError.
  ///
  /// In en, this message translates to:
  /// **'IP error: {error}'**
  String devicesIpLookupError(String error);

  /// No description provided for @devicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesTitle;

  /// No description provided for @devicesPromoTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices in KOMET'**
  String get devicesPromoTitle;

  /// No description provided for @devicesPromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Who has access to your account?'**
  String get devicesPromoSubtitle;

  /// No description provided for @devicesScanQrButton.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get devicesScanQrButton;

  /// No description provided for @devicesCurrentSuffix.
  ///
  /// In en, this message translates to:
  /// **' (current)'**
  String get devicesCurrentSuffix;

  /// No description provided for @devicesOnlineStatus.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get devicesOnlineStatus;

  /// No description provided for @devicesTerminateOthersButton.
  ///
  /// In en, this message translates to:
  /// **'Terminate all sessions except the current one'**
  String get devicesTerminateOthersButton;

  /// No description provided for @devicesMobileNetworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile network'**
  String get devicesMobileNetworkLabel;

  /// No description provided for @devicesProxyDetectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Proxy/VPN detected'**
  String get devicesProxyDetectedLabel;

  /// No description provided for @themeSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSettingsTitle;

  /// No description provided for @themeSettingsModeCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeSettingsModeCardTitle;

  /// No description provided for @themeSettingsModeCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Light, dark, or automatic switching'**
  String get themeSettingsModeCardSubtitle;

  /// No description provided for @themeSettingsModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSettingsModeSystem;

  /// No description provided for @themeSettingsModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeSettingsModeLight;

  /// No description provided for @themeSettingsModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeSettingsModeDark;

  /// No description provided for @themeSettingsModeSchedule.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get themeSettingsModeSchedule;

  /// No description provided for @themeSettingsAmoledTitle.
  ///
  /// In en, this message translates to:
  /// **'AMOLED black'**
  String get themeSettingsAmoledTitle;

  /// No description provided for @themeSettingsAmoledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pure black background for OLED screens'**
  String get themeSettingsAmoledSubtitle;

  /// No description provided for @themeSettingsScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get themeSettingsScheduleTitle;

  /// No description provided for @themeSettingsScheduleSubtitleEnabled.
  ///
  /// In en, this message translates to:
  /// **'When dark theme turns on automatically'**
  String get themeSettingsScheduleSubtitleEnabled;

  /// No description provided for @themeSettingsScheduleSubtitleDisabled.
  ///
  /// In en, this message translates to:
  /// **'Available in \"Scheduled\" mode'**
  String get themeSettingsScheduleSubtitleDisabled;

  /// No description provided for @themeSettingsScheduleDarkFrom.
  ///
  /// In en, this message translates to:
  /// **'Dark from'**
  String get themeSettingsScheduleDarkFrom;

  /// No description provided for @themeSettingsScheduleLightFrom.
  ///
  /// In en, this message translates to:
  /// **'Light from'**
  String get themeSettingsScheduleLightFrom;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @appearanceVisualStyleTitle.
  ///
  /// In en, this message translates to:
  /// **'Visual style'**
  String get appearanceVisualStyleTitle;

  /// No description provided for @appearanceVisualStyleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Material You or dimensional Glossy capsules'**
  String get appearanceVisualStyleSubtitle;

  /// No description provided for @appearanceVisualStyleMaterialYou.
  ///
  /// In en, this message translates to:
  /// **'Material You'**
  String get appearanceVisualStyleMaterialYou;

  /// No description provided for @appearanceVisualStyleGlossy.
  ///
  /// In en, this message translates to:
  /// **'Glossy'**
  String get appearanceVisualStyleGlossy;

  /// No description provided for @appearanceChatChromeTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat screen elements'**
  String get appearanceChatChromeTitle;

  /// No description provided for @appearanceChatChromeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Background of the top and bottom panels: color, blur, or transparent. With blur or transparency, messages scroll under the panels'**
  String get appearanceChatChromeSubtitle;

  /// No description provided for @appearanceChatChromeColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get appearanceChatChromeColor;

  /// No description provided for @appearanceChatChromeBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get appearanceChatChromeBlur;

  /// No description provided for @appearanceChatChromeNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get appearanceChatChromeNone;

  /// No description provided for @appearanceChatChromeTransparent.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get appearanceChatChromeTransparent;

  /// No description provided for @appearanceGradientTitle.
  ///
  /// In en, this message translates to:
  /// **'Gradient'**
  String get appearanceGradientTitle;

  /// No description provided for @appearanceGradientSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Depth and highlights in Glossy capsules'**
  String get appearanceGradientSubtitle;

  /// No description provided for @appearanceAccentColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get appearanceAccentColorTitle;

  /// No description provided for @appearanceAccentColorSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appearanceAccentColorSystem;

  /// No description provided for @appearanceAccentColorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Main color of the interface and bubbles'**
  String get appearanceAccentColorSubtitle;

  /// No description provided for @appearanceAccentColorSystemActive.
  ///
  /// In en, this message translates to:
  /// **'System color is active'**
  String get appearanceAccentColorSystemActive;

  /// No description provided for @appearanceAccentColorReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to system'**
  String get appearanceAccentColorReset;

  /// No description provided for @appearanceBubbleShapeTitle.
  ///
  /// In en, this message translates to:
  /// **'Message shape'**
  String get appearanceBubbleShapeTitle;

  /// No description provided for @appearanceBubbleShapeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bubble corner rounding'**
  String get appearanceBubbleShapeSubtitle;

  /// No description provided for @appearanceBubbleShapeMobile.
  ///
  /// In en, this message translates to:
  /// **'TG Mobile'**
  String get appearanceBubbleShapeMobile;

  /// No description provided for @appearanceBubbleShapeDesktop.
  ///
  /// In en, this message translates to:
  /// **'TG Desktop'**
  String get appearanceBubbleShapeDesktop;

  /// No description provided for @appearanceBubbleBehaviorTitle.
  ///
  /// In en, this message translates to:
  /// **'Message behavior'**
  String get appearanceBubbleBehaviorTitle;

  /// No description provided for @appearanceBubbleBehaviorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Whether bubble shape changes based on neighbors in a group'**
  String get appearanceBubbleBehaviorSubtitle;

  /// No description provided for @appearanceBubbleBehaviorMutable.
  ///
  /// In en, this message translates to:
  /// **'Mutable'**
  String get appearanceBubbleBehaviorMutable;

  /// No description provided for @appearanceBubbleBehaviorImmutable.
  ///
  /// In en, this message translates to:
  /// **'Immutable'**
  String get appearanceBubbleBehaviorImmutable;

  /// No description provided for @appearancePreviewHello.
  ///
  /// In en, this message translates to:
  /// **'Hi!'**
  String get appearancePreviewHello;

  /// No description provided for @appearancePreviewHowIsIt.
  ///
  /// In en, this message translates to:
  /// **'How do you like it?'**
  String get appearancePreviewHowIsIt;

  /// No description provided for @appearancePreviewHmm.
  ///
  /// In en, this message translates to:
  /// **'hmm...'**
  String get appearancePreviewHmm;

  /// No description provided for @appearancePreviewNotBad.
  ///
  /// In en, this message translates to:
  /// **'Not bad at all!'**
  String get appearancePreviewNotBad;

  /// No description provided for @callKometDetectedNotification.
  ///
  /// In en, this message translates to:
  /// **'This person uses Komet! :3'**
  String get callKometDetectedNotification;

  /// No description provided for @callStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get callStatusConnecting;

  /// No description provided for @callGroupConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get callGroupConnecting;

  /// No description provided for @callGroupWaitingParticipants.
  ///
  /// In en, this message translates to:
  /// **'Waiting for participants…'**
  String get callGroupWaitingParticipants;

  /// No description provided for @callParticipantYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get callParticipantYou;

  /// No description provided for @callParticipantFallback.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get callParticipantFallback;

  /// No description provided for @callTooltipMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get callTooltipMinimize;

  /// No description provided for @callTooltipKometHub.
  ///
  /// In en, this message translates to:
  /// **'Komet'**
  String get callTooltipKometHub;

  /// No description provided for @callInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'About call'**
  String get callInfoTitle;

  /// No description provided for @callPeerMicOff.
  ///
  /// In en, this message translates to:
  /// **'Microphone off'**
  String get callPeerMicOff;

  /// No description provided for @callPeerCameraOn.
  ///
  /// In en, this message translates to:
  /// **'Camera on'**
  String get callPeerCameraOn;

  /// No description provided for @callUnknownName.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get callUnknownName;

  /// No description provided for @callIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get callIncoming;

  /// No description provided for @callStatusRinging.
  ///
  /// In en, this message translates to:
  /// **'Calling'**
  String get callStatusRinging;

  /// No description provided for @callStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callStatusEnded;

  /// No description provided for @callDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get callDecline;

  /// No description provided for @callAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get callAccept;

  /// No description provided for @callSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get callSpeaker;

  /// No description provided for @callVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get callVideoLabel;

  /// No description provided for @callScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get callScreenLabel;

  /// No description provided for @callUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get callUnmute;

  /// No description provided for @callMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get callMute;

  /// No description provided for @callEndButton.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get callEndButton;

  /// No description provided for @callInfoClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get callInfoClient;

  /// No description provided for @callInfoPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get callInfoPlatform;

  /// No description provided for @callInfoCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get callInfoCountry;

  /// No description provided for @callInfoInContacts.
  ///
  /// In en, this message translates to:
  /// **'In contacts'**
  String get callInfoInContacts;

  /// No description provided for @callValueYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get callValueYes;

  /// No description provided for @callValueNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get callValueNo;

  /// No description provided for @callInfoPeerIp.
  ///
  /// In en, this message translates to:
  /// **'Peer IP'**
  String get callInfoPeerIp;

  /// No description provided for @callInfoPeerNetwork.
  ///
  /// In en, this message translates to:
  /// **'Peer network'**
  String get callInfoPeerNetwork;

  /// No description provided for @callInfoPath.
  ///
  /// In en, this message translates to:
  /// **'Connection path'**
  String get callInfoPath;

  /// No description provided for @callInfoCodec.
  ///
  /// In en, this message translates to:
  /// **'Codec'**
  String get callInfoCodec;

  /// No description provided for @callInfoServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get callInfoServer;

  /// No description provided for @callInfoTopology.
  ///
  /// In en, this message translates to:
  /// **'Topology'**
  String get callInfoTopology;

  /// No description provided for @callInfoStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get callInfoStatus;

  /// No description provided for @callStatusValueConnected.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get callStatusValueConnected;

  /// No description provided for @callStatusValueConnecting.
  ///
  /// In en, this message translates to:
  /// **'connecting…'**
  String get callStatusValueConnecting;

  /// No description provided for @callInfoPeerMic.
  ///
  /// In en, this message translates to:
  /// **'Peer microphone'**
  String get callInfoPeerMic;

  /// No description provided for @callMicValueOn.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get callMicValueOn;

  /// No description provided for @callMicValueOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get callMicValueOff;

  /// No description provided for @callInfoPeerCamera.
  ///
  /// In en, this message translates to:
  /// **'Peer camera'**
  String get callInfoPeerCamera;

  /// No description provided for @callCameraValueOn.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get callCameraValueOn;

  /// No description provided for @callCameraValueOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get callCameraValueOff;

  /// No description provided for @callInfoVideoTrack.
  ///
  /// In en, this message translates to:
  /// **'Video track'**
  String get callInfoVideoTrack;

  /// No description provided for @callInfoVideoTrackPresent.
  ///
  /// In en, this message translates to:
  /// **'yes ({count})'**
  String callInfoVideoTrackPresent(int count);

  /// No description provided for @callInfoVideoSize.
  ///
  /// In en, this message translates to:
  /// **'Video size'**
  String get callInfoVideoSize;

  /// No description provided for @callInfoFrameRendering.
  ///
  /// In en, this message translates to:
  /// **'Frame rendering'**
  String get callInfoFrameRendering;

  /// No description provided for @callBadgeEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get callBadgeEncrypted;

  /// No description provided for @callBadgeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get callBadgeAudio;

  /// No description provided for @callBadgeRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get callBadgeRecording;

  /// No description provided for @callBadgeNoiseSuppression.
  ///
  /// In en, this message translates to:
  /// **'Noise suppression'**
  String get callBadgeNoiseSuppression;

  /// No description provided for @callBadgeAnimoji.
  ///
  /// In en, this message translates to:
  /// **'Animoji'**
  String get callBadgeAnimoji;

  /// No description provided for @callInfoNoDataYet.
  ///
  /// In en, this message translates to:
  /// **'Data will appear after connecting…'**
  String get callInfoNoDataYet;

  /// No description provided for @hubTitleMenu.
  ///
  /// In en, this message translates to:
  /// **'Komet'**
  String get hubTitleMenu;

  /// No description provided for @hubChatPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Anonymous chat'**
  String get hubChatPageTitle;

  /// No description provided for @hubGamesTitle.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get hubGamesTitle;

  /// No description provided for @hubCheckersTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkers'**
  String get hubCheckersTitle;

  /// No description provided for @hubChatTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get hubChatTileTitle;

  /// No description provided for @hubChatTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anonymous messages'**
  String get hubChatTileSubtitle;

  /// No description provided for @hubGamesTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play with your partner'**
  String get hubGamesTileSubtitle;

  /// No description provided for @hubCheckersTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Russian checkers'**
  String get hubCheckersTileSubtitle;

  /// No description provided for @hubMoreSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'More coming soon…'**
  String get hubMoreSoonTitle;

  /// No description provided for @hubMoreSoonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In development'**
  String get hubMoreSoonSubtitle;

  /// No description provided for @hubChatPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Sent directly through the call, stored nowhere'**
  String get hubChatPrivacyNote;

  /// No description provided for @hubChatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get hubChatEmpty;

  /// No description provided for @hubChatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get hubChatInputHint;

  /// No description provided for @hubCheckersRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get hubCheckersRestart;

  /// No description provided for @hubCheckersYouWhite.
  ///
  /// In en, this message translates to:
  /// **'You\'re playing white'**
  String get hubCheckersYouWhite;

  /// No description provided for @hubCheckersYouBlack.
  ///
  /// In en, this message translates to:
  /// **'You\'re playing black'**
  String get hubCheckersYouBlack;

  /// No description provided for @hubCheckersWon.
  ///
  /// In en, this message translates to:
  /// **'You won 🎉'**
  String get hubCheckersWon;

  /// No description provided for @hubCheckersLost.
  ///
  /// In en, this message translates to:
  /// **'You lost'**
  String get hubCheckersLost;

  /// No description provided for @hubCheckersYourMove.
  ///
  /// In en, this message translates to:
  /// **'Your move'**
  String get hubCheckersYourMove;

  /// No description provided for @hubCheckersOpponentMove.
  ///
  /// In en, this message translates to:
  /// **'Opponent\'s move…'**
  String get hubCheckersOpponentMove;

  /// No description provided for @scheduledPickTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'When to send'**
  String get scheduledPickTimeTitle;

  /// No description provided for @scheduledEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get scheduledEditTitle;

  /// No description provided for @scheduledMessageTextHint.
  ///
  /// In en, this message translates to:
  /// **'Message text'**
  String get scheduledMessageTextHint;

  /// No description provided for @scheduledSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get scheduledSave;

  /// No description provided for @scheduledEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to edit message'**
  String get scheduledEditFailed;

  /// No description provided for @scheduledDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete scheduled message?'**
  String get scheduledDeleteConfirmTitle;

  /// No description provided for @scheduledDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'The message won\'t be sent.'**
  String get scheduledDeleteConfirmMessage;

  /// No description provided for @scheduledDeleteConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get scheduledDeleteConfirmLabel;

  /// No description provided for @scheduledDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete message'**
  String get scheduledDeleteFailed;

  /// No description provided for @scheduledAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduledAppBarTitle;

  /// No description provided for @scheduledEmpty.
  ///
  /// In en, this message translates to:
  /// **'No scheduled messages'**
  String get scheduledEmpty;

  /// No description provided for @scheduledAttachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get scheduledAttachPhoto;

  /// No description provided for @scheduledAttachVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get scheduledAttachVideo;

  /// No description provided for @scheduledAttachVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get scheduledAttachVoice;

  /// No description provided for @scheduledAttachFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get scheduledAttachFile;

  /// No description provided for @scheduledAttachLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get scheduledAttachLocation;

  /// No description provided for @scheduledAttachForwarded.
  ///
  /// In en, this message translates to:
  /// **'Forwarded'**
  String get scheduledAttachForwarded;

  /// No description provided for @scheduledAttachGeneric.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get scheduledAttachGeneric;

  /// No description provided for @contactProfileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String contactProfileLoadError(String error);

  /// No description provided for @contactProfileBot.
  ///
  /// In en, this message translates to:
  /// **'Bot'**
  String get contactProfileBot;

  /// No description provided for @contactProfileOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get contactProfileOnline;

  /// No description provided for @contactProfileRecentlyActive.
  ///
  /// In en, this message translates to:
  /// **'Recently active'**
  String get contactProfileRecentlyActive;

  /// No description provided for @contactProfileActionChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get contactProfileActionChat;

  /// No description provided for @contactProfileActionSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get contactProfileActionSound;

  /// No description provided for @contactProfileActionCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get contactProfileActionCall;

  /// No description provided for @contactProfileInfoPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contactProfileInfoPhone;

  /// No description provided for @contactProfileInfoCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get contactProfileInfoCountry;

  /// No description provided for @contactProfileInfoGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get contactProfileInfoGender;

  /// No description provided for @contactProfileInfoRegistration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get contactProfileInfoRegistration;

  /// No description provided for @contactProfileInfoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get contactProfileInfoUpdated;

  /// No description provided for @contactProfileInfoAccountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account status'**
  String get contactProfileInfoAccountStatus;

  /// No description provided for @contactProfileInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get contactProfileInfoDescription;

  /// No description provided for @contactProfileInfoLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get contactProfileInfoLink;

  /// No description provided for @contactProfileInfoFlags.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get contactProfileInfoFlags;

  /// No description provided for @nfcPeerNameFallback.
  ///
  /// In en, this message translates to:
  /// **'Contact #{id}'**
  String nfcPeerNameFallback(String id);

  /// No description provided for @nfcPeerFirstNameFallback.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get nfcPeerFirstNameFallback;

  /// No description provided for @nfcContactAdded.
  ///
  /// In en, this message translates to:
  /// **'Contact added'**
  String get nfcContactAdded;

  /// No description provided for @nfcAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add: {error}'**
  String nfcAddFailed(String error);

  /// No description provided for @nfcReasonBluetoothOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth and try again'**
  String get nfcReasonBluetoothOff;

  /// No description provided for @nfcReasonPermission.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permissions are needed for exchange'**
  String get nfcReasonPermission;

  /// No description provided for @nfcReasonDefault.
  ///
  /// In en, this message translates to:
  /// **'Failed to establish connection'**
  String get nfcReasonDefault;

  /// No description provided for @nfcSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact exchange'**
  String get nfcSheetTitle;

  /// No description provided for @nfcUnsupported.
  ///
  /// In en, this message translates to:
  /// **'NFC is not available on this device'**
  String get nfcUnsupported;

  /// No description provided for @nfcDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on NFC in phone settings and try again'**
  String get nfcDisabled;

  /// No description provided for @nfcScanningTitle.
  ///
  /// In en, this message translates to:
  /// **'Hold the phones close together'**
  String get nfcScanningTitle;

  /// No description provided for @nfcScanningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Both devices must keep this screen open'**
  String get nfcScanningSubtitle;

  /// No description provided for @nfcExchangingTitle.
  ///
  /// In en, this message translates to:
  /// **'Exchanging contacts…'**
  String get nfcExchangingTitle;

  /// No description provided for @nfcExchangingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Almost done'**
  String get nfcExchangingSubtitle;

  /// No description provided for @nfcPeerIdFallback.
  ///
  /// In en, this message translates to:
  /// **'ID {id}'**
  String nfcPeerIdFallback(String id);

  /// No description provided for @nfcAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get nfcAdded;

  /// No description provided for @nfcAddContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get nfcAddContact;

  /// No description provided for @chatInfoTabGeneralChats.
  ///
  /// In en, this message translates to:
  /// **'Common chats'**
  String get chatInfoTabGeneralChats;

  /// No description provided for @chatInfoTabMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get chatInfoTabMedia;

  /// No description provided for @chatInfoTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get chatInfoTabFiles;

  /// No description provided for @chatInfoTabVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice messages'**
  String get chatInfoTabVoice;

  /// No description provided for @chatInfoTabLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get chatInfoTabLinks;

  /// No description provided for @chatInfoTabMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get chatInfoTabMembers;

  /// No description provided for @chatInfoEmptyGeneralChats.
  ///
  /// In en, this message translates to:
  /// **'No common chats'**
  String get chatInfoEmptyGeneralChats;

  /// No description provided for @chatInfoEmptyMedia.
  ///
  /// In en, this message translates to:
  /// **'No media'**
  String get chatInfoEmptyMedia;

  /// No description provided for @chatInfoEmptyFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get chatInfoEmptyFiles;

  /// No description provided for @chatInfoEmptyVoice.
  ///
  /// In en, this message translates to:
  /// **'No voice messages'**
  String get chatInfoEmptyVoice;

  /// No description provided for @chatInfoEmptyLinks.
  ///
  /// In en, this message translates to:
  /// **'No links'**
  String get chatInfoEmptyLinks;

  /// No description provided for @chatInfoOnlineOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{online} of {total} online'**
  String chatInfoOnlineOfTotal(String online, String total);

  /// No description provided for @sharedMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String sharedMembersCount(int count);

  /// No description provided for @sharedLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get sharedLoadMore;

  /// No description provided for @sharedGoToMessage.
  ///
  /// In en, this message translates to:
  /// **'Go to message'**
  String get sharedGoToMessage;

  /// No description provided for @sharedDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get sharedDownload;

  /// No description provided for @sharedCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get sharedCopyLink;

  /// No description provided for @sharedLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get sharedLinkCopied;

  /// No description provided for @chatInfoActionLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get chatInfoActionLeave;

  /// No description provided for @chatInfoBio.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get chatInfoBio;

  /// No description provided for @chatInfoInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get chatInfoInviteLink;

  /// No description provided for @chatInfoCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get chatInfoCollapse;

  /// No description provided for @chatInfoShowMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatInfoShowMore;

  /// No description provided for @chatInfoAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get chatInfoAddMember;

  /// No description provided for @chatInfoRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'owner'**
  String get chatInfoRoleOwner;

  /// No description provided for @chatInfoRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get chatInfoRoleAdmin;

  /// No description provided for @chatInfoNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get chatInfoNoData;

  /// No description provided for @chatInfoHideExtra.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get chatInfoHideExtra;

  /// No description provided for @chatInfoShowMoreExtra.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get chatInfoShowMoreExtra;

  /// No description provided for @chatInfoRowId.
  ///
  /// In en, this message translates to:
  /// **'Chat ID'**
  String get chatInfoRowId;

  /// No description provided for @chatInfoRowCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get chatInfoRowCreated;

  /// No description provided for @chatInfoRowModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get chatInfoRowModified;

  /// No description provided for @chatInfoRowMembersCount.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get chatInfoRowMembersCount;

  /// No description provided for @chatInfoRowOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get chatInfoRowOwner;

  /// No description provided for @chatInfoRowCreatedGroup.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get chatInfoRowCreatedGroup;

  /// No description provided for @chatInfoRowJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get chatInfoRowJoined;

  /// No description provided for @chatInfoRowModifiedGroup.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get chatInfoRowModifiedGroup;

  /// No description provided for @chatInfoRowHasBots.
  ///
  /// In en, this message translates to:
  /// **'Has bots'**
  String get chatInfoRowHasBots;

  /// No description provided for @chatInfoRowBlockedCount.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get chatInfoRowBlockedCount;

  /// No description provided for @chatInfoRowOfficialGroup.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get chatInfoRowOfficialGroup;

  /// No description provided for @chatInfoRowSignAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin signature'**
  String get chatInfoRowSignAdmin;

  /// No description provided for @chatInfoRowSubscribersCount.
  ///
  /// In en, this message translates to:
  /// **'Subscribers'**
  String get chatInfoRowSubscribersCount;

  /// No description provided for @chatInfoRowOfficialChannel.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get chatInfoRowOfficialChannel;

  /// No description provided for @chatInfoRowComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get chatInfoRowComments;

  /// No description provided for @chatInfoRowRkn.
  ///
  /// In en, this message translates to:
  /// **'Roskomnadzor approved'**
  String get chatInfoRowRkn;

  /// No description provided for @chatInfoRowOnlyAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admins only'**
  String get chatInfoRowOnlyAdmin;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTitle;

  /// No description provided for @securityLoadError.
  ///
  /// In en, this message translates to:
  /// **'Loading error: {error}'**
  String securityLoadError(String error);

  /// No description provided for @securitySaveError.
  ///
  /// In en, this message translates to:
  /// **'Save error: {error}'**
  String securitySaveError(String error);

  /// No description provided for @securityPrivacyAll.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get securityPrivacyAll;

  /// No description provided for @securityPrivacyContacts.
  ///
  /// In en, this message translates to:
  /// **'My contacts'**
  String get securityPrivacyContacts;

  /// No description provided for @securityPrivacyNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody'**
  String get securityPrivacyNobody;

  /// No description provided for @securityFamilyProtection.
  ///
  /// In en, this message translates to:
  /// **'Family protection'**
  String get securityFamilyProtection;

  /// No description provided for @securityEnabledFem.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get securityEnabledFem;

  /// No description provided for @securityDisabledFem.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get securityDisabledFem;

  /// No description provided for @securityPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Login password'**
  String get securityPasswordTitle;

  /// No description provided for @securityEnabledMasc.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get securityEnabledMasc;

  /// No description provided for @securityDisabledMasc.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get securityDisabledMasc;

  /// No description provided for @securityModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Safe mode'**
  String get securityModeTitle;

  /// No description provided for @securityModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hides personal information'**
  String get securityModeSubtitle;

  /// No description provided for @securitySettingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Changing this setting is not available yet'**
  String get securitySettingsUnavailable;

  /// No description provided for @securityFindByPhone.
  ///
  /// In en, this message translates to:
  /// **'Find me by phone number'**
  String get securityFindByPhone;

  /// No description provided for @securityWhoCanCall.
  ///
  /// In en, this message translates to:
  /// **'Who can call me'**
  String get securityWhoCanCall;

  /// No description provided for @securityWhoCanInvite.
  ///
  /// In en, this message translates to:
  /// **'Who can invite me to chats'**
  String get securityWhoCanInvite;

  /// No description provided for @securityShowContact.
  ///
  /// In en, this message translates to:
  /// **'Show contact'**
  String get securityShowContact;

  /// No description provided for @securityContentSafe.
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get securityContentSafe;

  /// No description provided for @securityContentAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get securityContentAll;

  /// No description provided for @securityShowOnlineStatus.
  ///
  /// In en, this message translates to:
  /// **'See online status'**
  String get securityShowOnlineStatus;

  /// No description provided for @securityShowMyNumber.
  ///
  /// In en, this message translates to:
  /// **'See my number'**
  String get securityShowMyNumber;

  /// No description provided for @securityConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get securityConfirmTitle;

  /// No description provided for @securityHiddenStatusWarning.
  ///
  /// In en, this message translates to:
  /// **'You won\'t be able to see the online status of other users.'**
  String get securityHiddenStatusWarning;

  /// No description provided for @securityConfidentialityHeader.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY'**
  String get securityConfidentialityHeader;

  /// No description provided for @securityReadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Read receipts'**
  String get securityReadReceipts;

  /// No description provided for @securityAltKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Alternative keyboard'**
  String get securityAltKeyboard;

  /// No description provided for @securityUnsafeFiles.
  ///
  /// In en, this message translates to:
  /// **'Accept unsafe files'**
  String get securityUnsafeFiles;

  /// No description provided for @securityAudioTranscription.
  ///
  /// In en, this message translates to:
  /// **'Audio transcription'**
  String get securityAudioTranscription;

  /// No description provided for @securityBlacklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Blacklist'**
  String get securityBlacklistTitle;

  /// No description provided for @securityBlacklistNotification.
  ///
  /// In en, this message translates to:
  /// **'Blacklist: {count} contacts'**
  String securityBlacklistNotification(String count);

  /// No description provided for @passwordEntryWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get passwordEntryWrongPassword;

  /// No description provided for @passwordEntryConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get passwordEntryConfirmTitle;

  /// No description provided for @passwordEntryCurrentPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get passwordEntryCurrentPasswordHint;

  /// No description provided for @passwordEntryContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get passwordEntryContinue;

  /// No description provided for @passwordEntryNotSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Password is not set'**
  String get passwordEntryNotSetTitle;

  /// No description provided for @passwordEntry2faSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get passwordEntry2faSubtitle;

  /// No description provided for @passwordEntrySetupAction.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get passwordEntrySetupAction;

  /// No description provided for @passwordEntryGateMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your login password to manage protection'**
  String get passwordEntryGateMessage;

  /// No description provided for @passwordEntryGenericPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordEntryGenericPasswordHint;

  /// No description provided for @passwordEntrySetTitle.
  ///
  /// In en, this message translates to:
  /// **'Password is set'**
  String get passwordEntrySetTitle;

  /// No description provided for @passwordEntryHintPrefix.
  ///
  /// In en, this message translates to:
  /// **'Hint: {hint}'**
  String passwordEntryHintPrefix(String hint);

  /// No description provided for @passwordEntryChangePasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get passwordEntryChangePasswordAction;

  /// No description provided for @passwordEntryChangeEmailAction.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get passwordEntryChangeEmailAction;

  /// No description provided for @passwordEntryDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete password'**
  String get passwordEntryDeleteAction;

  /// No description provided for @passwordEntryMinPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordEntryMinPasswordError;

  /// No description provided for @passwordEntryMismatchError.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordEntryMismatchError;

  /// No description provided for @passwordEntryInvalidEmailError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get passwordEntryInvalidEmailError;

  /// No description provided for @passwordEntryInvalidCodeError.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get passwordEntryInvalidCodeError;

  /// No description provided for @passwordEntrySetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Password setup'**
  String get passwordEntrySetupTitle;

  /// No description provided for @passwordEntryStepPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordEntryStepPassword;

  /// No description provided for @passwordEntryStepHint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get passwordEntryStepHint;

  /// No description provided for @passwordEntryStepEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get passwordEntryStepEmail;

  /// No description provided for @passwordEntryStepCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get passwordEntryStepCode;

  /// No description provided for @passwordEntryChoosePassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a password'**
  String get passwordEntryChoosePassword;

  /// No description provided for @passwordEntryMinCharsHint.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordEntryMinCharsHint;

  /// No description provided for @passwordEntryEnterPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get passwordEntryEnterPasswordHint;

  /// No description provided for @passwordEntryEnterAgain.
  ///
  /// In en, this message translates to:
  /// **'Enter the password again'**
  String get passwordEntryEnterAgain;

  /// No description provided for @passwordEntryRepeatHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get passwordEntryRepeatHint;

  /// No description provided for @passwordEntryHintForPassword.
  ///
  /// In en, this message translates to:
  /// **'Password hint'**
  String get passwordEntryHintForPassword;

  /// No description provided for @passwordEntryOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get passwordEntryOptional;

  /// No description provided for @passwordEntryHintFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a hint (optional)'**
  String get passwordEntryHintFieldHint;

  /// No description provided for @passwordEntryLinkEmail.
  ///
  /// In en, this message translates to:
  /// **'Link an email'**
  String get passwordEntryLinkEmail;

  /// No description provided for @passwordEntryEmailPurpose.
  ///
  /// In en, this message translates to:
  /// **'For password recovery. Optional'**
  String get passwordEntryEmailPurpose;

  /// No description provided for @passwordEntryEmailHintOptional.
  ///
  /// In en, this message translates to:
  /// **'example@mail.com (optional)'**
  String get passwordEntryEmailHintOptional;

  /// No description provided for @passwordEntryEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get passwordEntryEnterCode;

  /// No description provided for @passwordEntryCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Code sent to {email}'**
  String passwordEntryCodeSentTo(String email);

  /// No description provided for @passwordEntryChangedNotif.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordEntryChangedNotif;

  /// No description provided for @passwordEntryNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get passwordEntryNewPassword;

  /// No description provided for @passwordEntryNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter new password'**
  String get passwordEntryNewPasswordHint;

  /// No description provided for @passwordEntryRepeatNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat new password'**
  String get passwordEntryRepeatNewPasswordHint;

  /// No description provided for @passwordEntryEmailChangedNotif.
  ///
  /// In en, this message translates to:
  /// **'Email changed'**
  String get passwordEntryEmailChangedNotif;

  /// No description provided for @passwordEntryNewEmail.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get passwordEntryNewEmail;

  /// No description provided for @passwordEntryEmailHint.
  ///
  /// In en, this message translates to:
  /// **'example@mail.com'**
  String get passwordEntryEmailHint;

  /// No description provided for @passwordEntryRemovedNotif.
  ///
  /// In en, this message translates to:
  /// **'Password removed'**
  String get passwordEntryRemovedNotif;

  /// No description provided for @passwordEntryRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove password'**
  String get passwordEntryRemoveTitle;

  /// No description provided for @passwordEntryRemoveWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning! Removing the password will weaken your account\'s protection.'**
  String get passwordEntryRemoveWarning;

  /// No description provided for @cloudStorageNoActiveProfile.
  ///
  /// In en, this message translates to:
  /// **'No active profile'**
  String get cloudStorageNoActiveProfile;

  /// No description provided for @cloudStorageSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create environment'**
  String get cloudStorageSetupFailed;

  /// No description provided for @cloudStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud storage'**
  String get cloudStorageTitle;

  /// No description provided for @cloudStorageNotConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud storage environment isn\'t set up'**
  String get cloudStorageNotConfiguredTitle;

  /// No description provided for @cloudStorageNotConfiguredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start? It\'s quick.'**
  String get cloudStorageNotConfiguredSubtitle;

  /// No description provided for @cloudStorageStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get cloudStorageStart;

  /// No description provided for @cloudStorageUploadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Uploading {percent}%'**
  String cloudStorageUploadingPercent(String percent);

  /// No description provided for @cloudStorageStartUploadHint.
  ///
  /// In en, this message translates to:
  /// **'Start an upload to see the progress bar'**
  String get cloudStorageStartUploadHint;

  /// No description provided for @cloudStorageEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No cloud files yet...'**
  String get cloudStorageEmptyTitle;

  /// No description provided for @cloudStorageEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add one?'**
  String get cloudStorageEmptySubtitle;

  /// No description provided for @cloudStorageUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get cloudStorageUpload;

  /// No description provided for @cloudStorageFromFile.
  ///
  /// In en, this message translates to:
  /// **'From file'**
  String get cloudStorageFromFile;

  /// No description provided for @cloudStorageById.
  ///
  /// In en, this message translates to:
  /// **'By ID'**
  String get cloudStorageById;

  /// No description provided for @cloudStorageFileIdLabel.
  ///
  /// In en, this message translates to:
  /// **'File ID'**
  String get cloudStorageFileIdLabel;

  /// No description provided for @cloudStorageSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get cloudStorageSizeLabel;

  /// No description provided for @cloudStorageNoLinkYet.
  ///
  /// In en, this message translates to:
  /// **'No link yet. Create one.'**
  String get cloudStorageNoLinkYet;

  /// No description provided for @cloudStorageLinkExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Link expires in {time}'**
  String cloudStorageLinkExpiresIn(String time);

  /// No description provided for @cloudStorageLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get cloudStorageLinkCopied;

  /// No description provided for @cloudStorageInvalidId.
  ///
  /// In en, this message translates to:
  /// **'Invalid ID'**
  String get cloudStorageInvalidId;

  /// No description provided for @cloudStorageSendError.
  ///
  /// In en, this message translates to:
  /// **'Send error'**
  String get cloudStorageSendError;

  /// No description provided for @cloudStorageSendByIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Send by ID'**
  String get cloudStorageSendByIdTitle;

  /// No description provided for @cloudStorageSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get cloudStorageSend;

  /// No description provided for @digitalIdGosuslugiLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Linking Gosuslugi isn\'t available on this platform. Do this in the mobile app.'**
  String get digitalIdGosuslugiLinkUnavailable;

  /// No description provided for @digitalIdGosuslugiLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not get the Gosuslugi link'**
  String get digitalIdGosuslugiLinkFailed;

  /// No description provided for @digitalIdGosuslugiTitle.
  ///
  /// In en, this message translates to:
  /// **'Gosuslugi'**
  String get digitalIdGosuslugiTitle;

  /// No description provided for @digitalIdDocsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Documents aren\'t available yet. Try again later.'**
  String get digitalIdDocsUnavailable;

  /// No description provided for @digitalIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Digital ID'**
  String get digitalIdTitle;

  /// No description provided for @digitalIdNotConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'Digital ID isn\'t set up'**
  String get digitalIdNotConfiguredTitle;

  /// No description provided for @digitalIdLinkGosuslugiHint.
  ///
  /// In en, this message translates to:
  /// **'Link your Gosuslugi account so your documents appear in Digital ID. The phone number in MAX must match the one in your Gosuslugi profile.'**
  String get digitalIdLinkGosuslugiHint;

  /// No description provided for @digitalIdLinkOrRefreshHint.
  ///
  /// In en, this message translates to:
  /// **'Link Gosuslugi to get access to your documents, or refresh the page if you\'ve already set up Digital ID.'**
  String get digitalIdLinkOrRefreshHint;

  /// No description provided for @digitalIdLoadDocuments.
  ///
  /// In en, this message translates to:
  /// **'Load documents'**
  String get digitalIdLoadDocuments;

  /// No description provided for @digitalIdLinkGosuslugiButton.
  ///
  /// In en, this message translates to:
  /// **'Link Gosuslugi'**
  String get digitalIdLinkGosuslugiButton;

  /// No description provided for @digitalIdGosuslugiProfileFallback.
  ///
  /// In en, this message translates to:
  /// **'Gosuslugi profile'**
  String get digitalIdGosuslugiProfileFallback;

  /// No description provided for @digitalIdBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Date of birth: {date}'**
  String digitalIdBirthDate(String date);

  /// No description provided for @digitalIdPersonalDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal data'**
  String get digitalIdPersonalDataTitle;

  /// No description provided for @digitalIdSnilsLabel.
  ///
  /// In en, this message translates to:
  /// **'SNILS'**
  String get digitalIdSnilsLabel;

  /// No description provided for @digitalIdInnLabel.
  ///
  /// In en, this message translates to:
  /// **'INN'**
  String get digitalIdInnLabel;

  /// No description provided for @digitalIdBirthPlaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Place of birth'**
  String get digitalIdBirthPlaceLabel;

  /// No description provided for @digitalIdRegistrationAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Registration address'**
  String get digitalIdRegistrationAddressLabel;

  /// No description provided for @digitalIdDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get digitalIdDocumentsTitle;

  /// No description provided for @digitalIdDocSeries.
  ///
  /// In en, this message translates to:
  /// **'series {series}'**
  String digitalIdDocSeries(String series);

  /// No description provided for @digitalIdDocNumber.
  ///
  /// In en, this message translates to:
  /// **'No. {number}'**
  String digitalIdDocNumber(String number);

  /// No description provided for @digitalIdPassesTitle.
  ///
  /// In en, this message translates to:
  /// **'Passes'**
  String get digitalIdPassesTitle;

  /// No description provided for @digitalIdCardInn.
  ///
  /// In en, this message translates to:
  /// **'INN {inn}'**
  String digitalIdCardInn(String inn);

  /// No description provided for @digitalIdBiometryConfigured.
  ///
  /// In en, this message translates to:
  /// **'Biometrics set up on this device'**
  String get digitalIdBiometryConfigured;

  /// No description provided for @digitalIdBiometryNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Biometrics not set up on this device'**
  String get digitalIdBiometryNotConfigured;

  /// No description provided for @digitalIdDocPassport.
  ///
  /// In en, this message translates to:
  /// **'Russian passport'**
  String get digitalIdDocPassport;

  /// No description provided for @digitalIdDocOms.
  ///
  /// In en, this message translates to:
  /// **'Health insurance policy (OMS)'**
  String get digitalIdDocOms;

  /// No description provided for @digitalIdDocDriverLicense.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s license'**
  String get digitalIdDocDriverLicense;

  /// No description provided for @digitalIdDocVehicleSts.
  ///
  /// In en, this message translates to:
  /// **'Vehicle registration certificate (STS)'**
  String get digitalIdDocVehicleSts;

  /// No description provided for @digitalIdDocChildBirthCert.
  ///
  /// In en, this message translates to:
  /// **'Birth certificate'**
  String get digitalIdDocChildBirthCert;

  /// No description provided for @digitalIdDocPensionCert.
  ///
  /// In en, this message translates to:
  /// **'Pension certificate'**
  String get digitalIdDocPensionCert;

  /// No description provided for @digitalIdDocDisabledCert.
  ///
  /// In en, this message translates to:
  /// **'Disability certificate'**
  String get digitalIdDocDisabledCert;

  /// No description provided for @digitalIdDocLargeFamilyCert.
  ///
  /// In en, this message translates to:
  /// **'Large family certificate'**
  String get digitalIdDocLargeFamilyCert;

  /// No description provided for @digitalIdDocStudentTicket.
  ///
  /// In en, this message translates to:
  /// **'Student ID'**
  String get digitalIdDocStudentTicket;

  /// No description provided for @digitalIdDocChildInn.
  ///
  /// In en, this message translates to:
  /// **'Child\'s INN'**
  String get digitalIdDocChildInn;

  /// No description provided for @digitalIdDocChildOms.
  ///
  /// In en, this message translates to:
  /// **'Child\'s health insurance policy (OMS)'**
  String get digitalIdDocChildOms;

  /// No description provided for @attachSheetGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get attachSheetGallery;

  /// No description provided for @attachSheetPoll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get attachSheetPoll;

  /// No description provided for @attachSheetCameraComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Camera is coming soon'**
  String get attachSheetCameraComingSoon;

  /// No description provided for @attachSheetSendFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Send a file'**
  String get attachSheetSendFileTitle;

  /// No description provided for @attachSheetSendFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A document, archive, or any other file'**
  String get attachSheetSendFileSubtitle;

  /// No description provided for @attachSheetChooseFileButton.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get attachSheetChooseFileButton;

  /// No description provided for @attachSheetShareLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Share location'**
  String get attachSheetShareLocationTitle;

  /// No description provided for @attachSheetShareLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send your current location'**
  String get attachSheetShareLocationSubtitle;

  /// No description provided for @attachSheetSendLocationButton.
  ///
  /// In en, this message translates to:
  /// **'Send location'**
  String get attachSheetSendLocationButton;

  /// No description provided for @attachSheetCreatePoll.
  ///
  /// In en, this message translates to:
  /// **'Create poll'**
  String get attachSheetCreatePoll;

  /// No description provided for @attachSheetCreatePollSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A question with answer options'**
  String get attachSheetCreatePollSubtitle;

  /// No description provided for @attachSheetNoImagesFound.
  ///
  /// In en, this message translates to:
  /// **'No images found'**
  String get attachSheetNoImagesFound;

  /// No description provided for @attachSheetLimitedAccessInfo.
  ///
  /// In en, this message translates to:
  /// **'Not all photos are accessible'**
  String get attachSheetLimitedAccessInfo;

  /// No description provided for @attachSheetSectionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Section under development'**
  String get attachSheetSectionInProgress;

  /// No description provided for @attachSheetNoGalleryAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'No access to the gallery'**
  String get attachSheetNoGalleryAccessTitle;

  /// No description provided for @attachSheetNoGalleryAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow access to photos to pick them from here'**
  String get attachSheetNoGalleryAccessSubtitle;

  /// No description provided for @attachSheetAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get attachSheetAllow;

  /// No description provided for @attachSheetSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get attachSheetSettings;

  /// No description provided for @attachSheetAddCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a caption...'**
  String get attachSheetAddCaptionHint;

  /// No description provided for @attachSheetCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get attachSheetCamera;

  /// No description provided for @photoEditorApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply'**
  String get photoEditorApplyFailed;

  /// No description provided for @photoEditorFlipTooltip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get photoEditorFlipTooltip;

  /// No description provided for @photoEditorRotateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get photoEditorRotateTooltip;

  /// No description provided for @photoEditorCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get photoEditorCancel;

  /// No description provided for @photoEditorReset.
  ///
  /// In en, this message translates to:
  /// **'RESET'**
  String get photoEditorReset;

  /// No description provided for @photoEditorDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get photoEditorDone;

  /// No description provided for @photoEditorTextDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get photoEditorTextDialogTitle;

  /// No description provided for @photoEditorTextDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter text'**
  String get photoEditorTextDialogHint;

  /// No description provided for @photoEditorOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get photoEditorOk;

  /// No description provided for @photoEditorApplyChangesFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply changes'**
  String get photoEditorApplyChangesFailed;

  /// No description provided for @photoEditorClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get photoEditorClearAll;

  /// No description provided for @photoEditorAddText.
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get photoEditorAddText;

  /// No description provided for @photoEditorTabDraw.
  ///
  /// In en, this message translates to:
  /// **'DRAW'**
  String get photoEditorTabDraw;

  /// No description provided for @photoEditorTabStickers.
  ///
  /// In en, this message translates to:
  /// **'STICKERS'**
  String get photoEditorTabStickers;

  /// No description provided for @photoEditorTabText.
  ///
  /// In en, this message translates to:
  /// **'TEXT'**
  String get photoEditorTabText;

  /// No description provided for @photoEditorChannelAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get photoEditorChannelAll;

  /// No description provided for @photoEditorChannelRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get photoEditorChannelRed;

  /// No description provided for @photoEditorChannelGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get photoEditorChannelGreen;

  /// No description provided for @photoEditorChannelBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get photoEditorChannelBlue;

  /// No description provided for @photoEditorEnhance.
  ///
  /// In en, this message translates to:
  /// **'Enhance'**
  String get photoEditorEnhance;

  /// No description provided for @photoEditorExposure.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get photoEditorExposure;

  /// No description provided for @photoEditorContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get photoEditorContrast;

  /// No description provided for @photoEditorSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get photoEditorSaturation;

  /// No description provided for @photoEditorWarmth.
  ///
  /// In en, this message translates to:
  /// **'Warmth'**
  String get photoEditorWarmth;

  /// No description provided for @photoEditorVignette.
  ///
  /// In en, this message translates to:
  /// **'Vignette'**
  String get photoEditorVignette;

  /// No description provided for @photoEditorBlurOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get photoEditorBlurOff;

  /// No description provided for @photoEditorBlurRadial.
  ///
  /// In en, this message translates to:
  /// **'Radial'**
  String get photoEditorBlurRadial;

  /// No description provided for @photoEditorBlurLinear.
  ///
  /// In en, this message translates to:
  /// **'Linear'**
  String get photoEditorBlurLinear;

  /// No description provided for @fontSettingsInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Enter a font link or name'**
  String get fontSettingsInvalidInput;

  /// No description provided for @fontSettingsFontNotFound.
  ///
  /// In en, this message translates to:
  /// **'Font \"{name}\" not found or no network'**
  String fontSettingsFontNotFound(String name);

  /// No description provided for @fontSettingsFontAdded.
  ///
  /// In en, this message translates to:
  /// **'Font \"{name}\" added'**
  String fontSettingsFontAdded(String name);

  /// No description provided for @fontSettingsFontRemoved.
  ///
  /// In en, this message translates to:
  /// **'Font \"{name}\" removed'**
  String fontSettingsFontRemoved(String name);

  /// No description provided for @fontSettingsAddFontTitle.
  ///
  /// In en, this message translates to:
  /// **'Add font'**
  String get fontSettingsAddFontTitle;

  /// No description provided for @fontSettingsAddFontDescription.
  ///
  /// In en, this message translates to:
  /// **'Paste a Google Fonts link or font name'**
  String get fontSettingsAddFontDescription;

  /// No description provided for @fontSettingsAddFontConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get fontSettingsAddFontConfirm;

  /// No description provided for @fontSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get fontSettingsTitle;

  /// No description provided for @fontSettingsSectionFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get fontSettingsSectionFont;

  /// No description provided for @fontSettingsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get fontSettingsLoading;

  /// No description provided for @fontSettingsSectionFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSettingsSectionFontSize;

  /// No description provided for @fontSettingsPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get fontSettingsPreviewLabel;

  /// No description provided for @fontSettingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get fontSettingsReset;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is out. Update the app?'**
  String updateAvailableBody(String version);

  /// No description provided for @updateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S NEW'**
  String get updateWhatsNew;

  /// No description provided for @updateAction.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateAction;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get updateSkip;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get updateDownloading;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download the update'**
  String get updateDownloadFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
