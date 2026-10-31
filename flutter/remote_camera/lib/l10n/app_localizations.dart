import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ko'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Webcam & Screen Saver'**
  String get appName;

  /// No description provided for @homeIntro.
  ///
  /// In en, this message translates to:
  /// **'A phone left at home sends the camera. On the phone you carry, enter only the home camera IP to watch and to turn home devices on or off. Away from home a Wi‑Fi IP will not work—use Tailscale with the same account, or open a router port. With Tailscale, enter the 100.x IP shown on the home phone.'**
  String get homeIntro;

  /// No description provided for @homeWindows.
  ///
  /// In en, this message translates to:
  /// **'The same video can run on Windows as a screensaver and as the desktop background. On a Windows PC, open the link below to download RemoteCamSaver-Setup.exe, then run it. IP-only setup works—enter the home camera IP; port and path are added for you.\nhttps://github.com/anyethernet/screen_saver/releases/latest/download/RemoteCamSaver-Setup.exe'**
  String get homeWindows;

  /// No description provided for @downloadWindows.
  ///
  /// In en, this message translates to:
  /// **'Download the Windows installer'**
  String get downloadWindows;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacy;

  /// No description provided for @openPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Open the policy on GitHub'**
  String get openPrivacy;

  /// No description provided for @homeCamera.
  ///
  /// In en, this message translates to:
  /// **'Home camera'**
  String get homeCamera;

  /// No description provided for @homeCameraBody.
  ///
  /// In en, this message translates to:
  /// **'Send this phone’s camera.'**
  String get homeCameraBody;

  /// No description provided for @away.
  ///
  /// In en, this message translates to:
  /// **'Watch away'**
  String get away;

  /// No description provided for @awayBody.
  ///
  /// In en, this message translates to:
  /// **'Watch the home video and control devices.'**
  String get awayBody;

  /// No description provided for @lastRole.
  ///
  /// In en, this message translates to:
  /// **'Last role you used'**
  String get lastRole;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @cameraSettings.
  ///
  /// In en, this message translates to:
  /// **'Camera settings'**
  String get cameraSettings;

  /// No description provided for @viewerSettings.
  ///
  /// In en, this message translates to:
  /// **'Viewer settings'**
  String get viewerSettings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get languageKorean;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparing;

  /// No description provided for @stopSending.
  ///
  /// In en, this message translates to:
  /// **'Stop sending'**
  String get stopSending;

  /// No description provided for @startSending.
  ///
  /// In en, this message translates to:
  /// **'Start sending'**
  String get startSending;

  /// No description provided for @viewerIp.
  ///
  /// In en, this message translates to:
  /// **'Home camera IP'**
  String get viewerIp;

  /// No description provided for @viewerIpHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter only the IP shown on the home camera phone. The port and video path are added for you.'**
  String get viewerIpHelp;

  /// No description provided for @screensaver.
  ///
  /// In en, this message translates to:
  /// **'Screensaver'**
  String get screensaver;

  /// No description provided for @enterIpInSettings.
  ///
  /// In en, this message translates to:
  /// **'Enter the home camera IP in settings.'**
  String get enterIpInSettings;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About this app'**
  String get aboutTitle;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Webcam & Screen Saver uses an Android phone left at home as the camera, and the phone you carry as the viewer. Enter only the home camera IP. Port 8787 and the video path are added for you. An upright phone sends a tall picture. A phone on its side sends a wide picture. On and off commands for home devices run on the home phone. Away from home, Tailscale with the same account is the easiest option; router port forwarding also works.'**
  String get aboutBody;

  /// No description provided for @aboutWindows.
  ///
  /// In en, this message translates to:
  /// **'The Windows program can fill the screen as a screensaver. In its settings, Show as background plays the same video behind the desktop icons. Moving the mouse closes the screensaver. The desktop background stays on. On a Windows PC, download the installer from the link below and run RemoteCamSaver-Setup.exe.\nhttps://github.com/anyethernet/screen_saver/releases/latest/download/RemoteCamSaver-Setup.exe'**
  String get aboutWindows;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Webcam & Screen Saver does not create a developer account. Video moves only between the home phone and the viewer, over Tailscale or an address you open. The developer server does not store video, accounts, or location history.\n\nCamera permission is used only when this phone is the home camera. Network permission is used to send and receive video. Nearby discovery looks for devices on the same home network.\n\nIf you use Tailscale, sign-in stays in the Tailscale app and follows Tailscale’s policy.\n\nThe GitHub account anyethernet publishes this app.\nPrivacy manager: Kim Judong\nContact: https://github.com/anyethernet'**
  String get privacyBody;
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
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
