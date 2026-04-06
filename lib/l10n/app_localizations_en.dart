// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginTitle => 'Log in to Komet';

  @override
  String get loginSubtitle =>
      'Check your country code and enter your\nphone number.';

  @override
  String get loginCountry => 'Country';

  @override
  String get loginPhoneNumber => 'Phone number';

  @override
  String get loginPhoneHint => '(000) 000-00-00';

  @override
  String get loginOtherSignInMethods => 'Other sign-in methods';

  @override
  String get loginTermsLink => 'Terms of Use «Komet»';

  @override
  String get loginTermsOfUse => 'Terms of Use «Komet»';

  @override
  String get loginConfirmPhoneTitle => 'Is this the correct number?';

  @override
  String get loginEdit => 'Change';

  @override
  String get loginDone => 'Done';

  @override
  String get loginReadTermsNotification =>
      'Please read the Terms of Use «Komet»';

  @override
  String get loginSpoofRedacted => 'Spoof redaction';

  @override
  String get loginProxy => 'Proxy';

  @override
  String get loginSignInWithQr => 'Log in with QR code';

  @override
  String get loginSignInWithToken => 'Log in with token';

  @override
  String get loginSignInWithSessionFile => 'Log in with session file';

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
}
