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
  /// **'Log in to Komet'**
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

  /// No description provided for @loginPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'(000) 000-00-00'**
  String get loginPhoneHint;

  /// No description provided for @loginOtherSignInMethods.
  ///
  /// In en, this message translates to:
  /// **'Other sign-in methods'**
  String get loginOtherSignInMethods;

  /// No description provided for @loginTermsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use «Komet»'**
  String get loginTermsLink;

  /// No description provided for @loginTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use «Komet»'**
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
  /// **'Please read the Terms of Use «Komet»'**
  String get loginReadTermsNotification;

  /// No description provided for @loginSpoofRedacted.
  ///
  /// In en, this message translates to:
  /// **'Spoof redaction'**
  String get loginSpoofRedacted;

  /// No description provided for @loginProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get loginProxy;

  /// No description provided for @loginSignInWithQr.
  ///
  /// In en, this message translates to:
  /// **'Log in with QR code'**
  String get loginSignInWithQr;

  /// No description provided for @loginSignInWithToken.
  ///
  /// In en, this message translates to:
  /// **'Log in with token'**
  String get loginSignInWithToken;

  /// No description provided for @loginSignInWithSessionFile.
  ///
  /// In en, this message translates to:
  /// **'Log in with session file'**
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
