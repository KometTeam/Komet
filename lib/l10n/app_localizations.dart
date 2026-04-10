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
  /// **'Choose a device type for preset generation. Tapping \"Generate\" will only use presets of the selected type.'**
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
