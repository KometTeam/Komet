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

  /// No description provided for @serverTrustMincifryTitle.
  ///
  /// In en, this message translates to:
  /// **'Trust the Минцифры CA'**
  String get serverTrustMincifryTitle;

  /// No description provided for @serverTrustMincifrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required for api2.oneme.ru: its certificate chains to the Russian Trusted Root CA, which is absent from the standard trust store. The root is bundled with the app; other hosts keep using the usual roots.'**
  String get serverTrustMincifrySubtitle;

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

  /// No description provided for @codeErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid code'**
  String get codeErrorInvalid;

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

  /// No description provided for @infoPacketSection.
  ///
  /// In en, this message translates to:
  /// **'Login packet'**
  String get infoPacketSection;

  /// No description provided for @infoChatsSection.
  ///
  /// In en, this message translates to:
  /// **'Chats in login packet'**
  String get infoChatsSection;

  /// No description provided for @infoChatSettingsSection.
  ///
  /// In en, this message translates to:
  /// **'Per-chat settings'**
  String get infoChatSettingsSection;

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

  /// No description provided for @infoExperimentsSection.
  ///
  /// In en, this message translates to:
  /// **'Experiments'**
  String get infoExperimentsSection;

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

  /// No description provided for @infoPhone.
  ///
  /// In en, this message translates to:
  /// **'phone'**
  String get infoPhone;

  /// No description provided for @infoPhotoId.
  ///
  /// In en, this message translates to:
  /// **'photoId'**
  String get infoPhotoId;

  /// No description provided for @infoAccountStatus.
  ///
  /// In en, this message translates to:
  /// **'accountStatus'**
  String get infoAccountStatus;

  /// No description provided for @infoContactOptions.
  ///
  /// In en, this message translates to:
  /// **'contact options'**
  String get infoContactOptions;

  /// No description provided for @infoProfileOptions.
  ///
  /// In en, this message translates to:
  /// **'profile options'**
  String get infoProfileOptions;

  /// No description provided for @infoNames.
  ///
  /// In en, this message translates to:
  /// **'names'**
  String get infoNames;

  /// No description provided for @infoBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'baseUrl'**
  String get infoBaseUrl;

  /// No description provided for @infoBaseRawUrl.
  ///
  /// In en, this message translates to:
  /// **'baseRawUrl'**
  String get infoBaseRawUrl;

  /// No description provided for @infoChatMarker.
  ///
  /// In en, this message translates to:
  /// **'chatMarker'**
  String get infoChatMarker;

  /// No description provided for @infoServerTime.
  ///
  /// In en, this message translates to:
  /// **'server time'**
  String get infoServerTime;

  /// No description provided for @infoUpdates.
  ///
  /// In en, this message translates to:
  /// **'updates'**
  String get infoUpdates;

  /// No description provided for @infoMessagesCount.
  ///
  /// In en, this message translates to:
  /// **'messages in packet'**
  String get infoMessagesCount;

  /// No description provided for @infoContactsCount.
  ///
  /// In en, this message translates to:
  /// **'contacts in packet'**
  String get infoContactsCount;

  /// No description provided for @infoPresenceCount.
  ///
  /// In en, this message translates to:
  /// **'presence records'**
  String get infoPresenceCount;

  /// No description provided for @infoConfigHash.
  ///
  /// In en, this message translates to:
  /// **'config hash'**
  String get infoConfigHash;

  /// No description provided for @infoChatsCount.
  ///
  /// In en, this message translates to:
  /// **'chats loaded'**
  String get infoChatsCount;

  /// No description provided for @infoChatsActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get infoChatsActive;

  /// No description provided for @infoChatsHidden.
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get infoChatsHidden;

  /// No description provided for @infoChatsDialogs.
  ///
  /// In en, this message translates to:
  /// **'dialogs'**
  String get infoChatsDialogs;

  /// No description provided for @infoChatsGroups.
  ///
  /// In en, this message translates to:
  /// **'groups'**
  String get infoChatsGroups;

  /// No description provided for @infoChatsChannels.
  ///
  /// In en, this message translates to:
  /// **'channels'**
  String get infoChatsChannels;

  /// No description provided for @infoChatsUnread.
  ///
  /// In en, this message translates to:
  /// **'unread chats'**
  String get infoChatsUnread;

  /// No description provided for @infoChatsNewMessages.
  ///
  /// In en, this message translates to:
  /// **'new messages'**
  String get infoChatsNewMessages;

  /// No description provided for @infoChatsMessages.
  ///
  /// In en, this message translates to:
  /// **'messages in loaded chats'**
  String get infoChatsMessages;

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

  /// No description provided for @commentsWrite.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get commentsWrite;

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @commentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 comment} other{{count} comments}}'**
  String commentsCount(int count);

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

  /// No description provided for @editProfileBio.
  ///
  /// In en, this message translates to:
  /// **'About me'**
  String get editProfileBio;

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

  /// No description provided for @msgActionsCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get msgActionsCopyLink;

  /// No description provided for @msgActionsSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get msgActionsSelectAll;

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

  /// No description provided for @msgActionsInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get msgActionsInfo;

  /// No description provided for @msgActionsReadBy.
  ///
  /// In en, this message translates to:
  /// **'Read by'**
  String get msgActionsReadBy;

  /// No description provided for @msgActionsReadByEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody has read it yet'**
  String get msgActionsReadByEmpty;

  /// No description provided for @msgActionsReadByUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get msgActionsReadByUnknownUser;

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

  /// No description provided for @notificationsFkmIosUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are not available on iOS yet.'**
  String get notificationsFkmIosUnsupported;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsFkmSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications without Google (FKM)'**
  String get notificationsFkmSectionTitle;

  /// No description provided for @notificationsFkmEnableLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get notificationsFkmEnableLabel;

  /// No description provided for @notificationsFkmEnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Komet keeps its own connection to the server and shows notifications itself. A service notification will stay in the shade while this is on.'**
  String get notificationsFkmEnableSubtitle;

  /// No description provided for @notificationsFkmUnsupported.
  ///
  /// In en, this message translates to:
  /// **'FKM is Android-only'**
  String get notificationsFkmUnsupported;

  /// No description provided for @notificationsFkmBatteryAction.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get notificationsFkmBatteryAction;

  /// No description provided for @notificationsFkmBatteryMessage.
  ///
  /// In en, this message translates to:
  /// **'Otherwise the system will put the background connection to sleep and notifications will be late or lost.'**
  String get notificationsFkmBatteryMessage;

  /// No description provided for @notificationsFkmBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off battery saving?'**
  String get notificationsFkmBatteryTitle;

  /// No description provided for @notificationsFkmPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'FKM cannot work without the notification permission'**
  String get notificationsFkmPermissionDenied;

  /// No description provided for @notificationsFkmConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Enable FKM'**
  String get notificationsFkmConfirmAction;

  /// No description provided for @notificationsFkmConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Notifications will arrive over the app’s own background connection, and a permanent service notification will stay in the shade. You can turn FKM off right from it.'**
  String get notificationsFkmConfirmMessage;

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

  /// No description provided for @themeSettingsCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get themeSettingsCustomTitle;

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

  /// No description provided for @appearanceStyleAuto.
  ///
  /// In en, this message translates to:
  /// **'Match theme'**
  String get appearanceStyleAuto;

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

  /// No description provided for @appearanceVisualStyleLiquidGlass.
  ///
  /// In en, this message translates to:
  /// **'Liquid Glass'**
  String get appearanceVisualStyleLiquidGlass;

  /// No description provided for @appearanceGlassMaterial.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get appearanceGlassMaterial;

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
  /// **'Frost blur'**
  String get appearanceChatChromeTransparent;

  /// No description provided for @appearanceComposerTitle.
  ///
  /// In en, this message translates to:
  /// **'Input bar'**
  String get appearanceComposerTitle;

  /// No description provided for @appearanceComposerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Style and background of the message input bar'**
  String get appearanceComposerSubtitle;

  /// No description provided for @appearanceComposerBackgroundStandard.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get appearanceComposerBackgroundStandard;

  /// No description provided for @appearanceComposerBackgroundFrost.
  ///
  /// In en, this message translates to:
  /// **'Frost blur'**
  String get appearanceComposerBackgroundFrost;

  /// No description provided for @appearanceNavPillTitle.
  ///
  /// In en, this message translates to:
  /// **'Switcher style'**
  String get appearanceNavPillTitle;

  /// No description provided for @appearanceNavPillSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Section switcher on the chats screen'**
  String get appearanceNavPillSubtitle;

  /// No description provided for @appearanceNavPillGlossy.
  ///
  /// In en, this message translates to:
  /// **'Glossy'**
  String get appearanceNavPillGlossy;

  /// No description provided for @appearanceNavPillFrost.
  ///
  /// In en, this message translates to:
  /// **'G-FrostBlur'**
  String get appearanceNavPillFrost;

  /// No description provided for @playbackPillAt.
  ///
  /// In en, this message translates to:
  /// **'at'**
  String get playbackPillAt;

  /// No description provided for @playbackPillYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get playbackPillYou;

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

  /// No description provided for @appearanceSpectrumTitle.
  ///
  /// In en, this message translates to:
  /// **'Spectrum background'**
  String get appearanceSpectrumTitle;

  /// No description provided for @appearanceSpectrumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Experimental — living bars beneath the interface'**
  String get appearanceSpectrumSubtitle;

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

  /// No description provided for @callLinkGroupCall.
  ///
  /// In en, this message translates to:
  /// **'Group call'**
  String get callLinkGroupCall;

  /// No description provided for @callLinkSendInMax.
  ///
  /// In en, this message translates to:
  /// **'Send in MAX'**
  String get callLinkSendInMax;

  /// No description provided for @callLinkStart.
  ///
  /// In en, this message translates to:
  /// **'Start call'**
  String get callLinkStart;

  /// No description provided for @callLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Link sent'**
  String get callLinkSent;

  /// No description provided for @callLinkSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the link'**
  String get callLinkSendFailed;

  /// No description provided for @callLinkCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the call'**
  String get callLinkCreateFailed;

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

  /// No description provided for @callTooltipExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get callTooltipExpand;

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

  /// No description provided for @callCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable: {error}'**
  String callCameraUnavailable(Object error);

  /// No description provided for @callTooltipMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get callTooltipMicrophone;

  /// No description provided for @callMicrophoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get callMicrophoneTitle;

  /// No description provided for @callMicrophoneSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get callMicrophoneSystem;

  /// No description provided for @callMicrophoneEmpty.
  ///
  /// In en, this message translates to:
  /// **'No microphones found'**
  String get callMicrophoneEmpty;

  /// No description provided for @callMicrophoneRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get callMicrophoneRefresh;

  /// No description provided for @callMicrophoneMonitors.
  ///
  /// In en, this message translates to:
  /// **'Monitors — system audio'**
  String get callMicrophoneMonitors;

  /// No description provided for @callMicrophoneFallback.
  ///
  /// In en, this message translates to:
  /// **'Microphone {index}'**
  String callMicrophoneFallback(Object index);

  /// No description provided for @callMicrophoneFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch microphone: {error}'**
  String callMicrophoneFailed(Object error);

  /// No description provided for @callMicStillLive.
  ///
  /// In en, this message translates to:
  /// **'Still live'**
  String get callMicStillLive;

  /// No description provided for @callNoMuteHint.
  ///
  /// In en, this message translates to:
  /// **'--no-mute: audio keeps going out even while the mic is off'**
  String get callNoMuteHint;

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

  /// No description provided for @contactProfileActionAddContact.
  ///
  /// In en, this message translates to:
  /// **'Add to contacts'**
  String get contactProfileActionAddContact;

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

  /// No description provided for @contactIdFallback.
  ///
  /// In en, this message translates to:
  /// **'ID {id}'**
  String contactIdFallback(String id);

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

  /// No description provided for @photoViewerCounter.
  ///
  /// In en, this message translates to:
  /// **'Photo {index} of {total}'**
  String photoViewerCounter(int index, int total);

  /// No description provided for @photoViewerCounterFile.
  ///
  /// In en, this message translates to:
  /// **'FILE of {total}'**
  String photoViewerCounterFile(int total);

  /// No description provided for @photoViewerSentToday.
  ///
  /// In en, this message translates to:
  /// **'{sender} • today at {time}'**
  String photoViewerSentToday(String sender, String time);

  /// No description provided for @photoViewerSentOn.
  ///
  /// In en, this message translates to:
  /// **'{sender} • {date} at {time}'**
  String photoViewerSentOn(String sender, String date, String time);

  /// No description provided for @photoViewerSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get photoViewerSaveAs;

  /// No description provided for @photoViewerSaveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to gallery'**
  String get photoViewerSaveToGallery;

  /// No description provided for @photoViewerViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all photos'**
  String get photoViewerViewAll;

  /// No description provided for @photoViewerRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get photoViewerRotate;

  /// No description provided for @mediaViewerCounter.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String mediaViewerCounter(int index, int total);

  /// No description provided for @mediaViewerViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all media'**
  String get mediaViewerViewAll;

  /// No description provided for @videoViewerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get videoViewerSettings;

  /// No description provided for @videoViewerSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get videoViewerSpeed;

  /// No description provided for @videoViewerQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get videoViewerQuality;

  /// No description provided for @videoViewerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play the video'**
  String get videoViewerFailed;

  /// No description provided for @videoViewerRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get videoViewerRetry;

  /// No description provided for @videoViewerClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get videoViewerClose;

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

  /// No description provided for @chatInfoActionSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get chatInfoActionSubscribe;

  /// No description provided for @chatInfoSubscribed.
  ///
  /// In en, this message translates to:
  /// **'You subscribed to the channel'**
  String get chatInfoSubscribed;

  /// No description provided for @chatInfoSubscribeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not subscribe to the channel'**
  String get chatInfoSubscribeFailed;

  /// No description provided for @chatInfoActionJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get chatInfoActionJoin;

  /// No description provided for @chatInfoJoinedGroup.
  ///
  /// In en, this message translates to:
  /// **'You joined the group'**
  String get chatInfoJoinedGroup;

  /// No description provided for @chatInfoJoinGroupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not join the group'**
  String get chatInfoJoinGroupFailed;

  /// No description provided for @chatInfoActionMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get chatInfoActionMuted;

  /// No description provided for @chatInfoNotificationsOn.
  ///
  /// In en, this message translates to:
  /// **'Notifications on'**
  String get chatInfoNotificationsOn;

  /// No description provided for @chatInfoNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications off'**
  String get chatInfoNotificationsOff;

  /// No description provided for @chatInfoMenuBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get chatInfoMenuBlock;

  /// No description provided for @chatInfoMenuUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get chatInfoMenuUnblock;

  /// No description provided for @chatInfoMenuDeleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get chatInfoMenuDeleteChat;

  /// No description provided for @chatInfoMenuClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get chatInfoMenuClearHistory;

  /// No description provided for @chatInfoClearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get chatInfoClearHistoryTitle;

  /// No description provided for @chatInfoClearHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'All messages in this chat will be deleted permanently.'**
  String get chatInfoClearHistoryMessage;

  /// No description provided for @chatInfoClearHistoryForAll.
  ///
  /// In en, this message translates to:
  /// **'For everyone'**
  String get chatInfoClearHistoryForAll;

  /// No description provided for @chatInfoClearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get chatInfoClearHistoryConfirm;

  /// No description provided for @chatInfoClearHistoryDone.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get chatInfoClearHistoryDone;

  /// No description provided for @chatInfoDeleteChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get chatInfoDeleteChatTitle;

  /// No description provided for @chatInfoDeleteChatMessage.
  ///
  /// In en, this message translates to:
  /// **'The chat will be deleted together with the whole conversation.'**
  String get chatInfoDeleteChatMessage;

  /// No description provided for @chatInfoDeleteChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatInfoDeleteChatConfirm;

  /// No description provided for @chatInfoLeaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get chatInfoLeaveGroupTitle;

  /// No description provided for @chatInfoLeaveGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'You will no longer receive messages from this group.'**
  String get chatInfoLeaveGroupMessage;

  /// No description provided for @chatInfoLeaveChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave channel'**
  String get chatInfoLeaveChannelTitle;

  /// No description provided for @chatInfoLeaveChannelMessage.
  ///
  /// In en, this message translates to:
  /// **'You will no longer receive posts from this channel.'**
  String get chatInfoLeaveChannelMessage;

  /// No description provided for @chatInfoLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get chatInfoLeaveConfirm;

  /// No description provided for @chatInfoLeaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not leave the chat'**
  String get chatInfoLeaveFailed;

  /// No description provided for @chatInfoCallConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a call'**
  String get chatInfoCallConfirmTitle;

  /// No description provided for @chatInfoCallConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Call {name}?'**
  String chatInfoCallConfirmMessage(String name);

  /// No description provided for @chatInfoConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get chatInfoConfirmYes;

  /// No description provided for @chatInfoConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get chatInfoConfirmNo;

  /// No description provided for @chatInfoCallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the call'**
  String get chatInfoCallFailed;

  /// No description provided for @chatInfoBlockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get chatInfoBlockConfirmTitle;

  /// No description provided for @chatInfoBlockConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to block {name}?'**
  String chatInfoBlockConfirmMessage(String name);

  /// No description provided for @chatInfoBlockDone.
  ///
  /// In en, this message translates to:
  /// **'User blocked'**
  String get chatInfoBlockDone;

  /// No description provided for @chatInfoUnblockDone.
  ///
  /// In en, this message translates to:
  /// **'User unblocked'**
  String get chatInfoUnblockDone;

  /// No description provided for @chatInfoBlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the block state'**
  String get chatInfoBlockFailed;

  /// No description provided for @chatInfoComplaintTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get chatInfoComplaintTitle;

  /// No description provided for @chatInfoComplaintSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a reason for the report'**
  String get chatInfoComplaintSubtitle;

  /// No description provided for @chatInfoComplaintSend.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get chatInfoComplaintSend;

  /// No description provided for @chatInfoComplaintClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get chatInfoComplaintClose;

  /// No description provided for @chatInfoComplaintEmpty.
  ///
  /// In en, this message translates to:
  /// **'Could not load the report reasons'**
  String get chatInfoComplaintEmpty;

  /// No description provided for @chatInfoComplaintSent.
  ///
  /// In en, this message translates to:
  /// **'Report sent'**
  String get chatInfoComplaintSent;

  /// No description provided for @chatInfoComplaintFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the report'**
  String get chatInfoComplaintFailed;

  /// No description provided for @chatInfoActionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatInfoActionCancel;

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

  /// No description provided for @chatInfoMemberDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get chatInfoMemberDeleted;

  /// No description provided for @chatInfoInviteByLink.
  ///
  /// In en, this message translates to:
  /// **'Invite via link'**
  String get chatInfoInviteByLink;

  /// No description provided for @chatInfoInviteLinkHint.
  ///
  /// In en, this message translates to:
  /// **'You can invite anyone with this link'**
  String get chatInfoInviteLinkHint;

  /// No description provided for @chatInfoAddMembersAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get chatInfoAddMembersAction;

  /// No description provided for @chatInfoMembersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get chatInfoMembersSearchHint;

  /// No description provided for @chatInfoAddMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one to add'**
  String get chatInfoAddMembersEmpty;

  /// No description provided for @chatInfoMembersAdded.
  ///
  /// In en, this message translates to:
  /// **'Members added'**
  String get chatInfoMembersAdded;

  /// No description provided for @chatInfoAddMembersError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add members'**
  String get chatInfoAddMembersError;

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

  /// No description provided for @chatSendConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Send this message to the chat?'**
  String get chatSendConfirmMessage;

  /// No description provided for @chatSendConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSendConfirmAction;

  /// No description provided for @chatInfoRowDisableForward.
  ///
  /// In en, this message translates to:
  /// **'Forwarding disabled'**
  String get chatInfoRowDisableForward;

  /// No description provided for @chatInfoRowCopyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Copying disabled'**
  String get chatInfoRowCopyDisabled;

  /// No description provided for @chatInfoRowOnlyAdminCall.
  ///
  /// In en, this message translates to:
  /// **'Admins can call'**
  String get chatInfoRowOnlyAdminCall;

  /// No description provided for @chatInfoRowAllCanPin.
  ///
  /// In en, this message translates to:
  /// **'Anyone can pin'**
  String get chatInfoRowAllCanPin;

  /// No description provided for @chatInfoRowMembersSeeLink.
  ///
  /// In en, this message translates to:
  /// **'Members see the link'**
  String get chatInfoRowMembersSeeLink;

  /// No description provided for @chatInfoRowConfirmBeforeSend.
  ///
  /// In en, this message translates to:
  /// **'Confirm before sending'**
  String get chatInfoRowConfirmBeforeSend;

  /// No description provided for @chatInfoRowOnlyOwnerIconTitle.
  ///
  /// In en, this message translates to:
  /// **'Owner edits title and icon'**
  String get chatInfoRowOnlyOwnerIconTitle;

  /// No description provided for @chatInfoRowPromotedDisabled.
  ///
  /// In en, this message translates to:
  /// **'Promoted content off'**
  String get chatInfoRowPromotedDisabled;

  /// No description provided for @chatInfoRowUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get chatInfoRowUserId;

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

  /// No description provided for @securityModeLocked.
  ///
  /// In en, this message translates to:
  /// **'Turn off safe mode to change this setting'**
  String get securityModeLocked;

  /// No description provided for @securityModeSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No unwanted contact or content'**
  String get securityModeSheetSubtitle;

  /// No description provided for @securityModeSheetSearch.
  ///
  /// In en, this message translates to:
  /// **'People won\'t be able to find you by phone number'**
  String get securityModeSheetSearch;

  /// No description provided for @securityModeSheetCalls.
  ///
  /// In en, this message translates to:
  /// **'Only people from your contacts can call you'**
  String get securityModeSheetCalls;

  /// No description provided for @securityModeSheetInvites.
  ///
  /// In en, this message translates to:
  /// **'Only people you\'ve already talked to can add you to groups'**
  String get securityModeSheetInvites;

  /// No description provided for @securityModeSheetContent.
  ///
  /// In en, this message translates to:
  /// **'You\'ll only see safe posts and channels'**
  String get securityModeSheetContent;

  /// No description provided for @securityModeSheetEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get securityModeSheetEnable;

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

  /// No description provided for @securityConfidentialityWarning.
  ///
  /// In en, this message translates to:
  /// **'These toggles do not exist in the original app, and they may be unavailable to you.\n\nIf the server refuses, it will drop the connection. (conection closed)'**
  String get securityConfidentialityWarning;

  /// No description provided for @securityConfidentialityDecline.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get securityConfidentialityDecline;

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

  /// No description provided for @attachSheetCameraError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera'**
  String get attachSheetCameraError;

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

  /// No description provided for @attachSheetMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get attachSheetMoreActions;

  /// No description provided for @attachSheetSendSeparately.
  ///
  /// In en, this message translates to:
  /// **'Send separately'**
  String get attachSheetSendSeparately;

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

  /// No description provided for @attachSheetContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get attachSheetContact;

  /// No description provided for @attachSheetContactSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get attachSheetContactSearchHint;

  /// No description provided for @attachSheetNoContacts.
  ///
  /// In en, this message translates to:
  /// **'You have no contacts yet'**
  String get attachSheetNoContacts;

  /// No description provided for @attachSheetNoContactsFound.
  ///
  /// In en, this message translates to:
  /// **'No contacts found'**
  String get attachSheetNoContactsFound;

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

  /// No description provided for @attachSheetGalleryFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load the gallery'**
  String get attachSheetGalleryFailedTitle;

  /// No description provided for @attachSheetRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get attachSheetRetry;

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

  /// No description provided for @attachSheetCameraAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow camera'**
  String get attachSheetCameraAllow;

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

  /// No description provided for @fontSettingsPickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get fontSettingsPickFile;

  /// No description provided for @fontSettingsPickFileHint.
  ///
  /// In en, this message translates to:
  /// **'A .ttf, .otf or .ttc font'**
  String get fontSettingsPickFileHint;

  /// No description provided for @fontSettingsNotAFont.
  ///
  /// In en, this message translates to:
  /// **'This is not a font file'**
  String get fontSettingsNotAFont;

  /// No description provided for @fontSettingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get fontSettingsCancel;

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

  /// No description provided for @updateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheck;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version'**
  String get updateUpToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates. Try again later'**
  String get updateCheckFailed;

  /// No description provided for @profileResurrecting.
  ///
  /// In en, this message translates to:
  /// **'Oops! The server didn\'t send your profile. Trying to regenerate…'**
  String get profileResurrecting;

  /// No description provided for @profilePhoneRegenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t regenerate your phone number. Please sign in again and report the issue to the developers'**
  String get profilePhoneRegenFailed;

  /// No description provided for @addContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContactTitle;

  /// No description provided for @addContactFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get addContactFirstName;

  /// No description provided for @addContactLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name (optional)'**
  String get addContactLastName;

  /// No description provided for @addContactSave.
  ///
  /// In en, this message translates to:
  /// **'Save contact'**
  String get addContactSave;

  /// No description provided for @addContactNotFound.
  ///
  /// In en, this message translates to:
  /// **'{phone} not found'**
  String addContactNotFound(String phone);

  /// No description provided for @addContactNotFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This number isn\'t on the app yet'**
  String get addContactNotFoundSubtitle;

  /// No description provided for @addContactSearchOther.
  ///
  /// In en, this message translates to:
  /// **'Search for other number'**
  String get addContactSearchOther;

  /// No description provided for @addContactError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add contact'**
  String get addContactError;

  /// No description provided for @contactBubbleNew.
  ///
  /// In en, this message translates to:
  /// **'New contact'**
  String get contactBubbleNew;

  /// No description provided for @contactBubbleAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already in your contacts'**
  String get contactBubbleAlreadyAdded;

  /// No description provided for @contactBubbleOpenProfile.
  ///
  /// In en, this message translates to:
  /// **'Open profile'**
  String get contactBubbleOpenProfile;

  /// No description provided for @miniAppOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get miniAppOpen;

  /// No description provided for @miniAppFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the app'**
  String get miniAppFailed;

  /// No description provided for @editContactMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get editContactMenu;

  /// No description provided for @editContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get editContactTitle;

  /// No description provided for @editContactFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get editContactFirstName;

  /// No description provided for @editContactLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get editContactLastName;

  /// No description provided for @editContactSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editContactSave;

  /// No description provided for @editContactDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete contact'**
  String get editContactDelete;

  /// No description provided for @editContactDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete contact?'**
  String get editContactDeleteConfirmTitle;

  /// No description provided for @editContactDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This contact will be removed from your list.'**
  String get editContactDeleteConfirmBody;

  /// No description provided for @editContactDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get editContactDeleteCancel;

  /// No description provided for @editContactError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save changes'**
  String get editContactError;

  /// No description provided for @downloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent downloads'**
  String get downloadsTitle;

  /// No description provided for @downloadsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTooltip;

  /// No description provided for @downloadsSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get downloadsSettings;

  /// No description provided for @downloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Downloaded files will appear here'**
  String get downloadsEmpty;

  /// No description provided for @downloadsUnknownSource.
  ///
  /// In en, this message translates to:
  /// **'Unknown source'**
  String get downloadsUnknownSource;

  /// No description provided for @downloadsPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get downloadsPhoto;

  /// No description provided for @downloadsVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get downloadsVideo;

  /// No description provided for @downloadsGif.
  ///
  /// In en, this message translates to:
  /// **'GIF'**
  String get downloadsGif;

  /// No description provided for @downloadsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get downloadsAudio;

  /// No description provided for @downloadsFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get downloadsFile;

  /// No description provided for @downloadsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the file'**
  String get downloadsOpenFailed;

  /// No description provided for @audioPlaybackChannel.
  ///
  /// In en, this message translates to:
  /// **'Audio playback'**
  String get audioPlaybackChannel;

  /// No description provided for @audioPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play the file'**
  String get audioPlaybackFailed;

  /// No description provided for @downloadsClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear download history'**
  String get downloadsClearHistory;

  /// No description provided for @downloadsClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear download history?'**
  String get downloadsClearTitle;

  /// No description provided for @downloadsClearBody.
  ///
  /// In en, this message translates to:
  /// **'The files will stay on the device, but this list will be cleared.'**
  String get downloadsClearBody;

  /// No description provided for @downloadsClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get downloadsClearConfirm;

  /// No description provided for @downloadsHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Download history cleared'**
  String get downloadsHistoryCleared;

  /// No description provided for @uploadNotificationPhotos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Photo} other{{count} photos}}'**
  String uploadNotificationPhotos(int count);

  /// No description provided for @uploadNotificationVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get uploadNotificationVideo;

  /// No description provided for @uploadNotificationVideoNote.
  ///
  /// In en, this message translates to:
  /// **'Video message'**
  String get uploadNotificationVideoNote;

  /// No description provided for @uploadNotificationVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get uploadNotificationVoice;

  /// No description provided for @uploadNotificationFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get uploadNotificationFile;

  /// No description provided for @uploadNotificationMultiple.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{Sending {count} files}}'**
  String uploadNotificationMultiple(int count);

  /// No description provided for @uploadNotificationPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get uploadNotificationPreparing;

  /// No description provided for @uploadSpeedBytes.
  ///
  /// In en, this message translates to:
  /// **'{value} B/s'**
  String uploadSpeedBytes(String value);

  /// No description provided for @uploadSpeedKb.
  ///
  /// In en, this message translates to:
  /// **'{value} KB/s'**
  String uploadSpeedKb(String value);

  /// No description provided for @uploadSpeedMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB/s'**
  String uploadSpeedMb(String value);

  /// No description provided for @savedMessagesEmptyPreview.
  ///
  /// In en, this message translates to:
  /// **'Save something here'**
  String get savedMessagesEmptyPreview;

  /// No description provided for @proxyCurrentState.
  ///
  /// In en, this message translates to:
  /// **'Currently: {value}'**
  String proxyCurrentState(String value);

  /// No description provided for @blacklistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody is blocked'**
  String get blacklistEmpty;

  /// No description provided for @joinRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Join requests'**
  String get joinRequestsTitle;

  /// No description provided for @joinRequestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get joinRequestsEmpty;

  /// No description provided for @joinRequestsApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get joinRequestsApprove;

  /// No description provided for @joinRequestsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get joinRequestsDecline;

  /// No description provided for @joinRequestsApproved.
  ///
  /// In en, this message translates to:
  /// **'Request approved'**
  String get joinRequestsApproved;

  /// No description provided for @joinRequestsDeclined.
  ///
  /// In en, this message translates to:
  /// **'Request declined'**
  String get joinRequestsDeclined;

  /// No description provided for @joinRequestsActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed, try again'**
  String get joinRequestsActionFailed;

  /// No description provided for @joinRequestsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load requests'**
  String get joinRequestsLoadError;

  /// No description provided for @blacklistLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load the blacklist'**
  String get blacklistLoadError;

  /// No description provided for @videoEditorQualityLow.
  ///
  /// In en, this message translates to:
  /// **'Small size'**
  String get videoEditorQualityLow;

  /// No description provided for @videoEditorQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High quality'**
  String get videoEditorQualityHigh;

  /// No description provided for @videoEditorCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a caption...'**
  String get videoEditorCaptionHint;

  /// No description provided for @videoEditorMuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send without sound'**
  String get videoEditorMuteTooltip;

  /// No description provided for @videoEditorProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing video…'**
  String get videoEditorProcessing;

  /// No description provided for @videoEditorExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to process the video'**
  String get videoEditorExportFailed;

  /// No description provided for @videoEditorFrameFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to grab a frame'**
  String get videoEditorFrameFailed;

  /// No description provided for @videoEditorQualityTooltip.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get videoEditorQualityTooltip;

  /// No description provided for @webPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications on iOS'**
  String get webPushTitle;

  /// No description provided for @webPushIntro.
  ///
  /// In en, this message translates to:
  /// **'Komet has no ordinary push on iOS: Apple issues a notification token only to apps signed with a developer certificate, and a sideloaded build never gets one.\n\nThe way around it is a web app on the Home Screen. MAX\'s own server sends the notifications through Apple, and a separate icon displays them.\n\nThat needs a web session. Komet creates one and approves it itself, from this very device — no phone number or code required.'**
  String get webPushIntro;

  /// No description provided for @webPushConfirm.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get webPushConfirm;

  /// No description provided for @webPushPasswordExplainer.
  ///
  /// In en, this message translates to:
  /// **'Two-factor protection is enabled on this account.'**
  String get webPushPasswordExplainer;

  /// No description provided for @webPushPasswordHintLabel.
  ///
  /// In en, this message translates to:
  /// **'Hint: {hint}'**
  String webPushPasswordHintLabel(String hint);

  /// No description provided for @webPushPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get webPushPasswordHint;

  /// No description provided for @webPushInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Install the web app'**
  String get webPushInstallTitle;

  /// No description provided for @webPushInstallBody.
  ///
  /// In en, this message translates to:
  /// **'Open push.komet.pw in Safari, add it to the Home Screen and launch the icon that appears. Notifications do not work from a browser tab — that is how iOS works.\n\nIn the app, allow notifications, create a subscription and tap \"Open Komet\". The subscription registers itself from there.'**
  String get webPushInstallBody;

  /// No description provided for @webPushLinkedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications connected'**
  String get webPushLinkedTitle;

  /// No description provided for @webPushLinkedBody.
  ///
  /// In en, this message translates to:
  /// **'The subscription is registered on the server. Do not delete the Home Screen icon — the notifications go with it.\n\nIf push stops arriving, open the web app and link again: Apple sometimes rotates the subscription address.'**
  String get webPushLinkedBody;

  /// No description provided for @webPushOpenSite.
  ///
  /// In en, this message translates to:
  /// **'Open push.komet.pw'**
  String get webPushOpenSite;

  /// No description provided for @webPushSignOut.
  ///
  /// In en, this message translates to:
  /// **'Disconnect notifications'**
  String get webPushSignOut;

  /// No description provided for @webPushLinked.
  ///
  /// In en, this message translates to:
  /// **'Notifications connected'**
  String get webPushLinked;

  /// No description provided for @webPushLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect notifications: {error}'**
  String webPushLinkFailed(String error);

  /// No description provided for @webPushNotAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Sign in under \"Notifications via PWA\" first'**
  String get webPushNotAuthorized;

  /// No description provided for @webPushConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect notifications'**
  String get webPushConnect;

  /// No description provided for @webPushWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'Komet is approving the web session from this device. This usually takes a few seconds.'**
  String get webPushWaitingBody;

  /// No description provided for @webPushNeedsOnline.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Wait for it and try again.'**
  String get webPushNeedsOnline;

  /// No description provided for @webPushSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'The web session will be terminated and disappear from your device list. To get notifications back you will have to connect again.'**
  String get webPushSignOutConfirm;

  /// No description provided for @webPushSignOutAction.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get webPushSignOutAction;

  /// No description provided for @webPushStatusService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get webPushStatusService;

  /// No description provided for @webPushStatusToken.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get webPushStatusToken;

  /// No description provided for @webPushStatusLinkedAt.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get webPushStatusLinkedAt;

  /// No description provided for @webPushStatusDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get webPushStatusDevice;

  /// No description provided for @securityDeleteProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get securityDeleteProfileTitle;

  /// No description provided for @securityDeleteProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The profile and all its data are removed after 30 days'**
  String get securityDeleteProfileSubtitle;

  /// No description provided for @securityDeleteProfileConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete profile?'**
  String get securityDeleteProfileConfirmTitle;

  /// No description provided for @securityDeleteProfileConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Your MAX profile will be deleted in 30 days. You can cancel the request at any time before that.'**
  String get securityDeleteProfileConfirmMessage;

  /// No description provided for @securityDeleteProfileConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get securityDeleteProfileConfirmAction;

  /// No description provided for @securityDeleteProfileScheduled.
  ///
  /// In en, this message translates to:
  /// **'Profile will be deleted on {date}'**
  String securityDeleteProfileScheduled(String date);

  /// No description provided for @securityDeleteProfileKeep.
  ///
  /// In en, this message translates to:
  /// **'Don\'t delete profile'**
  String get securityDeleteProfileKeep;

  /// No description provided for @securityDeleteProfileRequested.
  ///
  /// In en, this message translates to:
  /// **'Deletion request accepted'**
  String get securityDeleteProfileRequested;

  /// No description provided for @securityDeleteProfileCanceled.
  ///
  /// In en, this message translates to:
  /// **'Profile deletion canceled'**
  String get securityDeleteProfileCanceled;

  /// No description provided for @securityDeleteProfileError.
  ///
  /// In en, this message translates to:
  /// **'Failed to send the request: {error}'**
  String securityDeleteProfileError(String error);

  /// No description provided for @composerPasteAttachment.
  ///
  /// In en, this message translates to:
  /// **'Paste file'**
  String get composerPasteAttachment;

  /// No description provided for @pasteAttachTitleImage.
  ///
  /// In en, this message translates to:
  /// **'Send image'**
  String get pasteAttachTitleImage;

  /// No description provided for @pasteAttachTitleVideo.
  ///
  /// In en, this message translates to:
  /// **'Send video'**
  String get pasteAttachTitleVideo;

  /// No description provided for @pasteAttachTitleFile.
  ///
  /// In en, this message translates to:
  /// **'Send file'**
  String get pasteAttachTitleFile;

  /// No description provided for @pasteAttachTitleMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Send 1 file} other{Send {count} files}}'**
  String pasteAttachTitleMany(int count);

  /// No description provided for @pasteAttachCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get pasteAttachCaptionHint;

  /// No description provided for @pasteAttachSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get pasteAttachSend;

  /// No description provided for @pasteAttachCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get pasteAttachCancel;

  /// No description provided for @pasteAttachFailed.
  ///
  /// In en, this message translates to:
  /// **'Nothing to paste from the clipboard'**
  String get pasteAttachFailed;

  /// No description provided for @profileQrTitle.
  ///
  /// In en, this message translates to:
  /// **'My QR code'**
  String get profileQrTitle;

  /// No description provided for @profileQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan the code to open the profile'**
  String get profileQrHint;

  /// No description provided for @profileQrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not get the profile link'**
  String get profileQrUnavailable;

  /// No description provided for @authLimitsLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Account temporarily limited'**
  String get authLimitsLoginTitle;

  /// No description provided for @authLimitsLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The limits should lift around {until}'**
  String authLimitsLoginSubtitle(DateTime until);

  /// No description provided for @authLimitsLogin2faTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get authLimitsLogin2faTitle;

  /// No description provided for @authLimitsLogin2faBody.
  ///
  /// In en, this message translates to:
  /// **'You can\'t set or remove the login password.'**
  String get authLimitsLogin2faBody;

  /// No description provided for @authLimitsLoginSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ending sessions'**
  String get authLimitsLoginSessionsTitle;

  /// No description provided for @authLimitsLoginSessionsBody.
  ///
  /// In en, this message translates to:
  /// **'You can\'t end all sessions at once.'**
  String get authLimitsLoginSessionsBody;

  /// No description provided for @authLimitsSignupTitle.
  ///
  /// In en, this message translates to:
  /// **'Account may be limited'**
  String get authLimitsSignupTitle;

  /// No description provided for @authLimitsSignupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New accounts aren\'t all limited, and the server lifts the limits itself'**
  String get authLimitsSignupSubtitle;

  /// No description provided for @authLimitsSignupMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get authLimitsSignupMessagesTitle;

  /// No description provided for @authLimitsSignupMessagesBody.
  ///
  /// In en, this message translates to:
  /// **'You may only be able to write to people who already have you in their contacts.'**
  String get authLimitsSignupMessagesBody;

  /// No description provided for @authLimitsSignupGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get authLimitsSignupGroupsTitle;

  /// No description provided for @authLimitsSignupGroupsBody.
  ///
  /// In en, this message translates to:
  /// **'Joining groups may be unavailable.'**
  String get authLimitsSignupGroupsBody;

  /// No description provided for @authLimitsSignupMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Other limits are possible'**
  String get authLimitsSignupMoreTitle;

  /// No description provided for @authLimitsSignupMoreBody.
  ///
  /// In en, this message translates to:
  /// **'The server doesn\'t announce the full list — if something doesn\'t work, try again later.'**
  String get authLimitsSignupMoreBody;

  /// No description provided for @authLimitsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get authLimitsConfirm;

  /// No description provided for @e2eeTitle.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption'**
  String get e2eeTitle;

  /// No description provided for @e2eeStatusNone.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get e2eeStatusNone;

  /// No description provided for @e2eeStatusOffered.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name} to accept'**
  String e2eeStatusOffered(String name);

  /// No description provided for @e2eeStatusPending.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to turn on encryption'**
  String e2eeStatusPending(String name);

  /// No description provided for @e2eeStatusEstablished.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get e2eeStatusEstablished;

  /// No description provided for @e2eeStatusKeyChanged.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s encryption key has changed'**
  String e2eeStatusKeyChanged(String name);

  /// No description provided for @e2eeEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get e2eeEnable;

  /// No description provided for @e2eeAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get e2eeAccept;

  /// No description provided for @e2eeDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get e2eeDecline;

  /// No description provided for @e2eeCancelOffer.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get e2eeCancelOffer;

  /// No description provided for @e2eeReset.
  ///
  /// In en, this message translates to:
  /// **'Reset session'**
  String get e2eeReset;

  /// No description provided for @e2eeResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset the encrypted session? Both sides will need to set it up again.'**
  String get e2eeResetConfirm;

  /// No description provided for @e2eeFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Safety number'**
  String get e2eeFingerprint;

  /// No description provided for @e2eeFingerprintHint.
  ///
  /// In en, this message translates to:
  /// **'Compare these 60 digits with {name} outside MAX — in person or over another channel. If they match, the server did not substitute the keys.'**
  String e2eeFingerprintHint(String name);

  /// No description provided for @e2eeVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified in person'**
  String get e2eeVerified;

  /// No description provided for @e2eeCeiling.
  ///
  /// In en, this message translates to:
  /// **'Only message text and photos are encrypted. The server still sees who talks to whom and when, sees that the chat is encrypted, and can withhold messages. Nothing here hides that.'**
  String get e2eeCeiling;

  /// No description provided for @e2eeNeedsKomet.
  ///
  /// In en, this message translates to:
  /// **'{name} needs Komet for this to work.'**
  String e2eeNeedsKomet(String name);

  /// No description provided for @e2eeOfferSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get e2eeOfferSent;

  /// No description provided for @e2eeOfferFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the request'**
  String get e2eeOfferFailed;

  /// No description provided for @e2eeAcceptFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not accept the request'**
  String get e2eeAcceptFailed;

  /// No description provided for @e2eeBannerPending.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to turn on end-to-end encryption'**
  String e2eeBannerPending(String name);

  /// No description provided for @e2eeBannerKeyChanged.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s encryption key has changed. Check the safety number before accepting.'**
  String e2eeBannerKeyChanged(String name);

  /// No description provided for @e2eeTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to another device'**
  String get e2eeTransferTitle;

  /// No description provided for @e2eeTransferHint.
  ///
  /// In en, this message translates to:
  /// **'The transfer file holds your key and sessions. After importing it on the new device, stop using this one for encrypted chats.'**
  String get e2eeTransferHint;

  /// No description provided for @e2eeExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get e2eeExport;

  /// No description provided for @e2eeImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get e2eeImport;

  /// No description provided for @e2eeTransferPassword.
  ///
  /// In en, this message translates to:
  /// **'Transfer password'**
  String get e2eeTransferPassword;

  /// No description provided for @e2eeExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export'**
  String get e2eeExportFailed;

  /// No description provided for @e2eeImported.
  ///
  /// In en, this message translates to:
  /// **'Sessions moved: {count}'**
  String e2eeImported(int count);

  /// No description provided for @e2eeImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import — wrong password or damaged file'**
  String get e2eeImportFailed;

  /// No description provided for @e2eeLegacyNote.
  ///
  /// In en, this message translates to:
  /// **'Passphrase mode for groups: no forward secrecy, anyone who knows the passphrase can read the whole history.'**
  String get e2eeLegacyNote;

  /// No description provided for @e2eeTooLong.
  ///
  /// In en, this message translates to:
  /// **'The message is too long for an encrypted chat. Split it up.'**
  String get e2eeTooLong;

  /// No description provided for @e2eeEncryptFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not encrypt the message'**
  String get e2eeEncryptFailed;

  /// No description provided for @e2eeRotateIdentity.
  ///
  /// In en, this message translates to:
  /// **'Replace my key'**
  String get e2eeRotateIdentity;

  /// No description provided for @e2eeRotateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create a new identity key? Every encrypted session will be reset, your contacts will see a key-change warning, and the safety numbers will change.'**
  String get e2eeRotateConfirm;

  /// No description provided for @e2eeRotated.
  ///
  /// In en, this message translates to:
  /// **'Key replaced'**
  String get e2eeRotated;

  /// No description provided for @e2eeRotateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not replace the key'**
  String get e2eeRotateFailed;

  /// No description provided for @e2eeForwardBlocked.
  ///
  /// In en, this message translates to:
  /// **'Forwarding is off in an encrypted chat: the server, not your device, would supply the message text.'**
  String get e2eeForwardBlocked;

  /// No description provided for @e2eeEditUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This message can\'t be decrypted on this device, so it can\'t be edited.'**
  String get e2eeEditUnavailable;

  /// No description provided for @e2eeScheduledMediaBlocked.
  ///
  /// In en, this message translates to:
  /// **'Scheduled photos are not supported in an encrypted chat yet. Send them now, or turn encryption off.'**
  String get e2eeScheduledMediaBlocked;

  /// No description provided for @e2eeSearchBlocked.
  ///
  /// In en, this message translates to:
  /// **'Search is off in an encrypted chat: the query would go to the server, and the server only sees ciphertext.'**
  String get e2eeSearchBlocked;

  /// No description provided for @e2eeAwaitingPeer.
  ///
  /// In en, this message translates to:
  /// **'This session was moved from another device. Wait for one message from your contact before sending — otherwise both devices would use the same key.'**
  String get e2eeAwaitingPeer;

  /// No description provided for @e2eeBannerRehandshake.
  ///
  /// In en, this message translates to:
  /// **'{name} is turning encryption on again. Accept only if you expected this — otherwise the server is replaying an old request to reset your session.'**
  String e2eeBannerRehandshake(String name);

  /// No description provided for @e2eeExportedAndDisabled.
  ///
  /// In en, this message translates to:
  /// **'Transfer created. Encryption is now off on this device: import the file on the new one and turn it on there.'**
  String get e2eeExportedAndDisabled;

  /// No description provided for @chatNoAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this chat'**
  String get chatNoAccessMessage;

  /// No description provided for @chatNoAccessOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get chatNoAccessOk;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatEmptyTitle;

  /// No description provided for @chatGreetingHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message or send this sticker'**
  String get chatGreetingHint;

  /// No description provided for @chatCallBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Call in chat'**
  String get chatCallBannerTitle;

  /// No description provided for @chatVideoCallBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Video call in chat'**
  String get chatVideoCallBannerTitle;

  /// No description provided for @chatCallParticipants.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 participant} other{{count} participants}}'**
  String chatCallParticipants(int count);

  /// No description provided for @chatCallJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get chatCallJoin;

  /// No description provided for @composerHintMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get composerHintMessage;

  /// No description provided for @composerHintComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get composerHintComment;

  /// No description provided for @composerHintCommandArgs.
  ///
  /// In en, this message translates to:
  /// **'Fill in the command arguments'**
  String get composerHintCommandArgs;

  /// No description provided for @emojiPanelRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get emojiPanelRecent;

  /// No description provided for @emojiPanelAnimated.
  ///
  /// In en, this message translates to:
  /// **'Animated'**
  String get emojiPanelAnimated;

  /// No description provided for @attachmentFileFallback.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get attachmentFileFallback;

  /// No description provided for @attachmentContactFallback.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get attachmentContactFallback;

  /// No description provided for @userFallbackName.
  ///
  /// In en, this message translates to:
  /// **'User #{id}'**
  String userFallbackName(Object id);

  /// No description provided for @devicesUnknownValue.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get devicesUnknownValue;

  /// No description provided for @infoLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String infoLoadError(Object error);

  /// No description provided for @chatInfoTabInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get chatInfoTabInfo;

  /// No description provided for @callInfoConversationId.
  ///
  /// In en, this message translates to:
  /// **'Conversation ID'**
  String get callInfoConversationId;

  /// No description provided for @chatQrTitle.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get chatQrTitle;

  /// No description provided for @chatQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan the code to open this chat'**
  String get chatQrHint;

  /// No description provided for @linkQrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get the link'**
  String get linkQrUnavailable;

  /// No description provided for @notificationsDesktopNote.
  ///
  /// In en, this message translates to:
  /// **'Notifications aren\'t shown on the computer yet. The settings below are your account\'s push settings for phones.'**
  String get notificationsDesktopNote;

  /// No description provided for @fileNoAppToOpen.
  ///
  /// In en, this message translates to:
  /// **'No app on this device can open this file. Choose where to send it.'**
  String get fileNoAppToOpen;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your passcode'**
  String get lockTitle;

  /// No description provided for @lockBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Komet'**
  String get lockBiometricReason;

  /// No description provided for @lockBlocked.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {time}'**
  String lockBlocked(String time);

  /// No description provided for @lockAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'Wrong passcode. Attempts left: {count}'**
  String lockAttemptsLeft(int count);

  /// No description provided for @lockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock Komet'**
  String get lockNow;

  /// No description provided for @passcodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Passcode'**
  String get passcodeTitle;

  /// No description provided for @passcodeCreate.
  ///
  /// In en, this message translates to:
  /// **'Create a passcode'**
  String get passcodeCreate;

  /// No description provided for @passcodeRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat the passcode'**
  String get passcodeRepeat;

  /// No description provided for @passcodeMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passcodes didn\'t match, try again'**
  String get passcodeMismatch;

  /// No description provided for @passcodeDigitsHint.
  ///
  /// In en, this message translates to:
  /// **'Four digits'**
  String get passcodeDigitsHint;

  /// No description provided for @passcodeEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn passcode on'**
  String get passcodeEnable;

  /// No description provided for @passcodeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Passcode is on'**
  String get passcodeEnabled;

  /// No description provided for @passcodeChanged.
  ///
  /// In en, this message translates to:
  /// **'Passcode changed'**
  String get passcodeChanged;

  /// No description provided for @passcodeChange.
  ///
  /// In en, this message translates to:
  /// **'Change passcode'**
  String get passcodeChange;

  /// No description provided for @passcodeBiometric.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get passcodeBiometric;

  /// No description provided for @passcodeBiometricHint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint or face instead of the passcode'**
  String get passcodeBiometricHint;

  /// No description provided for @passcodeAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get passcodeAutoLock;

  /// No description provided for @passcodeAutoLockHint.
  ///
  /// In en, this message translates to:
  /// **'Lock Komet when you don\'t touch it for a while'**
  String get passcodeAutoLockHint;

  /// No description provided for @passcodeAutoLockOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get passcodeAutoLockOff;

  /// No description provided for @passcodeAutoLockAfter.
  ///
  /// In en, this message translates to:
  /// **'After {minutes} min'**
  String passcodeAutoLockAfter(int minutes);

  /// No description provided for @passcodeDisable.
  ///
  /// In en, this message translates to:
  /// **'Turn passcode off'**
  String get passcodeDisable;

  /// No description provided for @passcodeDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn passcode off?'**
  String get passcodeDisableTitle;

  /// No description provided for @passcodeDisableMessage.
  ///
  /// In en, this message translates to:
  /// **'Komet will open without asking for the passcode.'**
  String get passcodeDisableMessage;

  /// No description provided for @passcodeDisableAction.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get passcodeDisableAction;

  /// No description provided for @passcodeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get passcodeCancel;

  /// No description provided for @passcodeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Passcode is off'**
  String get passcodeDisabled;

  /// No description provided for @passcodeOnDescription.
  ///
  /// In en, this message translates to:
  /// **'Komet asks for the passcode every time you open it. The lock in the chat list header locks it right away.'**
  String get passcodeOnDescription;

  /// No description provided for @passcodeOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Protect your chats: Komet will ask for a passcode every time you open it.'**
  String get passcodeOffDescription;

  /// No description provided for @passcodeForgotHint.
  ///
  /// In en, this message translates to:
  /// **'If you forget the passcode, you\'ll have to clear Komet\'s data or reinstall it and sign in again. After five wrong attempts input is blocked for five minutes.'**
  String get passcodeForgotHint;

  /// No description provided for @mediaDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera and microphone'**
  String get mediaDevicesTitle;

  /// No description provided for @mediaDevicesMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get mediaDevicesMicrophone;

  /// No description provided for @mediaDevicesMicrophoneHint.
  ///
  /// In en, this message translates to:
  /// **'Used for calls and voice messages'**
  String get mediaDevicesMicrophoneHint;

  /// No description provided for @mediaDevicesCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get mediaDevicesCamera;

  /// No description provided for @mediaDevicesCameraHint.
  ///
  /// In en, this message translates to:
  /// **'Used for calls and, if you like, for video messages'**
  String get mediaDevicesCameraHint;

  /// No description provided for @mediaDevicesSystemMicrophone.
  ///
  /// In en, this message translates to:
  /// **'System microphone'**
  String get mediaDevicesSystemMicrophone;

  /// No description provided for @mediaDevicesSystemCamera.
  ///
  /// In en, this message translates to:
  /// **'System camera'**
  String get mediaDevicesSystemCamera;

  /// No description provided for @mediaDevicesCameraFallback.
  ///
  /// In en, this message translates to:
  /// **'Camera {number}'**
  String mediaDevicesCameraFallback(int number);

  /// No description provided for @mediaDevicesFront.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get mediaDevicesFront;

  /// No description provided for @mediaDevicesBack.
  ///
  /// In en, this message translates to:
  /// **'Rear'**
  String get mediaDevicesBack;

  /// No description provided for @mediaDevicesVideoNotes.
  ///
  /// In en, this message translates to:
  /// **'Video messages'**
  String get mediaDevicesVideoNotes;

  /// No description provided for @mediaDevicesVideoNoteCustom.
  ///
  /// In en, this message translates to:
  /// **'My camera'**
  String get mediaDevicesVideoNoteCustom;

  /// No description provided for @mediaDevicesVideoNoteCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Record video messages with the camera chosen above'**
  String get mediaDevicesVideoNoteCustomHint;

  /// No description provided for @mediaDevicesVideoNoteCustomMissing.
  ///
  /// In en, this message translates to:
  /// **'Choose a camera above, until then the system one is used'**
  String get mediaDevicesVideoNoteCustomMissing;

  /// No description provided for @mediaDevicesVideoNoteRear.
  ///
  /// In en, this message translates to:
  /// **'Start with the rear camera'**
  String get mediaDevicesVideoNoteRear;

  /// No description provided for @mediaDevicesVideoNoteRearHint.
  ///
  /// In en, this message translates to:
  /// **'Otherwise a video message starts with the front camera'**
  String get mediaDevicesVideoNoteRearHint;

  /// No description provided for @chatPreviewMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get chatPreviewMarkRead;

  /// No description provided for @chatPreviewOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get chatPreviewOpen;

  /// No description provided for @attachSheetSendAsVideoNote.
  ///
  /// In en, this message translates to:
  /// **'Send as video message'**
  String get attachSheetSendAsVideoNote;

  /// No description provided for @attachSheetVideoNoteTooLong.
  ///
  /// In en, this message translates to:
  /// **'A video message can\'t be longer than {seconds} s'**
  String attachSheetVideoNoteTooLong(int seconds);

  /// No description provided for @undoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// No description provided for @undoContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get undoContinue;

  /// No description provided for @undoMessageUnpinned.
  ///
  /// In en, this message translates to:
  /// **'You unpinned the message'**
  String get undoMessageUnpinned;

  /// No description provided for @undoMessagesDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Message deleted} other{{count} messages deleted}}'**
  String undoMessagesDeleted(int count);

  /// No description provided for @undoChatsDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Chat deleted} other{{count} chats deleted}}'**
  String undoChatsDeleted(int count);

  /// No description provided for @undoChatsArchived.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Chat archived} other{{count} chats archived}}'**
  String undoChatsArchived(int count);

  /// No description provided for @undoChatsUnarchived.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Chat unarchived} other{{count} chats unarchived}}'**
  String undoChatsUnarchived(int count);

  /// No description provided for @undoLeftGroup.
  ///
  /// In en, this message translates to:
  /// **'You left the group'**
  String get undoLeftGroup;

  /// No description provided for @undoLeftChannel.
  ///
  /// In en, this message translates to:
  /// **'You left the channel'**
  String get undoLeftChannel;

  /// No description provided for @forwardHideSender.
  ///
  /// In en, this message translates to:
  /// **'Hide sender\'s name'**
  String get forwardHideSender;

  /// No description provided for @forwardShowSender.
  ///
  /// In en, this message translates to:
  /// **'Show sender\'s name'**
  String get forwardShowSender;

  /// No description provided for @forwardHideSenderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Polls, calls and service messages can only be forwarded with the sender\'s name'**
  String get forwardHideSenderUnavailable;

  /// No description provided for @forwardWithoutSender.
  ///
  /// In en, this message translates to:
  /// **'Forward without sender'**
  String get forwardWithoutSender;

  /// No description provided for @forwardWithoutSenderCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Forward without sender: 1 message} other{Forward without sender: {count} messages}}'**
  String forwardWithoutSenderCount(int count);

  /// No description provided for @adminsTitle.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get adminsTitle;

  /// No description provided for @channelFollowersTitle.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get channelFollowersTitle;

  /// No description provided for @channelStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel statistics'**
  String get channelStatsTitle;

  /// No description provided for @channelStatsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Channel statistics aren\'t available yet'**
  String get channelStatsUnavailable;

  /// No description provided for @adminsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add admin'**
  String get adminsAdd;

  /// No description provided for @channelPickAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a follower'**
  String get channelPickAdminTitle;

  /// No description provided for @adminsPickEmpty.
  ///
  /// In en, this message translates to:
  /// **'No followers to appoint'**
  String get adminsPickEmpty;

  /// No description provided for @membersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get membersSearchHint;

  /// No description provided for @adminRoleYou.
  ///
  /// In en, this message translates to:
  /// **'{role} (you)'**
  String adminRoleYou(String role);

  /// No description provided for @channelAddFollowers.
  ///
  /// In en, this message translates to:
  /// **'Add followers'**
  String get channelAddFollowers;

  /// No description provided for @channelFollowersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No followers yet'**
  String get channelFollowersEmpty;

  /// No description provided for @membersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the list'**
  String get membersLoadFailed;

  /// No description provided for @adminAppointTitle.
  ///
  /// In en, this message translates to:
  /// **'Appoint admin'**
  String get adminAppointTitle;

  /// No description provided for @adminEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin rights'**
  String get adminEditTitle;

  /// No description provided for @channelRightEditChannel.
  ///
  /// In en, this message translates to:
  /// **'Edit channel'**
  String get channelRightEditChannel;

  /// No description provided for @adminRightEditInfoHint.
  ///
  /// In en, this message translates to:
  /// **'Photo, name, description'**
  String get adminRightEditInfoHint;

  /// No description provided for @channelRightCreatePosts.
  ///
  /// In en, this message translates to:
  /// **'Create posts'**
  String get channelRightCreatePosts;

  /// No description provided for @channelRightEditPosts.
  ///
  /// In en, this message translates to:
  /// **'Edit other people\'s posts'**
  String get channelRightEditPosts;

  /// No description provided for @channelRightDeletePosts.
  ///
  /// In en, this message translates to:
  /// **'Delete other people\'s posts'**
  String get channelRightDeletePosts;

  /// No description provided for @channelRightPinPosts.
  ///
  /// In en, this message translates to:
  /// **'Pin posts'**
  String get channelRightPinPosts;

  /// No description provided for @channelRightManageFollowers.
  ///
  /// In en, this message translates to:
  /// **'Add and remove followers'**
  String get channelRightManageFollowers;

  /// No description provided for @channelRightViewStats.
  ///
  /// In en, this message translates to:
  /// **'View channel stats'**
  String get channelRightViewStats;

  /// No description provided for @adminRightManageAdmins.
  ///
  /// In en, this message translates to:
  /// **'Appoint and remove admins'**
  String get adminRightManageAdmins;

  /// No description provided for @adminRightManageAdminsHint.
  ///
  /// In en, this message translates to:
  /// **'Will only be able to remove admins they appointed themselves'**
  String get adminRightManageAdminsHint;

  /// No description provided for @adminAppointAction.
  ///
  /// In en, this message translates to:
  /// **'Appoint as admin'**
  String get adminAppointAction;

  /// No description provided for @adminSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get adminSave;

  /// No description provided for @adminAppointed.
  ///
  /// In en, this message translates to:
  /// **'Admin appointed'**
  String get adminAppointed;

  /// No description provided for @adminSaved.
  ///
  /// In en, this message translates to:
  /// **'Rights saved'**
  String get adminSaved;

  /// No description provided for @ownershipTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get ownershipTransfer;

  /// No description provided for @ownershipTransferConfirm.
  ///
  /// In en, this message translates to:
  /// **'{name} will become the new owner.'**
  String ownershipTransferConfirm(String name);

  /// No description provided for @ownershipTransferAction.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get ownershipTransferAction;

  /// No description provided for @ownershipTransferred.
  ///
  /// In en, this message translates to:
  /// **'Ownership transferred'**
  String get ownershipTransferred;

  /// No description provided for @adminRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from admins'**
  String get adminRemove;

  /// No description provided for @adminRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'{name} will no longer be an admin.'**
  String adminRemoveConfirm(String name);

  /// No description provided for @adminRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get adminRemoveAction;

  /// No description provided for @adminRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from admins'**
  String get adminRemoved;

  /// No description provided for @adminActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply the change'**
  String get adminActionFailed;

  /// No description provided for @channelInviteSendInMax.
  ///
  /// In en, this message translates to:
  /// **'Send in MAX'**
  String get channelInviteSendInMax;

  /// No description provided for @channelInviteShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show QR code'**
  String get channelInviteShowQr;

  /// No description provided for @channelInviteRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke link'**
  String get channelInviteRevoke;

  /// No description provided for @channelInviteRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'The current link will stop working. People will be able to join only with the new one.'**
  String get channelInviteRevokeConfirm;

  /// No description provided for @channelInviteRevokeAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get channelInviteRevokeAction;

  /// No description provided for @channelInviteRevoked.
  ///
  /// In en, this message translates to:
  /// **'New link created'**
  String get channelInviteRevoked;

  /// No description provided for @channelJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'Join requests'**
  String get channelJoinRequests;

  /// No description provided for @channelJoinRequestsHint.
  ///
  /// In en, this message translates to:
  /// **'The channel can only be joined after an admin approves the request'**
  String get channelJoinRequestsHint;

  /// No description provided for @groupPickAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a member'**
  String get groupPickAdminTitle;

  /// No description provided for @groupRightEditInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit chat'**
  String get groupRightEditInfo;

  /// No description provided for @groupRightDeleteMessages.
  ///
  /// In en, this message translates to:
  /// **'Delete messages'**
  String get groupRightDeleteMessages;

  /// No description provided for @groupRightPinMessages.
  ///
  /// In en, this message translates to:
  /// **'Pin messages'**
  String get groupRightPinMessages;

  /// No description provided for @groupRightManageMembers.
  ///
  /// In en, this message translates to:
  /// **'Add and remove members'**
  String get groupRightManageMembers;

  /// No description provided for @groupRightEditLink.
  ///
  /// In en, this message translates to:
  /// **'Update chat link'**
  String get groupRightEditLink;

  /// No description provided for @groupSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Group settings'**
  String get groupSettingsTitle;

  /// No description provided for @groupSettingsName.
  ///
  /// In en, this message translates to:
  /// **'Chat name'**
  String get groupSettingsName;

  /// No description provided for @groupSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Chat description'**
  String get groupSettingsDescription;

  /// No description provided for @groupSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get groupSettingsSaved;

  /// No description provided for @groupSettingsPhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get groupSettingsPhotoUpdated;

  /// No description provided for @groupSettingsPhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The image is too large (8 MB max)'**
  String get groupSettingsPhotoTooLarge;

  /// No description provided for @groupSettingsLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave chat'**
  String get groupSettingsLeave;

  /// No description provided for @reactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get reactionsTitle;

  /// No description provided for @reactionsSummaryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reactionsSummaryAll;

  /// No description provided for @reactionsSummaryOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get reactionsSummaryOff;

  /// No description provided for @reactionsSummaryCount.
  ///
  /// In en, this message translates to:
  /// **'{allowed} of {total}'**
  String reactionsSummaryCount(int allowed, int total);

  /// No description provided for @reactionsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable reactions'**
  String get reactionsEnable;

  /// No description provided for @reactionsCountHeader.
  ///
  /// In en, this message translates to:
  /// **'Reactions per message'**
  String get reactionsCountHeader;

  /// No description provided for @reactionsCountValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reaction} other{{count} reactions}}'**
  String reactionsCountValue(int count);

  /// No description provided for @reactionsAllowedHeader.
  ///
  /// In en, this message translates to:
  /// **'Allowed reactions'**
  String get reactionsAllowedHeader;

  /// No description provided for @reactionsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get reactionsEdit;

  /// No description provided for @reactionsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reactionsDone;

  /// No description provided for @reactionsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset reaction settings'**
  String get reactionsReset;

  /// No description provided for @reactionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load reaction settings'**
  String get reactionsLoadFailed;

  /// No description provided for @reactionsNoneAllowed.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one reaction'**
  String get reactionsNoneAllowed;

  /// No description provided for @memberPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Member permissions'**
  String get memberPermissionsTitle;

  /// No description provided for @memberPermissionEditInfo.
  ///
  /// In en, this message translates to:
  /// **'Change the chat name, photo and description'**
  String get memberPermissionEditInfo;

  /// No description provided for @memberPermissionAddMembers.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get memberPermissionAddMembers;

  /// No description provided for @memberPermissionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin messages'**
  String get memberPermissionPin;

  /// No description provided for @memberPermissionInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite via link'**
  String get memberPermissionInvite;

  /// No description provided for @memberPermissionCall.
  ///
  /// In en, this message translates to:
  /// **'Call in the chat'**
  String get memberPermissionCall;

  /// No description provided for @ownerLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re the owner'**
  String get ownerLeaveTitle;

  /// No description provided for @ownerLeaveChannelMessage.
  ///
  /// In en, this message translates to:
  /// **'To leave the channel, first transfer ownership to another follower.'**
  String get ownerLeaveChannelMessage;

  /// No description provided for @ownerLeaveGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'To leave the group, first transfer ownership to another member.'**
  String get ownerLeaveGroupMessage;

  /// No description provided for @ownershipPickTitle.
  ///
  /// In en, this message translates to:
  /// **'New owner'**
  String get ownershipPickTitle;

  /// No description provided for @ownershipPickEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one to transfer ownership to'**
  String get ownershipPickEmpty;

  /// No description provided for @forwardOneTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward message'**
  String get forwardOneTitle;

  /// No description provided for @forwardBatchTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Forward 1 message} other{Forward {count} messages}}'**
  String forwardBatchTitle(int count);

  /// No description provided for @forwardCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get forwardCommentHint;

  /// No description provided for @forwardOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get forwardOffline;

  /// No description provided for @forwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t forward'**
  String get forwardFailed;

  /// No description provided for @forwardDelivered.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Forwarded to 1 chat} other{Forwarded to {count} chats}}'**
  String forwardDelivered(int count);

  /// No description provided for @forwardDeliveredPartly.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to {delivered}, failed for {failed}'**
  String forwardDeliveredPartly(int delivered, int failed);

  /// No description provided for @reactionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This reaction isn\'t allowed in this chat'**
  String get reactionUnavailable;

  /// No description provided for @membersSearchMore.
  ///
  /// In en, this message translates to:
  /// **'Search the rest'**
  String get membersSearchMore;

  /// No description provided for @groupRestrictionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Restrictions'**
  String get groupRestrictionsTitle;

  /// No description provided for @groupRestrictionForward.
  ///
  /// In en, this message translates to:
  /// **'Disable forwarding'**
  String get groupRestrictionForward;

  /// No description provided for @groupRestrictionForwardHint.
  ///
  /// In en, this message translates to:
  /// **'Messages from this chat can\'t be forwarded'**
  String get groupRestrictionForwardHint;

  /// No description provided for @groupRestrictionCopy.
  ///
  /// In en, this message translates to:
  /// **'Disable copying'**
  String get groupRestrictionCopy;

  /// No description provided for @groupRestrictionCopyHint.
  ///
  /// In en, this message translates to:
  /// **'Message text can\'t be copied'**
  String get groupRestrictionCopyHint;

  /// No description provided for @groupRestrictionConfirmSend.
  ///
  /// In en, this message translates to:
  /// **'Confirm before sending'**
  String get groupRestrictionConfirmSend;

  /// No description provided for @groupRestrictionConfirmSendHint.
  ///
  /// In en, this message translates to:
  /// **'Every message asks for confirmation before it is sent'**
  String get groupRestrictionConfirmSendHint;

  /// No description provided for @notificationsBadgeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'App icon badge'**
  String get notificationsBadgeSectionTitle;

  /// No description provided for @notificationsBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Show unread count'**
  String get notificationsBadgeLabel;

  /// No description provided for @notificationsBadgeMutedLabel.
  ///
  /// In en, this message translates to:
  /// **'Include muted chats'**
  String get notificationsBadgeMutedLabel;

  /// No description provided for @notificationsBadgeMessagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Count messages'**
  String get notificationsBadgeMessagesLabel;

  /// No description provided for @notificationsBadgeMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off — count unread chats instead'**
  String get notificationsBadgeMessagesSubtitle;

  /// No description provided for @accountSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t switch account'**
  String get accountSwitchFailed;

  /// No description provided for @accountSessionLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get accountSessionLostTitle;

  /// No description provided for @accountSessionLostBody.
  ///
  /// In en, this message translates to:
  /// **'The session of “{name}” is no longer valid on this device.'**
  String accountSessionLostBody(String name);

  /// No description provided for @accountSessionLostSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountSessionLostSignIn;

  /// No description provided for @accountSessionLostRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from device'**
  String get accountSessionLostRemove;

  /// No description provided for @accountSessionLostRemoved.
  ///
  /// In en, this message translates to:
  /// **'Account removed from this device'**
  String get accountSessionLostRemoved;

  /// No description provided for @contactsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get contactsSearchHint;

  /// No description provided for @contactsSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get contactsSearchEmpty;

  /// No description provided for @contactsNfcExchange.
  ///
  /// In en, this message translates to:
  /// **'NFC exchange'**
  String get contactsNfcExchange;

  /// No description provided for @contactsFindUser.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get contactsFindUser;

  /// No description provided for @contactDeleted.
  ///
  /// In en, this message translates to:
  /// **'Contact deleted'**
  String get contactDeleted;

  /// No description provided for @contactDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the contact'**
  String get contactDeleteFailed;

  /// No description provided for @contactLocalPhotoChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get contactLocalPhotoChoose;

  /// No description provided for @contactLocalPhotoReset.
  ///
  /// In en, this message translates to:
  /// **'Restore profile photo'**
  String get contactLocalPhotoReset;

  /// No description provided for @contactLocalPhotoSaved.
  ///
  /// In en, this message translates to:
  /// **'Photo is visible only to you'**
  String get contactLocalPhotoSaved;

  /// No description provided for @contactLocalPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t process the image'**
  String get contactLocalPhotoFailed;

  /// No description provided for @contactLocalPhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is too large (max 8 MB)'**
  String get contactLocalPhotoTooLarge;

  /// No description provided for @channelTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel type and link'**
  String get channelTypeTitle;

  /// No description provided for @channelCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Private channel created'**
  String get channelCreatedTitle;

  /// No description provided for @channelCreatedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'It is ready to be set up'**
  String get channelCreatedSubtitle;

  /// No description provided for @channelTypePrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get channelTypePrivate;

  /// No description provided for @channelTypePrivateHint.
  ///
  /// In en, this message translates to:
  /// **'The channel is available by link only'**
  String get channelTypePrivateHint;

  /// No description provided for @channelTypePublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get channelTypePublic;

  /// No description provided for @channelTypePublicHint.
  ///
  /// In en, this message translates to:
  /// **'The channel can be found in search'**
  String get channelTypePublicHint;

  /// No description provided for @channelTypePublicUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Public channels are not available yet'**
  String get channelTypePublicUnavailable;

  /// No description provided for @channelInviteLinkCaption.
  ///
  /// In en, this message translates to:
  /// **'Invite link to your channel'**
  String get channelInviteLinkCaption;

  /// No description provided for @channelBusinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Public for business'**
  String get channelBusinessTitle;

  /// No description provided for @channelBusinessHint.
  ///
  /// In en, this message translates to:
  /// **'For legal entities, individual entrepreneurs, self-employed workers and government organizations'**
  String get channelBusinessHint;

  /// No description provided for @channelSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel settings'**
  String get channelSettingsTitle;

  /// No description provided for @channelSettingsName.
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get channelSettingsName;

  /// No description provided for @channelSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Channel description'**
  String get channelSettingsDescription;

  /// No description provided for @channelConfirmPosting.
  ///
  /// In en, this message translates to:
  /// **'Confirm before posting'**
  String get channelConfirmPosting;

  /// No description provided for @channelConfirmPostingHint.
  ///
  /// In en, this message translates to:
  /// **'To double-check the post and avoid mistakes'**
  String get channelConfirmPostingHint;

  /// No description provided for @channelComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get channelComments;

  /// No description provided for @channelCommentsEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments are a part of your channel'**
  String get channelCommentsEnableTitle;

  /// No description provided for @channelCommentsEnableMessage.
  ///
  /// In en, this message translates to:
  /// **'Make sure to monitor discussions and keep them civil: you can remove comments and restrict users'**
  String get channelCommentsEnableMessage;

  /// No description provided for @channelCommentsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get channelCommentsEnable;

  /// No description provided for @channelCommentsKeepOff.
  ///
  /// In en, this message translates to:
  /// **'Don\'t enable'**
  String get channelCommentsKeepOff;

  /// No description provided for @channelDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete channel'**
  String get channelDelete;

  /// No description provided for @channelDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the channel?'**
  String get channelDeleteTitle;

  /// No description provided for @channelDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'To prevent the channel from being deleted for all followers, you can transfer the rights to another owner'**
  String get channelDeleteMessage;

  /// No description provided for @channelDeleteTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership and leave'**
  String get channelDeleteTransfer;

  /// No description provided for @followerRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get followerRemove;

  /// No description provided for @followerRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove follower'**
  String get followerRemoveTitle;

  /// No description provided for @followerRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'{name} will no longer follow the channel.'**
  String followerRemoveConfirm(String name);

  /// No description provided for @followerRemoved.
  ///
  /// In en, this message translates to:
  /// **'Follower removed'**
  String get followerRemoved;

  /// No description provided for @channelReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel is ready'**
  String get channelReadyTitle;

  /// No description provided for @channelReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Add posts and invite followers'**
  String get channelReadyHint;

  /// No description provided for @groupReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Group is ready'**
  String get groupReadyTitle;

  /// No description provided for @groupReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Send the first message and invite members'**
  String get groupReadyHint;

  /// No description provided for @botStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get botStart;

  /// No description provided for @memberRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get memberRemoveTitle;

  /// No description provided for @memberRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from the group.'**
  String memberRemoveConfirm(String name);

  /// No description provided for @memberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get memberRemoved;

  /// No description provided for @chatScreenReactionUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the reaction'**
  String get chatScreenReactionUpdateFailed;

  /// No description provided for @chatScreenBotStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the bot'**
  String get chatScreenBotStartFailed;

  /// No description provided for @chatScreenMessageNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'The message isn\'t loaded'**
  String get chatScreenMessageNotLoaded;

  /// No description provided for @chatScreenMarkUnreadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t mark as unread'**
  String get chatScreenMarkUnreadFailed;

  /// No description provided for @chatScreenMessagePinned.
  ///
  /// In en, this message translates to:
  /// **'Message pinned'**
  String get chatScreenMessagePinned;

  /// No description provided for @chatScreenNothingToForward.
  ///
  /// In en, this message translates to:
  /// **'Nothing to forward'**
  String get chatScreenNothingToForward;

  /// No description provided for @chatScreenDeleteMessagesFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the messages'**
  String get chatScreenDeleteMessagesFailed;

  /// No description provided for @chatScreenDeleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatScreenDeleteMessageTitle;

  /// No description provided for @chatScreenDeleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message?'**
  String get chatScreenDeleteMessageConfirm;

  /// No description provided for @chatScreenDeleteAlsoFor.
  ///
  /// In en, this message translates to:
  /// **'Also delete for {name}'**
  String chatScreenDeleteAlsoFor(String name);

  /// No description provided for @chatScreenMenuMute.
  ///
  /// In en, this message translates to:
  /// **'Disable notifications'**
  String get chatScreenMenuMute;

  /// No description provided for @chatScreenMenuChangeWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Change wallpaper'**
  String get chatScreenMenuChangeWallpaper;

  /// No description provided for @chatScreenMenuEncryption.
  ///
  /// In en, this message translates to:
  /// **'Message encryption'**
  String get chatScreenMenuEncryption;

  /// No description provided for @chatScreenChatLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get the chat link'**
  String get chatScreenChatLinkUnavailable;

  /// No description provided for @chatScreenSubscribeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t subscribe'**
  String get chatScreenSubscribeFailed;

  /// No description provided for @chatScreenJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t join'**
  String get chatScreenJoinFailed;

  /// No description provided for @chatScreenWallpaperSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the wallpaper'**
  String get chatScreenWallpaperSaveFailed;

  /// No description provided for @chatScreenCallsDialogsOnly.
  ///
  /// In en, this message translates to:
  /// **'Calls are only available in private chats'**
  String get chatScreenCallsDialogsOnly;

  /// No description provided for @chatScreenMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String chatScreenMembersCount(int count);

  /// No description provided for @chatScreenSubscribersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subscriber} other{{count} subscribers}}'**
  String chatScreenSubscribersCount(int count);

  /// No description provided for @chatScreenFormatHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get chatScreenFormatHeading;

  /// No description provided for @chatScreenFormatBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get chatScreenFormatBold;

  /// No description provided for @chatScreenFormatItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get chatScreenFormatItalic;

  /// No description provided for @chatScreenFormatUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get chatScreenFormatUnderline;

  /// No description provided for @chatScreenFormatStrikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get chatScreenFormatStrikethrough;

  /// No description provided for @chatScreenFormatMonospace.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get chatScreenFormatMonospace;

  /// No description provided for @chatScreenFormatQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get chatScreenFormatQuote;

  /// No description provided for @chatScreenFormatMention.
  ///
  /// In en, this message translates to:
  /// **'Mention'**
  String get chatScreenFormatMention;

  /// No description provided for @chatScreenMessageTooLong.
  ///
  /// In en, this message translates to:
  /// **'The message is too long. Split it into several'**
  String get chatScreenMessageTooLong;

  /// No description provided for @chatScreenEncryptionKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'No encryption key is set'**
  String get chatScreenEncryptionKeyMissing;

  /// No description provided for @chatScreenPluginFilesEncryptUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Plugin files can\'t be encrypted yet'**
  String get chatScreenPluginFilesEncryptUnsupported;

  /// No description provided for @chatScreenCommandMissingArgument.
  ///
  /// In en, this message translates to:
  /// **'Missing argument {name}. Format: {usage}'**
  String chatScreenCommandMissingArgument(String name, String usage);

  /// No description provided for @chatScreenPluginError.
  ///
  /// In en, this message translates to:
  /// **'Plugin error: {error}'**
  String chatScreenPluginError(String error);

  /// No description provided for @chatScreenCommandFillField.
  ///
  /// In en, this message translates to:
  /// **'Fill in the {name} field'**
  String chatScreenCommandFillField(String name);

  /// No description provided for @chatScreenScheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for {when}'**
  String chatScreenScheduledFor(String when);

  /// No description provided for @chatScreenScheduleFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t schedule the message'**
  String get chatScreenScheduleFailed;

  /// No description provided for @chatScreenMessageNotSentYet.
  ///
  /// In en, this message translates to:
  /// **'The message hasn\'t been sent yet'**
  String get chatScreenMessageNotSentYet;

  /// No description provided for @chatScreenChannelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Channel unavailable'**
  String get chatScreenChannelUnavailable;

  /// No description provided for @chatScreenChannelFallback.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get chatScreenChannelFallback;

  /// No description provided for @chatScreenNoEncryptFiles.
  ///
  /// In en, this message translates to:
  /// **'Files can\'t be encrypted yet'**
  String get chatScreenNoEncryptFiles;

  /// No description provided for @chatScreenNoEncryptLocation.
  ///
  /// In en, this message translates to:
  /// **'Location can\'t be encrypted yet'**
  String get chatScreenNoEncryptLocation;

  /// No description provided for @chatScreenNoEncryptPolls.
  ///
  /// In en, this message translates to:
  /// **'Polls can\'t be encrypted yet'**
  String get chatScreenNoEncryptPolls;

  /// No description provided for @chatScreenNoEncryptContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts can\'t be encrypted yet'**
  String get chatScreenNoEncryptContacts;

  /// No description provided for @stickerPackSheetRemoved.
  ///
  /// In en, this message translates to:
  /// **'Sticker pack removed'**
  String get stickerPackSheetRemoved;

  /// No description provided for @stickerPackSheetAdded.
  ///
  /// In en, this message translates to:
  /// **'Sticker pack added'**
  String get stickerPackSheetAdded;

  /// No description provided for @stickerPackSheetActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the action'**
  String get stickerPackSheetActionFailed;

  /// No description provided for @stickerPackSheetLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Link unavailable'**
  String get stickerPackSheetLinkUnavailable;

  /// No description provided for @stickerPackSheetForwardedTo.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to “{chat}”'**
  String stickerPackSheetForwardedTo(String chat);

  /// No description provided for @stickerPackSheetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sticker pack unavailable'**
  String get stickerPackSheetUnavailable;

  /// No description provided for @stickerPackSheetStickerCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sticker} other{{count} stickers}}'**
  String stickerPackSheetStickerCount(int count);

  /// No description provided for @stickerPackSheetRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get stickerPackSheetRemove;

  /// No description provided for @performanceScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performanceScreenTitle;

  /// No description provided for @performanceScreenLowWarning.
  ///
  /// In en, this message translates to:
  /// **'App performance may drop. Are you sure?'**
  String get performanceScreenLowWarning;

  /// No description provided for @performanceScreenHighWarning.
  ///
  /// In en, this message translates to:
  /// **'This is unlikely to give any noticeable FPS boost, but it may use more memory. Are you sure?'**
  String get performanceScreenHighWarning;

  /// No description provided for @performanceScreenCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Message cache'**
  String get performanceScreenCacheTitle;

  /// No description provided for @performanceScreenCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How many pixels of messages to keep built outside the visible area.'**
  String get performanceScreenCacheSubtitle;

  /// No description provided for @performanceScreenCurrentExtent.
  ///
  /// In en, this message translates to:
  /// **'Current cacheExtent: {value}'**
  String performanceScreenCurrentExtent(int value);

  /// No description provided for @performanceScreenLessUsage.
  ///
  /// In en, this message translates to:
  /// **'Lower usage'**
  String get performanceScreenLessUsage;

  /// No description provided for @performanceScreenMoreFps.
  ///
  /// In en, this message translates to:
  /// **'Higher FPS'**
  String get performanceScreenMoreFps;

  /// No description provided for @chatWallpaperSheetImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The image is too large (max 16 MB)'**
  String get chatWallpaperSheetImageTooLarge;

  /// No description provided for @chatWallpaperSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get chatWallpaperSheetTitle;

  /// No description provided for @chatWallpaperSheetSampleIncoming.
  ///
  /// In en, this message translates to:
  /// **'How about a new wallpaper for this chat?'**
  String get chatWallpaperSheetSampleIncoming;

  /// No description provided for @chatWallpaperSheetSampleOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Looks great 🔥'**
  String get chatWallpaperSheetSampleOutgoing;

  /// No description provided for @chatWallpaperSheetNone.
  ///
  /// In en, this message translates to:
  /// **'No wallpaper'**
  String get chatWallpaperSheetNone;

  /// No description provided for @chatWallpaperSheetYourPhoto.
  ///
  /// In en, this message translates to:
  /// **'Your photo'**
  String get chatWallpaperSheetYourPhoto;

  /// No description provided for @chatWallpaperSheetFromGallery.
  ///
  /// In en, this message translates to:
  /// **'From gallery'**
  String get chatWallpaperSheetFromGallery;

  /// No description provided for @maxLinkNavChatNotFound.
  ///
  /// In en, this message translates to:
  /// **'Chat not found'**
  String get maxLinkNavChatNotFound;

  /// No description provided for @maxLinkNavProfileFallback.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get maxLinkNavProfileFallback;

  /// No description provided for @maxLinkNavPlatformUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available on your platform'**
  String get maxLinkNavPlatformUnsupported;

  /// No description provided for @maxLinkNavAppFallback.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get maxLinkNavAppFallback;

  /// No description provided for @maxLinkNavNothingToSend.
  ///
  /// In en, this message translates to:
  /// **'Nothing to send'**
  String get maxLinkNavNothingToSend;

  /// No description provided for @maxLinkNavFolderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Folder not found'**
  String get maxLinkNavFolderNotFound;

  /// No description provided for @maxLinkNavSignInFirst.
  ///
  /// In en, this message translates to:
  /// **'Sign in to an account first'**
  String get maxLinkNavSignInFirst;

  /// No description provided for @pollCreateValidationHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a question and at least 2 options'**
  String get pollCreateValidationHint;

  /// No description provided for @pollCreateAnswersTitle.
  ///
  /// In en, this message translates to:
  /// **'Answer options'**
  String get pollCreateAnswersTitle;

  /// No description provided for @pollCreateMultipleAnswers.
  ///
  /// In en, this message translates to:
  /// **'Multiple answers'**
  String get pollCreateMultipleAnswers;

  /// No description provided for @pollCreateAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous voting'**
  String get pollCreateAnonymous;

  /// No description provided for @pollCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New poll'**
  String get pollCreateTitle;

  /// No description provided for @pollCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get pollCreateSubmit;

  /// No description provided for @pollCreateQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get pollCreateQuestionHint;

  /// No description provided for @pollCreateOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String pollCreateOptionHint(int number);

  /// No description provided for @pollCreateAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get pollCreateAddOption;

  /// No description provided for @webQrLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'QR sign-in'**
  String get webQrLoginTitle;

  /// No description provided for @webQrLoginMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign in to your account on the web or in the MAX desktop app?'**
  String get webQrLoginMessage;

  /// No description provided for @webQrLoginConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in confirmed'**
  String get webQrLoginConfirmed;

  /// No description provided for @webQrLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm sign-in: {error}'**
  String webQrLoginFailed(String error);

  /// No description provided for @messageActionsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Action menu'**
  String get messageActionsScreenTitle;

  /// No description provided for @messageActionsScreenRadialDescription.
  ///
  /// In en, this message translates to:
  /// **'An arc of buttons around the tap point'**
  String get messageActionsScreenRadialDescription;

  /// No description provided for @messageActionsScreenList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get messageActionsScreenList;

  /// No description provided for @messageActionsScreenListDescription.
  ///
  /// In en, this message translates to:
  /// **'A vertical menu next to the message'**
  String get messageActionsScreenListDescription;

  /// No description provided for @messageActionsScreenStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get messageActionsScreenStyle;

  /// No description provided for @messageActionsScreenStyleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How the menu appears when you long-press a message'**
  String get messageActionsScreenStyleSubtitle;

  /// No description provided for @videoNoteBubbleTranscriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t transcribe'**
  String get videoNoteBubbleTranscriptionFailed;

  /// No description provided for @webAppScreenCloseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close the mini app?'**
  String get webAppScreenCloseConfirm;

  /// No description provided for @voiceRecordUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Voice messages aren\'t available on this platform'**
  String get voiceRecordUnsupported;

  /// No description provided for @voiceRecordNoMicAccess.
  ///
  /// In en, this message translates to:
  /// **'No access to the microphone'**
  String get voiceRecordNoMicAccess;

  /// No description provided for @voiceRecordStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start recording'**
  String get voiceRecordStartFailed;

  /// No description provided for @voiceRecordEncodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t encode the recording'**
  String get voiceRecordEncodeFailed;

  /// No description provided for @spoofScreenFullWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'There may be consequences.'**
  String get spoofScreenFullWarningTitle;

  /// No description provided for @spoofScreenFullWarningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only change this if you know what you\'re doing.'**
  String get spoofScreenFullWarningSubtitle;

  /// No description provided for @callScreenShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Screen sharing didn\'t start: {error}'**
  String callScreenShareFailed(String error);

  /// No description provided for @themeSettingsCustomizeAction.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get themeSettingsCustomizeAction;

  /// No description provided for @chatListNavChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatListNavChats;

  /// No description provided for @chatListNavCalls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get chatListNavCalls;

  /// No description provided for @chatListNavContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get chatListNavContacts;

  /// No description provided for @chatListShareSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send'**
  String get chatListShareSendFailed;

  /// No description provided for @chatListMuteFailedCount.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change {count} chats: {error}'**
  String chatListMuteFailedCount(int count, String error);

  /// No description provided for @chatListDeleteStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'The chats\' status has changed, please try again'**
  String get chatListDeleteStatusChanged;

  /// No description provided for @chatListDeleteChatWith.
  ///
  /// In en, this message translates to:
  /// **'Delete chat with {name}?'**
  String chatListDeleteChatWith(String name);

  /// No description provided for @chatListDeleteChatsCount.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} chats?'**
  String chatListDeleteChatsCount(int count);

  /// No description provided for @chatListDeleteIrreversible.
  ///
  /// In en, this message translates to:
  /// **'The conversation can\'t be restored'**
  String get chatListDeleteIrreversible;

  /// No description provided for @chatListDeleteOwnedChat.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete the chat “{name}”?'**
  String chatListDeleteOwnedChat(String name);

  /// No description provided for @chatListDeleteGroupsForAll.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} groups for everyone?'**
  String chatListDeleteGroupsForAll(int count);

  /// No description provided for @chatListDeleteOwnedChatBody.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership so the other members can keep talking'**
  String get chatListDeleteOwnedChatBody;

  /// No description provided for @chatListDeleteCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This action can\'t be undone'**
  String get chatListDeleteCannotUndo;

  /// No description provided for @chatListDeleteChatForAll.
  ///
  /// In en, this message translates to:
  /// **'Delete chat for everyone'**
  String get chatListDeleteChatForAll;

  /// No description provided for @chatListDeleteForAll.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get chatListDeleteForAll;

  /// No description provided for @chatListYourStory.
  ///
  /// In en, this message translates to:
  /// **'Your story'**
  String get chatListYourStory;

  /// No description provided for @chatListAllChatsFolder.
  ///
  /// In en, this message translates to:
  /// **'All chats'**
  String get chatListAllChatsFolder;

  /// No description provided for @chatListRecipientsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} recipient} other{{count} recipients}}'**
  String chatListRecipientsCount(int count);

  /// No description provided for @chatListSavedMessages.
  ///
  /// In en, this message translates to:
  /// **'Saved Messages'**
  String get chatListSavedMessages;

  /// No description provided for @chatListReadAll.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get chatListReadAll;

  /// No description provided for @chatListForwardingHint.
  ///
  /// In en, this message translates to:
  /// **'Forwarding...'**
  String get chatListForwardingHint;

  /// No description provided for @chatListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Looks like it\'s empty here...'**
  String get chatListEmpty;

  /// No description provided for @chatListOpenToLoad.
  ///
  /// In en, this message translates to:
  /// **'open the chat to load it'**
  String get chatListOpenToLoad;

  /// No description provided for @chatListArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get chatListArchive;

  /// No description provided for @chatListNewStory.
  ///
  /// In en, this message translates to:
  /// **'New story'**
  String get chatListNewStory;

  /// No description provided for @chatListOpenVideoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the video'**
  String get chatListOpenVideoFailed;

  /// No description provided for @chatListOpenPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the photo'**
  String get chatListOpenPhotoFailed;

  /// No description provided for @chatListDraftPrefix.
  ///
  /// In en, this message translates to:
  /// **'Draft: '**
  String get chatListDraftPrefix;

  /// No description provided for @chatListPreviewWrongKey.
  ///
  /// In en, this message translates to:
  /// **'wrong key'**
  String get chatListPreviewWrongKey;

  /// No description provided for @chatListPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'unavailable on this device'**
  String get chatListPreviewUnavailable;

  /// No description provided for @chatListMessagePerson.
  ///
  /// In en, this message translates to:
  /// **'Message someone'**
  String get chatListMessagePerson;

  /// No description provided for @chatListCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get chatListCreateGroup;

  /// No description provided for @chatListCreateChannel.
  ///
  /// In en, this message translates to:
  /// **'New channel'**
  String get chatListCreateChannel;

  /// No description provided for @chatListCreateContact.
  ///
  /// In en, this message translates to:
  /// **'New contact'**
  String get chatListCreateContact;

  /// No description provided for @chatListCreateFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get chatListCreateFolder;

  /// No description provided for @chatListMessageAction.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatListMessageAction;

  /// No description provided for @chatListNoUnreadChats.
  ///
  /// In en, this message translates to:
  /// **'No unread chats'**
  String get chatListNoUnreadChats;

  /// No description provided for @chatListAllMarkedRead.
  ///
  /// In en, this message translates to:
  /// **'All chats marked as read'**
  String get chatListAllMarkedRead;

  /// No description provided for @callsTabStatusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get callsTabStatusMissed;

  /// No description provided for @callsTabStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get callsTabStatusCanceled;

  /// No description provided for @callsTabStatusOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get callsTabStatusOutgoing;

  /// No description provided for @callsTabStatusIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get callsTabStatusIncoming;

  /// No description provided for @callsTabCallBack.
  ///
  /// In en, this message translates to:
  /// **'Call back'**
  String get callsTabCallBack;

  /// No description provided for @callsTabPeerUnknown.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t identify the other person'**
  String get callsTabPeerUnknown;

  /// No description provided for @callsTabAlreadyInCall.
  ///
  /// In en, this message translates to:
  /// **'A call is already in progress'**
  String get callsTabAlreadyInCall;

  /// No description provided for @callsTabStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the call: {error}'**
  String callsTabStartFailed(String error);

  /// No description provided for @callsTabJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a call'**
  String get callsTabJoinTitle;

  /// No description provided for @callsTabJoinDescription.
  ///
  /// In en, this message translates to:
  /// **'Paste an invite link'**
  String get callsTabJoinDescription;

  /// No description provided for @callsTabNotACallLink.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a call link'**
  String get callsTabNotACallLink;

  /// No description provided for @callsTabCreateCall.
  ///
  /// In en, this message translates to:
  /// **'Create call'**
  String get callsTabCreateCall;

  /// No description provided for @callsTabMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get callsTabMissed;

  /// No description provided for @callsTabEmpty.
  ///
  /// In en, this message translates to:
  /// **'No calls'**
  String get callsTabEmpty;

  /// No description provided for @chatEncryptionProfileNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Profile hasn\'t loaded yet'**
  String get chatEncryptionProfileNotLoaded;

  /// No description provided for @chatEncryptionEnterKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter an encryption key'**
  String get chatEncryptionEnterKeyHint;

  /// No description provided for @chatEncryptionEnabled.
  ///
  /// In en, this message translates to:
  /// **'Encryption enabled'**
  String get chatEncryptionEnabled;

  /// No description provided for @chatEncryptionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Encryption disabled'**
  String get chatEncryptionDisabled;

  /// No description provided for @chatEncryptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Message encryption'**
  String get chatEncryptionTitle;

  /// No description provided for @chatEncryptionToggle.
  ///
  /// In en, this message translates to:
  /// **'Encrypt messages'**
  String get chatEncryptionToggle;

  /// No description provided for @chatEncryptionToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Message text in this chat will be encrypted with the key below'**
  String get chatEncryptionToggleSubtitle;

  /// No description provided for @chatEncryptionKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get chatEncryptionKeyLabel;

  /// No description provided for @chatEncryptionKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter key'**
  String get chatEncryptionKeyHint;

  /// No description provided for @chatEncryptionKeyNote.
  ///
  /// In en, this message translates to:
  /// **'The key is stored only on this device. The other person must enter the same key, otherwise they won\'t be able to read the messages. This is the password mode for groups: no forward secrecy, anyone who knows the password can read the whole history.'**
  String get chatEncryptionKeyNote;

  /// No description provided for @storyViewerDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete story?'**
  String get storyViewerDeleteTitle;

  /// No description provided for @storyViewerDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'The story will disappear for everyone who can view it.'**
  String get storyViewerDeleteMessage;

  /// No description provided for @storyViewerDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the story'**
  String get storyViewerDeleteFailed;

  /// No description provided for @storyViewerDeleteFailedWithReason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the story: {reason}'**
  String storyViewerDeleteFailedWithReason(String reason);

  /// No description provided for @storyViewerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stories'**
  String get storyViewerEmpty;

  /// No description provided for @storyViewerJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get storyViewerJustNow;

  /// No description provided for @storyViewerMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String storyViewerMinutesAgo(int count);

  /// No description provided for @storyViewerHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h'**
  String storyViewerHoursAgo(int count);

  /// No description provided for @storyViewerDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} d'**
  String storyViewerDaysAgo(int count);

  /// No description provided for @webviewPermissionCamera.
  ///
  /// In en, this message translates to:
  /// **'camera'**
  String get webviewPermissionCamera;

  /// No description provided for @webviewPermissionMicrophone.
  ///
  /// In en, this message translates to:
  /// **'microphone'**
  String get webviewPermissionMicrophone;

  /// No description provided for @webviewPermissionCameraAndMicrophone.
  ///
  /// In en, this message translates to:
  /// **'camera and microphone'**
  String get webviewPermissionCameraAndMicrophone;

  /// No description provided for @webviewPermissionGeolocation.
  ///
  /// In en, this message translates to:
  /// **'location'**
  String get webviewPermissionGeolocation;

  /// No description provided for @webviewPermissionOther.
  ///
  /// In en, this message translates to:
  /// **'additional access'**
  String get webviewPermissionOther;

  /// No description provided for @webviewPermissionWebPage.
  ///
  /// In en, this message translates to:
  /// **'Web page'**
  String get webviewPermissionWebPage;

  /// No description provided for @webviewPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Access request'**
  String get webviewPermissionTitle;

  /// No description provided for @webviewPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'{host} is requesting access to: {resources}.'**
  String webviewPermissionMessage(String host, String resources);

  /// No description provided for @webviewPermissionDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get webviewPermissionDeny;

  /// No description provided for @createChannelFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the channel'**
  String get createChannelFailed;

  /// No description provided for @createChannelAvatarProcessFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t process the avatar'**
  String get createChannelAvatarProcessFailed;

  /// No description provided for @createChannelAvatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the avatar'**
  String get createChannelAvatarUploadFailed;

  /// No description provided for @createChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Only you post in a channel, members read. You can invite them after it\'s created.'**
  String get createChannelDescription;

  /// No description provided for @createChannelCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get createChannelCancel;

  /// No description provided for @createChannelCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get createChannelCreating;

  /// No description provided for @createChannelCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createChannelCreate;

  /// No description provided for @codeConfirmationConnectionDropped.
  ///
  /// In en, this message translates to:
  /// **'Connection lost, reconnecting…'**
  String get codeConfirmationConnectionDropped;

  /// No description provided for @codeConfirmationNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server'**
  String get codeConfirmationNoConnection;

  /// No description provided for @codeConfirmationConnectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get codeConfirmationConnectionRestored;

  /// No description provided for @codeConfirmationReconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the connection: {error}'**
  String codeConfirmationReconnectFailed(String error);

  /// No description provided for @codeConfirmationRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh the code: {error}'**
  String codeConfirmationRefreshFailed(String error);

  /// No description provided for @codeConfirmationNewCodeSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a new code'**
  String get codeConfirmationNewCodeSent;

  /// No description provided for @codeConfirmationSmsNoToken.
  ///
  /// In en, this message translates to:
  /// **'SMS sign-in: the server didn\'t return a token'**
  String get codeConfirmationSmsNoToken;

  /// No description provided for @codeConfirmationCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'The code expired — we sent a new one'**
  String get codeConfirmationCodeExpired;

  /// No description provided for @pollViewVoteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t vote'**
  String get pollViewVoteFailed;

  /// No description provided for @pollViewLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading poll…'**
  String get pollViewLoading;

  /// No description provided for @pollViewMultipleAnswers.
  ///
  /// In en, this message translates to:
  /// **'Multiple answers'**
  String get pollViewMultipleAnswers;

  /// No description provided for @pollViewSingleAnswer.
  ///
  /// In en, this message translates to:
  /// **'Single answer'**
  String get pollViewSingleAnswer;

  /// No description provided for @pollViewVotesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} vote} other{{count} votes}}'**
  String pollViewVotesCount(int count);

  /// No description provided for @pollViewVote.
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get pollViewVote;

  /// No description provided for @customizationChatBackground.
  ///
  /// In en, this message translates to:
  /// **'Chat background'**
  String get customizationChatBackground;

  /// No description provided for @customizationMessageActions.
  ///
  /// In en, this message translates to:
  /// **'Actions menu'**
  String get customizationMessageActions;

  /// No description provided for @customizationAppIcon.
  ///
  /// In en, this message translates to:
  /// **'App icon'**
  String get customizationAppIcon;

  /// No description provided for @customizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Customization'**
  String get customizationTitle;

  /// No description provided for @folderActionNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get folderActionNewFolder;

  /// No description provided for @folderActionDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the folder “{title}”? The chats will stay where they are.'**
  String folderActionDeleteConfirm(String title);

  /// No description provided for @folderActionDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the folder'**
  String get folderActionDeleteFailed;

  /// No description provided for @webAppBiometryAccessNotice.
  ///
  /// In en, this message translates to:
  /// **'The mini app will be able to ask for fingerprint or face confirmation.'**
  String get webAppBiometryAccessNotice;

  /// No description provided for @webAppBiometryAuthReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm the action in the mini app'**
  String get webAppBiometryAuthReason;

  /// No description provided for @webAppBiometryAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow biometrics?'**
  String get webAppBiometryAccessTitle;

  /// No description provided for @webAppPhoneRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your phone number?'**
  String get webAppPhoneRequestTitle;

  /// No description provided for @webAppPhoneRequestMessage.
  ///
  /// In en, this message translates to:
  /// **'The mini app will receive your phone number.'**
  String get webAppPhoneRequestMessage;

  /// No description provided for @webAppPhoneRequestShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get webAppPhoneRequestShare;

  /// No description provided for @promptDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get promptDialogConfirm;

  /// No description provided for @emojiPanelLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load emoji'**
  String get emojiPanelLoadFailed;

  /// No description provided for @emojiPanelEmpty.
  ///
  /// In en, this message translates to:
  /// **'No emoji'**
  String get emojiPanelEmpty;

  /// No description provided for @mediaPreviewEditorOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the editor'**
  String get mediaPreviewEditorOpenFailed;

  /// No description provided for @fontSettingsSampleText.
  ///
  /// In en, this message translates to:
  /// **'The quick brown fox jumps over the lazy dog'**
  String get fontSettingsSampleText;

  /// No description provided for @callParticipantsNoServer.
  ///
  /// In en, this message translates to:
  /// **'No connection to the call server'**
  String get callParticipantsNoServer;

  /// No description provided for @callParticipantsActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String callParticipantsActionFailed(String error);

  /// No description provided for @callParticipantsMuteMic.
  ///
  /// In en, this message translates to:
  /// **'Mute microphone'**
  String get callParticipantsMuteMic;

  /// No description provided for @callParticipantsRequestCamera.
  ///
  /// In en, this message translates to:
  /// **'Request camera'**
  String get callParticipantsRequestCamera;

  /// No description provided for @callParticipantsRevokeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Remove admin'**
  String get callParticipantsRevokeAdmin;

  /// No description provided for @callParticipantsRevokeSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Remove from speakers'**
  String get callParticipantsRevokeSpeaker;

  /// No description provided for @callParticipantsMakeSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Make speaker'**
  String get callParticipantsMakeSpeaker;

  /// No description provided for @callParticipantsPromote.
  ///
  /// In en, this message translates to:
  /// **'Promote'**
  String get callParticipantsPromote;

  /// No description provided for @callParticipantsDemote.
  ///
  /// In en, this message translates to:
  /// **'Demote'**
  String get callParticipantsDemote;

  /// No description provided for @callParticipantsRemoveFromCall.
  ///
  /// In en, this message translates to:
  /// **'Remove from call'**
  String get callParticipantsRemoveFromCall;

  /// No description provided for @callParticipantsCallSettings.
  ///
  /// In en, this message translates to:
  /// **'Call settings'**
  String get callParticipantsCallSettings;

  /// No description provided for @callParticipantsFeatureAccess.
  ///
  /// In en, this message translates to:
  /// **'Who can use features'**
  String get callParticipantsFeatureAccess;

  /// No description provided for @callParticipantsInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Participant invite link'**
  String get callParticipantsInviteLink;

  /// No description provided for @callParticipantsOptionAuthOnly.
  ///
  /// In en, this message translates to:
  /// **'Signed-in users only'**
  String get callParticipantsOptionAuthOnly;

  /// No description provided for @callParticipantsOptionWaitingHall.
  ///
  /// In en, this message translates to:
  /// **'Waiting room'**
  String get callParticipantsOptionWaitingHall;

  /// No description provided for @callParticipantsOptionRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring call'**
  String get callParticipantsOptionRecurring;

  /// No description provided for @callParticipantsOptionFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback collection'**
  String get callParticipantsOptionFeedback;

  /// No description provided for @callParticipantsOptionAudienceMode.
  ///
  /// In en, this message translates to:
  /// **'Audience mode'**
  String get callParticipantsOptionAudienceMode;

  /// No description provided for @callParticipantsSpeechTranscription.
  ///
  /// In en, this message translates to:
  /// **'Speech transcription'**
  String get callParticipantsSpeechTranscription;

  /// No description provided for @callParticipantsOptionWaitForAdmin.
  ///
  /// In en, this message translates to:
  /// **'Wait for an admin'**
  String get callParticipantsOptionWaitForAdmin;

  /// No description provided for @callParticipantsOptionAdminIsHere.
  ///
  /// In en, this message translates to:
  /// **'Admin is present'**
  String get callParticipantsOptionAdminIsHere;

  /// No description provided for @callParticipantsFeatureMovieShare.
  ///
  /// In en, this message translates to:
  /// **'Watch together'**
  String get callParticipantsFeatureMovieShare;

  /// No description provided for @callParticipantsCallRecording.
  ///
  /// In en, this message translates to:
  /// **'Call recording'**
  String get callParticipantsCallRecording;

  /// No description provided for @callParticipantsFeatureSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Be a speaker'**
  String get callParticipantsFeatureSpeaker;

  /// No description provided for @callParticipantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Participants · {count}'**
  String callParticipantsTitle(int count);

  /// No description provided for @callParticipantsMuteAll.
  ///
  /// In en, this message translates to:
  /// **'Mute everyone'**
  String get callParticipantsMuteAll;

  /// No description provided for @callParticipantsLowerAllHands.
  ///
  /// In en, this message translates to:
  /// **'Lower all hands'**
  String get callParticipantsLowerAllHands;

  /// No description provided for @callParticipantsLowerHand.
  ///
  /// In en, this message translates to:
  /// **'Lower hand'**
  String get callParticipantsLowerHand;

  /// No description provided for @callParticipantsRaiseHand.
  ///
  /// In en, this message translates to:
  /// **'Raise hand'**
  String get callParticipantsRaiseHand;

  /// No description provided for @callParticipantsStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get callParticipantsStopRecording;

  /// No description provided for @callParticipantsStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get callParticipantsStartRecording;

  /// No description provided for @callParticipantsRolePermissions.
  ///
  /// In en, this message translates to:
  /// **'Role permissions'**
  String get callParticipantsRolePermissions;

  /// No description provided for @callParticipantsAddByLink.
  ///
  /// In en, this message translates to:
  /// **'Add by link'**
  String get callParticipantsAddByLink;

  /// No description provided for @callParticipantsCreator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get callParticipantsCreator;

  /// No description provided for @callParticipantsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get callParticipantsAdmin;

  /// No description provided for @callParticipantsSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get callParticipantsSpeaker;

  /// No description provided for @callParticipantsHandRaised.
  ///
  /// In en, this message translates to:
  /// **'Hand raised'**
  String get callParticipantsHandRaised;

  /// No description provided for @chatMediaSendEnableLocation.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services'**
  String get chatMediaSendEnableLocation;

  /// No description provided for @chatMediaSendNoLocationAccess.
  ///
  /// In en, this message translates to:
  /// **'No access to location'**
  String get chatMediaSendNoLocationAccess;

  /// No description provided for @chatMediaSendLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location'**
  String get chatMediaSendLocationFailed;

  /// No description provided for @chatMediaSendScheduledEncryptedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Scheduled photos aren\'t supported in encrypted chats yet'**
  String get chatMediaSendScheduledEncryptedPhotos;

  /// No description provided for @chatMediaSendVideoNotEncryptable.
  ///
  /// In en, this message translates to:
  /// **'Videos can\'t be encrypted yet'**
  String get chatMediaSendVideoNotEncryptable;

  /// No description provided for @chatMediaSendPhotoEncryptFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t encrypt the photo'**
  String get chatMediaSendPhotoEncryptFailed;

  /// No description provided for @chatMediaSendNoEncryptionKey.
  ///
  /// In en, this message translates to:
  /// **'Encryption key isn\'t set'**
  String get chatMediaSendNoEncryptionKey;

  /// No description provided for @chatMediaSendNoUploadUrl.
  ///
  /// In en, this message translates to:
  /// **'the server didn\'t provide an upload link'**
  String get chatMediaSendNoUploadUrl;

  /// No description provided for @chatMediaSendUploadRejected.
  ///
  /// In en, this message translates to:
  /// **'upload rejected'**
  String get chatMediaSendUploadRejected;

  /// No description provided for @chatMediaSendServerRejected.
  ///
  /// In en, this message translates to:
  /// **'the server didn\'t accept the message'**
  String get chatMediaSendServerRejected;

  /// No description provided for @chatMediaSendFileFailed.
  ///
  /// In en, this message translates to:
  /// **'File not sent: {detail}'**
  String chatMediaSendFileFailed(String detail);

  /// No description provided for @chatMediaSendVideoNoteFailed.
  ///
  /// In en, this message translates to:
  /// **'Video message not sent: {detail}'**
  String chatMediaSendVideoNoteFailed(String detail);

  /// No description provided for @chatMediaSendVoiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice message not sent: {detail}'**
  String chatMediaSendVoiceFailed(String detail);

  /// No description provided for @chatMediaSendPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo not sent: {detail}'**
  String chatMediaSendPhotoFailed(String detail);

  /// No description provided for @chatMediaSendVideoFailed.
  ///
  /// In en, this message translates to:
  /// **'Video not sent: {detail}'**
  String chatMediaSendVideoFailed(String detail);

  /// No description provided for @chatMediaSendScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get chatMediaSendScheduled;

  /// No description provided for @chatMediaSendScheduledAt.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for {date}'**
  String chatMediaSendScheduledAt(String date);

  /// No description provided for @chatMediaSendScheduleFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t schedule'**
  String get chatMediaSendScheduleFailed;

  /// No description provided for @messageListToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get messageListToday;

  /// No description provided for @messageListYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get messageListYesterday;

  /// No description provided for @messageListDateThisYear.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String messageListDateThisYear(DateTime date);

  /// No description provided for @messageListDateOtherYear.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String messageListDateOtherYear(DateTime date);

  /// No description provided for @messageListUnreadMessages.
  ///
  /// In en, this message translates to:
  /// **'Unread messages'**
  String get messageListUnreadMessages;

  /// No description provided for @photoViewerSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get photoViewerSavedToGallery;

  /// No description provided for @photoViewerSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String photoViewerSavedTo(String path);

  /// No description provided for @photoViewerSaveFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the file'**
  String get photoViewerSaveFileFailed;

  /// No description provided for @photoViewerFileSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get photoViewerFileSaved;

  /// No description provided for @photoViewerErrorNoLink.
  ///
  /// In en, this message translates to:
  /// **'no link'**
  String get photoViewerErrorNoLink;

  /// No description provided for @photoViewerErrorNoMedia.
  ///
  /// In en, this message translates to:
  /// **'no media'**
  String get photoViewerErrorNoMedia;

  /// No description provided for @photoViewerMediaLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the media'**
  String get photoViewerMediaLoadFailed;

  /// No description provided for @avatarPhotoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the photo'**
  String get avatarPhotoLoadFailed;

  /// No description provided for @avatarPhotoDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete photo?'**
  String get avatarPhotoDeleteTitle;

  /// No description provided for @avatarPhotoDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The photo will be removed from your profile and avatar history.'**
  String get avatarPhotoDeleteBody;

  /// No description provided for @loginScreenReconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reconnect: {error}'**
  String loginScreenReconnectFailed(String error);

  /// No description provided for @loginScreenSmsWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'IF YOUR ACCOUNT HAS NO 2FA, ALL SESSIONS WILL BE RESET'**
  String get loginScreenSmsWarningTitle;

  /// No description provided for @loginScreenSmsWarningBody.
  ///
  /// In en, this message translates to:
  /// **'This method is experimental, use it at your own risk.'**
  String get loginScreenSmsWarningBody;

  /// No description provided for @loginScreenOfflineWait.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Please wait until it connects.'**
  String get loginScreenOfflineWait;

  /// No description provided for @loginScreenOfflineRetry.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Please try again.'**
  String get loginScreenOfflineRetry;

  /// No description provided for @loginScreenConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the server, just a moment…'**
  String get loginScreenConnecting;

  /// No description provided for @loginScreenAlwaysSendSms.
  ///
  /// In en, this message translates to:
  /// **'Always send SMS (EXPERIMENTAL)'**
  String get loginScreenAlwaysSendSms;

  /// No description provided for @editProfileNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name can\'t be empty'**
  String get editProfileNameEmpty;

  /// No description provided for @editProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get editProfileSaved;

  /// No description provided for @editProfileAvatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the avatar'**
  String get editProfileAvatarUploadFailed;

  /// No description provided for @editProfileAvatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get editProfileAvatarUpdated;

  /// No description provided for @editProfilePhotoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Photo deleted'**
  String get editProfilePhotoDeleted;

  /// No description provided for @findUserInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get findUserInvalidPhone;

  /// No description provided for @findUserPhoneNotFound.
  ///
  /// In en, this message translates to:
  /// **'No contact with this number was found'**
  String get findUserPhoneNotFound;

  /// No description provided for @findUserInvalidId.
  ///
  /// In en, this message translates to:
  /// **'Enter a numeric ID'**
  String get findUserInvalidId;

  /// No description provided for @findUserIdNotFound.
  ///
  /// In en, this message translates to:
  /// **'No contact with this ID was found'**
  String get findUserIdNotFound;

  /// No description provided for @findUserPhoneTab.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get findUserPhoneTab;

  /// No description provided for @findUserPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number'**
  String get findUserPhoneHint;

  /// No description provided for @findUserIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a contact ID'**
  String get findUserIdHint;

  /// No description provided for @loginSuccessGreetingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Komet!'**
  String get loginSuccessGreetingWelcome;

  /// No description provided for @loginSuccessGreetingEmergencyExit.
  ///
  /// In en, this message translates to:
  /// **'An emergency exit at 30,000 feet. The illusion of safety.'**
  String get loginSuccessGreetingEmergencyExit;

  /// No description provided for @loginSuccessGreetingFunnyThings.
  ///
  /// In en, this message translates to:
  /// **'Sometimes funny things can be a criminal offense'**
  String get loginSuccessGreetingFunnyThings;

  /// No description provided for @loginSuccessGreetingFarewell.
  ///
  /// In en, this message translates to:
  /// **'If you\'re reading this message, I\'m no longer alive.'**
  String get loginSuccessGreetingFarewell;

  /// No description provided for @loginSuccessGreetingGondor.
  ///
  /// In en, this message translates to:
  /// **'Where was Gondor when...'**
  String get loginSuccessGreetingGondor;

  /// No description provided for @loginSuccessGreetingEasterEgg.
  ///
  /// In en, this message translates to:
  /// **'You found an Easter egg!'**
  String get loginSuccessGreetingEasterEgg;

  /// No description provided for @chatTextSendUnknownCommand.
  ///
  /// In en, this message translates to:
  /// **'NO SUCH COMMAND🚨🚨🚨'**
  String get chatTextSendUnknownCommand;

  /// No description provided for @chatTextSendSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the message'**
  String get chatTextSendSaveFailed;

  /// No description provided for @voiceBubbleLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the audio'**
  String get voiceBubbleLoadFailed;

  /// No description provided for @voiceBubblePlaybackError.
  ///
  /// In en, this message translates to:
  /// **'Playback error'**
  String get voiceBubblePlaybackError;

  /// No description provided for @voiceBubbleTranscribe.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get voiceBubbleTranscribe;

  /// No description provided for @voiceBubbleTranscribing.
  ///
  /// In en, this message translates to:
  /// **'transcribing...'**
  String get voiceBubbleTranscribing;

  /// No description provided for @voiceBubbleTranscriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'transcription failed'**
  String get voiceBubbleTranscriptionFailed;

  /// No description provided for @chatInfoStoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} story} other{{count} stories}}'**
  String chatInfoStoryCount(int count);

  /// No description provided for @chatInfoMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} member} other{{count} members}}'**
  String chatInfoMemberCount(int count);

  /// No description provided for @chatInfoSubscriberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} subscriber} other{{count} subscribers}}'**
  String chatInfoSubscriberCount(int count);

  /// No description provided for @customGradientTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom theme'**
  String get customGradientTitle;

  /// No description provided for @customGradientAnimation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get customGradientAnimation;

  /// No description provided for @customGradientAnimationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Smoothly shifting colors'**
  String get customGradientAnimationSubtitle;

  /// No description provided for @videoBubbleOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the video'**
  String get videoBubbleOpenFailed;

  /// No description provided for @videoBubbleLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get the video'**
  String get videoBubbleLoadFailed;

  /// No description provided for @accountSwitcherNoName.
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get accountSwitcherNoName;

  /// No description provided for @accountSwitcherAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountSwitcherAddAccount;

  /// No description provided for @infoScreenWeeksShort.
  ///
  /// In en, this message translates to:
  /// **'{weeks} wk'**
  String infoScreenWeeksShort(int weeks);

  /// No description provided for @infoScreenDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{days} d'**
  String infoScreenDaysShort(int days);

  /// No description provided for @pluginsScreenPickKinetFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file with the .kinet extension'**
  String get pluginsScreenPickKinetFile;

  /// No description provided for @pluginsScreenReadFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the selected file'**
  String get pluginsScreenReadFileFailed;

  /// No description provided for @pluginsScreenOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open .kinet: {error}'**
  String pluginsScreenOpenFailed(String error);

  /// No description provided for @pluginsScreenHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'A valid HTTPS link is required'**
  String get pluginsScreenHttpsRequired;

  /// No description provided for @pluginsScreenDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download .kinet: {error}'**
  String pluginsScreenDownloadFailed(String error);

  /// No description provided for @pluginsScreenVersionAuthor.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · {author}'**
  String pluginsScreenVersionAuthor(String version, String author);

  /// No description provided for @pluginsScreenSignatureVerified.
  ///
  /// In en, this message translates to:
  /// **'Ed25519 signature verified\n{fingerprint}'**
  String pluginsScreenSignatureVerified(String fingerprint);

  /// No description provided for @pluginsScreenNotSigned.
  ///
  /// In en, this message translates to:
  /// **'The plugin isn\'t signed'**
  String get pluginsScreenNotSigned;

  /// No description provided for @pluginsScreenPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'The plugin will be granted these permissions:'**
  String get pluginsScreenPermissionsTitle;

  /// No description provided for @pluginsScreenAllowAndInstall.
  ///
  /// In en, this message translates to:
  /// **'Allow and install'**
  String get pluginsScreenAllowAndInstall;

  /// No description provided for @pluginsScreenInstalled.
  ///
  /// In en, this message translates to:
  /// **'{name} installed'**
  String pluginsScreenInstalled(String name);

  /// No description provided for @pluginsScreenInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t install the plugin: {error}'**
  String pluginsScreenInstallFailed(String error);

  /// No description provided for @pluginsScreenNoUpdates.
  ///
  /// In en, this message translates to:
  /// **'No updates available'**
  String get pluginsScreenNoUpdates;

  /// No description provided for @pluginsScreenUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update plugin?'**
  String get pluginsScreenUpdateTitle;

  /// No description provided for @pluginsScreenUpdated.
  ///
  /// In en, this message translates to:
  /// **'Plugin updated'**
  String get pluginsScreenUpdated;

  /// No description provided for @pluginsScreenUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update: {error}'**
  String pluginsScreenUpdateFailed(String error);

  /// No description provided for @pluginsScreenUninstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete plugin?'**
  String get pluginsScreenUninstallTitle;

  /// No description provided for @pluginsScreenUninstalled.
  ///
  /// In en, this message translates to:
  /// **'Plugin and its data deleted'**
  String get pluginsScreenUninstalled;

  /// No description provided for @pluginsScreenUninstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete: {error}'**
  String pluginsScreenUninstallFailed(String error);

  /// No description provided for @pluginsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get pluginsScreenTitle;

  /// No description provided for @pluginsScreenInstallFile.
  ///
  /// In en, this message translates to:
  /// **'Install .kinet'**
  String get pluginsScreenInstallFile;

  /// No description provided for @pluginsScreenInstallUrl.
  ///
  /// In en, this message translates to:
  /// **'Install from URL'**
  String get pluginsScreenInstallUrl;

  /// No description provided for @pluginsScreenBundled.
  ///
  /// In en, this message translates to:
  /// **'Built-in Komet plugin'**
  String get pluginsScreenBundled;

  /// No description provided for @pluginsScreenSigned.
  ///
  /// In en, this message translates to:
  /// **'Signed · {fingerprint}'**
  String pluginsScreenSigned(String fingerprint);

  /// No description provided for @pluginsScreenUnsigned.
  ///
  /// In en, this message translates to:
  /// **'Not signed'**
  String get pluginsScreenUnsigned;

  /// No description provided for @pluginsScreenCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get pluginsScreenCheckUpdates;

  /// No description provided for @pluginsScreenDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get pluginsScreenDownload;

  /// No description provided for @kometSettingsViewDeletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show deleted messages'**
  String get kometSettingsViewDeletedSubtitle;

  /// No description provided for @kometSettingsViewRedactedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the edit history of messages'**
  String get kometSettingsViewRedactedSubtitle;

  /// No description provided for @kometSettingsFullTimestampSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show message times with seconds'**
  String get kometSettingsFullTimestampSubtitle;

  /// No description provided for @kometSettingsShowForwardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark forwarded messages even when no author is shown on them'**
  String get kometSettingsShowForwardSubtitle;

  /// No description provided for @kometSettingsTypingTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tries to estimate how long a message took to type'**
  String get kometSettingsTypingTimeSubtitle;

  /// No description provided for @kometSettingsFoldersHeader.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get kometSettingsFoldersHeader;

  /// No description provided for @kometSettingsHideAllFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide the \"All\" folder when you have other folders. Chats are sorted only by your folders'**
  String get kometSettingsHideAllFolderSubtitle;

  /// No description provided for @kometSettingsShowHiddenChatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show hidden chats that usually don\'t appear in the list: from group calls, private channels and chats you\'ve left'**
  String get kometSettingsShowHiddenChatsSubtitle;

  /// No description provided for @kometSettingsArchiveOnPullSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide the archive and show it when you pull the chat list down, after stories'**
  String get kometSettingsArchiveOnPullSubtitle;

  /// No description provided for @kometSettingsGhostModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You don\'t appear online'**
  String get kometSettingsGhostModeSubtitle;

  /// No description provided for @kometSettingsAntiReadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read messages without marking them as read'**
  String get kometSettingsAntiReadSubtitle;

  /// No description provided for @kometSettingsSelfOnlineCheckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Checks every ~10 seconds when you were last online. Useful for testing ghost mode'**
  String get kometSettingsSelfOnlineCheckSubtitle;

  /// No description provided for @kometSettingsDebugHeader.
  ///
  /// In en, this message translates to:
  /// **'Debugging'**
  String get kometSettingsDebugHeader;

  /// No description provided for @kometSettingsDebugLogsLabel.
  ///
  /// In en, this message translates to:
  /// **'Record debug logs'**
  String get kometSettingsDebugLogsLabel;

  /// No description provided for @kometSettingsDebugLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Writes protocol traffic to a file on the device — helps diagnose bugs in reports'**
  String get kometSettingsDebugLogsSubtitle;

  /// No description provided for @sharedContentSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get sharedContentSavedToGallery;

  /// No description provided for @sharedContentFileSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get sharedContentFileSaved;

  /// No description provided for @sharedContentVideoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the video'**
  String get sharedContentVideoLoadFailed;

  /// No description provided for @sharedContentAudioLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the audio'**
  String get sharedContentAudioLoadFailed;

  /// No description provided for @sharedContentPlaybackError.
  ///
  /// In en, this message translates to:
  /// **'Playback error'**
  String get sharedContentPlaybackError;

  /// No description provided for @messageBubbleButtonUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This button isn\'t supported'**
  String get messageBubbleButtonUnsupported;

  /// No description provided for @messageBubblePlatformUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available on your platform'**
  String get messageBubblePlatformUnavailable;

  /// No description provided for @messageBubbleEditedTime.
  ///
  /// In en, this message translates to:
  /// **'edited {time}'**
  String messageBubbleEditedTime(String time);

  /// No description provided for @messageBubbleWrongKey.
  ///
  /// In en, this message translates to:
  /// **'wrong key'**
  String get messageBubbleWrongKey;

  /// No description provided for @messageBubbleUnavailableOnDevice.
  ///
  /// In en, this message translates to:
  /// **'unavailable on this device'**
  String get messageBubbleUnavailableOnDevice;

  /// No description provided for @messageBubbleReplyDeleted.
  ///
  /// In en, this message translates to:
  /// **'message deleted'**
  String get messageBubbleReplyDeleted;

  /// No description provided for @searchScreenSavedMessages.
  ///
  /// In en, this message translates to:
  /// **'Saved Messages'**
  String get searchScreenSavedMessages;

  /// No description provided for @searchScreenStartTyping.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search'**
  String get searchScreenStartTyping;

  /// No description provided for @searchScreenByPhone.
  ///
  /// In en, this message translates to:
  /// **'By phone number'**
  String get searchScreenByPhone;

  /// No description provided for @searchScreenContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get searchScreenContacts;

  /// No description provided for @searchScreenChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get searchScreenChats;

  /// No description provided for @searchScreenGlobalSearch.
  ///
  /// In en, this message translates to:
  /// **'Global search'**
  String get searchScreenGlobalSearch;

  /// No description provided for @searchScreenUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get searchScreenUntitled;

  /// No description provided for @fileBubbleCorrupted.
  ///
  /// In en, this message translates to:
  /// **'File is corrupted'**
  String get fileBubbleCorrupted;

  /// No description provided for @fileBubbleWrongKey.
  ///
  /// In en, this message translates to:
  /// **'Wrong key'**
  String get fileBubbleWrongKey;

  /// No description provided for @fileBubbleTapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Tap to open'**
  String get fileBubbleTapToOpen;

  /// No description provided for @fileBubbleDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the file'**
  String get fileBubbleDownloadFailed;

  /// No description provided for @fileBubbleDecryptPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t decrypt the photo'**
  String get fileBubbleDecryptPhotoFailed;

  /// No description provided for @fileBubbleUnknownFile.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t identify the file'**
  String get fileBubbleUnknownFile;

  /// No description provided for @fileBubbleOpenFailedReason.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t open'**
  String get fileBubbleOpenFailedReason;

  /// No description provided for @fileBubbleDownloadFailedReason.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t download'**
  String get fileBubbleDownloadFailedReason;

  /// No description provided for @storyComposerUploadUrlFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get the upload address'**
  String get storyComposerUploadUrlFailed;

  /// No description provided for @storyComposerPhotoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the photo'**
  String get storyComposerPhotoUploadFailed;

  /// No description provided for @storyComposerVideoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the video'**
  String get storyComposerVideoUploadFailed;

  /// No description provided for @storyComposerPublished.
  ///
  /// In en, this message translates to:
  /// **'Story published'**
  String get storyComposerPublished;

  /// No description provided for @storyComposerPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get storyComposerPublish;

  /// No description provided for @storyComposerContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get storyComposerContacts;

  /// No description provided for @textEntityProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Profile @{nickname} not found'**
  String textEntityProfileNotFound(String nickname);

  /// No description provided for @textEntityCopyPhone.
  ///
  /// In en, this message translates to:
  /// **'Copy phone number'**
  String get textEntityCopyPhone;

  /// No description provided for @textEntityPhoneCopied.
  ///
  /// In en, this message translates to:
  /// **'Number copied'**
  String get textEntityPhoneCopied;

  /// No description provided for @textEntityCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get textEntityCall;

  /// No description provided for @textEntityCopyCard.
  ///
  /// In en, this message translates to:
  /// **'Copy card number'**
  String get textEntityCopyCard;

  /// No description provided for @textEntityCardCopied.
  ///
  /// In en, this message translates to:
  /// **'Card number copied'**
  String get textEntityCardCopied;

  /// No description provided for @textEntityDialFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the phone app'**
  String get textEntityDialFailed;

  /// No description provided for @textEntityNotOnMax.
  ///
  /// In en, this message translates to:
  /// **'This person isn\'t on MAX yet'**
  String get textEntityNotOnMax;

  /// No description provided for @callLinkHandlerAlreadyInCall.
  ///
  /// In en, this message translates to:
  /// **'A call is already in progress'**
  String get callLinkHandlerAlreadyInCall;

  /// No description provided for @callLinkHandlerJoinPromptWithCount.
  ///
  /// In en, this message translates to:
  /// **'Join the call “{name}”? In the call now: {count}.'**
  String callLinkHandlerJoinPromptWithCount(String name, int count);

  /// No description provided for @callLinkHandlerJoinPrompt.
  ///
  /// In en, this message translates to:
  /// **'Join the call “{name}”?'**
  String callLinkHandlerJoinPrompt(String name);

  /// No description provided for @callLinkHandlerJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t join the call'**
  String get callLinkHandlerJoinFailed;

  /// No description provided for @appIconScreenUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Changing the icon is only available on Android and iOS'**
  String get appIconScreenUnsupported;

  /// No description provided for @appIconScreenChanged.
  ///
  /// In en, this message translates to:
  /// **'Icon changed to “{name}”'**
  String appIconScreenChanged(String name);

  /// No description provided for @appIconScreenChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the icon: {error}'**
  String appIconScreenChangeFailed(String error);

  /// No description provided for @appIconScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'App icon'**
  String get appIconScreenTitle;

  /// No description provided for @appIconScreenAppearance.
  ///
  /// In en, this message translates to:
  /// **'Icon style'**
  String get appIconScreenAppearance;

  /// No description provided for @appIconScreenHint.
  ///
  /// In en, this message translates to:
  /// **'On Android the app will close so the launcher picks up the new icon. On iOS it changes instantly with a system dialog.'**
  String get appIconScreenHint;

  /// No description provided for @appIconScreenOnlyMobile.
  ///
  /// In en, this message translates to:
  /// **'Only available on Android and iOS'**
  String get appIconScreenOnlyMobile;

  /// No description provided for @password2faConnectionDropped.
  ///
  /// In en, this message translates to:
  /// **'Connection lost…'**
  String get password2faConnectionDropped;

  /// No description provided for @password2faConnectionDroppedRelogin.
  ///
  /// In en, this message translates to:
  /// **'Connection lost — sign in again'**
  String get password2faConnectionDroppedRelogin;

  /// No description provided for @password2faEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to finish signing in'**
  String get password2faEnterPassword;

  /// No description provided for @contactsTabFindContact.
  ///
  /// In en, this message translates to:
  /// **'Find contact'**
  String get contactsTabFindContact;

  /// No description provided for @contactsTabFind.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get contactsTabFind;

  /// No description provided for @contactsTabLastSeenRecently.
  ///
  /// In en, this message translates to:
  /// **'Last seen recently'**
  String get contactsTabLastSeenRecently;

  /// No description provided for @contactsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contactsTabTitle;

  /// No description provided for @contactsTabEmpty.
  ///
  /// In en, this message translates to:
  /// **'No contacts'**
  String get contactsTabEmpty;

  /// No description provided for @securityScreenBlockedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 contact} other{{count} contacts}}'**
  String securityScreenBlockedCount(int count);

  /// No description provided for @attachmentPanelInvalidFileId.
  ///
  /// In en, this message translates to:
  /// **'Invalid fileId'**
  String get attachmentPanelInvalidFileId;

  /// No description provided for @attachmentPanelPickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose from files'**
  String get attachmentPanelPickFile;

  /// No description provided for @attachmentPanelSendById.
  ///
  /// In en, this message translates to:
  /// **'Send by id'**
  String get attachmentPanelSendById;

  /// No description provided for @selectionBarSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectionBarSelectedCount(int count);

  /// No description provided for @metaMarksLikelyForwarded.
  ///
  /// In en, this message translates to:
  /// **'This message was most likely forwarded'**
  String get metaMarksLikelyForwarded;

  /// No description provided for @metaMarksTypingTime.
  ///
  /// In en, this message translates to:
  /// **'This message took about ~{duration} to type'**
  String metaMarksTypingTime(String duration);

  /// No description provided for @searchViewHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchViewHint;

  /// No description provided for @searchViewNoResults.
  ///
  /// In en, this message translates to:
  /// **'Search returned nothing...'**
  String get searchViewNoResults;

  /// No description provided for @adaptiveShellSelectChat.
  ///
  /// In en, this message translates to:
  /// **'Select a chat'**
  String get adaptiveShellSelectChat;

  /// No description provided for @settingsTabPhotoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Photo deleted'**
  String get settingsTabPhotoDeleted;

  /// No description provided for @settingsTabPhotoDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the photo: {error}'**
  String settingsTabPhotoDeleteFailed(String error);

  /// No description provided for @settingsTabAppVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String settingsTabAppVersion(String version, String build);

  /// No description provided for @settingsTabCloudStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Via MAX'**
  String get settingsTabCloudStorageSubtitle;

  /// No description provided for @settingsTabCloudStorageWhitelistTitle.
  ///
  /// In en, this message translates to:
  /// **'Works under whitelists'**
  String get settingsTabCloudStorageWhitelistTitle;

  /// No description provided for @settingsTabCloudStorageWhitelistBody.
  ///
  /// In en, this message translates to:
  /// **'You can send files even when your internet access is restricted.'**
  String get settingsTabCloudStorageWhitelistBody;

  /// No description provided for @settingsTabCloudStorageLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Files up to 4 GB, no limit on count.'**
  String get settingsTabCloudStorageLimitsTitle;

  /// No description provided for @settingsTabCloudStorageLimitsBody.
  ///
  /// In en, this message translates to:
  /// **'You can store a massive amount of data.'**
  String get settingsTabCloudStorageLimitsBody;

  /// No description provided for @settingsTabCloudStoragePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'File privacy is not guaranteed'**
  String get settingsTabCloudStoragePrivacyTitle;

  /// No description provided for @settingsTabCloudStoragePrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Cloud storage works through your account on the MAX server, so the right people can still look at it.'**
  String get settingsTabCloudStoragePrivacyBody;

  /// No description provided for @settingsTabLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out of your account?'**
  String get settingsTabLogoutConfirmTitle;

  /// No description provided for @settingsTabLogoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Account data will be removed from this device.'**
  String get settingsTabLogoutConfirmBody;

  /// No description provided for @settingsTabLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsTabLogoutConfirm;

  /// No description provided for @settingsTabLogoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t log out: {error}'**
  String settingsTabLogoutFailed(String error);

  /// No description provided for @settingsTabSferumSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Sferum'**
  String get settingsTabSferumSignIn;

  /// No description provided for @settingsTabSferumTitle.
  ///
  /// In en, this message translates to:
  /// **'Sferum'**
  String get settingsTabSferumTitle;

  /// No description provided for @settingsTabCloudStorageBeta.
  ///
  /// In en, this message translates to:
  /// **'Cloud storage [BETA]'**
  String get settingsTabCloudStorageBeta;

  /// No description provided for @settingsTabDevelopers.
  ///
  /// In en, this message translates to:
  /// **'For developers'**
  String get settingsTabDevelopers;

  /// No description provided for @settingsTabLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsTabLogout;

  /// No description provided for @settingsTabOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get settingsTabOnline;

  /// No description provided for @settingsTabLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {time}'**
  String settingsTabLastSeen(String time);

  /// No description provided for @settingsTabOffline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get settingsTabOffline;

  /// No description provided for @folderEditTypeContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get folderEditTypeContacts;

  /// No description provided for @folderEditTypeNonContacts.
  ///
  /// In en, this message translates to:
  /// **'Non-contacts'**
  String get folderEditTypeNonContacts;

  /// No description provided for @folderEditTypeChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get folderEditTypeChannels;

  /// No description provided for @folderEditTypeBots.
  ///
  /// In en, this message translates to:
  /// **'Bots'**
  String get folderEditTypeBots;

  /// No description provided for @folderEditSavedMessages.
  ///
  /// In en, this message translates to:
  /// **'Saved Messages'**
  String get folderEditSavedMessages;

  /// No description provided for @folderEditNoActiveAccount.
  ///
  /// In en, this message translates to:
  /// **'No active account'**
  String get folderEditNoActiveAccount;

  /// No description provided for @folderEditSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the folder'**
  String get folderEditSaveFailed;

  /// No description provided for @folderEditDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the folder “{title}”? The chats will stay where they are.'**
  String folderEditDeleteConfirm(String title);

  /// No description provided for @folderEditDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the folder'**
  String get folderEditDeleteFailed;

  /// No description provided for @folderEditNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get folderEditNewTitle;

  /// No description provided for @folderEditEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit folder'**
  String get folderEditEditTitle;

  /// No description provided for @folderEditNameHint.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderEditNameHint;

  /// No description provided for @folderEditChatTypesSection.
  ///
  /// In en, this message translates to:
  /// **'CHAT TYPES'**
  String get folderEditChatTypesSection;

  /// No description provided for @folderEditChatsSection.
  ///
  /// In en, this message translates to:
  /// **'CHATS AND CHANNELS'**
  String get folderEditChatsSection;

  /// No description provided for @folderEditSavedMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Messages to yourself'**
  String get folderEditSavedMessagesSubtitle;

  /// No description provided for @folderEditShowOnlySection.
  ///
  /// In en, this message translates to:
  /// **'SHOW ONLY'**
  String get folderEditShowOnlySection;

  /// No description provided for @folderEditNotMutedChats.
  ///
  /// In en, this message translates to:
  /// **'Chats with notifications on'**
  String get folderEditNotMutedChats;

  /// No description provided for @folderEditUnreadChats.
  ///
  /// In en, this message translates to:
  /// **'Unread chats'**
  String get folderEditUnreadChats;

  /// No description provided for @folderEditClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get folderEditClearSelection;

  /// No description provided for @folderEditDeleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get folderEditDeleteFolder;

  /// No description provided for @folderEditCreate.
  ///
  /// In en, this message translates to:
  /// **'Create folder'**
  String get folderEditCreate;

  /// No description provided for @composerInputMuteNotifications.
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get composerInputMuteNotifications;

  /// No description provided for @composerInputForwardFromYou.
  ///
  /// In en, this message translates to:
  /// **'Forwarding your message'**
  String get composerInputForwardFromYou;

  /// No description provided for @composerInputForwardMessage.
  ///
  /// In en, this message translates to:
  /// **'Forwarding a message'**
  String get composerInputForwardMessage;

  /// No description provided for @composerInputForwardFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarding from {name}'**
  String composerInputForwardFrom(String name);

  /// No description provided for @composerInputForwardCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Forwarding: 1 message} other{Forwarding: {count} messages}}'**
  String composerInputForwardCount(int count);

  /// No description provided for @composerInputReplyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}'**
  String composerInputReplyTo(String name);

  /// No description provided for @composerInputSwipeToCancel.
  ///
  /// In en, this message translates to:
  /// **'‹ Swipe left to cancel'**
  String get composerInputSwipeToCancel;

  /// No description provided for @composerInputSwipeToCancelHint.
  ///
  /// In en, this message translates to:
  /// **'‹ swipe left to cancel'**
  String get composerInputSwipeToCancelHint;

  /// No description provided for @composerInputHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'history is empty...'**
  String get composerInputHistoryEmpty;

  /// No description provided for @createGroupFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the group'**
  String get createGroupFailed;

  /// No description provided for @createGroupAvatarProcessFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t process the avatar'**
  String get createGroupAvatarProcessFailed;

  /// No description provided for @createGroupAvatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the avatar'**
  String get createGroupAvatarUploadFailed;

  /// No description provided for @createGroupSelectParticipants.
  ///
  /// In en, this message translates to:
  /// **'Select participants'**
  String get createGroupSelectParticipants;

  /// No description provided for @createGroupCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get createGroupCancel;

  /// No description provided for @createGroupNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get createGroupNext;

  /// No description provided for @createGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroupTitle;

  /// No description provided for @createGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get createGroupNameHint;

  /// No description provided for @createGroupCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get createGroupCreating;

  /// No description provided for @createGroupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createGroupCreate;

  /// No description provided for @controlBubbleQuotedTitle.
  ///
  /// In en, this message translates to:
  /// **'“{title}”'**
  String controlBubbleQuotedTitle(String title);

  /// No description provided for @controlBubbleCreatedByMe.
  ///
  /// In en, this message translates to:
  /// **' created the chat'**
  String get controlBubbleCreatedByMe;

  /// No description provided for @controlBubbleCreatedByOther.
  ///
  /// In en, this message translates to:
  /// **' created the chat'**
  String get controlBubbleCreatedByOther;

  /// No description provided for @controlBubbleAddedByMe.
  ///
  /// In en, this message translates to:
  /// **' added '**
  String get controlBubbleAddedByMe;

  /// No description provided for @controlBubbleAddedByOther.
  ///
  /// In en, this message translates to:
  /// **' added '**
  String get controlBubbleAddedByOther;

  /// No description provided for @controlBubbleLeftByMe.
  ///
  /// In en, this message translates to:
  /// **' left the chat'**
  String get controlBubbleLeftByMe;

  /// No description provided for @controlBubbleLeftByOther.
  ///
  /// In en, this message translates to:
  /// **' left the chat'**
  String get controlBubbleLeftByOther;

  /// No description provided for @controlBubbleJoinedByMe.
  ///
  /// In en, this message translates to:
  /// **' joined the chat'**
  String get controlBubbleJoinedByMe;

  /// No description provided for @controlBubbleJoinedByOther.
  ///
  /// In en, this message translates to:
  /// **' joined the chat'**
  String get controlBubbleJoinedByOther;

  /// No description provided for @controlBubblePinnedByMe.
  ///
  /// In en, this message translates to:
  /// **' pinned a message'**
  String get controlBubblePinnedByMe;

  /// No description provided for @controlBubblePinnedByOther.
  ///
  /// In en, this message translates to:
  /// **' pinned a message'**
  String get controlBubblePinnedByOther;

  /// No description provided for @controlBubbleRenamedByMe.
  ///
  /// In en, this message translates to:
  /// **' changed the chat name'**
  String get controlBubbleRenamedByMe;

  /// No description provided for @controlBubbleRenamedByOther.
  ///
  /// In en, this message translates to:
  /// **' changed the chat name'**
  String get controlBubbleRenamedByOther;

  /// No description provided for @controlBubbleRenamedTo.
  ///
  /// In en, this message translates to:
  /// **' to {title}'**
  String controlBubbleRenamedTo(String title);

  /// No description provided for @controlBubblePhotoChangedByMe.
  ///
  /// In en, this message translates to:
  /// **' changed the chat photo'**
  String get controlBubblePhotoChangedByMe;

  /// No description provided for @controlBubblePhotoChangedByOther.
  ///
  /// In en, this message translates to:
  /// **' changed the chat photo'**
  String get controlBubblePhotoChangedByOther;

  /// No description provided for @controlBubbleBotStarted.
  ///
  /// In en, this message translates to:
  /// **'Bot started'**
  String get controlBubbleBotStarted;

  /// No description provided for @maxLinkNoPublicLink.
  ///
  /// In en, this message translates to:
  /// **'This profile has no public link'**
  String get maxLinkNoPublicLink;

  /// No description provided for @maxLinkShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share the link'**
  String get maxLinkShareFailed;

  /// No description provided for @maxLinkOpenProfileFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the profile'**
  String get maxLinkOpenProfileFailed;

  /// No description provided for @maxLinkOpenChatFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the chat'**
  String get maxLinkOpenChatFailed;

  /// No description provided for @maxLinkJoinThisChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Join this chat?'**
  String get maxLinkJoinThisChatConfirm;

  /// No description provided for @maxLinkJoinChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Join “{title}”?'**
  String maxLinkJoinChatConfirm(String title);

  /// No description provided for @maxLinkProfileFallback.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get maxLinkProfileFallback;

  /// No description provided for @videoNoteCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get videoNoteCameraUnavailable;

  /// No description provided for @videoNoteNeedCameraAndMic.
  ///
  /// In en, this message translates to:
  /// **'Video messages need access to the camera and microphone'**
  String get videoNoteNeedCameraAndMic;

  /// No description provided for @videoNoteNoMicAccess.
  ///
  /// In en, this message translates to:
  /// **'No access to the microphone'**
  String get videoNoteNoMicAccess;

  /// No description provided for @videoNoteNoCameraAccess.
  ///
  /// In en, this message translates to:
  /// **'No access to the camera'**
  String get videoNoteNoCameraAccess;

  /// No description provided for @videoNoteCameraNotReady.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t ready yet'**
  String get videoNoteCameraNotReady;

  /// No description provided for @videoNoteStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start recording the video message'**
  String get videoNoteStartFailed;

  /// No description provided for @videoNoteSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the video message'**
  String get videoNoteSaveFailed;

  /// No description provided for @scheduleTimePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Send later'**
  String get scheduleTimePickerTitle;

  /// No description provided for @scheduleTimePickerToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get scheduleTimePickerToday;

  /// No description provided for @scheduleTimePickerTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get scheduleTimePickerTomorrow;

  /// No description provided for @scheduleTimePickerTodayLower.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get scheduleTimePickerTodayLower;

  /// No description provided for @scheduleTimePickerTomorrowLower.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get scheduleTimePickerTomorrowLower;

  /// No description provided for @scheduleTimePickerSendAt.
  ///
  /// In en, this message translates to:
  /// **'Send {day} at {time}'**
  String scheduleTimePickerSendAt(String day, String time);

  /// No description provided for @scheduleTimePickerPastTime.
  ///
  /// In en, this message translates to:
  /// **'The time must be in the future'**
  String get scheduleTimePickerPastTime;

  /// No description provided for @chatBackgroundSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the wallpaper'**
  String get chatBackgroundSaveFailed;

  /// No description provided for @chatBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat background'**
  String get chatBackgroundTitle;

  /// No description provided for @chatBackgroundDescription.
  ///
  /// In en, this message translates to:
  /// **'This wallpaper applies to every chat that doesn\'t have its own background.'**
  String get chatBackgroundDescription;

  /// No description provided for @chatBackgroundTintTitle.
  ///
  /// In en, this message translates to:
  /// **'Match the interface to the wallpaper'**
  String get chatBackgroundTintTitle;

  /// No description provided for @chatBackgroundTintSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app\'s accent color will be taken from the background'**
  String get chatBackgroundTintSubtitle;

  /// No description provided for @chatBackgroundPick.
  ///
  /// In en, this message translates to:
  /// **'Choose wallpaper'**
  String get chatBackgroundPick;

  /// No description provided for @chatBackgroundSampleIncoming.
  ///
  /// In en, this message translates to:
  /// **'One background for all chats'**
  String get chatBackgroundSampleIncoming;

  /// No description provided for @chatBackgroundSampleOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Beautiful ✨'**
  String get chatBackgroundSampleOutgoing;

  /// No description provided for @chatWallpaperPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get chatWallpaperPreviewTitle;

  /// No description provided for @chatWallpaperPreviewBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get chatWallpaperPreviewBlur;

  /// No description provided for @chatWallpaperPreviewMotion.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get chatWallpaperPreviewMotion;

  /// No description provided for @chatWallpaperPreviewDimming.
  ///
  /// In en, this message translates to:
  /// **'Dimming'**
  String get chatWallpaperPreviewDimming;

  /// No description provided for @chatWallpaperPreviewSampleIncoming.
  ///
  /// In en, this message translates to:
  /// **'How about new wallpaper for this chat?'**
  String get chatWallpaperPreviewSampleIncoming;

  /// No description provided for @chatWallpaperPreviewSampleOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Great idea.'**
  String get chatWallpaperPreviewSampleOutgoing;

  /// No description provided for @stickerPanelLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load stickers'**
  String get stickerPanelLoadFailed;

  /// No description provided for @stickerPanelEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stickers'**
  String get stickerPanelEmpty;

  /// No description provided for @stickerPanelEmojiTab.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get stickerPanelEmojiTab;

  /// No description provided for @stickerPanelStickersTab.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get stickerPanelStickersTab;

  /// No description provided for @callBubbleGroupVideo.
  ///
  /// In en, this message translates to:
  /// **'Group video call'**
  String get callBubbleGroupVideo;

  /// No description provided for @callBubbleCanceledVideo.
  ///
  /// In en, this message translates to:
  /// **'Canceled video call'**
  String get callBubbleCanceledVideo;

  /// No description provided for @callBubbleMissedVideo.
  ///
  /// In en, this message translates to:
  /// **'Missed video call'**
  String get callBubbleMissedVideo;

  /// No description provided for @callBubbleOutgoingVideo.
  ///
  /// In en, this message translates to:
  /// **'Outgoing video call'**
  String get callBubbleOutgoingVideo;

  /// No description provided for @callBubbleIncomingVideo.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get callBubbleIncomingVideo;

  /// No description provided for @callBubbleCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled call'**
  String get callBubbleCanceled;

  /// No description provided for @callBubbleMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed call'**
  String get callBubbleMissed;

  /// No description provided for @callBubbleOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing call'**
  String get callBubbleOutgoing;

  /// No description provided for @maxRouteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Link not supported: {route}'**
  String maxRouteUnsupported(String route);

  /// No description provided for @maxRouteIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete link: {route}'**
  String maxRouteIncomplete(String route);

  /// No description provided for @cloudStorageScreenExpired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get cloudStorageScreenExpired;

  /// No description provided for @cloudStorageScreenExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'{days} d'**
  String cloudStorageScreenExpiresInDays(int days);

  /// No description provided for @cloudStorageScreenExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String cloudStorageScreenExpiresInHours(int hours, int minutes);

  /// No description provided for @cloudStorageScreenExpiresInMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String cloudStorageScreenExpiresInMinutes(int minutes);

  /// No description provided for @webQrScanTitle.
  ///
  /// In en, this message translates to:
  /// **'QR for web and desktop'**
  String get webQrScanTitle;

  /// No description provided for @webQrScanCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get webQrScanCameraUnavailable;

  /// No description provided for @webQrScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code on your computer screen'**
  String get webQrScanHint;

  /// No description provided for @messageRowEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get messageRowEditTitle;

  /// No description provided for @locationBubbleOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in maps'**
  String get locationBubbleOpenInMaps;

  /// No description provided for @commandArgumentsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel command'**
  String get commandArgumentsCancel;

  /// No description provided for @commandArgumentsOptional.
  ///
  /// In en, this message translates to:
  /// **'{name} · optional'**
  String commandArgumentsOptional(String name);

  /// No description provided for @storyRingYourStory.
  ///
  /// In en, this message translates to:
  /// **'Your story'**
  String get storyRingYourStory;

  /// No description provided for @formatBytesB.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String formatBytesB(String value);

  /// No description provided for @formatBytesKb.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String formatBytesKb(String value);

  /// No description provided for @formatBytesMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String formatBytesMb(String value);

  /// No description provided for @formatBytesGb.
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String formatBytesGb(String value);

  /// No description provided for @formatApproxSeconds.
  ///
  /// In en, this message translates to:
  /// **'{whole}.{fraction} s'**
  String formatApproxSeconds(String whole, String fraction);

  /// No description provided for @formatApproxMinutes.
  ///
  /// In en, this message translates to:
  /// **'{whole}.{fraction} min'**
  String formatApproxMinutes(String whole, String fraction);

  /// No description provided for @lastSeenJustNow.
  ///
  /// In en, this message translates to:
  /// **'Last seen just now'**
  String get lastSeenJustNow;

  /// No description provided for @lastSeenMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Last seen {minutes} min ago'**
  String lastSeenMinutesAgo(int minutes);

  /// No description provided for @lastSeenHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'Last seen {hours} h ago'**
  String lastSeenHoursAgo(int hours);

  /// No description provided for @lastSeenDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Last seen {days} d ago'**
  String lastSeenDaysAgo(int days);

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @connectionStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connectionStatusConnecting;

  /// No description provided for @connectionStatusWaitingForNetwork.
  ///
  /// In en, this message translates to:
  /// **'Waiting for network...'**
  String get connectionStatusWaitingForNetwork;

  /// No description provided for @chatActivityTyping.
  ///
  /// In en, this message translates to:
  /// **'Typing...'**
  String get chatActivityTyping;

  /// No description provided for @chatActivityChoosingSticker.
  ///
  /// In en, this message translates to:
  /// **'Choosing a sticker...'**
  String get chatActivityChoosingSticker;

  /// No description provided for @chatActivityTypingOne.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing...'**
  String chatActivityTypingOne(String name);

  /// No description provided for @chatActivityTypingTwo.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second} are typing...'**
  String chatActivityTypingTwo(String first, String second);

  /// No description provided for @chatActivityTypingMany.
  ///
  /// In en, this message translates to:
  /// **'{name} and {count} more are typing...'**
  String chatActivityTypingMany(String name, int count);

  /// No description provided for @chatActivityStickerOne.
  ///
  /// In en, this message translates to:
  /// **'{name} is choosing a sticker...'**
  String chatActivityStickerOne(String name);

  /// No description provided for @chatActivityStickerTwo.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second} are choosing stickers...'**
  String chatActivityStickerTwo(String first, String second);

  /// No description provided for @chatActivityStickerMany.
  ///
  /// In en, this message translates to:
  /// **'{name} and {count} more are choosing stickers...'**
  String chatActivityStickerMany(String name, int count);

  /// No description provided for @shareTitleMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get shareTitleMessage;

  /// No description provided for @shareTitlePhoto.
  ///
  /// In en, this message translates to:
  /// **'Send photo'**
  String get shareTitlePhoto;

  /// No description provided for @shareTitlePhotos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Send {count} photo} other{Send {count} photos}}'**
  String shareTitlePhotos(int count);

  /// No description provided for @shareTitleVideos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Send {count} video} other{Send {count} videos}}'**
  String shareTitleVideos(int count);

  /// No description provided for @shareTitleFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Send {count} file} other{Send {count} files}}'**
  String shareTitleFiles(int count);

  /// No description provided for @shareSubtitleToChats.
  ///
  /// In en, this message translates to:
  /// **'To {names}'**
  String shareSubtitleToChats(String names);

  /// No description provided for @shareSubtitleChatCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{To {count} chat} other{To {count} chats}}'**
  String shareSubtitleChatCount(int count);

  /// No description provided for @pluginPermissionChatWrite.
  ///
  /// In en, this message translates to:
  /// **'Send messages'**
  String get pluginPermissionChatWrite;

  /// No description provided for @pluginPermissionChatEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit sent messages'**
  String get pluginPermissionChatEdit;

  /// No description provided for @pluginPermissionUiNotify.
  ///
  /// In en, this message translates to:
  /// **'Show notifications'**
  String get pluginPermissionUiNotify;

  /// No description provided for @pluginPermissionContactRead.
  ///
  /// In en, this message translates to:
  /// **'Read the chat partner\'s data'**
  String get pluginPermissionContactRead;

  /// No description provided for @pluginPermissionReplyRead.
  ///
  /// In en, this message translates to:
  /// **'Read the message the command replies to'**
  String get pluginPermissionReplyRead;

  /// No description provided for @pluginPermissionNetwork.
  ///
  /// In en, this message translates to:
  /// **'Internet access'**
  String get pluginPermissionNetwork;

  /// No description provided for @pluginPermissionPhotoWrite.
  ///
  /// In en, this message translates to:
  /// **'Send photos'**
  String get pluginPermissionPhotoWrite;

  /// No description provided for @pluginPermissionFileWrite.
  ///
  /// In en, this message translates to:
  /// **'Send files'**
  String get pluginPermissionFileWrite;

  /// No description provided for @pluginPermissionStorage.
  ///
  /// In en, this message translates to:
  /// **'Plugin local storage'**
  String get pluginPermissionStorage;

  /// No description provided for @pluginUpdateNewPermissions.
  ///
  /// In en, this message translates to:
  /// **'The update requests new permissions: {permissions}'**
  String pluginUpdateNewPermissions(String permissions);

  /// No description provided for @transcriptionNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t recognize the voice'**
  String get transcriptionNotRecognized;

  /// No description provided for @chatWallpaperThemeOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get chatWallpaperThemeOcean;

  /// No description provided for @chatWallpaperThemeSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get chatWallpaperThemeSunset;

  /// No description provided for @chatWallpaperThemeLavender.
  ///
  /// In en, this message translates to:
  /// **'Lavender'**
  String get chatWallpaperThemeLavender;

  /// No description provided for @chatWallpaperThemeMint.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get chatWallpaperThemeMint;

  /// No description provided for @chatWallpaperThemeGraphite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get chatWallpaperThemeGraphite;

  /// No description provided for @chatWallpaperThemeSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get chatWallpaperThemeSky;

  /// No description provided for @chatWallpaperThemePeach.
  ///
  /// In en, this message translates to:
  /// **'Peach'**
  String get chatWallpaperThemePeach;

  /// No description provided for @chatWallpaperThemeForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get chatWallpaperThemeForest;

  /// No description provided for @chatWallpaperThemeGrape.
  ///
  /// In en, this message translates to:
  /// **'Grape'**
  String get chatWallpaperThemeGrape;

  /// No description provided for @chatWallpaperThemeNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get chatWallpaperThemeNight;

  /// No description provided for @chatWallpaperThemeRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get chatWallpaperThemeRose;

  /// No description provided for @chatWallpaperThemeAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get chatWallpaperThemeAmber;

  /// No description provided for @mediaSaveFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'file not found'**
  String get mediaSaveFileNotFound;

  /// No description provided for @mediaSaveNoGalleryAccess.
  ///
  /// In en, this message translates to:
  /// **'no access to the gallery'**
  String get mediaSaveNoGalleryAccess;

  /// No description provided for @commandShrugDescription.
  ///
  /// In en, this message translates to:
  /// **'send a kaomoji'**
  String get commandShrugDescription;

  /// No description provided for @scheduleTimePickerDayLabel.
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {date}'**
  String scheduleTimePickerDayLabel(String weekday, String date);

  /// No description provided for @avatarEditorSetPhoto.
  ///
  /// In en, this message translates to:
  /// **'Set photo'**
  String get avatarEditorSetPhoto;

  /// No description provided for @avatarEditorDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get avatarEditorDraw;

  /// No description provided for @avatarPickerFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a photo from files'**
  String get avatarPickerFilesTitle;

  /// No description provided for @avatarPickerFilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If the photo you need isn\'t in the gallery'**
  String get avatarPickerFilesSubtitle;
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
